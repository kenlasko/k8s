PARAM(
)
$DataPath = '/garmin-data'
$ActivityFileType = 'FIT'
$Overwrite = 'Yes'
$DownloadOption = 'New'
$Destination = $DataPath
$TempDir = $DataPath

# Log into Garmin and pull the most recent activity
$Username = (Get-ChildItem env:GarminUser).Value 
$Password = (Get-ChildItem env:GarminPassword).Value 

$ProgramSettings = [PSCustomObject]@{
    GCProgramSettings = [PSCustomObject]@{
        BaseURLs  = [PSCustomObject]@{
            BaseLoginURL       = "https://sso.garmin.com/sso/login?service=https%3A%2F%2Fconnect.garmin.com%2Fmodern%2F&webhost=olaxpw-conctmodern004&source=https%3A%2F%2Fconnect.garmin.com%2Fnl-NL%2Fsignin&redirectAfterAccountLoginUrl=https%3A%2F%2Fconnect.garmin.com%2Fmodern%2F&redirectAfterAccountCreationUrl=https%3A%2F%2Fconnect.garmin.com%2Fmodern%2F&gauthHost=https%3A%2F%2Fsso.garmin.com%2Fsso&locale=nl_NL&id=gauth-widget&cssUrl=https%3A%2F%2Fstatic.garmincdn.com%2Fcom.garmin.connect%2Fui%2Fcss%2Fgauth-custom-v1.2-min.css&clientId=GarminConnect&rememberMeShown=true&rememberMeChecked=false&createAccountShown=true&openCreateAccount=false&usernameShown=false&displayNameShown=false&consumeServiceTicket=false&initialFocus=true&embedWidget=false&generateExtraServiceTicket=false&globalOptInShown=false&globalOptInChecked=false"
            OAuthUrl           = "https://connect.garmin.com/modern/di-oauth/exchange"
            PostLoginURL       = "https://connect.garmin.com/modern/"
            ActivitySearchURL  = "https://connect.garmin.com/activitylist-service/activities/search/activities?"
            GPXActivityBaseURL = "https://connect.garmin.com/download-service/export/gpx/activity/"
            TCXActivityBaseURL = "https://connect.garmin.com/download-service/export/tcx/activity/"
            FITActivityBaseURL = "https://connect.garmin.com/download-service/files/activity/"
            KMLActivityBaseURL = "https://connect.garmin.com/download-service/export/kml/activity/"
        }
        UserAgent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.0.0 Safari/537.36 Edg/123.0.0.0"
    }
}
"ProgramSettings: {0}" -f $ProgramSettings | ConvertTo-Json | Write-Verbose

$ProgramSettingsBaseURLNodes = $ProgramSettings.GCProgramSettings.BaseURLs | Get-Member -MemberType Properties | Select-Object name -ExpandProperty name
foreach ($n in $ProgramSettingsBaseURLNodes) {
    $variablename = $n
    New-Variable $n -Force
    Set-Variable -Name $variablename -Value  $($ProgramSettings.GCProgramSettings.BaseURLs.$n)
}
$UserAgent = $ProgramSettings.GCProgramSettings.UserAgent

$CookieFilename = ".GCDownloadStatus$ActivityFileType.cookie"
$CookieFileFullPath = ($Destination + "/" + $CookieFilename)

# Write process information:
Write-Host "INFO - Starting processing $ActivityFileType files from Garmin Connect with the following parameters:"
Write-Host "- Activity File Type = $ActivityFileType"
Write-Host "- Download Option = $DownloadOption"
Write-Host "- Destination = $Destination"
Write-Host "- Username = $Username"
Write-Host "- Overwrite = $Overwrite"

