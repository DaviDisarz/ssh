$ErrorActionPreference = 'Continue'
$d = "$env:ProgramFiles\OpenSSH"
$log = "$env:TEMP\sshd_debug.txt"
if (Test-Path $log) { Remove-Item $log -Force }

Write-Host 'Rodando sshd em modo debug por 4s para capturar o erro...'
$p = Start-Process -FilePath "$d\sshd.exe" -ArgumentList '-d', '-E', $log -PassThru -WindowStyle Hidden
Start-Sleep -Seconds 4
if (-not $p.HasExited) {
  Stop-Process -Id $p.Id -Force
  Write-Host '(sshd CONTINUOU rodando em foreground - isso e bom; parei so para ler)'
} else {
  Write-Host ('(sshd ABORTOU sozinho - exit code ' + $p.ExitCode + ')')
}

Write-Host ''
Write-Host '--- log de debug do sshd ---'
if (Test-Path $log) { Get-Content $log } else { Write-Host '(sem log gerado)' }

Write-Host ''
Write-Host '--- permissoes das host keys ---'
Get-ChildItem "$env:ProgramData\ssh\ssh_host_*_key" -ErrorAction SilentlyContinue | ForEach-Object {
  Write-Host ('-> ' + $_.Name)
  icacls $_.FullName
}
Write-Host 'PRONTO'
