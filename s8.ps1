$ErrorActionPreference = 'Continue'
$d = "$env:ProgramFiles\OpenSSH"

Write-Host 'Desativando servico sshd (vamos usar tarefa agendada)...'
Stop-Service sshd -Force -ErrorAction SilentlyContinue
Set-Service sshd -StartupType Disabled -ErrorAction SilentlyContinue

Write-Host 'Criando tarefa agendada (sshd como SYSTEM, no boot)...'
$action = New-ScheduledTaskAction -Execute "$d\sshd.exe" -Argument '-D'
$trigger = New-ScheduledTaskTrigger -AtStartup
$principal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 1)
$settings.ExecutionTimeLimit = 'PT0S'
Unregister-ScheduledTask -TaskName 'SSHD-Foreground' -Confirm:$false -ErrorAction SilentlyContinue
Register-ScheduledTask -TaskName 'SSHD-Foreground' -Action $action -Trigger $trigger -Principal $principal -Settings $settings | Out-Null

Write-Host 'Iniciando a tarefa agora...'
Start-ScheduledTask -TaskName 'SSHD-Foreground'
Start-Sleep -Seconds 4

$proc = Get-Process sshd -ErrorAction SilentlyContinue
if ($proc) { $pinfo = 'RODANDO (pid ' + ($proc.Id -join ',') + ')' } else { $pinfo = 'NAO esta rodando' }

Write-Host ''
Write-Host '--- estado da tarefa ---'
Get-ScheduledTask -TaskName 'SSHD-Foreground' | Get-ScheduledTaskInfo | Select-Object LastRunTime, LastTaskResult | Format-List
Write-Host ('Processo sshd: ' + $pinfo)

$porta = if (Get-NetTCPConnection -LocalPort 22 -State Listen -ErrorAction SilentlyContinue) { 'SIM' } else { 'NAO' }
$ip = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.IPAddress -like '192.168.*' } | Select-Object -First 1).IPAddress

Write-Host ''
Write-Host '========================================'
Write-Host ('  IP do computador : ' + $ip)
Write-Host ('  Processo sshd    : ' + $pinfo)
Write-Host ('  Porta 22 ouvindo : ' + $porta)
Write-Host '========================================'
Write-Host 'PRONTO'