# Authenticate
Try {
    Write-Host "INFO - Connecting to Garmin Connect for user $Username" -ForegroundColor Gray
    "BaseLoginUrl: {0}" -f $BaseLoginURL | Write-Verbose
    $BaseLogin = Invoke-WebRequest -Uri $BaseLoginURL -SessionVariable GarminConnectSession

    $LoginForm = @{
        username                    = $Username
        password                    = $Password
        embed                       = 'false'
        'login-remember-checkbox'   = 'on'
        '_csrf'                     = $BaseLogin.InputFields | Where-Object {$_.name -eq '_csrf'} | Select-Object value -ExpandProperty value
    }

    $Di2Headers = @{
        "origin"                    = "https://sso.garmin.com";
        "authority"                 = "connect.garmin.com"
        "scheme"                    = "https"
        "path"                      = "/signin/"
        "pragma"                    = "no-cache"
        "cache-control"             = "no-cache"
        "dnt"                       = "1"
        "upgrade-insecure-requests" = "1"
        "user-agent"                = $UserAgent
        "accept"                    = "text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.9"
        "sec-fetch-site"            = "cross-site"
        "sec-fetch-mode"            = "navigate"
        "sec-fetch-user"            = "?1"
        "sec-fetch-dest"            = "document"
        "accept-language"           = "en,en-US;q=0.9,nl;q=0.8"
    }
    $Service = "service=https%3A%2F%2Fconnect.garmin.com%2Fmodern%2F"
    $BaseLogin = Invoke-RestMethod -Uri ($BaseLoginURL + "?" + $Service) -WebSession $GarminConnectSession -Method POST -Body $LoginForm -Headers $Di2Headers -UserAgent $UserAgent
}
Catch {
    Throw "Error with initial login to Garmin Connect."
}

# Get Cookies
"Read cookies" | Write-Verbose
$Cookies = $GarminConnectSession.Cookies.GetCookies($BaseLoginURL)

# Get SSO cookie
$SSOCookie = $Cookies | Where-Object name -EQ "CASTGC" | Select-Object value -ExpandProperty value
if ($SSOCookie.Length -lt 1) {
    Write-Error "ERROR - No valid SSO cookie found, wrong credentials?"
    break
}

Try {
    # Authenticate by using cookie
    "Post login authentication" | Write-Verbose
    $PostLogin = Invoke-RestMethod -Uri ($PostLoginURL + "?ticket=" + $SSOCookie) -WebSession $GarminConnectSession  -UserAgent $UserAgent
}
Catch {
    Throw "Error with cookie login to Garmin Connect."
}

# Get the bearer token
"Get bearer token" | Write-Verbose
$OAuthResult = Invoke-RestMethod -UseBasicParsing -Uri $OAuthUrl -Method POST -WebSession $GarminConnectSession -UserAgent $UserAgent -Headers @{
    "Accept"          = "application/json, text/plain, */*"
    "Accept-Language" = "en-US,en;q=0.5"
    "Accept-Encoding" = "gzip, deflate"
    "Referer"         = "https://connect.garmin.com/modern/"
    "NK"              = "NT"
    "Origin"          = "https://connect.garmin.com"
    "DNT"             = "1"
    "Sec-GPC"         = "1"
    "Sec-Fetch-Dest"  = "empty"
    "Sec-Fetch-Mode"  = "cors"
    "Sec-Fetch-Site"  = "same-origin"
    "TE"              = "trailers"
}

