$session = New-Object Microsoft.PowerShell.Commands.WebRequestSession
$session.Cookies.Add((New-Object System.Net.Cookie("__cflb", "***REDACTED***", "/", "connect.garmin.com")))
$session.Cookies.Add((New-Object System.Net.Cookie("notice_behavior", "none", "/", "connect.garmin.com")))
$session.Cookies.Add((New-Object System.Net.Cookie("_cfuvid", "***REDACTED***", "/", "connect.garmin.com")))
$session.Cookies.Add((New-Object System.Net.Cookie("GarminUserPrefs", "en-US", "/", "connect.garmin.com")))
$session.Cookies.Add((New-Object System.Net.Cookie("GarminUserPrefs", "en", "/", "connect.garmin.com")))
$session.Cookies.Add((New-Object System.Net.Cookie("__cfruid", "***REDACTED***", "/", "connect.garmin.com")))
$session.Cookies.Add((New-Object System.Net.Cookie("GARMIN-SSO", "1", "/", "connect.garmin.com")))
$session.Cookies.Add((New-Object System.Net.Cookie("GARMIN-SSO-CUST-GUID", "***REDACTED***", "/", "connect.garmin.com")))
$session.Cookies.Add((New-Object System.Net.Cookie("SESSIONID", "***REDACTED***", "/", "connect.garmin.com")))
$session.Cookies.Add((New-Object System.Net.Cookie("JWT_WEB", "***REDACTED***", "/", "connect.garmin.com")))
$session.Cookies.Add((New-Object System.Net.Cookie("JWT_FGP", "***REDACTED***", "/", "connect.garmin.com")))
Invoke-WebRequest -UseBasicParsing -Uri "https://connect.garmin.com/activity-service/activity/18733101347" `
-Method POST `
-WebSession $session `
-UserAgent "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:137.0) Gecko/20100101 Firefox/137.0" `
-Headers @{
"Accept" = "application/json, text/javascript, */*; q=0.01"
  "Accept-Language" = "en-US,en;q=0.5"
  "Accept-Encoding" = "gzip, deflate, br, zstd"
  "NK" = "NT"
  "X-app-ver" = "5.11.2.1"
  "X-lang" = "en-US"
  "X-HTTP-Method-Override" = "PUT"
  "DI-Backend" = "connectapi.garmin.com"
  "Authorization" = "Bearer ***REDACTED***"
  "X-Requested-With" = "XMLHttpRequest"
  "sentry-trace" = "***REDACTED***"
  "baggage" = "sentry-environment=prod,sentry-release=connect%405.11.32,sentry-public_key=***REDACTED***,sentry-trace_id=***REDACTED***"
  "Origin" = "https://connect.garmin.com"
  "DNT" = "1"
  "Sec-GPC" = "1"
  "Referer" = "https://connect.garmin.com/modern/activity/18733101347"
  "Sec-Fetch-Dest" = "empty"
  "Sec-Fetch-Mode" = "cors"
  "Sec-Fetch-Site" = "same-origin"
  "Priority" = "u=0"
} `
-ContentType "application/json" `
-Body "{`"description`":`"Finally got Old Man Johnny out for a ride. Managed to hit some totally legit power numbers too. Definitely not a glitch.\n\nhttps://www.mybiketraffic.com/rides/view/335563\nhttps://di2stats.com/rides/view/122655`",`"activityId`":18733101347}"