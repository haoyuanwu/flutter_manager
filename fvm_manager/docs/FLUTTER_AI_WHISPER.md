# Flutter AI Whisper 使用指南

`flutter_ai_whisper` 是独立的 stdio MCP 服务，通过 Dart VM Service 检查 Flutter Debug 应用。它与 Flutter Manager MCP 可同时使用：Manager 负责项目、设备、运行和控制台；Whisper 负责应用内部状态检查、状态注入与路由调试。

## 一键接入闭环

在 MCP 服务页展开 Flutter AI Whisper，点击“一键复制接入提示词”。按钮复用 Manager 的文件准备与服务启用流程，复制目标项目、真实 Server / Skill 路径和含端口、Token 的 Manager 配置。只粘贴给本机可信 AI；凭据不写入文档、日志或提交。

提示词明确授权安装独立工具、合并配置，并在目标未运行时通过 Manager 启动 Debug，等待 VM 就绪后连接和读取状态。已有会话直接复用；目标或设备不唯一才询问，不授权停止/重启已有会话。只配置 Manager 的“一键复制接入说明”仍不授权启动项目。

安装先检查并复用已有版本；遇镜像缺包时临时使用官方源；给服务 PATH 前置真实 Dart SDK bin，避免绝对启动脚本仍找不到 Dart。SDK 缓存权限、CLI 损坏、Manager 鉴权失败分别处理，不误判为版本不兼容或项目未运行。

验收分三项：**当前聊天实际加载工具、连接目标成功、只读状态调用成功**。独立握手或配置可读取不足以宣布完成。客户端若不支持当前聊天重载，AI 完成可执行准备后，提供一次人工 Restart 指引和不含凭据的续接提示词；重载后继续验证。不能承诺所有客户端都能免重启完成。

## 安装

在开发机使用 Dart 3.8 或更新版本：

```sh
dart pub global activate flutter_ai_whisper
flutter_ai_whisper --help
```

无需给被调试项目添加依赖，也无需修改 `main.dart`。使用 FVM 时先确认 `dart --version` 对应的 SDK 可用。安装命令由开发者执行，本指南不会自动安装或修改客户端配置。

找不到命令时，检查 Pub 缓存的 bin 目录是否在 AI 客户端的 PATH 中；GUI 客户端可能没有终端的 PATH。也可把下方 command 改为可执行文件绝对路径。启动脚本内部仍可能调用 `dart`，因此即使 command 为绝对路径，也需要在该服务的 `env.PATH` 中前置真实 Dart SDK bin 并保留原 PATH，再按相同环境验证。Windows 路径使用 JSON 时转义反斜杠，并使用实际生成的启动文件。

## 配置 AI 客户端

合并配置，保留已有 `flutter_manager` 和其他服务。

Cursor 的项目 `.cursor/mcp.json` 或 Claude Desktop 的 `claude_desktop_config.json`：

```json
{
  "mcpServers": {
    "flutter-ai-whisper": {
      "command": "flutter_ai_whisper"
    }
  }
}
```

Codex 的 `~/.codex/config.toml`：

```toml
[mcp_servers.flutter-ai-whisper]
command = "flutter_ai_whisper"
```

VS Code 的 `.vscode/mcp.json` 使用 `servers` 作为顶层键：

```json
{
  "servers": {
    "flutter-ai-whisper": {
      "type": "stdio",
      "command": "flutter_ai_whisper"
    }
  }
}
```

OpenCode 的 `~/.config/opencode/opencode.json`：

```json
{
  "mcp": {
    "flutter-ai-whisper": {
      "type": "local",
      "command": ["flutter_ai_whisper"],
      "enabled": true
    }
  }
}
```

重新加载客户端，确认服务及工具已出现。它由客户端启动，通过 stdio 通信，不是交互式终端程序，也不使用 Flutter Manager 的 HTTP 端口或 Token。

## 在 Flutter Manager 管理的项目中使用

1. 选择项目和运行设备，以 **Debug** 模式运行。Profile、Release 和混淆产物不适用。
2. 让 AI 调用 `discover_running_apps` 找到目标，再用 `connect_to_app` 连接。多个项目同时运行时传入 `workspaceFilter`，避免连错应用。
3. 用 `list_active_state_holders` 读取状态；确需修改时用 `inject_state_variable` 调用源码中已有的方法。路由导航使用 `trigger_route_navigation`，目标必须已注册。
4. 修改后确认页面刷新，不能仅以变量变化判断界面更新。Web 不支持堆枚举，应结合源码传入 `expressions`；私有成员需指定声明它的 `libraryUri`。

可以复制给 AI：

> 使用 Flutter AI Whisper 发现并连接当前项目的 Debug 应用，先列出可读取的状态，不修改。多个应用时按项目路径筛选。需要修改时先结合源码解释将调用的方法，再按我的要求执行并确认页面更新。

自动发现失败时，才使用当前调试会话的 VM Service WebSocket 地址作为 `vmUri`。应用重启后重新发现，不复用旧认证地址；浏览器页面 URL 不是 VM Service 地址。不要把 DTD 地址直接作为 `vmUri`。

仅连接自己控制的本机调试应用，VM Service 保持本机访问；状态注入会在应用进程内执行 Dart，具有该应用的权限。

## 来源

- [flutter_ai_whisper 包文档](https://pub.dev/packages/flutter_ai_whisper)：安装、客户端配置、工具参数及平台限制。包版本和能力可能变化，以该文档为准。
- [原始微信文章](https://mp.weixin.qq.com/s/-b1-ou5gwJ2W8OGiazrYKQ)：本次访问被环境验证拦截，未将未读取的文章内容作为实现依据。
