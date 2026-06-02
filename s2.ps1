$ProgressPreference = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

Write-Host 'Plano B: baixando OpenSSH do GitHub (sem Windows Update)...'
$zip = "$env:TEMP\OpenSSH-Win64.zip"
$dst = "$env:ProgramFiles\OpenSSH"
Invoke-WebRequest -Uri 'https://github.com/PowerShell/Win32-OpenSSH/releases/latest/download/OpenSSH-Win64.zip' -OutFile $zip

Write-Host 'Extraindo...'
if (Test-Path $dst) { Remove-Item $dst -Recurse -Force }
Expand-Archive -Path $zip -DestinationPath $env:ProgramFiles -Force
$extracted = Join-Path $env:ProgramFiles 'OpenSSH-Win64'
if (Test-Path $extracted) { Rename-Item $extracted 'OpenSSH' -Force }

Write-Host 'Registrando servico sshd...'
& powershell.exe -ExecutionPolicy Bypass -File "$dst\install-sshd.ps1" | Out-Null
& "$dst\ssh-keygen.exe" -A | Out-Null
Set-Service sshd -StartupType Automatic

Write-Host 'Liberando firewall (porta 22)...'
Remove-NetFirewallRule -Name sshd -ErrorAction SilentlyContinue
New-NetFirewallRule -Name sshd -DisplayName 'OpenSSH SSH Server' -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 22 | Out-Null

$key = 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIA5QQ5zL4TzzFcasIoDx0VNGSE3yJGqKYO/I/f3MVcX2 david-main-pc'
$enc = New-Object System.Text.UTF8Encoding $false

if (-not (Test-Path "$env:ProgramData\ssh")) { New-Item -ItemType Directory -Path "$env:ProgramData\ssh" | Out-Null }

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
