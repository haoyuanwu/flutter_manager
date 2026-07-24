# Flutter Manager 剩余优化路线与 AI 交接说明

> 用途：本文档用于把后续优化工作交给其他 AI 或开发者。  
> 项目根目录：`fvm_manager/`  
> 目标平台：macOS、Windows。

## 1. 项目定位

Flutter Manager 是一个 Flutter 桌面工具，用来统一管理：

- FVM 和多个 Flutter SDK。
- Flutter 项目、项目别名和项目级 FVM 版本。
- Flutter Run、Rerun、Pub Get、Clean、Build、DevTools。
- 多项目、多命令进程和隔离控制台。
- Android、iOS、macOS、Windows 构建与打包。
- DMG、Inno Setup 安装包。
- 构建产物管理与蒲公英、fir.im、App Store、Google Play、Transporter 分发。
- 本地 HTTP/MCP Server，供 Codex 等 AI 工具操作 App。
- 菜单栏状态、环境诊断、镜像源切换、日志等辅助功能。

## 2. 继续修改前必须了解的约束

1. 不要覆盖或回退工作区中的现有改动。当前多项优化可能尚未提交。
2. macOS 与 Windows 必须使用平台分支，不要为了修复 Windows 而改变 macOS 现有逻辑。
3. 设备监听是全局能力，不应在切换项目时重建。
4. 命令和控制台必须按项目、进程隔离。
5. 所有删除操作必须二次确认。
6. 用户偏好轻量验证：默认只做格式化、静态分析和 `git diff --check`；没有明确报错时不执行完整构建。
7. 敏感信息不得打印到日志、MCP 响应或错误文本中。

## 3. 已完成的优化，请勿重复实现

### 3.1 FVM 与环境

- 检测不到 FVM 时，会引导安装或选择本地 FVM 目录。
- 有 Dart 时使用 Dart Pub 安装 FVM。
- macOS/Linux 无 Dart 时可调用 FVM 官方安装程序。
- Windows 无 Dart 时可使用 Chocolatey。
- 已补充独立 FVM 安装目录、Pub Cache 和常见 PATH 的自动检测。
- 执行 Run、Build、Pub Get、Clean、DevTools 等命令前会检查 FVM 和 Flutter SDK。
- 项目指定的 Flutter 版本未安装时，会精确提示并支持安装。

### 3.2 环境诊断

- 已有独立“环境诊断”页面。
- App 每次运行期间，第一次进入自动诊断；普通页面切换不会重复诊断。
- 已检查 FVM、Flutter SDK、项目版本、镜像源、设备、项目目录、Flavor、构建产物、MCP。
- Android 工具链：Android SDK、ADB、Java/JDK。
- macOS/iOS 工具链：Xcode、CocoaPods。
- Windows 工具链：Visual Studio C++ workload、Inno Setup。
- 缺少工具时提供官方下载或安装说明链接。
- 镜像源故障时可并行测速并自动切换到最快可用源。
- 已整合 `flutter doctor -v`，会根据当前项目平台过滤无关项。
- Flutter Doctor 最长等待 90 秒，超时会终止。

### 3.3 构建产物中心第一阶段

- 左侧导航的“分发平台”已升级为“产物中心”。
- 支持 APK、AAB、IPA、HAP、DMG、PKG、MSIX、EXE、ZIP。
- 已收紧 APK/AAB/IPA 扫描路径，降低误识别中间产物的概率。
- 支持项目选择、文件名搜索、平台筛选、格式筛选。
- 支持最新优先、体积最大、文件名排序。
- 已有产物数量、总体积、最近产物等轻量概览。
- 宽窗口为左侧产物列表+右侧检查器，窄窗口为上下布局。
- 右侧已分为“产物详情”和“分发上传”标签页。
- 支持复制路径、在文件管理器中定位、添加自定义本地产物。
- 保留蒲公英、fir.im、App Store、Google Play、Transporter 能力。

### 3.4 其他已有能力

- 项目别名持久化，项目列表优先显示别名。
- 命令控制台已按项目隔离，支持多进程。
- 支持独立控制台窗口、Command+F 搜索、Command+W 关闭。
- 支持菜单栏状态菜单。
- 支持 MCP Server 与 App 内 localhost HTTP 接口。
- 支持 MCP Skill 配置说明与导出。
- 支持 macOS DMG 以及 Windows Inno Setup 打包。

