$ErrorActionPreference = 'Continue'
$d = "$env:ProgramFiles\OpenSSH"

Write-Host 'Gerando host keys...'
& "$d\ssh-keygen.exe" -A | Out-Null

Write-Host 'Corrigindo permissoes das host keys...'
& "$d\FixHostFilePermissions.ps1" -Confirm:$false | Out-Null

Write-Host ''
Write-Host '--- teste de config (sshd -t) ---'
& "$d\sshd.exe" -t

Write-Host ''
Write-Host '--- tentando iniciar sshd ---'
try { Start-Service sshd; Write-Host 'START OK' } catch { Write-Host ('START FALHOU: ' + $_.Exception.Message) }
Start-Sleep -Seconds 2

$status = (Get-Service sshd).Status
$porta = if (Get-NetTCPConnection -LocalPort 22 -State Listen -ErrorAction SilentlyContinue) { 'SIM' } else { 'NAO' }

Write-Host ''
Write-Host '--- ultimos eventos do sshd ---'
Get-WinEvent -LogName 'OpenSSH/Operational' -MaxEvents 5 -ErrorAction SilentlyContinue | Select-Object TimeCreated, LevelDisplayName, Message | Format-List

Write-Host '========================================'
Write-Host ('  Servico sshd     : ' + $status)
Write-Host ('  Porta 22 ouvindo : ' + $porta)
Write-Host '========================================'
Write-Host 'PRONTO'
