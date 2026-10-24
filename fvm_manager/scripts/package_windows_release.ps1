[CmdletBinding()]
param(
    [string]$IsccPath,
    [string]$VcRuntimeDirectory,
    [string]$Repository = 'haoyuanwu/flutter_manager',
    [string]$BundleDirectory,
    [string]$FlutterRoot,
    [switch]$Build,
    [switch]$Upload,
    [switch]$UploadOnly,
    [ValidatePattern('^[a-z0-9][a-z0-9-]*$')]
    [string]$Revision,
    [ValidateRange(0, 7200)]
    [int]$WaitForReleaseSeconds = 0
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
$pubspec = Get-Content -LiteralPath (Join-Path $projectRoot 'pubspec.yaml') -Raw
if ($pubspec -notmatch '(?m)^version:\s*(\d+\.\d+\.\d+)\+(\d+)\s*$') {
    throw 'Expected pubspec version X.Y.Z+Build.'
}
$version = $Matches[1]
$buildNumber = $Matches[2]
$tag = "v$version"
$revisionSuffix = if ($Revision) { "-$Revision" } else { '' }
$manifestName = "SHA256SUMS-windows$revisionSuffix.txt"
$sourceCommit = (& git -C $projectRoot rev-parse HEAD).Trim()
if ($LASTEXITCODE -ne 0) { throw '无法读取当前 Git 提交。' }
if ($UploadOnly -and !$Upload) { throw '-UploadOnly 必须和 -Upload 一起使用。' }
if ($UploadOnly -and $Build) { throw '-UploadOnly 不能与 -Build 同时使用。' }
if ($Upload) {
    $workingTree = & git -C $projectRoot status --porcelain
    if ($workingTree) { throw '发布前请先检查、提交并推送源码，工作区必须干净。' }
    & gh auth status
    if ($LASTEXITCODE -ne 0) { throw '请先执行 gh auth login。' }
}
if ($Build) {
    if (!$FlutterRoot) { $FlutterRoot = $env:FLUTTER_ROOT }
    if (!$FlutterRoot) {
        $flutterCommand = Get-Command flutter -ErrorAction SilentlyContinue
        if ($flutterCommand) { $FlutterRoot = Split-Path (Split-Path $flutterCommand.Source -Parent) -Parent }
    }
    if (!$FlutterRoot) { throw '请通过 -FlutterRoot 指定 Flutter SDK 目录。' }
    $FlutterRoot = (Resolve-Path -LiteralPath $FlutterRoot).Path
    $dart = Join-Path $FlutterRoot 'bin\cache\dart-sdk\bin\dart.exe'
    $flutterTools = Join-Path $FlutterRoot 'bin\cache\flutter_tools.snapshot'
    if (!(Test-Path -LiteralPath $dart) -or !(Test-Path -LiteralPath $flutterTools)) {
        throw 'Flutter SDK 缓存不完整，请先完成 SDK 初始化。'
    }
    # 每个版本使用独立构建目录，避免正在运行的旧程序锁住 Release 文件。
    $buildDirectory = "build/windows-publish-$version-$buildNumber$revisionSuffix"
    $profile = Join-Path $projectRoot "build\windows-publish-profile-$version-$buildNumber"
    New-Item -ItemType Directory -Path $profile -Force | Out-Null
    @{ 'build-dir' = $buildDirectory } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $profile '.flutter_settings') -Encoding utf8
    $previousAppData = $env:APPDATA
    $previousFlutterRoot = $env:FLUTTER_ROOT
    Push-Location $projectRoot
    try {
        $env:APPDATA = $profile
        $env:FLUTTER_ROOT = $FlutterRoot
        # 直接使用 Dart 快照，绕开部分 Windows 环境中无响应的 flutter.bat。
        & $dart $flutterTools pub get
        if ($LASTEXITCODE -ne 0) { throw 'Flutter 依赖解析失败。' }
        & $dart $flutterTools build windows --release --no-pub
        if ($LASTEXITCODE -ne 0) { throw 'Windows Release 构建失败。' }
    } finally {
        $env:APPDATA = $previousAppData
        $env:FLUTTER_ROOT = $previousFlutterRoot
        Pop-Location
    }
    $BundleDirectory = Join-Path $projectRoot "$buildDirectory/windows/x64/runner/Release"
}
$bundle = if ($BundleDirectory) { (Resolve-Path -LiteralPath $BundleDirectory).Path } else { Join-Path $projectRoot 'build\windows\x64\runner\Release' }
$executable = Join-Path $bundle 'flutter_manager.exe'
if (!$UploadOnly) {
if (!(Test-Path -LiteralPath $executable)) {
    throw 'Build first: flutter build windows --release'
}
$binaryVersion = (Get-Item -LiteralPath $executable).VersionInfo.ProductVersion
if ($binaryVersion -ne "$version+$buildNumber") {
    throw "Executable version $binaryVersion does not match $version+$buildNumber."
}
foreach ($required in @('flutter_windows.dll', 'data\app.so', 'data\icudtl.dat')) {
    if (!(Test-Path -LiteralPath (Join-Path $bundle $required))) {
        throw "Missing release bundle file: $required"
    }
}
}