$GarminHeaders = @{
    "authority"          = "connect.garmin.com"
    "method"             = "GET"
    "path"               = $Path
    "scheme"             = "https"
    "accept"             = "application/json, text/javascript, */*; q=0.01"
    "accept-encoding"    = "gzip, deflate"
    "accept-language"    = "en,en-US;q=0.9,nl;q=0.8"
    "authorization"      = "Bearer {0}" -f $OAuthResult.access_token
    "baggage"            = "sentry-environment=prod,sentry-release=connect%404.77.317,sentry-public_key=f0377f25d5534ad589ab3a9634f25e71,sentry-trace_id=2ad3f9199d7245f48903717ee8de989e,sentry-sample_rate=1,sentry-sampled=true"
    "di-backend"         = "connectapi.garmin.com"
    "dnt"                = "1"
    "nk"                 = "NT"
    "referer"            = "https://connect.garmin.com/modern/activities"
    "sec-ch-ua"          = "`"Microsoft Edge`";v=`"123`", `"Not:A-Brand`";v=`"8`", `"Chromium`";v=`"123`""
    "sec-ch-ua-mobile"   = "?0"
    "sec-ch-ua-platform" = "`"Windows`""
    "sec-fetch-dest"     = "empty"
    "sec-fetch-mode"     = "cors"
    "sec-fetch-site"     = "same-origin"
    "x-lang"             = "en-US"
    "x-requested-with"   = "XMLHttpRequest"
}

# Set the correct activity download URL for the selected type.
switch ($ActivityFileType) {
    'TCX' { $ActivityBaseURL = $TCXActivityBaseURL }
    'GPX' { $ActivityBaseURL = $GPXActivityBaseURL }
    'KML' { $ActivityBaseURL = $KMLActivityBaseURL }
    Default { $ActivityBaseURL = $FITActivityBaseURL }
}
"ActivityFileType: {0}" -f $ActivityFileType | Write-Verbose

# Get activity pages and check if the connection is successfull
$ActivityList = @()
$PageSize = 100
$FirstRecord = 0
$Pages = 0
do {
    $Uri = [System.Uri]::new($ActivitySearchURL)
    $Path = "{0}limit={1}&start={2}" -f $Uri.PathAndQuery, $PageSize, $FirstRecord
    $GarminHeaders.Path = $Path
    $Url = "https://connect.garmin.com", $Path -join ""
    "Activity list url: {0}" -f $Url | Write-Verbose
    $SearchResults = Invoke-RestMethod -Uri $Url -Method get -WebSession $GarminConnectSession -ErrorAction SilentlyContinue -Headers $GarminHeaders
    $ActivityList += $SearchResults
    $FirstRecord = $FirstRecord + $PageSize
    $Pages++
}
until ($SearchResults.Count -eq 0)

if ($Pages -gt 0) { 
    Write-Host "SUCCESS - Successfully connected to Garmin Connect" -ForegroundColor Green 
} else {
    Write-Error "ERROR - Connection to Garmin Connect failed. Error:`n$($error[0])."
    break
}

# Validate delta cookie
$ErrorFound = $true
if (Test-Path $CookieFileFullPath -ErrorAction SilentlyContinue) {
    $DeltaCookie = Get-Content $CookieFileFullPath
    if (($DeltaCookie -match '^[0-9]*$') -and (($DeltaCookie | Measure-Object -Line).lines -eq 1) -and (($DeltaCookie | Measure-Object -Word).words -eq 1)) {
        $ErrorFound = $false
    }
}
if ($ErrorFound -eq $true) {
    Write-Host "A valid delta cookie not found. Exiting"
    break
}

# Get activities
$Activities = @()
Write-Host "INFO - Retrieving current status of your activities in Garmin Connect, please wait..."
foreach ($Activity in $ActivityList) {
    if ($($Activity.activityId) -gt $DeltaCookie) { $Activities += $Activity }
}

# Download activities in queue and unpack to destination location
Write-Host "INFO - Continue to process all retrieved activities, please wait..."
$ActivityFileType = $ActivityFileType.tolower()

$ActivityExportedCount = 0
foreach ($Activity in $Activities) {
    # Download files
    $Uri = [System.Uri]::new($ActivityBaseURL)
    $Path = "{0}{1}/" -f $Uri.PathAndQuery, $($Activity.activityID)
    $GarminHeaders.path = $Path
    $URL = $ActivityBaseURL, $($Activity.activityID) -Join ""
    "Download Url: {0}" -f $URL | Write-Verbose
    $OutputFileFullPath = Join-Path -Path $TempDir -ChildPath "$($Activity.activityID).zip"

    if (Test-Path $OutputFileFullPath) {
        # Allways overwrite temp files
        $null = Remove-Item $OutputFileFullPath -Force
    }
    Invoke-RestMethod -Uri $URL -WebSession $GarminConnectSession -Headers $GarminHeaders -OutFile $OutputFileFullPath

    # Unzip the activity files
    Expand-Archive -Path $OutputFileFullPath -DestinationPath $DataPath -Force
    $null = Remove-Item $OutputFileFullPath -Force

    $ActivityExportedCount++
}

