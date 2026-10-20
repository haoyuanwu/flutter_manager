# Flutter Manager MCP Server

这个目录是 Flutter Manager 的独立 MCP Server。

AI 软件通过 MCP 调用本服务，本服务再转发到 Flutter Manager App 内置的本地 HTTP 接口。

```text
AI 软件
  ↓ MCP stdio
mcp_server
  ↓ http://127.0.0.1:17891
Flutter Manager App
```

## 打包后的 App

推荐打开「MCP 服务 → 一键接入 AI」，点击「一键复制接入说明」。App 会把内置 MCP Server、Skill 和命令选择指南准备到用户目录并开启本机接口。将复制内容粘贴给能访问本机文件的 AI 工具，AI 可按说明合并 MCP 配置、安装 Skill、学习命令选择规则，并验证连接。部分客户端需要重启后才能加载新配置。

命令选择指南位于 Skill 的 `references/command-guide.md`，区分普通 Flutter UI 修改的热重载、Dart 初始化变化的热重启、原生代码或插件变化后的重新运行，以及依赖、资源和构建相关命令。接入本身只做配置和只读验证，不会启动或重启项目。

也可以展开「手动配置」：

安装 Flutter Manager 后，不需要复制项目源码：

1. 打开「MCP 服务」。
2. 点击「下载 MCP Server」。
3. 选择一个长期保留的目录。
4. App 会把内置的 `flutter-manager-mcp.mjs` 写入该目录并保存路径。
5. 从页面复制 OpenCode、Crush 或 Codex 配置。

目标电脑仍需安装 Node.js 18 或更高版本。

### 下载 Skill

Skill 用于告诉 AI 什么时候以及如何调用 Flutter Manager，不能代替 MCP Server 配置。

在 App 的「MCP 服务 → AI 工具安装 → AI Skill」中可以直接点击：

- 「安装到 Codex」：自动写入 Codex 全局 Skills 目录。
- 「安装到 OpenCode」：自动写入 OpenCode 全局 Skills 目录。
- 「安装到 Xiaomi MiMo」：自动写入 MiMo 全局 Skills 目录，并生成 `locales/zh-CN.json`、`locales/en-US.json` 展示信息。
- 「选择其他目录」：用于项目级或自定义安装位置。

默认目录：

- Codex（macOS/Linux）：`~/.codex/skills`
- Codex（Windows）：`%USERPROFILE%\.codex\skills`
- OpenCode（macOS/Linux）：`~/.config/opencode/skills`
- OpenCode（Windows）：`%USERPROFILE%\.config\opencode\skills`
- Xiaomi MiMo（macOS/Linux）：`~/.config/mimocode/skills`
- Xiaomi MiMo（Windows）：`%USERPROFILE%\.config\mimocode\skills`

App 会自动创建：

```text
flutter-manager-mcp/
├── SKILL.md
├── agents/
│   └── openai.yaml
└── scripts/
    └── call_flutter_manager.py
```

安装完成后重启对应 AI 工具（含 Xiaomi MiMo）。完整使用需要同时完成：

1. 下载 MCP Server。
2. 开启 App 的 MCP 控制接口。
3. 配置 AI 工具的 MCP Server。
4. 下载 Skill 到 AI 工具的 Skills 根目录。

## 1. 在 App 里开启 MCP 服务

打开 Flutter Manager：

1. 左侧进入「MCP 服务」
2. 打开「启用 MCP 控制接口」
3. 记下页面里的：
   - 端口，默认 `17891`
   - Token

App 只监听 `127.0.0.1`，不会开放到局域网。

## 2. 开发项目中安装和编译 MCP Server

进入本目录：

```bash
cd <Flutter Manager 项目目录>/mcp_server
npm install
npm run build
```

编译后入口文件是：

```text
<Flutter Manager 项目目录>/mcp_server/dist/index.js
```

打包 Flutter Manager 前需要刷新内置的单文件 MCP Server：

```bash
cd <Flutter Manager 项目目录>/mcp_server
npm install
npm run bundle
```

生成的 `dist/flutter-manager-mcp.mjs` 会作为 Flutter asset 一起进入安装包。

## 3. 配置 AI 软件