if (!$UploadOnly -and !$IsccPath) {
    $compilerCandidates = @(
        "${env:ProgramFiles}\Inno Setup 7\ISCC.exe",
        "${env:ProgramFiles}\Inno Setup 6\ISCC.exe",
        "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe"
    )
    $IsccPath = $compilerCandidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
}
if (!$UploadOnly -and (!$IsccPath -or !(Test-Path -LiteralPath $IsccPath))) {
    throw 'Specify the Inno Setup compiler with -IsccPath.'
}
if (!$UploadOnly -and !$VcRuntimeDirectory) {
    $vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
    if (Test-Path -LiteralPath $vswhere) {
        $visualStudio = & $vswhere -latest -products '*' -property installationPath
        if ($LASTEXITCODE -eq 0 -and $visualStudio) {
            $redist = Join-Path $visualStudio 'VC\Redist\MSVC'
            $VcRuntimeDirectory = Get-ChildItem -LiteralPath $redist -Directory |
                Sort-Object Name -Descending |
                ForEach-Object {
                    Get-ChildItem -Path (Join-Path $_.FullName 'x64\Microsoft.VC*.CRT') -Directory -ErrorAction SilentlyContinue
                } | Select-Object -First 1 -ExpandProperty FullName
        }
    }
}
$runtimeFiles = @('msvcp140.dll', 'vcruntime140.dll', 'vcruntime140_1.dll')
foreach ($runtimeFile in $runtimeFiles) {
    if (!$UploadOnly -and (!$VcRuntimeDirectory -or !(Test-Path -LiteralPath (Join-Path $VcRuntimeDirectory $runtimeFile)))) {
        throw "Specify a Visual C++ x64 redistributable directory with -VcRuntimeDirectory (missing $runtimeFile)."
    }
}

