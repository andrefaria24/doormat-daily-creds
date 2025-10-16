# This script schedules a daily task at 9:00 AM EST that runs Doormat aws login and tf-push commands.

# (Set these permanently in Windows or beforehand in PowerShell)
# Example:
#   [System.Environment]::SetEnvironmentVariable("DOORMAT_TF_ACCOUNT_ID", "0123456789", "User")
#   [System.Environment]::SetEnvironmentVariable("DOORMAT_TF_VARSET_ID_1", "varset-abc123", "User")
#   [System.Environment]::SetEnvironmentVariable("DOORMAT_TF_VARSET_ID_2", "varset-abc123", "User")

$account = $env:DOORMAT_TF_ACCOUNT_ID
$varset1 = $env:DOORMAT_TF_VARSET_ID_1
$varset2 = $env:DOORMAT_TF_VARSET_ID_2

# Define commands
$commands = @(
    "doormat login -f",
    "doormat aws tf-push variable-set -a $account --id $varset1",
    "doormat aws tf-push variable-set -a $account --id $varset2"
)

# Create a PowerShell script that runs the commands
$taskScript = "$env:TEMP\run-doormat-push.ps1"
$commands | Out-File -FilePath $taskScript -Encoding utf8

# Define the scheduled task
$action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-ExecutionPolicy Bypass -File `"$taskScript`""
$trigger = New-ScheduledTaskTrigger -Daily -At 9:00AM
$timezone = [System.TimeZoneInfo]::FindSystemTimeZoneById("Eastern Standard Time")

# Register the task
Register-ScheduledTask -TaskName "Daily Doormat Push" -Action $action -Trigger $trigger -Description "Runs daily Doormat tf-push commands at 9:00AM EST" -User $env:USERNAME -RunLevel Highest

# Output success message (will always display in this itteration, even if task creation fails)
Write-Host "✅ Scheduled task 'Daily Doormat Push' created successfully."
Write-Host "It will run daily at 9:00 AM EST."