在支持 MCP 的 AI 软件里添加一个 MCP Server。

### OpenCode

全局配置文件：

- macOS/Linux：`~/.config/opencode/opencode.json`
- Windows：`%USERPROFILE%\.config\opencode\opencode.json`

将 `mcp.flutter_manager` 合并到已有配置，不要覆盖其他 OpenCode 设置：

```json
{
  "$schema": "https://opencode.ai/config.json",
  "mcp": {
    "flutter_manager": {
      "type": "local",
      "command": [
        "node",
        "<Flutter Manager 项目目录>/mcp_server/dist/index.js"
      ],
      "enabled": true,
      "timeout": 30000,
      "environment": {
        "FLUTTER_MANAGER_PORT": "17891",
        "FLUTTER_MANAGER_TOKEN": "把 App 页面里的 Token 粘贴到这里"
      }
    }
  }
}
```

配置后重启 OpenCode，可执行 `opencode mcp list` 检查连接状态。

### Xiaomi MiMo

配置文件：

- macOS/Linux：`~/.config/mimocode/mimocode.jsonc`
- Windows：`%USERPROFILE%\.config\mimocode\mimocode.jsonc`

将下列条目合并进顶层 `mcp` 段（不要覆盖已有 MCP 服务）：

```jsonc
{
  "mcp": {
    "flutter_manager": {
      "type": "local",
      "command": ["node", "<MCP Server 路径>/flutter-manager-mcp.mjs"],
      "environment": {
        "FLUTTER_MANAGER_PORT": "17891",
        "FLUTTER_MANAGER_TOKEN": "把 App 页面里的 Token 粘贴到这里"
      },
      "enabled": true
    }
  }
}
```

配置后重启 Xiaomi MiMo 或新开会话生效。

### 其他支持 `mcpServers` 的 AI 工具

示例配置：

```json
{
  "mcpServers": {
    "flutter-manager": {
      "command": "node",
      "args": [
        "<Flutter Manager 项目目录>/mcp_server/dist/index.js"
      ],
      "env": {
        "FLUTTER_MANAGER_PORT": "17891",
        "FLUTTER_MANAGER_TOKEN": "把 App 页面里的 Token 粘贴到这里"
      }
    }
  }
}
```

如果你修改了 App 里的端口，也要同步修改 `FLUTTER_MANAGER_PORT`。

## 4. 第一版支持的工具

当前开放第一版工具：

- `flutter_manager_list_projects`
- `flutter_manager_get_current_project`
- `flutter_manager_select_project`
- `flutter_manager_list_devices`
- `flutter_manager_run`
- `flutter_manager_rerun`
- `flutter_manager_hot_reload`
- `flutter_manager_hot_restart`
- `flutter_manager_stop`
- `flutter_manager_read_console`
- `flutter_manager_list_running_projects`
- `flutter_manager_get_runtime_status`
- `flutter_manager_wait_for_runtime_change`
- `flutter_manager_pub_get`
- `flutter_manager_clean`
- `flutter_manager_build`
- `flutter_manager_devtools`

大多数工具都可以传：

```json
{
  "projectPath": "/你的/Flutter/项目路径"
}
```

如果不传 `projectPath`，App 会使用当前选中的项目。

选择项目：

```json
{
  "projectPath": "/你的/Flutter/项目路径"
}
```

停止命令可以传：

```json
{
  "projectPath": "/你的/Flutter/项目路径"
}
```

或者传指定任务：

```json
{
  "taskId": "run::/你的/Flutter/项目路径"
}
```

`taskId` 可以通过 `flutter_manager_read_console` 返回的 `tasks` 获取。

## 5. 常见问题

### AI 软件提示连接失败

确认：

1. Flutter Manager App 已打开
2. 「MCP 服务」页面已启用控制接口
3. MCP 配置里的端口和 Token 与 App 页面一致
4. 已执行 `npm run build`

### Token 错误

在 App 的「MCP 服务」页面复制最新 Token。

如果点了「重置 Token」，AI 软件配置里的 `FLUTTER_MANAGER_TOKEN` 也要一起更新。

### 修改代码后不生效

重新编译：

```bash
npm run build
```

然后重启 AI 软件里的 MCP Server。
