# Daily Doormat Automation Script

This PowerShell script (`schedule-doormat-push.ps1`) automates a daily workflow for AWS credential management and Terraform variable updates using **Doormat**.

It performs the following actions every day at **9:00 AM Eastern Time (EST)**:

1. Logs in to Doormat (`doormat login -f`)
2. Exports temporary AWS credentials (`doormat aws export`)
3. Writes/updates the AWS credentials file (`%USERPROFILE%\.aws\credentials`)
4. Pushes two Terraform variable sets via Doormat (`doormat aws tf-push variable-set`)

---

## Prerequisites

Before running the script, ensure you have the following:

- **PowerShell 5.1 or newer**  
  (Installed by default on Windows 10 and newer)
- **Doormat CLI** installed and available in your system `PATH`
  ```powershell
  doormat --version
  ```
- **Administrative privileges** to create scheduled tasks
  (Run PowerShell as Administrator)

## Environment Variable Configuration

The script retrieves all configuration values from environment variables.
Set them once using the following PowerShell commands:

```powershell
[System.Environment]::SetEnvironmentVariable("TF_ACCOUNT_ID",  "000000000",                "User")
[System.Environment]::SetEnvironmentVariable("TF_VARSET_ID_1", "varset-FdoE67Mndg7jz9r6", "User")
[System.Environment]::SetEnvironmentVariable("TF_VARSET_ID_2", "varset-2Hyk5PuGfUHbwjUU", "User")
```

## Script Workflow

When executed, the script will:
1. Create a Windows Scheduled Task that runs daily at 9:00 AM EST
2. Generate a helper script (Run-DoormatPush.ps1) in your temporary directory
3. The scheduled task runs this helper script, which performs:
    - doormat login -f
    - doormat aws export -a <account>
    - Parses the export output and writes it to C:\Users\<YourUser>\.aws\credentials

## Setup & Execution

1. Open PowerShell as Administrator
2. Navigate to the directory containing the script
3. Execute ```powershell .\schedule-doormat-push.ps1```
4. You should see Scheduled task created: Daily Doormat Login + Export + TF Push (9AM ET) It will run daily at 9:00 AM.

## Verifying the Scheduled Task

To confirm that the task was created successfully:

```powershell
Get-ScheduledTask -TaskName "Daily Doormat Login + Export + TF Push (9AM)"
```

## Log File Location

C:\ProgramData\DoormatTask\run.log

## Uninstall / Remove Scheduled Task

```powershell
Unregister-ScheduledTask -TaskName "Daily Doormat Login + Export + TF Push (9AM ET)" -Confirm:$false
```