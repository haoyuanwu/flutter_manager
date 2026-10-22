import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  private var statusItem: NSStatusItem?
  private var statusMenuChannel: FlutterMethodChannel?
  private var dragDropChannel: FlutterMethodChannel?
  private var appearanceChannel: FlutterMethodChannel?
  private var mainWindow: MainFlutterWindow?
  private var fvmVersion = "检测中…"
  private var flutterVersion = "检测中…"
  private var managedProjects: [[String: String]] = []
  private var runningProcesses: [[String: String]] = []
  private var dockVisibilityUpdateScheduled = false
  private var observingWindowVisibility = false
  private let closingWindows = NSHashTable<NSWindow>.weakObjects()
  private let managedWindows = NSHashTable<NSWindow>.weakObjects()

  override func applicationDidFinishLaunching(_ notification: Notification) {
    super.applicationDidFinishLaunching(notification)
    if let window = NSApp.windows.first(where: { $0 is MainFlutterWindow }) as? MainFlutterWindow {
      attachMainWindow(window)
    } else {
      configureStatusItem()
    }
    observeWindowVisibility()
  }

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return false
  }

  override func applicationShouldHandleReopen(
    _ sender: NSApplication,
    hasVisibleWindows flag: Bool
  ) -> Bool {
    showMainWindow()
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }

  // 支持接收拖放到应用图标上的文件
  override func application(_ sender: NSApplication, openFile filename: String) -> Bool {
    handleDroppedPath(filename)
    return true
  }

  // 支持接收多个文件
  override func application(_ sender: NSApplication, openFiles filenames: [String]) {
    for filename in filenames {
      handleDroppedPath(filename)
    }
  }

  // 处理拖放的路径
  private func handleDroppedPath(_ path: String) {
    // 确保主窗口可见
    showMainWindow()

    // 通过 Flutter Method Channel 发送到 Flutter 端
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
      self?.dragDropChannel?.invokeMethod("onPathDropped", arguments: path)
    }
  }

  private func configureStatusItem() {
    guard statusItem == nil else { return }
    let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    if let button = item.button {
      if let image = NSApp.applicationIconImage.copy() as? NSImage {
        image.isTemplate = false
        image.size = NSSize(width: 18, height: 18)
        button.image = image
      } else if #available(macOS 11.0, *) {
        let fallback = NSImage(
          systemSymbolName: "hammer.fill",
          accessibilityDescription: "Flutter Manager"
        )
        fallback?.isTemplate = true
        fallback?.size = NSSize(width: 17, height: 17)
        button.image = fallback
      }
      button.imagePosition = .imageOnly
      button.imageScaling = .scaleProportionallyDown
      button.title = ""
      button.toolTip = "Flutter Manager"
    }

    statusItem = item
    rebuildStatusMenu()
    NSLog("[Flutter Manager] status item created: %@", item.button == nil ? "no" : "yes")
  }

  private func configureStatusMenuChannel() {
    guard statusMenuChannel == nil else { return }
    guard let controller = mainWindow?.contentViewController as? FlutterViewController else {
      return
    }
    let channel = FlutterMethodChannel(
      name: "fvm_manager/status_menu",
      binaryMessenger: controller.engine.binaryMessenger
    )
    channel.setMethodCallHandler { [weak self] call, result in
      guard call.method == "updateStatus",
            let arguments = call.arguments as? [String: Any] else {
        result(FlutterMethodNotImplemented)
        return
      }
      self?.fvmVersion = arguments["fvmVersion"] as? String ?? "未检测到"
      self?.flutterVersion = arguments["flutterVersion"] as? String ?? "未检测到"
      self?.managedProjects = arguments["projects"] as? [[String: String]] ?? []
      self?.runningProcesses = arguments["processes"] as? [[String: String]] ?? []
      DispatchQueue.main.async {
        self?.rebuildStatusMenu()
      }
      result(nil)
    }
    statusMenuChannel = channel
  }

  private func configureDragDropChannel() {
    guard dragDropChannel == nil else { return }
    guard let controller = mainWindow?.contentViewController as? FlutterViewController else {
      return
    }
    let channel = FlutterMethodChannel(
      name: "fvm_manager/drag_drop",
      binaryMessenger: controller.engine.binaryMessenger
    )
    dragDropChannel = channel
  }

  func attachMainWindow(_ window: MainFlutterWindow) {
    mainWindow = window
    managedWindows.add(window)
    configureStatusItem()
    configureStatusMenuChannel()
    configureDragDropChannel()
    configureAppearanceChannel()

    // 设置窗口支持拖放
    setupWindowDragDrop(window)
  }

  func attachConsoleWindow(_ window: NSWindow) {
    managedWindows.add(window)
    scheduleDockVisibilityUpdate()
  }

  private func configureAppearanceChannel() {
    guard appearanceChannel == nil,
          let controller = mainWindow?.contentViewController as? FlutterViewController else {
      return
    }
    let channel = FlutterMethodChannel(
      name: "fvm_manager/appearance",
      binaryMessenger: controller.engine.binaryMessenger
    )
    channel.setMethodCallHandler { call, result in
      guard call.method == "setTheme",
            let arguments = call.arguments as? [String: Any],
            let mode = arguments["mode"] as? String else {
        result(FlutterMethodNotImplemented)
        return
      }
      switch mode {
      case "light": NSApp.appearance = NSAppearance(named: .aqua)
      case "dark": NSApp.appearance = NSAppearance(named: .darkAqua)
      default: NSApp.appearance = nil
      }
      result(nil)
    }
    appearanceChannel = channel
  }

  func mainWindowWillClose(_ window: NSWindow) {
    managedWindows.add(window)
    closingWindows.add(window)
    scheduleDockVisibilityUpdate()
  }

  func mainWindowVisibilityChanged(_ window: NSWindow) {
    managedWindows.add(window)
    if window.isVisible { closingWindows.remove(window) }
    scheduleDockVisibilityUpdate()
  }

  private func observeWindowVisibility() {
    guard !observingWindowVisibility else { return }
    observingWindowVisibility = true
    let center = NotificationCenter.default
    for name in [
      NSWindow.willCloseNotification,
      NSWindow.didBecomeKeyNotification,
      NSWindow.didMiniaturizeNotification,
      NSWindow.didDeminiaturizeNotification,
      NSWindow.didChangeOcclusionStateNotification,
      NSWindow.didUpdateNotification,
    ] {
      center.addObserver(
        self,
        selector: #selector(applicationWindowVisibilityChanged(_:)),
        name: name,
        object: nil
      )
    }
    scheduleDockVisibilityUpdate()
  }

  @objc private func applicationWindowVisibilityChanged(_ notification: Notification) {
    // Only app windows count. Status-menu windows, tooltips and system panels
    // must not bring the Dock icon back while the app is running in the tray.
    guard let window = notification.object as? NSWindow,
          managedWindows.contains(window) || window is MainFlutterWindow else { return }
    if notification.name == NSWindow.willCloseNotification {
      closingWindows.add(window)
    } else if window.isVisible &&
              (notification.name == NSWindow.didBecomeKeyNotification ||
               notification.name == NSWindow.didDeminiaturizeNotification) {
      closingWindows.remove(window)
    }
    scheduleDockVisibilityUpdate()
  }

  private func scheduleDockVisibilityUpdate() {
    guard !dockVisibilityUpdateScheduled else { return }
    dockVisibilityUpdateScheduled = true
    // willClose is sent before isVisible changes. Coalesce notifications and
    // evaluate after AppKit finishes closing/hiding/ordering the windows.
    DispatchQueue.main.async { [weak self] in
      guard let self else { return }
      self.dockVisibilityUpdateScheduled = false
      // Cmd-H hides an application, not its windows. Keep its existing Dock
      // policy so it can be restored through the normal system shortcuts.
      guard !NSApp.isHidden else { return }
      let hasOpenWindow = self.managedWindows.allObjects.contains { window in
        !self.closingWindows.contains(window) &&
          (window.isVisible || window.isMiniaturized)
      }
      // Minimizing, hiding the app (Cmd-H), or covering a window is not closing
      // it. Keep the Dock entry so those windows can still be restored normally.
      let policy: NSApplication.ActivationPolicy = hasOpenWindow ? .regular : .accessory
      if NSApp.activationPolicy() != policy {
        NSApp.setActivationPolicy(policy)
      }
    }
  }

  // 设置窗口拖放支持
  private func setupWindowDragDrop(_ window: NSWindow) {
    // 注册接收拖放的类型
    window.registerForDraggedTypes([.fileURL])

    // 使用 NSWindow 的拖放代理
    let dragDropView = DragDropView(frame: window.contentView?.bounds ?? .zero)
    dragDropView.onPathDropped = { [weak self] path in
      self?.handleDroppedPath(path)
    }
    dragDropView.autoresizingMask = [.width, .height]
    window.contentView?.addSubview(dragDropView)
  }

  private func rebuildStatusMenu() {
    guard let statusItem else { return }
    let menu = NSMenu()
    let showItem = NSMenuItem(
      title: "打开主界面",
      action: #selector(showMainWindowFromMenu(_:)),
      keyEquivalent: ""
    )
    showItem.target = self
    menu.addItem(showItem)
    menu.addItem(.separator())

    menu.addItem(infoItem(title: "当前 FVM 版本：\(fvmVersion)"))
    menu.addItem(infoItem(title: "当前 Flutter 版本：\(flutterVersion)"))
    menu.addItem(.separator())

    let projectsItem = NSMenuItem(title: "项目管理", action: nil, keyEquivalent: "")
    projectsItem.submenu = projectsSubmenu()
    menu.addItem(projectsItem)

    let processesItem = NSMenuItem(title: "正在运行的进程", action: nil, keyEquivalent: "")
    processesItem.submenu = processSubmenu(opensConsole: false)
    menu.addItem(processesItem)

    let consolesItem = NSMenuItem(title: "控制台", action: nil, keyEquivalent: "")
    consolesItem.submenu = processSubmenu(opensConsole: true)
    menu.addItem(consolesItem)

    menu.addItem(.separator())
    let quitItem = NSMenuItem(
      title: "退出 Flutter Manager",
      action: #selector(quitApplication(_:)),
      keyEquivalent: "q"
    )
    quitItem.target = self
    menu.addItem(quitItem)
    statusItem.menu = menu
  }

  private func infoItem(title: String) -> NSMenuItem {
    let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
    item.isEnabled = false
    return item
  }

  private func projectsSubmenu() -> NSMenu {
    let submenu = NSMenu()
    guard !managedProjects.isEmpty else {
      submenu.addItem(infoItem(title: "暂无项目"))
      return submenu
    }
    for project in managedProjects {
      let projectItem = NSMenuItem(
        title: project["projectName"] ?? "未知项目",
        action: nil,
        keyEquivalent: ""
      )
      projectItem.submenu = projectCommandsSubmenu(
        projectPath: project["projectPath"] ?? ""
      )
      submenu.addItem(projectItem)
    }
    return submenu
  }

  private func projectCommandsSubmenu(projectPath: String) -> NSMenu {
    let submenu = NSMenu()
    let commands = [
      (title: "运行", action: "run"),
      (title: "热更新", action: "hotReload"),
      (title: "热重载", action: "hotRestart"),
      (title: "DevTools", action: "devtools"),
    ]
    for command in commands {
      let item = NSMenuItem(
        title: command.title,
        action: #selector(runProjectActionFromMenu(_:)),
        keyEquivalent: ""
      )
      item.target = self
      item.representedObject = [
        "projectPath": projectPath,
        "action": command.action,
      ]
      submenu.addItem(item)
    }
    return submenu
  }

  private func processSubmenu(opensConsole: Bool) -> NSMenu {
    let submenu = NSMenu()
    guard !runningProcesses.isEmpty else {
      submenu.addItem(infoItem(title: opensConsole ? "暂无可用控制台" : "暂无运行中的进程"))
      return submenu
    }
    for process in runningProcesses {
      let projectName = process["projectName"] ?? "未知项目"
      let processName = process["processName"] ?? "Command"
      let item = NSMenuItem(
        title: "\(projectName) - \(processName)",
        action: opensConsole ? #selector(openConsoleFromMenu(_:)) : nil,
        keyEquivalent: ""
      )
      if opensConsole {
        item.target = self
        item.representedObject = process["projectPath"]
      } else {
        item.isEnabled = false
      }
      submenu.addItem(item)
    }
    return submenu
  }

  @objc private func showMainWindowFromMenu(_ sender: Any?) {
    showMainWindow()
  }

  @objc private func openConsoleFromMenu(_ sender: NSMenuItem) {
    guard let projectPath = sender.representedObject as? String else { return }
    statusMenuChannel?.invokeMethod(
      "openConsole",
      arguments: ["projectPath": projectPath]
    )
  }

  @objc private func runProjectActionFromMenu(_ sender: NSMenuItem) {
    guard let arguments = sender.representedObject as? [String: String] else { return }
    statusMenuChannel?.invokeMethod("runProjectAction", arguments: arguments)
  }

  private func showMainWindow() {
    let window = mainWindow
      ?? NSApp.windows.first(where: { $0 is MainFlutterWindow }) as? MainFlutterWindow
    guard let window else {
      return
    }
    mainWindow = window
    closingWindows.remove(window)
    // Restore a regular app before activating it from the tray or Finder.
    if NSApp.activationPolicy() != .regular {
      NSApp.setActivationPolicy(.regular)
    }
    if window.isMiniaturized { window.deminiaturize(nil) }
    window.makeKeyAndOrderFront(nil)
    NSApp.activate(ignoringOtherApps: true)
  }

  @objc private func quitApplication(_ sender: Any?) {
    NSApp.terminate(sender)
  }
}

