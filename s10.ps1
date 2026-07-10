# s10 - FIX: host keys com ACE de usuario comum (ex: JUSSANIA\jobru:(M)).
# Sintoma: sshd roda em foreground (sshd -d escuta na 22) mas o SERVICO nao sobe.
# Causa: como SYSTEM, o sshd rejeita host key privada acessivel a usuario comum;
# em foreground o processo e do proprio usuario, entao a checagem passa.
# Fix: dono + ACL das host keys = somente SYSTEM e Administradores, e sobe o servico.
$ErrorActionPreference = 'Continue'

Write-Host '--- estado do servico ANTES do fix ---'
& sc.exe query sshd
Get-CimInstance Win32_Service -Filter "Name='sshd'" | Select-Object State, ExitCode | Format-List

Write-Host 'Corrigindo ACL das host keys (somente SYSTEM + Administradores)...'
$sidSys = New-Object System.Security.Principal.SecurityIdentifier 'S-1-5-18'
$sidAdm = New-Object System.Security.Principal.SecurityIdentifier 'S-1-5-32-544'
foreach ($f in Get-ChildItem "$env:ProgramData\ssh\ssh_host_*_key") {
  $acl = Get-Acl $f.FullName
  $acl.SetOwner($sidAdm)
  $acl.SetAccessRuleProtection($true, $false)
  foreach ($ace in @($acl.Access)) { $acl.PurgeAccessRules($ace.IdentityReference) }
  $acl.AddAccessRule((New-Object System.Security.AccessControl.FileSystemAccessRule($sidSys, 'FullControl', 'Allow')))
  $acl.AddAccessRule((New-Object System.Security.AccessControl.FileSystemAccessRule($sidAdm, 'FullControl', 'Allow')))
  Set-Acl $f.FullName $acl
  Write-Host ('-> ' + $f.Name)
  icacls $f.FullName
}

Write-Host 'Iniciando servico sshd...'
& sc.exe start sshd | Out-Null
Start-Sleep -Seconds 4

$status = (Get-Service sshd).Status
$porta = if (Get-NetTCPConnection -LocalPort 22 -State Listen -ErrorAction SilentlyContinue) { 'SIM' } else { 'NAO' }
$ip = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.IPAddress -like '192.168.*' } | Select-Object -First 1).IPAddress
$cu = (Get-CimInstance Win32_ComputerSystem).UserName

Write-Host ''
Write-Host '========================================'
Write-Host ('  IP do computador : ' + $ip)
Write-Host ('  Servico sshd     : ' + $status)
Write-Host ('  Porta 22 ouvindo : ' + $porta)
Write-Host ('  Usuario do login : ' + $cu)
Write-Host '========================================'
if ($porta -eq 'SIM') { Write-Host 'PRONTO' } else {
  Write-Host 'AINDA NAO SUBIU - exit code decisivo abaixo:'
  & sc.exe query sshd
}
