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

## 1. 在 App 里开启 MCP 服务

打开 Flutter Manager：

1. 左侧进入「MCP 服务」
2. 打开「启用 MCP 控制接口」
3. 记下页面里的：
   - 端口，默认 `17891`
   - Token

App 只监听 `127.0.0.1`，不会开放到局域网。

## 2. 安装和编译 MCP Server

进入本目录：

```bash
cd /Users/why/Documents/flutter_manager/fvm_manager/mcp_server
npm install
npm run build
```

编译后入口文件是：

```text
/Users/why/Documents/flutter_manager/fvm_manager/mcp_server/dist/index.js
```

## 3. 配置 AI 软件

在支持 MCP 的 AI 软件里添加一个 MCP Server。

示例配置：

```json
{
  "mcpServers": {
    "flutter-manager": {
      "command": "node",
      "args": [
        "/Users/why/Documents/flutter_manager/fvm_manager/mcp_server/dist/index.js"
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
- `flutter_manager_stop`
- `flutter_manager_read_console`
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
