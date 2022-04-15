def get
  app, window, url = `osascript gaze.scpt`.split("\t").map(&:strip)
  host_match = url.match(%r{https?:\/\/(www\.)?([^\/]+)})
  host = host_match ? host_match[2] : nil
  [app, window, url, host]
end

loop do
  p get
  sleep 1
end