---

## 4. 剩余优化总览

| 优先级 | 主题 | 主要价值 |
| --- | --- | --- |
| P0 | 产物历史与构建会话 | 让产物中心从“文件扫描器”变成真正的构建记录中心 |
| P0 | 产物自动刷新与失效管理 | 构建完成后无需手动刷新，清晰区分存在/丢失文件 |
| P0 | 敏感信息安全存储 | 避免 API Key、Token 明文落盘 |
| P1 | 进程与控制台基础设施拆分 | 降低 `providers.dart` 复杂度，提高稳定性 |
| P1 | 环境诊断的可执行修复 | 从“看问题”进一步到“安全地解决问题” |
| P1 | MCP API 版本化与事件接口 | 提高 AI 自动化的可靠性和节省 Token |
| P1 | Windows 平台适配收口 | 减少 shell、编码、TLS、路径差异造成的故障 |
| P2 | 构建签名、公证和发布检查 | 提高产物真正可交付性 |
| P2 | 启动性能与长时间运行稳定性 | 降低首启等待、内存与日志压力 |
| P2 | UI 一致性、可访问性和空状态 | 降低学习成本，改善小窗口和键盘操作 |

---

## 5. P0：构建产物中心第二阶段

### 5.1 持久化产物历史

#### 当前实施状态（2026-07-10）

基础版已完成：

- 已新增 `BuildSession`、`BuildArtifactRecord`、`BuildHistorySnapshot`。
- 已新增 `BuildHistoryRepository`，使用 `schemaVersion: 1`，保存到 `.fvm_manager/build_history.json`。
- 已限制最多保留 500 个 Build Session，裁剪时同步裁剪关联产物。
- “读取→合并→写入”已整体串行化，多项目并发构建不应互相覆盖。
- 标准 Build 会在 `_runProjectCommands(taskKind: 'build')` 创建 Session，并在结束后记录 success/failed/stopped。
- 成功构建只关联本次构建开始后新建或更新的最终产物，避免把旧文件归入新 Session。
- App 启动时会将上次崩溃遗留的 running Session 标记为 interrupted，当前运行中的 Build 不会被误判。
- 产物中心右侧已新增“构建历史”标签页，展示状态、目标、模式、Flavor、Flutter 版本、耗时、命令和关联产物。
- 历史产物文件已丢失时会显示失效状态并禁用文件定位。

仍待补充：

- 自定义构建工作流的 Build Session 关联。
- App 版本、Build Number、Bundle ID/Application ID 等元数据。
- 完整的上传历史与签名/公证状态。
- 按日期分组、全页历史视图和历史搜索。

#### 问题

当前产物中心主要依赖扫描 `build/` 目录。一旦执行 Clean，过往构建信息就会消失；同名文件也无法判断对应哪次构建。

#### 建议数据模型

新增独立模型，不要直接把所有字段塞进 `FlutterProject`：

```dart
class BuildSession {
  String id;
  String projectPath;
  DateTime startedAt;
  DateTime? finishedAt;
  String taskId;
  String command;
  String target;
  String mode;
  List<String> flavors;
  String? flutterVersion;
  String? appVersion;
  String? buildNumber;
  int? exitCode;
  bool stoppedByUser;
  List<String> artifactIds;
}

class BuildArtifactRecord {
  String id;
  String buildSessionId;
  String projectPath;
  String path;
  String name;
  String type;
  String platform;
  int size;
  DateTime modified;
  bool exists;
  String source; // build / manual / imported
  String? fingerprint;
}
```

#### 存储建议

- 新增 `BuildHistoryRepository`，参考现有 `ProjectRepository`。
- 保存到 App Support 目录的 JSON，不要写入 Flutter 项目本身。
- 列表页加载时检查 `exists`，但不要自动删除历史。
- 历史记录与实体文件分离：Clean 后仍保留历史，标记为“文件已丢失”。
- `fingerprint` 第一版可使用 `path + size + modified`；SHA-256 应按需后台计算，避免大 IPA/DMG 阻塞 UI。

#### 接入点

- 构建任务启动时创建 `BuildSession`。
- 建议从 `FvmController._runProjectCommands` 的 build task 分支接入。
- 构建成功后调用 `DistributionService.scanArtifacts(projectPath)`，只关联本次构建时间后新增或改动的产物。
- 构建失败也保留 Session，但不应误关联旧文件。

