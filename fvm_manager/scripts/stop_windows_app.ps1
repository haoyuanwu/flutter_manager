param(
    [Parameter(Mandatory = $true)][string]$Executable,
    [int]$GraceSeconds = 10
)
$ErrorActionPreference = 'Stop'
$target = [IO.Path]::GetFullPath($Executable)
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class InstallerAppExit {
    public delegate bool EnumProc(IntPtr hwnd, IntPtr data);
    [DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc callback, IntPtr data);
    [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr hwnd, out uint pid);
    [DllImport("user32.dll")] public static extern bool PostMessage(IntPtr hwnd, uint msg, IntPtr wparam, IntPtr lparam);
    public static void Request(uint pid) {
        EnumWindows((hwnd, data) => {
            uint owner; GetWindowThreadProcessId(hwnd, out owner);
            if (owner == pid) PostMessage(hwnd, 0x0111, (IntPtr)40002, IntPtr.Zero);
            return true;
        }, IntPtr.Zero);
    }
}
'@
function Find-Target {
    @(Get-CimInstance Win32_Process -Filter "Name = 'flutter_manager.exe'" |
        Where-Object { $_.ExecutablePath -and [string]::Equals($_.ExecutablePath, $target, [StringComparison]::OrdinalIgnoreCase) })
}
try {
    foreach ($app in (Find-Target)) { [InstallerAppExit]::Request([uint32]$app.ProcessId) }
    $deadline = [DateTime]::UtcNow.AddSeconds($GraceSeconds)
    while ((Find-Target).Count -gt 0 -and [DateTime]::UtcNow -lt $deadline) { Start-Sleep -Milliseconds 200 }
    # 旧版本的关闭按钮仅隐藏到托盘；无响应时只终止安装目录下的主程序。
    foreach ($app in (Find-Target)) { Stop-Process -Id $app.ProcessId -Force -ErrorAction Stop }
    $deadline = [DateTime]::UtcNow.AddSeconds(5)
    while ((Find-Target).Count -gt 0 -and [DateTime]::UtcNow -lt $deadline) { Start-Sleep -Milliseconds 200 }
    if ((Find-Target).Count -gt 0) { throw '目标程序仍在运行' }
    exit 0
} catch {
    Write-Error $_
    exit 1
}
