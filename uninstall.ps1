$D = "$env:APPDATA\Microsoft\WinAudioSvc"
Write-Host "Removing..." -ForegroundColor Red
Get-WmiObject Win32_Process | Where-Object { $_.CommandLine -like '*engine.ps1*' } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Run" /v "WinAudioSvc" /f 2>$null
attrib -h -s "$D\sounds\*.*" 2>$null
attrib -h -s "$D\sounds" 2>$null
attrib -h -s "$D\*.*" 2>$null
attrib -h -s "$D" 2>$null
Remove-Item -Recurse -Force $D -ErrorAction SilentlyContinue
Write-Host "`nDone. Prank removed.`n" -ForegroundColor Green
