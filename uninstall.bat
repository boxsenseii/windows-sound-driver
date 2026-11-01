@echo off
title Removing Update
color 0c

set "D=%APPDATA%\Microsoft\WinAudioSvc"

echo Removing...

for /f "tokens=2" %%p in ('wmic process where "commandline like '%%engine.ps1%%'" get processid 2^>nul ^| findstr /r "[0-9]"') do (
    taskkill /f /pid %%p >nul 2>&1
)

reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Run" /v "WinAudioSvc" /f >nul 2>&1

attrib -h -s "%D%\sounds\*.*" 2>nul
attrib -h -s "%D%\sounds" 2>nul
attrib -h -s "%D%\*.*" 2>nul
attrib -h -s "%D%" 2>nul
rd /s /q "%D%" 2>nul

echo.
echo Done. Prank removed.
echo.
pause
exit
