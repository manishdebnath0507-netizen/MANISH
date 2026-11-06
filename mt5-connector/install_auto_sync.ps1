$ErrorActionPreference = "Stop"

$python = Join-Path $PSScriptRoot ".venv\Scripts\python.exe"
$connector = Join-Path $PSScriptRoot "connector.py"
if (!(Test-Path $python)) { throw "Python virtual environment not found. Complete the connector installation first." }
if (!(Test-Path $connector)) { throw "connector.py was not found in this folder." }
if ([string]::IsNullOrWhiteSpace($env:ATI_CONNECTOR_TOKEN)) {
    throw "ATI_CONNECTOR_TOKEN is not available. Set the token in your Windows user environment, then reopen PowerShell."
}

$taskName = "AI Trading Intelligence - MT5 Read Only Sync"
$action = New-ScheduledTaskAction -Execute $python -Argument "`"$connector`" --sync" -WorkingDirectory $PSScriptRoot
$trigger = New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(1) -RepetitionInterval (New-TimeSpan -Minutes 15) -RepetitionDuration (New-TimeSpan -Days 3650)
$principal = New-ScheduledTaskPrincipal -UserId "$env:USERDOMAIN\$env:USERNAME" -LogonType Interactive -RunLevel Limited
$settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -MultipleInstances IgnoreNew -ExecutionTimeLimit (New-TimeSpan -Minutes 10)
Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Description "Read-only MT5 history synchronization to AI Trading Intelligence." -Force | Out-Null
Write-Host "Automatic read-only sync is scheduled every 15 minutes while you are signed in."
Write-Host "Keep MetaTrader 5 open and logged in. No trading actions are performed."
