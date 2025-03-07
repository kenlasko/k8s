PARAM(
)
$DataPath = '/garmin-data'
$ActivityFileType = 'FIT'
$Overwrite = 'Yes'
$DownloadOption = 'New'
$Destination = $DataPath

# Log into Garmin and pull the most recent activity
$Username = (Get-ChildItem env:GARMIN_USER).Value 
$Password = (Get-ChildItem env:GARMIN_PASSWORD).Value 


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
$CookieFileFullPath = ($Destination + "\" + $CookieFilename)

#Write process information:
Write-Host "INFO - Starting processing $ActivityFileType files from Garmin Connect with the following parameters:"
Write-Host "- Activity File Type = $ActivityFileType"
Write-Host "- Download Option = $DownloadOption"
Write-Host "- Destination = $Destination"
Write-Host "- Username = $Username"
Write-Host "- Overwrite = $Overwrite"

#Authenticate
Write-Host "INFO - Connecting to Garmin Connect for user $Username" -ForegroundColor Gray
"BaseLoginUrl: {0}" -f $BaseLoginURL | Write-Verbose
$BaseLogin = Invoke-WebRequest -Uri $BaseLoginURL -SessionVariable GarminConnectSession
$LoginForm = $BaseLogin.Forms[0]
$LoginForm.Fields["username"] = "$Username"
$LoginForm.Fields["password"] = "$Password"
$Headers = @{
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
$BaseLogin = Invoke-RestMethod -Uri ($BaseLoginURL + "?" + $Service) -WebSession $GarminConnectSession -Method POST -Body $LoginForm.Fields -Headers $Headers  -UserAgent $UserAgent

#Get Cookies
"Read cookies" | Write-Verbose
$Cookies = $GarminConnectSession.Cookies.GetCookies($BaseLoginURL)

#Get SSO cookie
$SSOCookie = $Cookies | Where-Object name -EQ "CASTGC" | Select-Object value -ExpandProperty value
if ($SSOCookie.Length -lt 1) {
    Write-Error "ERROR - No valid SSO cookie found, wrong credentials?"
    break
}

#Authenticate by using cookie
"Post login authentication" | Write-Verbose
$PostLogin = Invoke-RestMethod -Uri ($PostLoginURL + "?ticket=" + $SSOCookie) -WebSession $GarminConnectSession  -UserAgent $UserAgent

#Get the bearer token
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

$Headers = @{
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

#Set the correct activity download URL for the selected type.
switch ($ActivityFileType) {
    'TCX' { $ActivityBaseURL = $TCXActivityBaseURL }
    'GPX' { $ActivityBaseURL = $GPXActivityBaseURL }
    'KML' { $ActivityBaseURL = $KMLActivityBaseURL }
    Default { $ActivityBaseURL = $FITActivityBaseURL }
}
"ActivityFileType: {0}" -f $ActivityFileType | Write-Verbose

#Get activity pages and check if the connection is successfull
$ActivityList = @()
$PageSize = 100
$FirstRecord = 0
$Pages = 0
do {
    $Uri = [System.Uri]::new($ActivitySearchURL)
    $Path = "{0}limit={1}&start={2}" -f $Uri.PathAndQuery, $PageSize, $FirstRecord
    $Headers.Path = $Path
    $Url = "https://connect.garmin.com", $Path -join ""
    "Activity list url: {0}" -f $Url | Write-Verbose
    $SearchResults = Invoke-RestMethod -Uri $Url -Method get -WebSession $GarminConnectSession -ErrorAction SilentlyContinue -Headers $Headers
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
    $msg = "A valid delta cookie not found. Exiting"
    break
}

#Get activities
$Activities = @()
Write-Host "INFO - Retrieving current status of your activities in Garmin Connect, please wait..."
foreach ($Activity in $ActivityList) {
    if ($($Activity.activityId) -gt $DeltaCookie) { $Activities += $Activity }
}

#Download activities in queue and unpack to destination location
Write-Host "INFO - Continue to process all retrieved activities, please wait..."
$TempDir = Join-Path -Path $env:temp -ChildPath GarminConnectActivityExportTMP
"TempDir: {0}" -f $TempDir | Write-Verbose
$ActivityFileType = $ActivityFileType.tolower()
if (!(Test-Path $TempDir)) { $null = New-Item -Path $TempDir -ItemType Directory -Force }
$ActivityExportedCount = 0
foreach ($Activity in $Activities) {
    #Download files
    $Uri = [System.Uri]::new($ActivityBaseURL)
    $Path = "{0}{1}/" -f $Uri.PathAndQuery, $($Activity.activityID)
    $Headers.path = $Path
    $URL = $ActivityBaseURL, $($Activity.activityID) -Join ""
    "Download Url: {0}" -f $URL | Write-Verbose
    $OutputFileFullPath = Join-Path -Path $TempDir -ChildPath "$($Activity.activityID).zip"

    if (Test-Path $OutputFileFullPath) {
        #Allways overwrite temp files
        $null = Remove-Item $OutputFileFullPath -Force
    }
    Invoke-RestMethod -Uri $URL  -WebSession $GarminConnectSession -Headers $Headers -OutFile $OutputFileFullPath

    #Setting naming parameters for having the file to a more readable format
    $ActivityID = $Activity.activityId
    $ActivityName = $Activity.activityName
    $ActivityType = $Activity.activityType.typekey
    $ActivityBeginTimeStamp = (Get-Date $Activity.startTimeLocal).ToString("yyyy-MM-dd")
    $NamingMask = (("$ActivityID - $ActivityBeginTimeStamp - $ActivityType - $ActivityName").TrimEnd() -replace $_.name -replace '[^A-Za-z0-9-_\@\,\(\) \.\[\]]', '-')

    #Unzip the temporary files for FIT files and move all files to the destination location
    $Shell = New-Object -com shell.application
    $ZIP = $shell.NameSpace(“$OutputFileFullPath”)
    if ($zip.items().count -gt 1) {
        $Count = 0
        foreach ($Item in $ZIP.items()) {
            $Count++
            Write-Host "INFO - Downloading file $Destination$NamingMask-$Count.$ActivityFileType"
            $Shell.Namespace(“$TempDir”).copyhere($Item, 0x14)
            $DownloadedFileFullPath = Join-Path -Path $TempDir -ChildPath $($Item.name)
            $FinalFileName = ($NamingMask + "-" + $Count + "." + $ActivityFileType)
            $FinalFileNameTempFullPath = Join-Path -Path $TempDir -ChildPath $FinalFileName
            if (Test-Path $FinalFileNameTempFullPath) {
                #Allways overwrite temp files
                $null = Remove-Item $FinalFileNameTempFullPath -Force
            }
            Rename-Item $DownloadedFileFullPath -NewName $FinalFileNameTempFullPath -Force
            if ($Overwrite -eq "Yes") {
                Move-Item $FinalFileNameTempFullPath -Destination $Destination -Force
            } else {
                if (Test-Path (Join-Path -Path $Destination -ChildPath $FinalFileName)) {
                    Write-Warning "WARNING - Skipping file $FinalFileName because it allready exists in the destination directory."
                } else {
                    Move-Item $FinalFileNameTempFullPath -Destination $Destination
                }
            }

        }
    } elseif ($zip.items().count -eq 1) {
        Write-Host "INFO - Trying to create file $NamingMask.$ActivityFileType"
        foreach ($Item in $ZIP.items()) {
            $Shell.Namespace(“$TempDir”).copyhere($zip.items(), 0x14)
            $DownloadedFileFullPath = Join-Path -Path $TempDir -ChildPath $($Item.name)
            $FinalFileName = ($NamingMask + "." + $ActivityFileType)
            $FinalFileNameTempFullPath = Join-Path -Path $TempDir -ChildPath $FinalFileName
            if (Test-Path $FinalFileNameTempFullPath) {
                #Allways overwrite temp files
                $null = Remove-Item $FinalFileNameTempFullPath -Force
            }
            Rename-Item $DownloadedFileFullPath -NewName $FinalFileNameTempFullPath -Force
            if ($Overwrite -eq "Yes") {
                Move-Item $FinalFileNameTempFullPath -Destination $Destination -Force
            } else {
                if (Test-Path (Join-Path -Path $Destination -ChildPath $FinalFileName)) {
                    Write-Warning "WARNING - Skipping file $FinalFileName because it allready exists in the destination directory."
                } else {
                    Move-Item $FinalFileNameTempFullPath -Destination $Destination
                }
            }
        }
    }
    $ActivityExportedCount++
}

Write-Host "Temp exit point"
Break

# Get the activity info
$Activity = Get-Content -Raw -Path $DataPath/activities-1-1.json | ConvertFrom-Json

#Setting naming parameters for having the file to a more readable format
$ActivityID = $Activity.activityId
$ActivityName = $Activity.activityName
$ActivityNotes = $Activity.description

$FilePath = "$DataPath/activity_$($ActivityID).fit"
$DownloadedFile = "activity_$($ActivityID).fit"

Write-Host "INFO - FILENAME: $DownloadedFile"

Try {
    # Di2Stats Upload
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

    # Login and get session cookie
    $Di2Session = New-Object Microsoft.PowerShell.Commands.WebRequestSession
    $Di2Session.UserAgent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/100.0.4896.60 Safari/537.36"
    $Di2Session.Cookies.Add((New-Object System.Net.Cookie("PHPSESSID", $InitSessionID, "/", "di2stats.com")))
    [string]$Di2StatsUser = (Get-ChildItem env:Di2StatsUser).Value
    [string]$Di2StatsPassword = (Get-ChildItem env:Di2StatsPassword).Value

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

    Write-Host 'INFO - Getting Di2Stats session cookie'
    $Cookie = $Di2Login.Headers.'Set-Cookie' #[2]
    $RegEx = 'PHPSESSID=(\w{26});\ path=/$'
    $Match = Select-String -InputObject $Cookie -Pattern $RegEx	
    $SessionCookie = $Match.Matches.Groups[1].Value

    # Create session variable
    $Di2Session = New-Object Microsoft.PowerShell.Commands.WebRequestSession
    $Di2Session.UserAgent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/100.0.4896.60 Safari/537.36"
    $Di2Session.Cookies.Add((New-Object System.Net.Cookie("PHPSESSID", $SessionCookie, "/", "di2stats.com")))

    Write-Host "INFO - Path to downloaded file: $FilePath"
    $Uri = 'https://di2stats.com/import'

    $fileBytes = [System.IO.File]::ReadAllBytes($FilePath);
    $fileEnc = [System.Text.Encoding]::GetEncoding('ISO-8859-1').GetString($fileBytes);
    $boundary = [System.Guid]::NewGuid().ToString(); 
    $LF = "`r`n";

    $bodyLines = ( 
    "--$boundary",
    "Content-Disposition: form-data; name=`"data[Item][correct]`"$LF",
    "1$LF",    
    "--$boundary",
    "Content-Disposition: form-data; name=`"data[Item][submittedfile][]`"; filename=`"$FilePath`"",
    "Content-Type: application/octet-stream$LF",
    $fileEnc,
    "--$boundary--$LF" 
    ) -join $LF

    Write-Host 'INFO - Uploading activity file to Di2Stats'
    $Di2Upload = Invoke-WebRequest -Uri $URI -Method POST -ContentType "multipart/form-data; boundary=`"$boundary`"" -Body $bodyLines -websession $Di2Session
    Write-Host 'INFO - Uploaded activity file to Di2Stats'

    #Parse out the URL
    Write-Host 'INFO - Parsing URL'
    $RegEx = '/rides/mapview/(\d{6})'
    $Match = Select-String -InputObject $Di2Upload.Content -Pattern $RegEx	
    $Di2RideID = $Match.Matches.Groups[1].Value
    $Di2URL = "https://di2stats.com/rides/view/$Di2RideID"
    Write-Host "INFO - Di2Status ride URL: $Di2URL"

    Remove-Variable Di2Upload
    
    # Update the name and description from Garmin
    Write-Host 'Adding name/description from Garmin to Di2stats.com'
    $Di2EditURL = "https://di2stats.com/rides/edit/$Di2RideID"
    
    $Headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $Headers.Add("Connection", "keep-alive")
    $Headers.Add("Content-Type", "application/x-www-form-urlencoded")
    $Headers.Add("Cookie", "PHPSESSID=$SessionCookie")
    $Headers.Add("Origin", "https://di2stats.com")
    $Headers.Add("Referer", $Di2EditURL)
    $Headers.Add("Sec-Fetch-Dest", "document")
    $Headers.Add("Sec-Fetch-Mode", "navigate")
    $Headers.Add("Sec-Fetch-Site", "same-origin")
    $Headers.Add("Sec-Fetch-User", "?1")
    $Headers.Add("Upgrade-Insecure-Requests", "1")

    $Body = "_method=PUT&data%5BRide%5D%5Bid%5D=$Di2RideID&data%5BRide%5D%5Btitle%5D=$ActivityName&data%5BRide%5D%5Bnotes%5D=$ActivityNotes&data%5BRide%5D%5Bexclude%5D=0"

    $Di2Update = Invoke-WebRequest $Di2EditURL -Method 'POST' -Headers $Headers -Body $Body
}
Catch {
    Write-Warning 'Error uploading to Di2Stats.com'
    Write-Warning $Error[0]
    $Di2Url = $NULL
}

# MyBikeTraffic Upload
Write-Host 'INFO - Logging into MyBikeTraffic.com'
[string]$MBTUser = (Get-ChildItem env:MBTUser).Value
[string]$MBTPassword = (Get-ChildItem env:MBTPassword).Value

$MBTLoginForm = @{'email' = $MBTUser
        'password' = $MBTPassword
        }
$MBTLoginResponse = Invoke-WebRequest -Uri https://www.mybiketraffic.com/auth/login -Form $MBTLoginForm -Method POST -SessionVariable 'MBTSession'

$MBTUploadForm = @{
        'fitfile' = Get-ChildItem $FilePath
        }
        
Write-Host 'INFO - Uploading FIT file to MyBikeTraffic.com'
$MBTUpload = Invoke-WebRequest -Uri https://www.mybiketraffic.com/rides/upload -Form $MBTUploadForm -Method POST -WebSession $MBTSession

#Parse out the URL
$RegEx = '"id":(\d{5})'
$Match = Select-String -InputObject $MBTUpload.Content -Pattern $RegEx	
$MBTRideID = $Match.Matches.Groups[1].Value
$MBTURL = "https://www.mybiketraffic.com/rides/view/$MBTRideID"
Remove-Variable MBTUploadForm


# Update Strava with URLs for Di2Stats and MyBikeTraffic
Try {
    Write-Host 'INFO - Getting cached Strave auth token'
    $AuthToken = Get-Content -Raw -Path /garmin-data/StravaToken.json | ConvertFrom-Json
}
Catch {
    Write-Warning 'Couldn''t find new auth token. Generating from original' 
    $AuthToken = Get-Content -Raw -Path /garmin-prog/StravaToken.json | ConvertFrom-Json
}

$TokenExpires = [timezone]::CurrentTimeZone.ToLocalTime(([datetime]'1/1/1970').AddSeconds($AuthToken.expires_at))

If ((New-TimeSpan -Start (Get-Date) -End $TokenExpires).Ticks -lt 0) {  # Token expired
    # Get new token using refresh token
    Write-Host 'INFO - Strave auth token expired or not found. Refreshing...'
    [string]$StravaSecret = (Get-ChildItem env:StravaSecret).Value

    $AuthBody = @{
    grant_type = 'refresh_token'
    client_id = 63572
    client_secret = $StravaSecret
    refresh_token = $AuthToken.refresh_token
    }	

    $AuthToken = Invoke-RestMethod -Method POST -uri "https://www.strava.com/oauth/token" -Body $AuthBody
    
    Write-Host 'INFO - Obtained new Strave auth token'
    $AuthToken | ConvertTo-Json | Out-File /garmin-data/StravaToken.json
}


$AccessToken = $AuthToken.Access_Token

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
}
Else {
    $NewDescription = "$ActivityNotes\n\n$MBTURL\n$Di2URL"
}

$StravaBody = "{
`n  `"commute`": false,
`n  `"trainer`": false,
`n  `"description`": `"$NewDescription`",
`n  `"name`": `"$ActivityName`",
`n  `"type`": `"$($JSON.Type)`",
`n  `"gear_id`": `"$($JSON.gear_id)`"
`n}"

$UpdateStrava = Invoke-RestMethod -Method PUT -uri $StravaURI -Headers $StravaHeaders -Body $StravaBody

# Update Garmin activity with MyBikeTraffic and Di2Stats URLs

# Write-Host "Updating Garmin activity with Di2Stats and MyBikeTraffic URLS"
# $UpdatedActivityNotes = $ActivityNotes + "`r`n`r`n$MBTURL`r`n$Di2URL"

# # Update the description to include MyBikeTraffic and Di2Stats data
# $DescriptionUpdate = @{
# 	description = $UpdatedActivityNotes
# 	activityId = $ActivityId
# }

# $JSONUpdate = $DescriptionUpdate | ConvertTo-Json

# $UpdateURL = "https://connect.garmin.com/modern/proxy/activity-service/activity/$ActivityID"

# $UpdateHeaders = @{
# 	"authority"="connect.garmin.com"
# 	"path"="/modern/proxy/activity-service/activity/$ActivityID"
# 	"scheme"="https"
# 	"accept"="application/json, text/javascript, */*; q=0.01"
# 	"accept-encoding"="gzip, deflate, br"
# 	"accept-language"="en-CA,en-GB;q=0.9,en-US;q=0.8,en;q=0.7,pt;q=0.6"
# 	"content-type"="application/json"
# 	"nk"="NT"
# 	"origin"="https://connect.garmin.com"
# 	"referer"="https://connect.garmin.com/modern/activity/$ActivityID"
# 	"sec-ch-ua-mobile"="?0"
# 	"sec-fetch-dest"="empty"
# 	"sec-fetch-mode"="cors"
# 	"sec-fetch-site"="same-origin"
# 	"user-agent"="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/88.0.4324.182 Safari/537.36 Edge/88.0.705.81"
# 	"x-app-ver"="4.41.2.0"
# 	"x-http-method-override"="PUT"
# 	"x-lang"="en-US"
# 	"x-requested-with"="XMLHttpRequest"
# }		

# Invoke-RestMethod -Uri $UpdateURL -Method POST -WebSession $GarminConnectSession -Body $JSONUpdate -Headers $UpdateHeaders
# Write-Host "INFO - Garmin activity updated"

# Delete all files 
# Remove-Item -Path $DataPath/*.* -Exclude StravaToken.json -Force

# Update Garmin last activity cookie
$CookieFileFullPath = Join-Path -Path $Destination -ChildPath $CookieFilename
(Get-Item $CookieFileFullPath -Force).Attributes = "Normal"
$NewestActivity | Out-File $CookieFileFullPath -Force
(Get-Item $CookieFileFullPath -Force).Attributes = "Hidden"
Write-Host "INFO - Finished exporting $ActivityExportedCount activities from Garmin Connect to $Destination. Delta file successfully stored."
