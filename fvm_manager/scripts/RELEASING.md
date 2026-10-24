# 一条命令发布 macOS 版本

日常发版不再重复本地和 CI 的完整验证。默认由 GitHub Actions 统一执行一次测试、Release 构建、双架构 DMG 打包、签名校验、上传和附件下载校验。

## 使用方法

1. 在 `main` 上完成代码修改，检查差异后，显式 `git add` 要发布的代码和测试文件。脚本不自动暂存整个工作区；被全局规则忽略的新增测试需要 `git add -f`。
2. 确认版本号和 Build No。以下仅为示例，不会自动推断新版本。
3. 在 `fvm_manager` 目录运行预览：

```sh
python3 scripts/release.py 1.2.8+14 \
  --note "新增功能说明" \
  --note "优化操作体验" \
  --note "修复已知问题"
```

预览只读取本地状态，不改文件、不提交、不推送。确认后，在同一命令末尾添加 `--publish`，脚本将：

- 检查当前分支、暂存状态、版本递增和标签冲突；同步检查远程 main。
- 更新 `pubspec.yaml`，生成 `RELEASE_NOTES_vX.Y.Z.md`，自动按 `1. 2. 3.` 编号。
- 将已暂存的代码与版本元数据一起提交，提交记录使用中文。
- 原子推送 main 与版本标签，触发自动发布。不会强推，也不会覆盖已有版本。

## Windows 电脑使用

发布入口 `release.py` 仅依赖 Python 3 标准库和 Git，macOS / Windows 均可运行。先安装 Python 3.9+、Git，并配置 Git 提交身份和当前仓库的 GitHub 推送权限（例如 SSH 密钥）。无需在本地安装 `gh` 或 macOS 构建工具。

在仓库根目录同步代码，然后进入应用目录。在 PowerShell 中使用单行命令：

```powershell
git switch main
git pull --ff-only origin main
cd fvm_manager
py -3 scripts/release.py 1.2.8+14 --note "新增功能说明" --note "优化操作体验" --note "修复已知问题"
```

上面的版本号仅为示例，请替换为本次确认的新版本。若没有 `py` 启动器，可改用 `python`，先确认 `python --version` 为 Python 3.9 或以上。需要发布代码改动时，先检查并显式暂存；确认预览后在发布命令末尾追加 `--publish`。

Windows 执行此命令会推送标签，由 GitHub 的 macOS 云端 runner 打包两个架构的 DMG，不是在 Windows 本地构建 macOS 应用。目前该发布流程不生成 Windows 安装包；`package_macos_release.py` 仍只能在 macOS 本地使用。

### 为已有版本补充 Windows 安装包

在 Windows 上构建当前版本后，使用 Inno Setup 6/7 打包并补传到同版本的已发布 Release：

```powershell
flutter pub get
flutter build windows --release --no-pub
powershell -ExecutionPolicy Bypass -File scripts/package_windows_release.ps1 -Upload
```

本地需要 Visual Studio C++ 桌面构建工具、Inno Setup、已登录的 GitHub CLI。
Windows 安装器显式要求管理员权限，应用清单也声明 `requireAdministrator`。
安装完成后通过 Windows Shell 以安装器当前管理员身份启动应用；从快捷方式
或资源管理器启动时，由 Windows 按需弹出 UAC 确认，不能静默绕过授权。
应用执行的 Flutter/FVM 等子进程也会继承管理员权限，请仅运行可信项目和命令。
脚本会核对 exe 与 pubspec 的完整版本号，自动查找 Inno Setup 和 x64 Visual C++ 运行库。
也可用 `-IsccPath`、`-VcRuntimeDirectory` 显式指定路径。去掉 `-Upload` 则仅打包。
产物为 `build/release/windows-X.Y.Z-Build/Flutter-Manager-X.Y.Z-windows-x64-setup.exe` 和独立的
`SHA256SUMS-windows.txt`。脚本拒绝覆盖本地或远端已有同名文件，保留 Mac 附件与
`SHA256SUMS.txt`；上传后会下载 Windows 两个附件并校验 SHA-256。

### Windows 一条命令构建并上传

用户明确要求维持版本号修复 Windows 包时，先用中文提交并推送修订源码，再添加
`-Revision admin-fix`（修订名按实际问题指定）。该模式验证原发布提交是当前源码的
祖先、当前源码已推送；不移动旧标签。安装包、校验清单及输出目录均带修订名，
旧附件不覆盖。恢复上传时也必须带同一个 `-Revision`。

先按上文用 `release.py --publish` 推送中文提交与新版本标签，再执行：

```powershell
pwsh -File scripts/package_windows_release.ps1 -Build -FlutterRoot D:\fvm\default -Upload -WaitForReleaseSeconds 3600
```

脚本使用独立的版本构建目录，不会关闭正在运行的旧程序；直接调用 Dart 和
Flutter 工具快照，避免 `flutter.bat` 无响应。不在本地运行应用、截图或重复测试，
GitHub Actions 仍执行既有的发布检查与 macOS 构建。

`-WaitForReleaseSeconds` 会等待 Actions 发布同版本 Release，再补充 Windows 安装包。
上传前核对当前提交与远端标签；上传后重新下载附件并校验。不会替换或删除已有附件。
若上传被网络中断，可恢复，无需重新构建：

```powershell
pwsh -File scripts/package_windows_release.ps1 -Upload -UploadOnly -WaitForReleaseSeconds 3600
```

恢复时会校验安装包记录中的版本、源码提交和 SHA-256。远端同名附件只有在摘要
一致时才跳过，否则停止并保留原文件。`-BundleDirectory` 可指定已经构建好的
Release 目录，`-IsccPath` 和 `-VcRuntimeDirectory` 仍可手动指定。

脚本测试可在两种系统执行：

```powershell
py -3 -m unittest discover -s scripts/tests -v
```

## 验证分工

- 本地：仅做 Git / 版本 / 更新说明检查，通常数秒；不重复构建和运行全套测试。
- CI：全量测试一次，构建一次，再提取 arm64 / x86_64，生成两个 DMG 和 SHA256SUMS.txt。
- 上传后：自动确认版本号标题、附件列表，并实际下载两个安装包核对 SHA-256。
- Actions 成功后再向用户报告发布完成，附 Release 链接与编号更新要点。

修改原生窗口逻辑等高风险功能时，仍建议额外进行本地实机冒烟测试。自动化校验不能证明所有运行交互都正确。

## 单独本地打包（可选）

```sh
flutter build macos --release
python3 scripts/package_macos_release.py
```

输出在 `build/release/`。已有同名包时脚本会拒绝覆盖，请先移动或归档旧包。不要为了发布重复执行本地打包和 CI 打包。

## 失败恢复

推送失败时本地提交和标签会保留，脚本不会重置工作区。查明原因后可重新执行对应的 `git push --atomic`；不要删除、移动已发布标签。

若 CI 在上传前失败，在 GitHub Actions 修复问题后按实际情况重跑或发布新版本。若 Release 已上传而下载校验失败，应先检查网络和现有附件，不能重复创建或覆盖 Release。