// MARK: - 拖放视图
class DragDropView: NSView {
  var onPathDropped: ((String) -> Void)?

  override init(frame: NSRect) {
    super.init(frame: frame)
    setup()
  }

  required init?(coder: NSCoder) {
    super.init(coder: coder)
    setup()
  }

  private func setup() {
    // 注册接收拖放的类型
    registerForDraggedTypes([.fileURL])
  }

  override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
    // 检查是否包含文件夹
    if hasValidDirectory(sender) {
      // 高亮显示
      wantsLayer = true
      layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.1).cgColor
      return .copy
    }
    return []
  }

  override func draggingExited(_ sender: NSDraggingInfo?) {
    // 取消高亮
    wantsLayer = false
    layer?.backgroundColor = nil
  }

  override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool {
    return hasValidDirectory(sender)
  }

  override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
    // 取消高亮
    wantsLayer = false
    layer?.backgroundColor = nil

    // 获取拖放的文件 URL
    let pasteboard = sender.draggingPasteboard
    guard let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: [
      .urlReadingFileURLsOnly: true,
      .urlReadingContentsConformToTypes: ["public.folder"]
    ]) as? [URL] else {
      return false
    }

    // 处理每个拖放的文件夹
    for url in urls {
      if url.hasDirectoryPath {
        onPathDropped?(url.path)
      }
    }

    return true
  }

  // 检查是否包含有效的目录
  private func hasValidDirectory(_ sender: NSDraggingInfo) -> Bool {
    let pasteboard = sender.draggingPasteboard
    guard let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: [
      .urlReadingFileURLsOnly: true
    ]) as? [URL] else {
      return false
    }

    // 检查是否有目录
    return urls.contains { $0.hasDirectoryPath }
  }
}
