$ProgressPreference = 'SilentlyContinue'
Write-Host 'Instalando OpenSSH Server...'
Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0 | Out-Null
Set-Service sshd -StartupType Automatic
Restart-Service sshd

Write-Host 'Liberando firewall (porta 22)...'
Remove-NetFirewallRule -Name sshd -ErrorAction SilentlyContinue
New-NetFirewallRule -Name sshd -DisplayName 'OpenSSH SSH Server' -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 22 | Out-Null

$key = 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIA5QQ5zL4TzzFcasIoDx0VNGSE3yJGqKYO/I/f3MVcX2 david-main-pc'
$enc = New-Object System.Text.UTF8Encoding $false

Write-Host 'Gravando chave (admins)...'
$fa = "$env:ProgramData\ssh\administrators_authorized_keys"
[System.IO.File]::WriteAllText($fa, $key + "`n", $enc)
takeown /F $fa /A | Out-Null
icacls $fa /inheritance:r | Out-Null
icacls $fa /grant '*S-1-5-18:F' | Out-Null
icacls $fa /grant '*S-1-5-32-544:F' | Out-Null

Write-Host 'Gravando chave (usuario do console)...'
$cu = (Get-CimInstance Win32_ComputerSystem).UserName
$uname = ''
if ($cu) {
  $uname = $cu.Split('\')[-1]
  $prof = "C:\Users\$uname"
  if (Test-Path $prof) {
    $ud = Join-Path $prof '.ssh'
    if (-not (Test-Path $ud)) { New-Item -ItemType Directory -Path $ud | Out-Null }
    $fu = Join-Path $ud 'authorized_keys'
    [System.IO.File]::WriteAllText($fu, $key + "`n", $enc)
    icacls $fu /inheritance:r | Out-Null
    icacls $fu /grant '*S-1-5-18:F' | Out-Null
    icacls $fu /grant ($cu + ':F') | Out-Null
  }
}

Restart-Service sshd
Start-Sleep -Seconds 2

$isadmin = $false
if ($uname) {
  $g = net localgroup administradores 2>$null
  if (-not $g) { $g = net localgroup administrators 2>$null }
  $isadmin = (($g -join "`n") -match [regex]::Escape($uname))
}
$ip = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.IPAddress -like '192.168.*' } | Select-Object -First 1).IPAddress
$porta = if (Get-NetTCPConnection -LocalPort 22 -State Listen -ErrorAction SilentlyContinue) { 'SIM' } else { 'NAO' }
$status = (Get-Service sshd).Status

Write-Host ''
Write-Host '========================================'
Write-Host ('  IP do computador : ' + $ip)
Write-Host ('  Servico sshd     : ' + $status)
Write-Host ('  Porta 22 ouvindo : ' + $porta)
Write-Host ('  Usuario do login : ' + $cu)
Write-Host ('  Eh administrador : ' + $isadmin)
Write-Host '========================================'
Write-Host 'PRONTO'