# Setting naming parameters for having the file to a more readable format
$ActivityID = $Activity.activityId
$ActivityName = $Activity.activityName
$ActivityNotes = $Activity.description

$DownloadedFile = "$($ActivityID)_ACTIVITY.fit"
$FilePath = "$DataPath/$DownloadedFile"
Write-Host "INFO - FILENAME: $DownloadedFile"


###########################################################################################################################################
###################                                            Di2Stats Upload                                          ###################
###########################################################################################################################################
Try {
    Write-Host 'INFO - Logging into Di2stats.com'
    # Generate initial PHPSESSID
    $InitSessionID = -join ((0x30..0x39) + ( 0x61..0x7A) | Get-Random -Count 26  | % {[char]$_})

    # Get initial login data
    $Di2Session = New-Object Microsoft.PowerShell.Commands.WebRequestSession
    $Di2Session.UserAgent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/100.0.4896.60 Safari/537.36"
    $Di2Session.Cookies.Add((New-Object System.Net.Cookie("PHPSESSID", $InitSessionID, "/", "di2stats.com")))
    $Startup = Invoke-WebRequest -UseBasicParsing -Uri "https://di2stats.com/login" `
        -WebSession $Di2Session `
        -Headers @{
            "Accept"="text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.9"
            "Referer"="https://di2stats.com/"
            "Sec-Fetch-Dest"="document"
            "Sec-Fetch-Mode"="navigate"
            "Sec-Fetch-Site"="same-origin"
            "Sec-Fetch-User"="?1"
            "Upgrade-Insecure-Requests"="1"
        }
} Catch {
    Write-Host 'Error with initial login to Di2Stats.com' -ForegroundColor Red
    Write-Host $Error[0]
    $Di2Url = $NULL 
    Break       
}

# Login and get session cookie
$Di2Session = New-Object Microsoft.PowerShell.Commands.WebRequestSession
$Di2Session.UserAgent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/100.0.4896.60 Safari/537.36"
$Di2Session.Cookies.Add((New-Object System.Net.Cookie("PHPSESSID", $InitSessionID, "/", "di2stats.com")))
[string]$Di2StatsUser = (Get-ChildItem env:Di2StatsUser).Value
[string]$Di2StatsPassword = (Get-ChildItem env:Di2StatsPassword).Value

Try {
    $Di2Login = Invoke-WebRequest -UseBasicParsing -Uri "https://di2stats.com/login" `
        -Method "POST" `
        -MaximumRedirection 0 `
        -ErrorAction SilentlyContinue `
        -SkipHttpErrorCheck `
        -WebSession $Di2Session `
        -Headers @{
            "Accept"="text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.9"
            "Origin"="https://di2stats.com"
            "Referer"="https://di2stats.com/login"
            "Sec-Fetch-Dest"="document"
            "Sec-Fetch-Mode"="navigate"
            "Sec-Fetch-Site"="same-origin"
            "Sec-Fetch-User"="?1"
            "Upgrade-Insecure-Requests"="1"
        } `
        -ContentType "application/x-www-form-urlencoded" `
        -Body "_method=POST&data%5BUser%5D%5Busername%5D=$($Di2StatsUser)&data%5BUser%5D%5Bpassword%5D=$($Di2StatsPassword)&data%5BUser%5D%5Bremember_me%5D=0"
} Catch {
    Write-Host 'Error with login to Di2Stats.com' -ForegroundColor Red
    Write-Host $Error[0]
    Break   
}

Write-Host 'INFO - Getting Di2Stats session cookie'
$Cookie = $Di2Login.Headers.'Set-Cookie'
$RegEx = 'PHPSESSID=(\w{26});\ path=/$'
$Match = Select-String -InputObject $Cookie -Pattern $RegEx	
$SessionCookie = $Match.Matches.Groups[1].Value