#### UI 建议

- 产物列表支持“当前文件 / 构建历史”切换。
- 历史按日期或 Build Session 分组，不要把所有文件放成一个无限列表。
- 显示构建目标、Mode、Flavor、Flutter 版本、App 版本、构建时长与结果。
- 文件丢失时禁用“打开/上传”，但允许查看构建参数和日志。

#### 验收标准

- 完成两次不同 Flavor 构建后，能分清产物属于哪次构建。
- Clean 后历史仍在，但文件标记为丢失。
- 构建失败不会把上一次产物归到新 Session。
- App 重启后历史仍存在。

### 5.2 构建目录自动监听

#### 实现建议

- 每个当前选中项目最多保留一个 `Directory.watch` 订阅。
- 监听 `build/` 不要监听整个项目。
- `build/` 不存在时，可以监听项目根目录的直接子级，发现 build 创建后切换订阅。
- 使用 500~1000ms debounce，不要每个 Gradle/Xcode 文件事件都全量扫描。
- 只对支持的扩展名、目录创建和删除事件触发刷新。
- 页面销毁、项目切换、App 退出时必须取消订阅和 Timer。
- 自动刷新应为静默刷新，不要频繁闪烁全屏 Loading。

#### 验收标准

- 产物中心打开时完成构建，新产物自动出现。
- 一次 Android 构建不会导致数十次明显刷新。
- 切换项目后旧项目事件不再修改当前列表。

### 5.3 产物操作与失效处理

- 增加单个产物删除，必须二次确认。
- 确认框必须显示项目名、文件名、完整路径和大小。
- 区分“删除实体文件”与“只删除历史记录”。
- 禁止使用递归目录删除来删除单个产物。
- 添加“重新检查文件”和“清理失效记录”，后者也需要二次确认。
- 上传前再次检查文件存在性、大小和扩展名。

### 5.4 产物元数据与分发记录

建议后续补充：

- App 版本号、Build Number、Bundle ID/Application ID。
- Android Flavor、Build Type、ABI。
- Flutter/FVM/Dart 版本。
- 文件签名状态、macOS 公证状态、Windows 数字签名状态。
- 上传渠道、上传时间、结果、下载页、失败摘要。
- 同一产物重复上传时保留每次记录，不要只覆盖最后一次。
- API Key/Token 永远不写入产物历史。

---

## 6. P0：敏感信息安全

### 当前风险

项目存在 MCP Token、蒲公英 API Key、fir.im API Token 等敏感数据。如果继续使用普通 JSON 明文持久化，安全性不足。

### 建议方案

- 定义 `SecretStorage` 接口，UI 和 Controller 不直接依赖具体存储。
- macOS 使用 Keychain。
- Windows 使用 Credential Manager 或 DPAPI。
- 普通设置 JSON 只保存“已配置”状态和非敏感选项。
- 第一次升级时做一次明文到安全存储的迁移，成功后从旧 JSON 移除。
- 日志、错误、MCP 返回中要统一脱敏。不要只针对 `-appkey` 一个参数。
- 脱敏关键字至少包括：`token`、`apiKey`、`api_token`、`authorization`、`password`、`secret`。
- UI 只显示前 4~8 位+掩码，不应通过 SelectableText 显示完整值。

### 验收标准

- 搜索 App 设置目录不能找到完整 Token/API Key。
- 上传失败、MCP 调用失败时日志中不出现完整密钥。
- 从旧版升级后原有配置仍可用。

---

## 7. P1：拆分过大 Controller 与进程基础设施

### 问题

`lib/src/presentation/providers.dart` 已包含过多职责：FVM、Flutter SDK、项目、设备、命令、构建、打包、上传、菜单栏、MCP 状态等。继续在该文件追加功能会提高回归风险。

### 建议拆分

- `EnvironmentController`：FVM、Flutter SDK、镜像源、环境诊断。
- `ProjectController`：项目列表、别名、项目配置、路径重定位。
- `CommandController`：Run/Rerun/Stop/Pub Get/Clean/DevTools。
- `BuildController`：Build workflow、DMG、Inno Setup、符号表。
- `ArtifactController`：扫描、历史、筛选、删除、监听。
- `DistributionController`：蒲公英、fir.im、App Store 等。
- `DeviceController`：全局设备 daemon，不随项目切换。
- `McpController`：服务启停、配置与状态。

