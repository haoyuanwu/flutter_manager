param(
    [string]$Executable = (Join-Path $PSScriptRoot '..\build\windows\x64\runner\Release\flutter_manager.exe')
)

$ErrorActionPreference = 'Stop'
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class TrayProbe {
    public delegate bool EnumProc(IntPtr hwnd, IntPtr data);
    [DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc callback, IntPtr data);
    [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr hwnd, out uint pid);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern int GetClassName(IntPtr hwnd, System.Text.StringBuilder name, int count);
    [DllImport("user32.dll")] public static extern bool PostMessage(IntPtr hwnd, uint message, IntPtr wparam, IntPtr lparam);
    [DllImport("user32.dll")] public static extern IntPtr SendMessage(IntPtr hwnd, uint message, IntPtr wparam, IntPtr lparam);
    [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr hwnd);
    [DllImport("user32.dll")] public static extern bool IsWindow(IntPtr hwnd);
    [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
    [DllImport("user32.dll")] public static extern int GetMenuItemCount(IntPtr menu);
    [DllImport("user32.dll")] public static extern uint GetMenuItemID(IntPtr menu, int position);
    public static IntPtr Find(uint pid, string className) {
        IntPtr found = IntPtr.Zero;
        EnumWindows((hwnd, data) => {
            uint owner;
            GetWindowThreadProcessId(hwnd, out owner);
            var name = new System.Text.StringBuilder(256);
            GetClassName(hwnd, name, name.Capacity);
            if (owner == pid && name.ToString() == className) {
                found = hwnd;
                return false;
            }
            return true;
        }, IntPtr.Zero);
        return found;
    }
}
'@

[void][TrayProbe]::SetProcessDPIAware()
$app = Start-Process -FilePath (Resolve-Path -LiteralPath $Executable) -PassThru -WindowStyle Hidden
try {
    $window = [IntPtr]::Zero
    for ($i = 0; $i -lt 60 -and $window -eq [IntPtr]::Zero; $i++) {
        Start-Sleep -Milliseconds 250
        $window = [TrayProbe]::Find($app.Id, 'FLUTTER_RUNNER_WIN32_WINDOW')
    }
    if ($window -eq [IntPtr]::Zero) { throw 'Main window was not created.' }
    Start-Sleep -Seconds 2

    [void][TrayProbe]::PostMessage($window, 0x0010, [IntPtr]::Zero, [IntPtr]::Zero)
    Start-Sleep -Milliseconds 500
    if ([TrayProbe]::IsWindowVisible($window)) { throw 'Closing the window did not hide it to the tray.' }

    # Version 4 callbacks include icon ID 1 in the high word.
    [void][TrayProbe]::PostMessage($window, 0x8001, [IntPtr]::Zero, [IntPtr]0x10400)
    Start-Sleep -Milliseconds 500
    if (-not [TrayProbe]::IsWindowVisible($window)) { throw 'Tray activation did not restore the window.' }
    [void][TrayProbe]::PostMessage($window, 0x0010, [IntPtr]::Zero, [IntPtr]::Zero)
    Start-Sleep -Milliseconds 500
    if ([TrayProbe]::IsWindowVisible($window)) { throw 'Closing the window did not hide it to the tray.' }

    [void][TrayProbe]::PostMessage($window, 0x8001, [IntPtr]::Zero, [IntPtr]0x1007B)
    $popup = [IntPtr]::Zero
    for ($i = 0; $i -lt 20 -and $popup -eq [IntPtr]::Zero; $i++) {
        Start-Sleep -Milliseconds 100
        $popup = [TrayProbe]::Find($app.Id, '#32768')
    }
    if ($popup -eq [IntPtr]::Zero) { throw 'Tray context menu was not displayed.' }
    $menu = [TrayProbe]::SendMessage($popup, 0x01E1, [IntPtr]::Zero, [IntPtr]::Zero)
    if ([TrayProbe]::GetMenuItemCount($menu) -ne 3) { throw 'Tray menu items are missing.' }
    if ([TrayProbe]::GetMenuItemID($menu, 0) -ne 40001 -or
        [TrayProbe]::GetMenuItemID($menu, 2) -ne 40002) {
        throw 'Tray menu commands do not match the window command handlers.'
    }
    # Validate command dispatch separately from interactive desktop input.
    [void][TrayProbe]::SendMessage($window, 0x001F, [IntPtr]::Zero, [IntPtr]::Zero)
    [void][TrayProbe]::PostMessage($window, 0x0111, [IntPtr]40002, [IntPtr]::Zero)
    if (-not $app.WaitForExit(10000)) {
        throw "Exit command did not terminate the application. Window exists: $([TrayProbe]::IsWindow($window))."
    }
    Write-Output 'PASS: packed tray activation, hide, context menu, and Exit command.'
} finally {
    if (-not $app.HasExited) { Stop-Process -Id $app.Id }
}
