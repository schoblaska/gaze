# https://stackoverflow.com/a/51886819

tell application "System Events"
  set frontmostProcess to first process where it is frontmost
  set appName to name of frontmostProcess
end tell

# tell application appName
#   set windowName to the name of the front window
# end tell

if appName is equal to "Safari" then
  tell application "Safari"
    set theURL to the URL of the current tab of the front window
  end tell
else if appName is equal to "Google Chrome" then
  tell application "Google Chrome"
    set theURL to the URL of the active tab of the front window
  end tell
else
  set theURL to ""
end if

set AppleScript's text item delimiters to "\t"
return {appName, theUrl} as text