Write-Host "INFO - Path to downloaded file: $FilePath"
$Uri = 'https://di2stats.com/import'

$Di2Headers = @{
    "Accept" = "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8"
    "Accept-Language" = "en-US,en;q=0.5"
    "Accept-Encoding" = "gzip, deflate, br, zstd"
    "Origin" = "https://di2stats.com"
    "Referer" = "https://di2stats.com/import"
    "Upgrade-Insecure-Requests" = "1"
    "Sec-Fetch-Dest" = "document"
    "Sec-Fetch-Mode" = "navigate"
    "Sec-Fetch-Site" = "same-origin"
    "Sec-Fetch-User" = "?1"
    "Priority" = "u=0, i"
  }

$boundary = "----WebKitFormBoundary" + ([System.Guid]::NewGuid().ToString("N"))
$LF = "`r`n"

# Prepare memory stream
$ms = New-Object System.IO.MemoryStream
$sw = New-Object System.IO.StreamWriter($ms, [System.Text.Encoding]::UTF8)

# Add form parts
$sw.Write("--$boundary$LF")
$sw.Write("Content-Disposition: form-data; name=`"_method`"$LF$LF")
$sw.Write("POST$LF")

$sw.Write("--$boundary$LF")
$sw.Write("Content-Disposition: form-data; name=`"data[Item][submittedfile][]`"; filename=`"$DownloadedFile`"$LF")
$sw.Write("Content-Type: application/octet-stream$LF$LF")
$sw.Flush()

# Add file binary content
$fileBytes = [System.IO.File]::ReadAllBytes($FilePath)
$ms.Write($fileBytes, 0, $fileBytes.Length)

# Continue writing form fields
$sw.Write("$LF--$boundary$LF")
$sw.Write("Content-Disposition: form-data; name=`"data[Item][correct]`"$LF$LF")
$sw.Write("0$LF")

$sw.Write("--$boundary$LF")
$sw.Write("Content-Disposition: form-data; name=`"data[Item][correct]`"$LF$LF")
$sw.Write("1$LF")

# End boundary
$sw.Write("--$boundary--$LF")
$sw.Flush()

# Finalize body
$ms.Seek(0, [System.IO.SeekOrigin]::Begin) | Out-Null
$Body = $ms.ToArray()

# Add session if needed
$Di2Session = New-Object Microsoft.PowerShell.Commands.WebRequestSession
$Di2Session.UserAgent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:136.0) Gecko/20100101 Firefox/136.0"
$Di2Session.Cookies.Add((New-Object System.Net.Cookie("PHPSESSID", $SessionCookie, "/", "di2stats.com")))

# Add content-type header
$Di2Headers["Content-Type"] = "multipart/form-data; boundary=$boundary"

# Send request
Write-Host "INFO - Uploading activity file to Di2Stats"
$Di2Upload = Invoke-WebRequest -Uri $Uri -Method POST -Headers $Di2Headers -Body $Body -WebSession $Di2Session -HttpVersion 2.0
Write-Host 'INFO - Uploaded activity file to Di2Stats'

# Cleanup
$sw.Dispose()
$ms.Dispose()

Write-Host 'INFO - Parsing URL'
$RegEx = '/rides/mapview/(\d{6})'
$Match = Select-String -InputObject $Di2Upload.Content -Pattern $RegEx	
$Di2RideID = $Match.Matches.Groups[1].Value
$Di2URL = "https://di2stats.com/rides/view/$Di2RideID"
Write-Host "INFO - Di2Status ride URL: $Di2URL"
Remove-Variable Di2Upload

