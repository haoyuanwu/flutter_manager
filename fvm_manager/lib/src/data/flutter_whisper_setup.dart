import 'dart:convert';

/// User-invoked setup prompt; installation is performed by the chosen AI client.
String buildFlutterWhisperSetupPrompt({
  String? projectPath,
  String? managerConfig,
  String? managerSkillPath,
}) {
  final target = projectPath?.trim();
  final targetDescription = target == null || target.isEmpty
      ? '目标项目尚未选择：先读取 Flutter Manager 当前选择或当前工作区的 Flutter 项目。无法唯一确定时只询问项目，不猜测。'
      : '目标项目路径（JSON 字符串）：${jsonEncode(target)}；这是连接和启动的目标，不要改用安装说明所在的项目。';
  final manager = managerConfig == null
      ? '复用当前客户端已有 flutter_manager 配置与有效认证；没有连接信息时说明缺少什么，不猜测端口或 Token。'
      : '''Flutter Manager 本机连接配置（含私密 Token，仅用于本机配置与请求，不输出到日志、提交或接入记录）：
```json
$managerConfig
```
Skill 源目录（JSON 字符串）：${jsonEncode(managerSkillPath)}
读取该目录的 SKILL.md、references/command-guide.md 和 scripts/call_flutter_manager.py；按客户端能力安装或复用整个 Skill 目录，保留已有内容备份，不把 Token 写入 Skill。此提示词已明确授权下面的目标 Debug 启动；Skill 中“仅配置时不启动”的默认规则不适用于本次端到端接入。''';
  return '''请直接在当前 AI 客户端完成 Flutter AI Whisper（flutter_ai_whisper）安装、配置、加载、目标 Debug 应用连接和只读状态验证，直到可使用；不要只给操作建议或停在安装成功。
官方包文档：https://pub.dev/packages/flutter_ai_whisper
Codex 配置文档：https://developers.openai.com/codex/mcp
$targetDescription

本次授权：安装独立开发工具，备份并合并本机客户端配置，加载 MCP；若目标没有 Debug 会话，通过 Flutter Manager 启动目标 Debug 应用并等待连接。目标和设备明确时直接执行，无需再次询问是否启动。保留无关项目和现有运行会话；切换现有 Profile / Release、停止或重启已有应用不在此授权内。

一、先检查环境并处理已知安装问题
1. 阅读当前包文档与当前 AI 客户端的真实配置规则；确认在本机运行且能访问目标路径，云端的 127.0.0.1 不是开发机。识别操作系统、Dart/FVM、PUB_CACHE、实际 Dart SDK bin 和启动文件；先查已安装版本及 --help，可用则复用，不盲目升级。包目前要求 Dart 3.8+，以当前文档为准。
2. 未安装时执行 dart pub global activate flutter_ai_whisper。若镜像报 Package not available/找不到包，仅对本次安装指定 PUB_HOSTED_URL=https://pub.dev 后重试，不永久更改镜像；POSIX 可用 PUB_HOSTED_URL=https://pub.dev dart pub global activate flutter_ai_whisper，PowerShell 应临时设置环境变量并在 finally 中恢复原值。安装失败不能继续声称成功。
3. 若 dart --version 因 FVM/SDK 缓存写入被沙箱阻止，区分权限问题与版本问题；按客户端允许的权限流程重试，不绕过限制或擅自替换 SDK。权限不可获得时明确阻塞原因。
4. 找到实际全局启动文件并用绝对路径执行 --help。全局启动脚本仍可能调用 dart：在该 MCP 服务的 env.PATH 中前置已验证的真实 Dart SDK bin，并保留原 PATH；用与服务配置一致的环境验证启动，不能仅凭 command 为绝对路径判断可用。Windows 使用实际生成的启动文件与正确 JSON/TOML 路径转义，不写其他机器的示例路径。它是独立开发工具，不要加入应用 pubspec.yaml，也不要修改 main.dart，不安装可选 DevTools 插件。

二、配置 Whisper 与 Flutter Manager
5. 识别当前客户端实际使用的配置文件；先备份、读取再合并，保留 flutter_manager、其他服务、设置与注释；同名条目已正确则复用，错误则只修复该条目。写入后解析检查，确认无重复服务且其他配置未变。通用 JSON 使用 mcpServers，VS Code 使用 servers 和 type=stdio；OpenCode 使用 mcp、type=local 和 command 数组；Codex 使用真实 CODEX_HOME（如已设置）下的 config.toml，否则 ~/.codex/config.toml：
[mcp_servers.flutter-ai-whisper]
command = "<已验证的启动文件绝对路径>"
[mcp_servers.flutter-ai-whisper.env]
PATH = "<实际 Dart SDK bin + 本机分隔符 + 原 PATH>"
这是结构示意，必须替换为本机实值，不能把占位符写入配置。优先用当前客户端支持的方式；若系统 codex CLI 报 ENOENT/安装损坏，使用已验证的当前客户端自带 CLI（若可定位），或直接安全合并配置，不为此重装客户端，也不要硬编码 App 名称或路径。CLI 的 mcp get/list 只证明配置可读。
$manager
6. 检查 Node.js 18+ 和上述 Manager Server 文件；Manager 未接入或配置过期时，转换上面的 JSON 并合并到当前客户端，保留其他服务。用配置 env 中的主机、端口和 Token 请求 GET /health，带 Authorization: Bearer <Token>。Unauthorized 表示认证无效，不表示项目未运行；先复核本次配置与请求是否确实带有效 Token，不清空或重置认证。Whisper 是 stdio 服务，不使用 Manager 的 HTTP 端口或 Token。

三、加载工具与启动目标
7. 优先使用客户端公开支持的 MCP 重载/工具发现能力，实际调用 flutter_manager_list_projects 和 Whisper 的 discover_running_apps。配置可读、--help 或独立 stdio initialize/tools/list 成功，都不能代替“当前聊天已加载工具”。缺少已加载的 Manager 工具时，可用上面 Skill 的 HTTP 脚本并传入本次有效 env 完成运行查询和启动；HTTP 成功仍不证明客户端 MCP 已加载。
8. 若客户端无法在当前聊天重载，先完成所有可执行的安装、配置、鉴权检查，并在 HTTP 桥接可用时继续下面的目标运行检查和必要的 Debug 启动；允许独立 MCP 握手作诊断并结束诊断进程，但不能据此宣布接入完成。不要关闭当前客户端、尝试被禁止的 UI 自动化或反复绕过限制。只请求一次必要的人工操作：在客户端 MCP 设置 Restart，必要时重启客户端/新开聊天；同时提供不含 Token 的续接提示词，包含目标项目、真实配置路径、已完成项及“复用现有安装，发现工具→查运行→必要时启动目标 Debug→连接→读取状态”的剩余步骤。明确当前处于待重载状态。
9. 用目标绝对路径作为 workspaceFilter 调用 discover_running_apps，再调用 connect_to_app。发现为空不等于机器上没有 Debug 应用；先查 Manager 的 list_running_projects/get_runtime_status（HTTP 对应短工具名）。已运行或正在构建时复用并等待，不重复 run；若 VM 已就绪但发现为空，从目标当前运行状态取 vmServiceUri 作为 vmUri 回退，不能用网页 URL 或 DTD 地址，不暴露完整认证地址。
10. 确认目标确实未运行时，查 list_projects/list_devices，先用 get_capabilities/get_project_config 检查能力及配置，复用该项目已选设备、flavor、入口和运行参数。注意 run/rerun 没有 mode 参数：若保存的 runMode 不是 debug，只在目标未运行时用 configure_project 将 runMode 设为 debug（不是构建用的 mode），等待 get_operation 成功并复查后再 run；不要给 run 塞入无效参数。旧版不支持 configure_project 时明确说明需升级 Manager 或手动选择 Debug，不冒充已切换。有唯一兼容设备可直接选择，多个候选又无已选设备/必要 flavor 不明时才询问这一项。若必须切换已有 Profile / Release 会话，先说明并征求确认，不停止它来验证。通过 Flutter Manager run，不在终端另起 flutter run；启动后用 get_runtime_status 和 wait_for_runtime_change 的 cursor/logLength 读取增量日志，等待 VM Service 就绪；按具体错误处理本次启动问题，不默认 clean，不擅自修改业务代码或添加生产依赖。重新发现并连接目标，失败就报告具体证据，不盲目重试。

四、验证和完成标准
11. 连接成功后只做只读验证，调用 list_active_state_holders；Web 或原生枚举为空时先读源码，用真实可读取的 expressions，私有成员传声明库 libraryUri，不猜变量名。不注入状态、不导航、不启用会执行变更方法的 change refresh，不上传安装包。
12. 分项报告：实际安装版本与启动环境、修改的配置/备份/Skill 路径、当前客户端工具加载情况、Manager 鉴权、目标项目/设备/Debug 运行情况、Whisper 连接和状态读取结果。只有“当前聊天工具已加载 + 目标连接成功 + 只读状态调用成功”都满足，才报告接入完成、可以使用；空状态列表要如实说明，不虚构业务状态。任一失败就标明未完成项与下一步，不把独立握手当最终验收。记录和回复隐藏 Token 与完整 VM Service 认证地址。
''';
}
