# Flutter 修改后的命令选择

本指南用于通过 Flutter Manager 验证用户已要求的代码修改。接入配置阶段只学习规则、验证连接，不主动启动项目。执行前结合实际改动与运行状态判断，不把扩展名作为唯一依据。

## 先区分三种刷新

Flutter 官方区分：热重载保留 Dart 状态，不重跑 `main()` / `initState()`；热重启重新启动 Dart 应用，丢失其内存状态；原生代码变化需要停止并重新启动应用。热重载与热重启适用于 debug 会话。

依据：[Flutter Hot reload 文档](https://docs.flutter.dev/tools/hot-reload)。以下表格将这些区别映射到本项目提供的命令。

| 修改或场景 | 优先调用 | 判断依据 |
| --- | --- | --- |
| Flutter 页面布局、文案、颜色、Widget 的 `build()` 内容 | `flutter_manager_hot_reload` | 通常可保留当前页面与状态，快速看到修改 |
| 普通 Dart 方法、事件回调中的逻辑 | `flutter_manager_hot_reload` | 修改后的代码需要再次被执行，例如重新点击按钮 |
| `main()`、启动初始化、现有对象的 `initState()`、全局或 static 初始化值 | `flutter_manager_hot_restart` | 需要重新执行 Dart 初始化；先说明会重置运行时状态 |
| Dart 类型变化导致热重载明确被拒绝，或修改必须清空旧内存状态才能验证 | `flutter_manager_hot_restart` | 以实际拒绝信息或状态依赖为依据，不反复盲发热重载 |
| Kotlin、Java、Swift、Objective-C、C/C++ 原生实现，平台插件注册或桥接实现 | `flutter_manager_rerun` | 停止后重编译并运行；热重启不会重新编译原生部分 |
| AndroidManifest、Info.plist、Entitlements、Gradle、Podfile、CMake、原生图标等宿主配置 | `flutter_manager_rerun` | 宿主构建或打包配置需要重新应用；如报错，再处理对应工具链 |
| 新增、删除依赖或升级版本 | `flutter_manager_pub_get`，成功后 `flutter_manager_rerun` | 先更新依赖；包含原生插件时必须重编译宿主 |
| 新增、删除或调整 `pubspec.yaml` 的 assets / fonts 声明 | `flutter_manager_pub_get`，成功后 `flutter_manager_rerun` | 重建资源声明，不能承诺热重载就更新资源包 |
| 仅替换已有图片或字体内容 | 先检查资源缓存；必要时 `flutter_manager_rerun` | 资源缓存可能保留旧内容，不能只凭“重载成功”判断图片已更新 |
| 修改 flavor、入口文件、设备、运行参数或 `--dart-define` | `flutter_manager_rerun` | 新参数需应用于新的启动过程；先确认目标与配置 |
| 没有运行会话、进程已退出 | `flutter_manager_run` | 没有可接收热重载或热重启的进程 |
| 需要正式安装包、Release/Profile 验证 | `flutter_manager_build` 或按用户要求启动对应模式 | debug 刷新不能代替产物构建或其他模式验证 |
| 纯文档、测试文件、未用于当前应用的脚本修改 | 通常无需刷新应用 | 只做任务所需的文档或测试验证 |

## 各命令怎么用

- `flutter_manager_list_projects`：获取真实项目路径，优先按用户的项目别名选择，避免猜测路径。
- `flutter_manager_list_devices`：查找设备 ID；有多个设备时，保持原任务设备，或使用用户明确指定的设备。
- `flutter_manager_get_runtime_status`：先确认目标项目是否有 Flutter run 会话、运行任务和 VM Service。正在构建不等于有可热重载的运行会话。
- `flutter_manager_run`：没有 Flutter run 时启动。传入已确认的 `projectPath`、`deviceId`，需要渠道时传 `flavor`。
- `flutter_manager_hot_reload`：普通 Dart / UI 修改的默认选择，对应 Flutter 控制台的小写 `r`。
- `flutter_manager_hot_restart`：重建 Dart 运行状态，对应大写 `R`；不会重新编译原生代码。
- `flutter_manager_rerun`：停止目标项目当前运行并重新启动，用于原生改动、启动参数变化及需要完整运行的场景。注意保留设备和 flavor；不因一个项目修改而停止其他项目。
- `flutter_manager_stop`：用户要求停止时，或需要更换运行目标时，指定准确的 taskId / projectPath，不停止所有任务。
- `flutter_manager_pub_get`：依赖、资源声明变化后执行；等待完成再运行后续命令。
- `flutter_manager_clean`：仅在构建输出或缓存异常且有证据时使用。普通 UI 修改、语法错误和一次热重载失败不需要 clean。clean 会移除构建输出，执行前考虑现有任务。
- `flutter_manager_build`：用户要求构建时执行，使用 App 中已确认的构建平台、模式与渠道。该工具不是任意 shell 命令入口；若需修改未暴露的参数，明确说明限制。
- `flutter_manager_devtools`：确认有活动 Flutter run 和 VM Service 后再打开。

## 执行后怎么判断生效

1. 保存修改，确认必要的依赖更新、代码生成或平台配置已经完成。项目要求代码生成时使用它已有的流程，不把所有项目都套到某个固定脚本上。
2. 多种改动混合时，选择能够覆盖它们的一次操作，例如 UI + 原生改动直接 rerun，不再先发一次热重载和一次热重启。
3. 读取目标任务的增量控制台与状态。工具返回“已触发”只说明命令已发送，不等于刷新或构建成功。
4. 对长任务使用 `flutter_manager_wait_for_runtime_change` 和上次的 cursor / logLength，避免循环获取整份日志。确认 reload / restart 结果、运行状态或具体错误。
5. 热重载遇到编译错误时，先修复错误再重试；不要用 clean 或重启掩盖语法问题。原生编译失败则读取对应构建错误，不继续发送热重载。
6. 报告项目、设备、选择的命令及实际结果。无法观察屏幕时，只报告日志可确认的结果，不把“热重载成功”描述成界面已目视验证。

## 例子

- “调整登录按钮颜色”：运行状态正常 → hot_reload → 阅读结果；保留当前页面。
- “修改应用启动时加载的配置”：hot_restart → 等待重新初始化；提醒内存状态会重置。
- “修改 Android 原生方法供 MethodChannel 调用”：rerun → 等待原生编译和应用重新启动。
- “新增一个带原生实现的插件”：pub_get 完成 → rerun → 检查插件注册与运行结果。
- “修了页面，但项目还没运行”：确认设备后 run，不先发 hot_reload。
