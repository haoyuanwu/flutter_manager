# 发布约定

- GitHub Release 标题仅使用版本号（例如 `v1.2.6`），不要添加 Flutter Manager 等产品名前缀。

- 按用户确认的版本号构建和发布，代码、Git 标签和安装包版本保持一致。
- 每次 GitHub Release 都附上简短更新说明，使用 `1. 2. 3.` 编号，优先描述用户可见的新增、优化与修复。
- 上传后核实 Release 与附件可下载，在回复中提供发布链接，并再次按编号列出本次更新要点。

## AI 发布流程：优先使用已有脚本

- 开始打包、上传、补传或恢复发布前，先读 `fvm_manager/scripts/RELEASING.md`，核对相关脚本与工作流。不要凭旧会话记忆重新拼装流程。
- 发布入口：`fvm_manager/scripts/release.py`。Windows 和 macOS 都可运行；在 `fvm_manager` 目录执行。版本号必须由用户确认，不把文档示例当作本次版本。
- 检查 Git 差异后只暂存本次发布的文件；脚本不会自动暂存所有改动。测试目录可能被全局 Git 规则忽略，需要显式 `git add -f`。保留无关用户改动。
- 先运行预览，再在同一命令追加 `--publish`。脚本负责更新版本、生成编号说明、中文提交、创建标签，并原子推送 main 与标签；不要再手工重复这些步骤。

```sh
# 以下版本号仅为示例，必须换成用户确认的版本。
python3 scripts/release.py 1.2.12+18 --note "新增功能说明" --note "优化与修复说明"
python3 scripts/release.py 1.2.12+18 --note "新增功能说明" --note "优化与修复说明" --publish
```

### 脚本职责与验证边界

| 入口 | 用途 |
| --- | --- |
| `fvm_manager/scripts/release.py` | 本地版本/Git 检查、预览、中文提交与推送，触发云端发布 |
| `.github/workflows/release-macos.yml` | 云端测试、macOS Release 构建、双架构 DMG 打包、上传、下载校验 |
| `fvm_manager/scripts/package_macos_release.py` | macOS 本地或 CI 打包 DMG；不负责上传。仅在明确需要本地打包时运行 |
| `fvm_manager/scripts/verify_github_release.py` | CI 上传后的 Release 标题、附件及下载 SHA-256 校验 |
| `fvm_manager/scripts/package_windows_release.ps1` | 在 Windows 构建、打包、补传同版本安装包；支持恢复上传，参数见发布文档 |

- 日常发包让脚本/CI 完成既有验证，不在本地重复完整测试、构建、截图、手工签名检查或下载全部附件。
- 上传后核实要求优先由 CI 的 `Verify published release and downloads` 步骤满足；该步骤成功后，不再额外下载并校验一遍。
- 允许读取 Actions 状态、失败日志和最终发布链接。这是确认流程结果，不是另做一套验证；避免短间隔反复查询或播报不变状态。
- 推送成功不等于发布成功。等待工作流及下载校验成功后才报告“发布完成”；失败或仍运行时明确说明实际状态。
- 仅在脚本失败、校验缺失、用户要求或具体风险需要时追加针对性排查，并说明原因。不要无故扩大验证范围，也不要为了加快发布擅自删除已有安全校验。
- 修改代码过程中的必要回归测试不等于发布时重复验证；不要因本约定跳过功能开发所需的测试。

### 失败恢复与平台约束

- 已有提交/标签/Release 时先核实实际状态，按文档恢复，不要重复执行新版本发布入口、强推、移动已发布标签或擅自覆盖附件。
- Windows 一键构建上传与 `-UploadOnly` 恢复优先复用现有 PowerShell 脚本，不重写上传逻辑；只能在 Windows 环境构建 Windows 安装包。
- macOS 默认通过 GitHub Actions 生成 Apple Silicon / Intel 两个 DMG；无需本地再构建一次。当前签名为临时签名，不宣称已完成 Developer ID 签名或公证。
- 最终回复提供 Release 链接、产物平台和 `1. 2. 3.` 更新要点；如有未完成的平台或步骤，明确列出。

## 维护约定

- 可跨会话复用的项目操作流程写进仓库文档与本文件，不只留在聊天中；脚本参数或职责变更时同步更新 `scripts/RELEASING.md`。
- 这里只记录规则和入口，不写令牌、密码、SSH 私钥或一次性任务进度。
