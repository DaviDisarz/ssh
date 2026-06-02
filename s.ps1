# ===========================================================
#  Setup remoto de acesso SSH - metodo DEFINITIVO (Davi)
#  - Instala OpenSSH 9.5 (estavel) direto do GitHub release.
#  - NAO depende do Windows Update (evita travar) e PULA a
#    build 10.0 (que nao sobe como servico em algumas maquinas).
#  - Idempotente: se ja estiver funcional, so reconfigura a chave.
#  Rodar no PowerShell como ADMINISTRADOR.
# ===========================================================
$ProgressPreference = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$ErrorActionPreference = 'Continue'

$d   = "$env:ProgramFiles\OpenSSH"
$ver = 'v9.5.0.0p1-Beta'
$url = "https://github.com/PowerShell/Win32-OpenSSH/releases/download/$ver/OpenSSH-Win64.zip"
$key = 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIA5QQ5zL4TzzFcasIoDx0VNGSE3yJGqKYO/I/f3MVcX2 david-main-pc'
$enc = New-Object System.Text.UTF8Encoding $false

function Test-SshUp { [bool](Get-NetTCPConnection -LocalPort 22 -State Listen -ErrorAction SilentlyContinue) }

Write-Host '== Setup SSH (OpenSSH 9.5 via GitHub) =='

# --- reexecucao rapida: tenta reaproveitar instalacao existente ---
$precisaInstalar = $true
if (Test-Path "$d\sshd.exe") {
  Write-Host 'Instalacao encontrada - tentando subir o servico existente...'
  Set-Service sshd -StartupType Automatic -ErrorAction SilentlyContinue
  & sc.exe start sshd | Out-Null
  Start-Sleep -Seconds 3
  if (Test-SshUp) { Write-Host 'Servico ja funcional - nao reinstala.'; $precisaInstalar = $false }
  else { Write-Host 'Servico nao subiu - reinstalando a 9.5 limpa.' }
}

if ($precisaInstalar) {
  Write-Host 'Limpando instalacao/tarefa anterior (se houver)...'
  Unregister-ScheduledTask -TaskName 'SSHD-Foreground' -Confirm:$false -ErrorAction SilentlyContinue
  Stop-Service sshd -Force -ErrorAction SilentlyContinue
  if (Test-Path "$d\uninstall-sshd.ps1") { powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$d\uninstall-sshd.ps1" | Out-Null }
  Get-Process sshd, sshd-session -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
  Start-Sleep -Seconds 1
  if (Test-Path $d) { Remove-Item $d -Recurse -Force -ErrorAction SilentlyContinue }

  Write-Host ('Baixando OpenSSH ' + $ver + ' (~16 MB)...')
  $zip = "$env:TEMP\OpenSSH-Win64.zip"
  Invoke-WebRequest -Uri $url -OutFile $zip
  Expand-Archive -Path $zip -DestinationPath $env:ProgramFiles -Force
  $ext = Join-Path $env:ProgramFiles 'OpenSSH-Win64'
  if (Test-Path $ext) { Rename-Item $ext 'OpenSSH' -Force }

  Write-Host 'Instalando servico (bypass de ExecutionPolicy)...'
  powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$d\install-sshd.ps1" | Out-Null
  & "$d\ssh-keygen.exe" -A | Out-Null
  powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$d\FixHostFilePermissions.ps1" -Confirm:$false | Out-Null
  Set-Service sshd -StartupType Automatic
}

Write-Host 'Liberando firewall (porta 22)...'
Remove-NetFirewallRule -Name sshd -ErrorAction SilentlyContinue
New-NetFirewallRule -Name sshd -DisplayName 'OpenSSH SSH Server' -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 22 | Out-Null

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

& sc.exe start sshd | Out-Null
Start-Sleep -Seconds 3

$isadmin = $false
if ($uname) {
  $g = net localgroup administradores 2>$null
  if (-not $g) { $g = net localgroup administrators 2>$null }
  $isadmin = (($g -join "`n") -match [regex]::Escape($uname))
}
$ip = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.IPAddress -like '192.168.*' } | Select-Object -First 1).IPAddress
$porta = if (Test-SshUp) { 'SIM' } else { 'NAO' }
$status = (Get-Service sshd).Status

Write-Host ''
Write-Host '========================================'
Write-Host ('  IP do computador : ' + $ip)
Write-Host ('  Servico sshd     : ' + $status)
Write-Host ('  Porta 22 ouvindo : ' + $porta)
Write-Host ('  Usuario do login : ' + $cu)
Write-Host ('  Eh administrador : ' + $isadmin)
Write-Host '========================================'
if ($porta -eq 'SIM') { Write-Host 'PRONTO' } else { Write-Host 'ATENCAO: porta 22 nao subiu - avisar o Davi' }
