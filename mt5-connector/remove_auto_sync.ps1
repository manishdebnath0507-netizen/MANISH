$taskName = "AI Trading Intelligence - MT5 Read Only Sync"
Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue
Write-Host "AI Trading Intelligence MT5 scheduled sync removed."