If ($Di2RideID) {
    # Update the name and description from Garmin
    Write-Host 'INFO - Adding name/description from Garmin to Di2stats.com'
    $Di2EditURL = "https://di2stats.com/rides/edit/$Di2RideID"
    Write-Host "INFO - Activity Name: $ActivityName"
    Write-Host "INFO - Activity Notes: $ActivityNotes"

    $Di2Headers = @{
        "Accept" = "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8"
        "Accept-Language" = "en-US,en;q=0.5"
        "Accept-Encoding" = "gzip, deflate, br, zstd"
        "Origin" = "https://di2stats.com"
        "Referer" = "https://di2stats.com/rides/edit/$Di2RideID"
        "Upgrade-Insecure-Requests" = "1"
        "Sec-Fetch-Dest" = "document"
        "Sec-Fetch-Mode" = "navigate"
        "Sec-Fetch-Site" = "same-origin"
        "Sec-Fetch-User" = "?1"
        "Priority" = "u=0, i"
    }

    If ($ActivityNotes) {
        $ActivityNotesForDi2Stats = $ActivityNotes.Replace(' ','+')
    } 

    $ContentType = "application/x-www-form-urlencoded"
    $Body = "_method=PUT&data%5BRide%5D%5Bid%5D=$Di2RideID&data%5BRide%5D%5Btitle%5D=$($ActivityName.Replace(' ','+'))&data%5BRide%5D%5Bnotes%5D=$ActivityNotesForDi2Stats&data%5BRide%5D%5Bexclude%5D=0"

    Try {
        $Di2Update = Invoke-WebRequest $Di2EditURL -Method 'POST' -Headers $Di2Headers -ContentType $ContentType -Body $Body -WebSession $Di2Session -UseBasicParsing
    } Catch {
        if ($_.Exception.Response.StatusCode -eq 302) {
            Write-Host "INFO - Redirect happened, probably OK."
        } else {
            Write-Error $_.Exception.Response
        }
    }
}



###########################################################################################################################################
###################                                         MyBikeTraffic Upload                                        ###################
###########################################################################################################################################
Write-Host 'INFO - Logging into MyBikeTraffic.com'
[string]$MBTUser = (Get-ChildItem env:MBTUser).Value
[string]$MBTPassword = (Get-ChildItem env:MBTPassword).Value

$MBTLoginForm = @{
    'email' = $MBTUser
    'password' = $MBTPassword
}
$MBTLoginResponse = Invoke-WebRequest -Uri https://www.mybiketraffic.com/auth/login -Form $MBTLoginForm -Method POST -SessionVariable 'MBTSession'

$MBTUploadForm = @{ 'fitfile' = Get-ChildItem $FilePath }
        
Write-Host 'INFO - Uploading FIT file to MyBikeTraffic.com...'
$MBTUpload = Invoke-WebRequest -Uri https://www.mybiketraffic.com/rides/upload -Form $MBTUploadForm -Method POST -WebSession $MBTSession
Write-Host 'INFO - Upload successful'
#Parse out the URL
$RegEx = '"id":(\d{5})'
$Match = Select-String -InputObject $MBTUpload.Content -Pattern $RegEx	
$MBTRideID = $Match.Matches.Groups[1].Value
$MBTURL = "https://www.mybiketraffic.com/rides/view/$MBTRideID"
Remove-Variable MBTUploadForm


###########################################################################################################################################
###################                                             Strava Update                                           ###################
###########################################################################################################################################
# Update Strava with URLs for Di2Stats and MyBikeTraffic
Write-Host 'INFO - Strave auth token expired or not found. Refreshing...'
[int]$StravaClientID = (Get-ChildItem env:CLIENT_ID).Value
[string]$StravaSecret = (Get-ChildItem env:CLIENT_SECRET).Value
[string]$AuthToken = (Get-ChildItem env:REFRESH_TOKEN).Value

$AuthBody = @{
    grant_type = 'refresh_token'
    client_id = $StravaClientID
    client_secret = $StravaSecret
    refresh_token = $AuthToken
}	

$AuthToken = Invoke-RestMethod -Method POST -uri "https://www.strava.com/oauth/token" -Body $AuthBody
if ($AuthToken -Match 'access_token=([^;]+)') {
    $AccessToken = $Matches[1]
}

Write-Host 'INFO - Obtained new Strave auth token'
$StravaHeaders = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$StravaHeaders.Add("Authorization", "Bearer $AccessToken")
$StravaHeaders.Add("Content-Type", "application/json")

