$ErrorActionPreference = 'Continue'

Write-Host 'Habilitando canal de log OpenSSH/Operational...'
wevtutil sl "OpenSSH/Operational" /e:true 2>$null
wevtutil cl "OpenSSH/Operational" 2>$null

Write-Host 'Iniciando servico sshd...'
& sc.exe start sshd | Out-Null
Start-Sleep -Seconds 4
$status = (Get-Service sshd).Status
Write-Host ('Status: ' + $status)

Write-Host ''
Write-Host '--- eventos OpenSSH/Operational (modo servico) ---'
Get-WinEvent -LogName 'OpenSSH/Operational' -MaxEvents 30 -ErrorAction SilentlyContinue | Sort-Object TimeCreated | Select-Object TimeCreated, Id, LevelDisplayName, Message | Format-List

Write-Host ''
Write-Host '--- permissoes da pasta de instalacao ---'
icacls "$env:ProgramFiles\OpenSSH\sshd.exe"

$porta = if (Get-NetTCPConnection -LocalPort 22 -State Listen -ErrorAction SilentlyContinue) { 'SIM' } else { 'NAO' }
Write-Host '========================================'
Write-Host ('  Servico sshd : ' + $status)
Write-Host ('  Porta 22     : ' + $porta)
Write-Host '========================================'
Write-Host 'PRONTO'
