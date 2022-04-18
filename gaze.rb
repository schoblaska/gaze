require "sqlite3"
require "digest"

# gaze will print the top PRINT_N observations (combination of app and host of
# browser URL) from the last WINDOW minutes, highlighting the active
# observation and the total observed time for each
WINDOW = 10
PRINT_N = 3
COLORS = {
  default: "\u001b[37;1m",
  active: "\u001b[35;1m",
  reset: "\u001b[0m",
  blank: "\u001b[37m"
}

def init_db
  `mkdir -p tmp`
  `rm tmp/gaze.db`

  db = SQLite3::Database.new "tmp/gaze.db"

  db.execute <<-SQL
    CREATE TABLE observations (
      hash varchar(64),
      app varchar(50),
      host varchar(50),
      duration int,
      observed_at int
    );

    CREATE INDEX index_observations_on_hash ON observations(hash);
  SQL

  db
end

# integer time in milliseconds
def time(seconds_ago: 0)
  ((Time.now.to_f - seconds_ago) * 1000).round
end

def pretty_time(ms)
  if ms < 60 * 1000
    "#{(ms / 1000.0).round}s"
  elsif ms < 60 * 60 * 1000
    "#{(ms / 60 / 1000.0).round}m"
  else
    hours = ms / 60 / 60 / 1000
    minutes = (ms - hours * 60 * 60 * 1000) / 60.0 / 1000
    "#{hours}h#{minutes.round}m"
  end
end

def record_gaze(db, since)
  app, url = `osascript gaze.scpt`.split("\t").map(&:strip)
  host_match = url ? url.match(%r{https?:\/\/(www\.)?([^\/]+)}) : nil
  host = host_match ? host_match[2] : nil
  hash = Digest::SHA2.hexdigest([app, host].map(&:to_s).join("\t"))

  db.execute(
    "INSERT INTO observations (hash, app, host, duration, observed_at) 
            VALUES (?, ?, ?, ?, ?)",
    [hash, app, host, time - since, time]
  )
end

def print_gaze(db, window = WINDOW, n = PRINT_N)
  top_recent = db.execute <<-SQL
    SELECT hash, app, host, SUM(duration) as sum_duration
    FROM observations
    WHERE observed_at > #{time(seconds_ago: window * 60)}
    GROUP BY hash
    ORDER BY sum_duration DESC
    LIMIT #{PRINT_N}
  SQL

  active = db.execute <<-SQL
    SELECT hash, app, host
    FROM observations
    ORDER BY observed_at DESC
    LIMIT 1
  SQL

  to_print =
    if top_recent.any? { |o| o[0] == active[0][0] }
      # the active observation is already in top_recent
      top_recent
    else
      top_recent[0, PRINT_N - 1] + active
    end

  lines =
    to_print.map do |obs|
      total = db.execute <<-SQL
        SELECT SUM(duration)
        FROM observations
        WHERE hash = '#{obs[0]}'
      SQL

      color = active[0][0] == obs[0] ? COLORS[:active] : COLORS[:default]
      print_time = "[#{pretty_time(total[0][0])}]".rjust(7, " ")

      "#{color} - #{print_time}: #{obs[2] || obs[1]}#{COLORS[:reset]}"
    end

  (PRINT_N - lines.count).times do
    lines << "#{COLORS[:blank]} -      []#{COLORS[:reset]}"
  end

  system("clear")
  puts "#{COLORS[:default]}Recent apps and websites:#{COLORS[:reset]}"
  lines.each { |l| puts l }
  puts
end

db = init_db
since = time
last_printed = nil

loop do
  record_gaze(db, since)

  if last_printed.nil? || last_printed < time(seconds_ago: 5)
    print_gaze(db)
    last_printed = time
  end

  since = time
  sleep 1
end
