$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$fixture = Join-Path $projectRoot ('build\installer-exit-test-' + [Guid]::NewGuid().ToString('N'))
$targetDir = Join-Path $fixture 'target app'
$otherDir = Join-Path $fixture 'unrelated app'
New-Item -ItemType Directory -Path $targetDir, $otherDir -Force | Out-Null
Add-Type -TypeDefinition 'public class ExitFixture { public static void Main() { System.Threading.Thread.Sleep(60000); } }' -OutputAssembly (Join-Path $targetDir 'flutter_manager.exe') -OutputType ConsoleApplication
Copy-Item -LiteralPath (Join-Path $targetDir 'flutter_manager.exe') -Destination (Join-Path $otherDir 'flutter_manager.exe')
$target = Start-Process -FilePath (Join-Path $targetDir 'flutter_manager.exe') -WindowStyle Hidden -PassThru
$other = Start-Process -FilePath (Join-Path $otherDir 'flutter_manager.exe') -WindowStyle Hidden -PassThru
try {
    Start-Sleep -Milliseconds 500
    if ($target.HasExited -or $other.HasExited) { throw '测试进程未启动' }
    & "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File (Join-Path $projectRoot 'scripts\stop_windows_app.ps1') -Executable (Join-Path $targetDir 'flutter_manager.exe') -GraceSeconds 1
    if ($LASTEXITCODE -ne 0) { throw '退出脚本失败' }
    if (!$target.WaitForExit(5000)) { throw '目标程序没有退出' }
    $other.Refresh()
    if ($other.HasExited) { throw '误关闭了其他目录下的同名程序' }
    Write-Output 'PASS: 安装前退出目标目录程序，保留其他目录同名程序。'
} finally {
    foreach ($process in @($target, $other)) {
        $process.Refresh()
        if (!$process.HasExited) { Stop-Process -Id $process.Id -Force }
    }
}
