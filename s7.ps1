$ErrorActionPreference = 'Continue'
$d = "$env:ProgramFiles\OpenSSH"

Write-Host 'Registrando manifesto de eventos ETW...'
$man = "$d\openssh-events.man"
if (Test-Path $man) {
  $txt = Get-Content $man -Raw
  $txt = $txt.Replace('%SystemRoot%\System32\OpenSSH', $d)
  $enc = New-Object System.Text.UTF8Encoding $false
  [System.IO.File]::WriteAllText($man, $txt, $enc)
  wevtutil um $man 2>$null
  wevtutil im $man 2>$null
  Write-Host 'manifesto registrado'
} else {
  Write-Host '(openssh-events.man nao encontrado)'
}

Write-Host ''
Write-Host 'Iniciando servico...'
& sc.exe start sshd
Start-Sleep -Seconds 3

Write-Host ''
Write-Host '--- sc query sshd (EXIT CODE decisivo) ---'
& sc.exe query sshd

Write-Host ''
Write-Host '--- Win32_Service ---'
Get-CimInstance Win32_Service -Filter "Name='sshd'" | Select-Object Name, State, ExitCode, StartName, PathName | Format-List

Write-Host ''
Write-Host '--- Application log (fonte ssh) ---'
Get-WinEvent -FilterHashtable @{LogName='Application'} -MaxEvents 50 -ErrorAction SilentlyContinue | Where-Object { $_.ProviderName -match 'ssh' -or $_.Message -match 'sshd' } | Select-Object TimeCreated, Id, ProviderName, Message | Format-List

Write-Host ''
Write-Host '--- OpenSSH/Operational ---'
Get-WinEvent -LogName 'OpenSSH/Operational' -MaxEvents 20 -ErrorAction SilentlyContinue | Sort-Object TimeCreated | Select-Object TimeCreated, Id, Message | Format-List

Write-Host 'PRONTO'
