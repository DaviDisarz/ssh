$ProgressPreference = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$ErrorActionPreference = 'Continue'
$d = "$env:ProgramFiles\OpenSSH"

Write-Host 'Limpando instalacao 10.0 e tarefa agendada...'
Unregister-ScheduledTask -TaskName 'SSHD-Foreground' -Confirm:$false -ErrorAction SilentlyContinue
Stop-Service sshd -Force -ErrorAction SilentlyContinue
if (Test-Path "$d\uninstall-sshd.ps1") { powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$d\uninstall-sshd.ps1" | Out-Null }
Get-Process sshd, sshd-session -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 1
if (Test-Path $d) { Remove-Item $d -Recurse -Force -ErrorAction SilentlyContinue }

Write-Host 'Baixando OpenSSH 9.5 (estavel)...'
$zip = "$env:TEMP\OpenSSH-95.zip"
Invoke-WebRequest -Uri 'https://github.com/PowerShell/Win32-OpenSSH/releases/download/v9.5.0.0p1-Beta/OpenSSH-Win64.zip' -OutFile $zip
Expand-Archive -Path $zip -DestinationPath $env:ProgramFiles -Force
$extracted = Join-Path $env:ProgramFiles 'OpenSSH-Win64'
if (Test-Path $extracted) { Rename-Item $extracted 'OpenSSH' -Force }

Write-Host 'Instalando servico...'
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$d\install-sshd.ps1" | Out-Null
& "$d\ssh-keygen.exe" -A | Out-Null
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$d\FixHostFilePermissions.ps1" -Confirm:$false | Out-Null
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

Write-Host 'Iniciando servico...'
& sc.exe start sshd | Out-Null
Start-Sleep -Seconds 3
$status = (Get-Service sshd).Status
$porta = if (Get-NetTCPConnection -LocalPort 22 -State Listen -ErrorAction SilentlyContinue) { 'SIM' } else { 'NAO' }
$ip = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.IPAddress -like '192.168.*' } | Select-Object -First 1).IPAddress

Write-Host ''
Write-Host '========================================'
Write-Host ('  IP do computador : ' + $ip)
Write-Host ('  Servico sshd     : ' + $status)
Write-Host ('  Porta 22 ouvindo : ' + $porta)
Write-Host ('  Usuario do login : ' + $cu)
Write-Host '========================================'
Write-Host 'PRONTO'