不建议一次性大量搬迁。应该在每个新功能开始前，先把它依赖的那一小块状态和逻辑拆出。

### 统一进程模型

建议引入统一的 `ManagedProcess` / `CommandTask` 实体：

- `taskId`、`projectPath`、`kind`、`label`、`command`。
- `startedAt`、`finishedAt`、`exitCode`、`status`。
- `pid`、`processGroupId`（如平台支持）。
- `vmServiceUri`、`deviceId`。
- `expectedTermination`，用来区分用户 Stop 与真实异常。

Stop 时不能只杀 shell 父进程，应尽量终止整个进程组，并给 Flutter tool 足够时间关闭设备端 App。

### 验收标准

- 同一项目可同时运行 Run 和 Build，互不覆盖。
- 不同项目的日志、VM Service URI、Stop 操作完全隔离。
- 用户 Stop 导致的 `-15`/termination code 不显示为错误。
- Stop Android Run 后，设备上的 App 按预期退出；如 Flutter tool 无法做到，UI 需明确说明。

---

## 8. P1：控制台与日志长时间稳定性

### 建议

- 每个项目/任务使用有上限的 ring buffer，避免长时间 Run 导致内存持续增长。
- 内存只保留最近若干 MB 或若干行；完整日志可选择流式写入文件。
- Command+F 搜索不应每输入一个字符都对超大字符串做全量高亮。使用 debounce 和匹配上限。
- 增加“跳到上一个/下一个匹配”和匹配计数。
- 新输出到来时，只有用户已在底部才自动跟随；用户向上查看历史时不要强制拉回底部。
- 显示“有新输出”按钮，点击回到底部。
- 支持导出当前任务日志，文件名包含项目别名、任务类型和时间。
- 日志文件也要做敏感信息脱敏。

---

## 9. P1：环境诊断后续优化

### 9.1 安全的可执行修复

可自动完成：

- 测试并切换 Pub/Flutter 镜像源（已有）。
- 安装 FVM（已有）。
- 安装项目需要的 Flutter SDK（已有）。
- 已安装 Flutter SDK 但无 global 时，允许一键设为 global。
- 打开 Android Studio SDK Manager、Xcode、Visual Studio Installer、Inno Setup 下载页。

不应无确认自动完成：

- `sudo xcodebuild -license`。
- Android licenses 的交互式协议接受。
- 需要管理员权限的安装。
- 修改系统级 PATH、证书、代理、防火墙。

这些操作应显示将要执行的命令、风险说明和二次确认，再在独立控制台中执行。

### 9.2 诊断缓存与失效规则

- 当前诊断结果在 App 运行期间缓存。
- 后续应为每个诊断项增加依赖签名，例如：项目路径、Flutter 版本、镜像源、平台。
- 切换项目后不必自动运行完整 Doctor，但 UI 应显示“当前结果属于上一个项目”或标记结果过期。
- 当 FVM/Flutter 安装、镜像源切换、项目版本改变后，只失效相关诊断类别。
- Flutter Doctor 应支持取消，离开页面后不应留下无主进程。

---

## 10. P1：MCP/HTTP 接口继续优化

### API 设计

- 为 HTTP 路由增加版本前缀，例如 `/api/v1/...`。
- 增加 `capabilities` 接口，返回 App 版本、MCP 版本、支持的命令和平台。
- 所有异步任务返回统一 `taskId`，不要让 AI 依赖 UI 文本判断任务。
- 统一错误结构：`code`、`message`、`recoverable`、`details`（脱敏）。
- 读控制台支持 `offset/cursor/limit`，不要每次返回全部日志。
- 增加任务状态接口和事件流（SSE 或 WebSocket），供 AI 等待 Run/Build 完成。
- 为产物中心增加：列表产物、获取产物详情、列表 Build Session、打开产物位置。
- 删除产物、上传产物等有副作用操作必须要求明确参数，不得默认使用“列表第一个”。

### Skill 同步

- 每次新增 MCP tool 后，同步更新项目中的 Skill 源文件。
- Skill 需写明先获取 capabilities，再决定可用命令。
- 所有示例使用相对于项目根目录的路径，不得写入开发者本机绝对路径。
- App 中的配置说明应提供一键复制，并根据当前端口/Token 生成。

