# Flutter Manager v1.2.6

## 新增与优化

1. 项目列表自动读取项目 Logo，收起后可直接点击 Logo 切换项目。
2. MCP 页面精简，新增一键复制 AI 接入说明，自动准备 MCP Server、Skill 和命令指南。
3. AI 命令指南说明何时热重载、热重启或重新运行，以及依赖和资源变化的处理方式。
4. DMG 打包支持选择 Intel 或 Apple Silicon 架构，文件名包含版本号与架构。
5. 刷新项目时同步读取最新版本号和 Build No，修正版本输入框未及时更新的问题。

## macOS 安装包

下载 DMG，打开后将 Flutter Manager 拖入 Applications。

- 应用版本：1.2.6（build 12）。
- 包含 Apple Silicon（arm64）和 Intel（x86_64）架构。
- 支持 macOS 12.0 及更新版本。
- 此包未使用 Developer ID 签名，也未进行 Apple 公证。

本次仅发布 macOS 安装包。Windows 版本需要 Windows 构建环境，未在 macOS 上交叉构建。