$output = Join-Path $projectRoot "build\release\windows-$version-$buildNumber$revisionSuffix"
$filename = "Flutter-Manager-$version-windows-x64$revisionSuffix-setup.exe"
$installer = Join-Path $output $filename
$manifest = Join-Path $output $manifestName
$receipt = Join-Path $output "$filename.json"
foreach ($destination in @($installer, $manifest, $receipt)) {
    if (!$UploadOnly -and (Test-Path -LiteralPath $destination)) {
        throw "Refusing to overwrite $destination"
    }
}
if ($Upload) {
    $deadline = [DateTime]::UtcNow.AddSeconds($WaitForReleaseSeconds)
    do {
        $metadataText = & gh release view $tag --repo $Repository --json tagName,isDraft,assets 2>$null
        if ($LASTEXITCODE -eq 0) {
            $metadata = $metadataText | ConvertFrom-Json
            if (!$metadata.isDraft) { break }
        }
        if ([DateTime]::UtcNow -ge $deadline) { throw "未找到已发布的 $tag，请先完成版本发布。" }
        Write-Output "等待 $tag 的 GitHub Release 发布，30 秒后重试……"
        Start-Sleep -Seconds 30
    } while ($true)
    if ($metadata.tagName -ne $tag -or $metadata.isDraft) { throw 'Expected an existing published release.' }
    # 核对标签指向，禁止把当前代码构建的附件上传到其他版本源码下。
    $remoteCommit = & gh api "repos/$Repository/commits/$tag" --jq '.sha'
    if ($LASTEXITCODE -ne 0) { throw '无法读取 Release 标签源码。' }
    if ($Revision) {
        # 同版本修订保留原标签；源码必须已推送，且由原发布提交演进而来。
        & git -C $projectRoot merge-base --is-ancestor $remoteCommit.Trim() $sourceCommit
        if ($LASTEXITCODE -ne 0) { throw '修订源码不是原发布提交的后续版本。' }
        $publishedCommit = & gh api "repos/$Repository/commits/$sourceCommit" --jq '.sha'
        if ($LASTEXITCODE -ne 0 -or $publishedCommit.Trim() -ne $sourceCommit) { throw '请先推送修订源码。' }
    } elseif ($remoteCommit.Trim() -ne $sourceCommit) { throw 'Release 标签与当前源码提交不一致。' }
    if (& git -C $projectRoot status --porcelain) { throw '构建后源码发生变化，请先检查并提交。' }
}
New-Item -ItemType Directory -Path $output -Force | Out-Null
if (!$UploadOnly) {
$scriptDirectory = Join-Path $projectRoot 'build\windows\installer'
New-Item -ItemType Directory -Path $scriptDirectory -Force | Out-Null
$script = Join-Path $scriptDirectory "installer-$version.iss"
$icon = Join-Path $projectRoot 'windows\runner\resources\app_icon.ico'
$runtimeEntries = ($runtimeFiles | ForEach-Object {
    'Source: "' + (Join-Path $VcRuntimeDirectory $_) + '"; DestDir: "{app}"; Flags: ignoreversion'
}) -join "`n"
@"
[Setup]
AppId=flutter_manager
AppName=Flutter Manager
AppVersion=$version
AppPublisher=Flutter Manager
PrivilegesRequired=admin
DefaultDirName={autopf}\flutter_manager
DefaultGroupName=Flutter Manager
DisableProgramGroupPage=yes
OutputDir=$output
OutputBaseFilename=$([IO.Path]::GetFileNameWithoutExtension($filename))
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
UninstallDisplayIcon={app}\flutter_manager.exe
SetupIconFile=$icon

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "$bundle\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
$runtimeEntries

[Icons]
Name: "{group}\Flutter Manager"; Filename: "{app}\flutter_manager.exe"
Name: "{autodesktop}\Flutter Manager"; Filename: "{app}\flutter_manager.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\flutter_manager.exe"; WorkingDir: "{app}"; Description: "{cm:LaunchProgram,Flutter Manager}"; Flags: nowait postinstall skipifsilent shellexec runascurrentuser
"@ | Set-Content -LiteralPath $script -Encoding UTF8
& $IsccPath /Qp $script
if ($LASTEXITCODE -ne 0 -or !(Test-Path -LiteralPath $installer)) {
    throw 'Inno Setup packaging failed.'
}
$digest = (Get-FileHash -LiteralPath $installer -Algorithm SHA256).Hash.ToLowerInvariant()
"$digest  $filename" | Set-Content -LiteralPath $manifest -Encoding ascii
@{
    version = "$version+$buildNumber"
    sourceCommit = $sourceCommit
    installerSha256 = $digest
} | ConvertTo-Json | Set-Content -LiteralPath $receipt -Encoding utf8
} else {
    foreach ($required in @($installer, $manifest, $receipt)) {
        if (!(Test-Path -LiteralPath $required)) { throw "缺少已打包产物：$required" }
    }
    $saved = Get-Content -LiteralPath $receipt -Raw | ConvertFrom-Json
    $digest = (Get-FileHash -LiteralPath $installer -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($saved.sourceCommit -ne $sourceCommit -or $saved.version -ne "$version+$buildNumber" -or $saved.installerSha256 -ne $digest) {
        throw '安装包记录与当前源码、版本或校验值不一致，拒绝上传。'
    }
    if ((Get-Content -LiteralPath $manifest -Raw).Trim() -ne "$digest  $filename") { throw '本地校验清单不匹配。' }
}
Write-Output "Packaged: $installer"
Write-Output "SHA256: $digest"

if ($Upload) {
    # 允许上传中断后继续；已有附件只校验，不覆盖，更不会删除 Mac 附件。
    foreach ($assetPath in @($installer, $manifest)) {
        $assetName = [IO.Path]::GetFileName($assetPath)
        $existing = $metadata.assets | Where-Object { $_.name -eq $assetName } | Select-Object -First 1
        if ($existing) {
            $localHash = (Get-FileHash -LiteralPath $assetPath -Algorithm SHA256).Hash.ToLowerInvariant()
            if ($existing.digest -ne "sha256:$localHash") { throw "远端已有不同内容的附件，未覆盖：$assetName" }
        } else {
            & gh release upload $tag $assetPath --repo $Repository
            if ($LASTEXITCODE -ne 0) { throw '上传失败；可使用 -Upload -UploadOnly 继续，已有附件不会覆盖。' }
        }
    }
    $verification = Join-Path $output ('download-check-' + [Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $verification | Out-Null
    & gh release download $tag --repo $Repository --pattern $filename --pattern $manifestName --dir $verification
    if ($LASTEXITCODE -ne 0) { throw 'Uploaded, but download verification failed.' }
    $downloadedDigest = (Get-FileHash -LiteralPath (Join-Path $verification $filename) -Algorithm SHA256).Hash.ToLowerInvariant()
    $downloadedManifest = (Get-Content -LiteralPath (Join-Path $verification $manifestName) -Raw).Trim()
    if ($downloadedDigest -ne $digest -or $downloadedManifest -ne "$digest  $filename") {
        throw 'Downloaded installer checksum mismatch.'
    }
    Write-Output "Upload and download verified: https://github.com/$Repository/releases/tag/$tag"
}