---

## 11. P1：Windows 兼容性收口

### 建议引入平台适配层

将以下逻辑从 UI/Controller 中抽出：

- 可执行文件后缀：`.exe/.bat/.cmd`。
- shell 调用：macOS/Linux 直接 `Process.start`，Windows 只在必要时 `runInShell`。
- 路径拼接和引号：始终传递 arguments 列表，尽量不拼接命令字符串。
- stdout/stderr 编码：UTF-8、系统编码和 malformed bytes 兜底。
- 打开文件/目录/网址。
- 终止进程树。
- 常见工具路径检测。

### Windows 专项验收

- 无管理员权限时的错误可理解，不得默默失败。
- Pub TLS 失败时能进入环境诊断并切换镜像，不要修改 macOS 的环境逻辑。
- Flutter Run/Pub Get/Clean/Build 不依赖 bash 语法。
- 项目路径含空格、中文时所有命令仍可执行。
- Inno Setup 可自动检测并允许手动选择；生成后打开所在目录。

---

## 12. P2：签名、公证与发布前检查

### macOS/iOS

- 检查 Xcode signing identity、Team、Provisioning Profile。
- DMG/PKG 生成后可选做 `codesign --verify`。
- 增加 notarization 状态与 stapling 检查，但不要在无用户明确配置时自动提交 Apple。
- 凭证必须放入 Keychain，不得放入项目设置 JSON。

### Windows

- 支持选择代码签名证书和 `signtool.exe`。
- 安装包生成后校验签名。
- 无证书时可生成未签名产物，但产物中心要明确标记“未签名”。

### 发布前通用检查

- 包名/Bundle ID、版本号、Build Number 为空或异常时警告。
- Release 产物中包含 debug 标记时警告。
- 上传前对大小与渠道支持格式做检查。
- 所有警告应可追溯到某个 Build Session。

---

## 13. P2：启动性能与资源管理

### 建议的初始化阶段

1. 立即加载本地设置与项目列表。
2. 检测 FVM 并恢复菜单栏/MCP 配置。
3. 启动唯一的全局设备 daemon。
4. 首屏可交互后，后台获取 Flutter/FVM 在线版本。
5. FVM cache 大小、产物扫描、Flutter Doctor 全部延迟或按需。

### 其他优化

- 为长时间文件扫描增加取消标记。
- 大目录计算不应占用 UI isolate；但先测量，不要为小任务过度引入 isolate。
- 页面销毁时统一检查 StreamSubscription、Timer、Process 和 TextEditingController 释放。
- 为启动步骤记录耗时，但日志不记录敏感环境变量。
- 对网络版本信息添加合理缓存时间，不要每次进页重复拉取。

---

## 14. P2：UI 一致性与可访问性

### 通用设计约定

- 提取统一 spacing、card radius、border color、section title 和 empty state 组件。
- 标准化四种状态：Loading、Empty、Error、Ready。
- 错误态尽量带“重试 / 环境诊断 / 查看说明”操作。
- 新 UI 展开时延续现有“自动滚动到新内容”原则。
- 不要在卡片中堆叠过多卡片；优先使用分区、Divider 或 Tab。
- 按钮文字描述结果，图标按钮必须有 Tooltip。
- 同一行操作超过 3~4 个时，使用“更多”菜单。

### 可访问性

- 不能只靠颜色区分成功/错误/选中，同时使用图标和文字。
- 关键文字与背景保持足够对比度。
- 支持键盘 Tab 导航、Enter/Space 触发、Esc 关闭弹窗。
- 检查系统字体放大时的溢出。
- 小窗口时优先保留核心操作，次要信息收起或放入 Tab/更多菜单。

---

## 15. 数据迁移与向后兼容

- 任何持久化结构都增加 `schemaVersion`。
- 读取旧数据时使用宽松默认值，不要因新字段缺失导致 App 无法启动。
- 迁移前对原文件做一份带时间的备份。
- 写入使用临时文件+原子替换，避免 App 崩溃后 JSON 被截断。
- 单个项目数据损坏不应阻止其他项目加载。
- 新增“导出配置备份 / 导入配置备份”时，默认不包含敏感凭证。

---

## 16. 建议的实施顺序

### 阶段 A：产物中心数据层