# Get the most recent activity
Write-Host 'INFO - Pulling most recent Strava activity'
$URI = "https://www.strava.com/api/v3/athlete/activities?per_page=1"

$JSON = Invoke-RestMethod -Method GET -uri $URI -Headers $StravaHeaders
$ID = $JSON.id

# Get the details about the most recent activity
$StravaURI = "https://www.strava.com/api/v3/activities/$ID"		

Write-Host 'INFO - Adding MyBikeTraffic and Di2Stats URLs to Strava'

If ($ActivityNotes -eq $NULL) {
    $NewDescription = "$MBTURL\n$Di2URL"
} Else {
    $NewDescription = "$ActivityNotes\n\n$MBTURL\n$Di2URL"
}

$StravaBody = @{
    commute     = $false
    trainer     = $false
    description = $NewDescription
    name        = $ActivityName
    type        = $JSON.type
    gear_id     = $JSON.gear_id
} | ConvertTo-Json

$UpdateStrava = Invoke-RestMethod -Method PUT -uri $StravaURI -Headers $StravaHeaders -Body $StravaBody -ContentType "application/json"


###########################################################################################################################################
###################                                             Garmin Update                                           ###################
###########################################################################################################################################
# Update Garmin activity with MyBikeTraffic and Di2Stats URLs
Write-Host "INFO - Updating Garmin activity with Di2Stats and MyBikeTraffic URLS"
$UpdatedActivityNotes = $ActivityNotes + "`n`n$MBTURL`n$Di2URL"

[int64]$intActivityID = $ActivityID

# Update the description to include MyBikeTraffic and Di2Stats data
$DescriptionUpdate = @{
	description = $UpdatedActivityNotes
	activityId = $intActivityID
}

$JSONUpdate = $DescriptionUpdate | ConvertTo-Json

$UpdateURL = "https://connect.garmin.com/modern/proxy/activity-service/activity/$ActivityID"

$UpdateHeaders = @{
	"authority"="connect.garmin.com"
    "Authorization" = $OAuthResult.access_token
	"path"="/modern/proxy/activity-service/activity/$ActivityID"
	"scheme"="https"
	"accept"="application/json, text/javascript, */*; q=0.01"
	"accept-encoding"="gzip, deflate, br, zstd"
	"accept-language"="en-US,en;q=0.5"
	"content-type"="application/json"
    "DI-Backend" = "connectapi.garmin.com"
    "DNT" = "1"
	"NK"="NT"
	"origin"="https://connect.garmin.com"
	"referer"="https://connect.garmin.com/modern/activity/$ActivityID"
	"sec-ch-ua-mobile"="?0"
    "Sec-Fetch-Dest" = "empty"
    "Sec-Fetch-Mode" = "cors"
    "Sec-Fetch-Site" = "same-origin"
    "Priority" = "u=0"
    "Sec-GPC" = "1"
	"user-agent"="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/88.0.4324.182 Safari/537.36 Edge/88.0.705.81"
	"x-app-ver"="5.11.2.1"
	"x-http-method-override"="PUT"
	"x-lang"="en-US"
	"x-requested-with"="XMLHttpRequest"
}		

Invoke-RestMethod -Uri $UpdateURL -Method POST -WebSession $GarminConnectSession -Body $JSONUpdate -Headers $UpdateHeaders -UseBasicParsing
Write-Host "INFO - Garmin activity updated"

# Delete all FIT files 
# Remove-Item -Path $DataPath/*.fit -Force

# Update Garmin last activity cookie
$CookieFileFullPath = Join-Path -Path $Destination -ChildPath $CookieFilename
(Get-Item $CookieFileFullPath -Force).Attributes = "Normal"
$ActivityID | Out-File $CookieFileFullPath -Force
(Get-Item $CookieFileFullPath -Force).Attributes = "Hidden"
Write-Host "INFO - Finished exporting $ActivityExportedCount activities from Garmin Connect to $Destination. Delta file successfully stored."
