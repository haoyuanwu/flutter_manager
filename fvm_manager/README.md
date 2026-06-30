# Flutter Manager

一个面向 macOS 与 Windows 的 Flutter/FVM 可视化管理工具。

## 当前功能

- 检测并通过 Dart Pub 安装、更新 FVM
- 展示本机已安装的 Flutter SDK
- 从 Flutter 官方 release 清单读取 Stable、Beta、Dev 版本
- 使用 Dio 下载 Flutter SDK，显示进度并支持取消
- 将 SDK 解压到 FVM cache，并通过 FVM 设置全局 Flutter 版本
- 选择本地 Flutter 项目并设置项目独立的 FVM 版本
- 持久化管理本地 Flutter 项目，识别平台与 Android flavors
- 提供 run、clean、pub get 及 Android/iOS/macOS/Windows 构建命令和实时日志
- Flutter Run 期间支持页面热重载与项目热重启
- Android APK Release 构建后可按渠道自动上传 Bugly 符号表
- 支持持久化 runCommand 自定义工作流和构建选项
- 项目目录丢失时支持重新定位或删除记录
- 启动时检查 Flutter Stable 与 FVM 更新，并显示红点和 Toast 提示
- 一键设置国内 Pub/Flutter Storage 镜像或恢复官方默认环境
- 提供 macOS 与 Windows 手动 PATH 配置说明

## 技术栈

- Flutter desktop
- `flutter_riverpod` 状态管理与依赖注入
- `freezed_annotation` / `freezed` 不可变模型
- Dio 下载

## 开发

```bash
flutter pub get
dart run build_runner build
flutter run -d macos # 或 windows
```

若所在网络无法直连 pub.dev，可临时使用可用的 Dart Pub 镜像后再执行依赖解析。

> 本工具需要执行 FVM/Dart 子进程并读写 FVM 缓存，因此 macOS 构建未启用 App Sandbox。
