# This script schedules a daily task at 9:00 AM EST that runs Doormat aws export, login and tf-push commands.

# (Set these permanently in Windows or beforehand in PowerShell)
# Example:
#   [System.Environment]::SetEnvironmentVariable("DOORMAT_TF_ACCOUNT_ID", "0123456789", "User")
#   [System.Environment]::SetEnvironmentVariable("DOORMAT_TF_VARSET_ID_1", "varset-abc123", "User")
#   [System.Environment]::SetEnvironmentVariable("DOORMAT_TF_VARSET_ID_2", "varset-abc123", "User")

$account = $env:DOORMAT_TF_ACCOUNT_ID
$varset1 = $env:DOORMAT_TF_VARSET_ID_1
$varset2 = $env:DOORMAT_TF_VARSET_ID_2

if (-not $account -or -not $varset1 -or -not $varset2) {
    throw "Missing required environment variables: TF_ACCOUNT_ID, TF_VARSET_ID_1, TF_VARSET_ID_2"
}

$taskScript = Join-Path $env:TEMP "Run-DoormatPush.ps1"

$taskScriptContent = @'
param(
    [string]$Account,
    [string]$Varset1,
    [string]$Varset2
)

$logDir  = Join-Path $env:ProgramData "DoormatTask"
$null    = New-Item -ItemType Directory -Path $logDir -Force -ErrorAction SilentlyContinue
$logFile = Join-Path $logDir "run.log"
function Log { param([string]$msg) "$(Get-Date -Format o)  $msg" | Add-Content -Path $logFile }

try {
    Log "=== Run start (account: $Account) ==="

    # 0) Ensure fresh login
    & doormat login -f
    if ($LASTEXITCODE -ne 0) {
        Log "doormat login -f failed."
        throw "doormat login failed"
    }
    Log "doormat login -f OK."

    # 1) Export AWS creds (plain text line with env exports)
    $exportOutput = & doormat aws export -a $Account 2>&1
    if ($LASTEXITCODE -ne 0) {
        Log "doormat aws export failed. Output:`n$exportOutput"
        throw "doormat export failed"
    }
    $joined = ($exportOutput | Out-String) -replace "`r?`n"," "

    # Extract values, tolerate optional brackets
    if ($joined -match 'AWS_ACCESS_KEY_ID=([\[\]A-Za-z0-9+/=_-]+)') { $AWS_ACCESS_KEY_ID = $Matches[1].Trim('[]') }
    if ($joined -match 'AWS_SECRET_ACCESS_KEY=([\[\]A-Za-z0-9+/=_-]+)') { $AWS_SECRET_ACCESS_KEY = $Matches[1].Trim('[]') }
    if ($joined -match 'AWS_SESSION_TOKEN=([\[\]A-Za-z0-9+/=_-]+)') { $AWS_SESSION_TOKEN = $Matches[1].Trim('[]') }
    if ($joined -match 'AWS_SESSION_EXPIRATION=([\[\]A-Za-z0-9:+.-]+)') { $AWS_SESSION_EXPIRATION = $Matches[1].Trim('[]') }

    if (-not $AWS_ACCESS_KEY_ID -or -not $AWS_SECRET_ACCESS_KEY -or -not $AWS_SESSION_TOKEN -or -not $AWS_SESSION_EXPIRATION) {
        Log "Failed to parse AWS values from export output: $joined"
        throw "Could not parse AWS credentials from doormat export output."
    }

    # 2) Update only the [default] section in %USERPROFILE%\.aws\credentials
    $awsDir   = Join-Path $env:USERPROFILE ".aws"
    $null     = New-Item -ItemType Directory -Path $awsDir -Force -ErrorAction SilentlyContinue
    $credPath = Join-Path $awsDir "credentials"

    $defaultSection = @"
[default]
aws_access_key_id=$AWS_ACCESS_KEY_ID
aws_secret_access_key=$AWS_SECRET_ACCESS_KEY
aws_session_token=$AWS_SESSION_TOKEN
aws_session_expiration=$AWS_SESSION_EXPIRATION
"@.Trim()

    $existingCreds = if (Test-Path $credPath) {
        Get-Content -Path $credPath -Raw -ErrorAction SilentlyContinue
    } else {
        ""
    }

    if ($null -eq $existingCreds) {
        $existingCreds = ""
    }

    $defaultSectionPattern = '(?ms)^\[default\][^\r\n]*\r?\n.*?(?=^\[[^\]]+\]|\z)'

    if ([regex]::IsMatch($existingCreds, $defaultSectionPattern)) {
        $updatedCreds = [regex]::Replace(
            $existingCreds,
            $defaultSectionPattern,
            [System.Text.RegularExpressions.MatchEvaluator]{ param($match) $defaultSection + "`r`n" }
        )
    }
    else {
        $updatedCreds = $existingCreds

        if ($updatedCreds.Length -gt 0 -and -not $updatedCreds.EndsWith("`n")) {
            $updatedCreds += "`r`n"
        }

        if ($updatedCreds.Trim().Length -gt 0) {
            $updatedCreds += "`r`n"
        }

        $updatedCreds += $defaultSection + "`r`n"
    }

    Set-Content -Path $credPath -Value $updatedCreds -Encoding ASCII
    Log "Updated [default] credentials in $credPath"

    # 3) Push the two Terraform variable sets
    & doormat aws tf-push variable-set -a $Account --id $Varset1
    if ($LASTEXITCODE -ne 0) {
        Log "First tf-push failed."
        throw "First tf-push failed."
    }
    Log "First tf-push OK."

    & doormat aws tf-push variable-set -a $Account --id $Varset2
    if ($LASTEXITCODE -ne 0) {
        Log "Second tf-push failed."
        throw "Second tf-push failed."
    }
    Log "Second tf-push OK."

    Log "=== Run completed successfully ==="
}
catch {
    Log "ERROR: $($_.Exception.Message)"
    throw
}
'@

$taskScriptContent | Out-File -FilePath $taskScript -Encoding ASCII

$easternTzId = "Eastern Standard Time"
$localTzId   = (Get-TimeZone).Id

$todayEasternNine = [datetime]::Today.AddHours(9)
$localStart       = [System.TimeZoneInfo]::ConvertTimeBySystemTimeZoneId($todayEasternNine, $easternTzId, $localTzId)

$action  = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$taskScript`" -Account `"$account`" -Varset1 `"$varset1`" -Varset2 `"$varset2`""
$trigger = New-ScheduledTaskTrigger -Daily -At $localStart

Register-ScheduledTask `
  -TaskName "Daily Doormat Push (9AM ET)" `
  -Action $action `
  -Trigger $trigger `
  -Description "Runs doormat login -f, exports AWS creds to %USERPROFILE%\.aws\credentials, then tf-pushes two var sets at 9:00 AM Eastern daily." `
  -User $env:USERNAME `
  -RunLevel Highest

Write-Host "✅ Scheduled task created: Daily Doormat Push (9AM ET)"
Write-Host "It will run daily at 9:00 AM Eastern (converted to this machine's local time)."