1. 新增 Build Session / Artifact Record 模型。
2. 新增持久化 Repository 和 schemaVersion。
3. 在 build task 启动/结束处记录 Session。
4. 扫描并关联产物。
5. 在现有产物中心增加“当前/历史”切换。

### 阶段 B：自动刷新与产物操作

1. 增加 build 目录 watcher 与 debounce。
2. 增加文件存在性检查和失效标记。
3. 增加删除文件/删除记录，两者都二次确认。
4. 增加上传历史。

### 阶段 C：安全存储

1. 抽象 SecretStorage。
2. 实现 macOS Keychain。
3. 实现 Windows Credential Manager/DPAPI。
4. 迁移现有 MCP/蒲公英/fir.im 凭证。
5. 统一日志脱敏。

### 阶段 D：架构拆分

1. 先拆 ArtifactController/Repository。
2. 再拆 Command/Build Controller。
3. 最后拆 Environment/Device/MCP。
4. 每次拆分后保持 UI 行为不变，不要同时大改 UI。

### 阶段 E：MCP 与发布检查

1. API v1、capabilities、统一 task/error 模型。
2. 日志分页和任务状态。
3. 事件流。
4. 产物查询工具。
5. 更新 Skill 并从 App 导出。

---

## 17. 每次改动的最小验证要求

默认执行：

```bash
dart format <changed dart files>
flutter analyze --no-pub
git diff --check
```

不要默认执行：

- 完整 `flutter build macos/windows`。
- 重新安装 FVM/Flutter SDK。
- 删除 FVM cache 或项目 build 目录。
- 真实上传到蒲公英/fir.im/App Store。
- 修改系统 PATH、签名、证书、代理或防火墙。

仅在以下情况加大验证范围：

- 用户明确要求。
- 静态分析或实际运行已出现错误。
- 修改了 macOS/Windows 原生启动、窗口、菜单栏、打包配置。
- 修改了文件删除、密钥迁移、进程终止等高风险逻辑。

---

## 18. 关键文件导航

| 功能 | 当前主要文件 |
| --- | --- |
| 全局 Controller/Provider | `lib/src/presentation/providers.dart` |
| 主页与导航切换 | `lib/src/presentation/home_page.dart` |
| 产物中心 UI | `lib/src/presentation/pages/distribution_page.dart` |
| 产物扫描/分发平台 | `lib/src/data/distribution_service.dart` |
| 项目管理 UI/构建入口 | `lib/src/presentation/pages/project_management_page.dart` |
| 项目持久化 | `lib/src/data/project_repository.dart` |
| FVM | `lib/src/data/fvm_service.dart` |
| Pub 镜像与设置 | `lib/src/data/pub_environment_service.dart` |
| 环境诊断服务 | `lib/src/data/environment_diagnostics_service.dart` |
| 环境诊断 UI | `lib/src/presentation/pages/environment_diagnostics_page.dart` |
| Flutter 命令 | `lib/src/data/flutter_command_service.dart` |
| 设备监听 | `lib/src/data/flutter_device_monitor.dart` |
| 控制台窗口 | `lib/src/presentation/pages/console_window_page.dart` |
| MCP/HTTP | `lib/src/presentation/mcp_control_server.dart` |
| 菜单栏 | `lib/src/presentation/status_menu_service.dart` |
| 域模型 | `lib/src/domain/models.dart`、`lib/src/domain/project_models.dart` |

---

## 19. 给后续 AI 的执行模板

建议每个任务按以下方式进行：

1. 先读本文档的“已完成”和相关优化章节。
2. 使用 `rg` 确认现有实现，不要仅根据文档猜测代码现状。
3. 说明本次只做哪一个阶段，避免同时改动数据层、进程层和大量 UI。
4. 优先新增小型 Service/Repository/Controller，不要继续扩大 `providers.dart`。
5. 保留 macOS 现有行为，Windows 适配使用独立分支或平台适配层。
6. 涉及删除、上传、凭证、系统环境、签名的操作，先检查授权边界和二次确认。
7. 完成后只做最小验证，并明确说明未做完整构建。

### 建议的下一个任务

**从“5.2 构建目录自动监听”开始。**

原因：Build Session/Artifact Record 数据层和基础历史 UI 已完成。下一步应让产物中心在构建或外部文件变化后自动静默刷新，再继续产物删除、上传历史和 MCP 查询。
