$ErrorActionPreference = 'Continue'
$d = "$env:ProgramFiles\OpenSSH"

Write-Host 'Gerando host keys...'
& "$d\ssh-keygen.exe" -A | Out-Null

Write-Host 'Corrigindo permissoes das host keys (bypass)...'
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$d\FixHostFilePermissions.ps1" -Confirm:$false | Out-Null

Write-Host ''
Write-Host '--- sshd -t (teste de config) ---'
$tlog = "$env:TEMP\sshd_t.txt"
& "$d\sshd.exe" -t *> $tlog
if (Test-Path $tlog) { Get-Content $tlog }

Write-Host ''
Write-Host '--- tentando iniciar ---'
& sc.exe start sshd | Out-Null
Start-Sleep -Seconds 3
$status = (Get-Service sshd).Status
Write-Host ('Status: ' + $status)

Write-Host ''
Write-Host '--- log do sshd (ultimas linhas) ---'
$slog = "$env:ProgramData\ssh\logs\sshd.log"
if (Test-Path $slog) { Get-Content $slog -Tail 25 } else { Write-Host '(sem arquivo de log ainda)' }

Write-Host ''
Write-Host '--- eventos System sobre sshd ---'
Get-WinEvent -FilterHashtable @{LogName='System'; ProviderName='Service Control Manager'} -MaxEvents 15 -ErrorAction SilentlyContinue | Where-Object { $_.Message -match 'sshd|SSH' } | Select-Object TimeCreated, Id, Message | Format-List

$porta = if (Get-NetTCPConnection -LocalPort 22 -State Listen -ErrorAction SilentlyContinue) { 'SIM' } else { 'NAO' }
Write-Host '========================================'
Write-Host ('  Servico sshd : ' + $status)
Write-Host ('  Porta 22     : ' + $porta)
Write-Host '========================================'
Write-Host 'PRONTO'
