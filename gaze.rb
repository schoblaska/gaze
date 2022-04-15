require "sqlite3"
require "digest"

def init_db
  `mkdir -p tmp`
  `rm tmp/gaze.db`

  db = SQLite3::Database.new "tmp/gaze.db"

  db.execute <<-SQL
    create table subjects (
      hash varchar(64),
      app varchar(50),
      window varchar(50),
      host varchar(50),
      duration int,
      observed_at int
    );
  SQL

  db
end

# integer time in hundreths of seconds
def time(seconds_ago: 0)
  ((Time.now.to_f - seconds_ago) * 100).round
end

def record_gaze(db, since)
  app, window, url = `osascript gaze.scpt`.split("\t").map(&:strip)
  host_match = url.match(%r{https?:\/\/(www\.)?([^\/]+)})
  host = host_match ? host_match[2] : nil
  hash = Digest::SHA2.hexdigest([app, window, host].map(&:to_s).join("\t"))

  db.execute(
    "INSERT INTO subjects (hash, app, window, host, duration, observed_at) 
            VALUES (?, ?, ?, ?, ?, ?)",
    [hash, app, window, host, time - since, time]
  )
end

def print_gaze(db)
  db.execute("SELECT * FROM SUBJECTS") { |row| p row }
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
