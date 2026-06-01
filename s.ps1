$ProgressPreference = 'SilentlyContinue'
Write-Host 'Instalando OpenSSH Server...'
Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0 | Out-Null
Set-Service sshd -StartupType Automatic
Restart-Service sshd

Write-Host 'Liberando firewall (porta 22)...'
Remove-NetFirewallRule -Name sshd -ErrorAction SilentlyContinue
New-NetFirewallRule -Name sshd -DisplayName 'OpenSSH SSH Server' -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 22 | Out-Null

Write-Host 'Gravando chave mestra...'
$f = "$env:ProgramData\ssh\administrators_authorized_keys"
$key = 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIA5QQ5zL4TzzFcasIoDx0VNGSE3yJGqKYO/I/f3MVcX2 david-main-pc'
[System.IO.File]::WriteAllText($f, $key + "`n", (New-Object System.Text.UTF8Encoding $false))

Write-Host 'Ajustando dono e permissoes...'
takeown /F $f /A | Out-Null
icacls $f /inheritance:r | Out-Null
icacls $f /grant '*S-1-5-18:F' | Out-Null
icacls $f /grant '*S-1-5-32-544:F' | Out-Null

Restart-Service sshd
Start-Sleep -Seconds 2

$ip = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.IPAddress -like '192.168.*' } | Select-Object -First 1).IPAddress
$porta = if (Get-NetTCPConnection -LocalPort 22 -State Listen -ErrorAction SilentlyContinue) { 'SIM' } else { 'NAO' }
$status = (Get-Service sshd).Status
$owner = (Get-Acl $f).Owner

Write-Host ''
Write-Host '========================================'
Write-Host ('  IP do computador : ' + $ip)
Write-Host ('  Servico sshd     : ' + $status)
Write-Host ('  Porta 22 ouvindo : ' + $porta)
Write-Host ('  Dono da chave    : ' + $owner)
Write-Host '========================================'
Write-Host 'PRONTO'
