import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  private var statusItem: NSStatusItem?
  private var statusMenuChannel: FlutterMethodChannel?
  private var mainWindow: MainFlutterWindow?
  private var fvmVersion = "检测中…"
  private var flutterVersion = "检测中…"
  private var managedProjects: [[String: String]] = []
  private var runningProcesses: [[String: String]] = []

  override func applicationDidFinishLaunching(_ notification: Notification) {
    super.applicationDidFinishLaunching(notification)
    if let window = NSApp.windows.first(where: { $0 is MainFlutterWindow }) as? MainFlutterWindow {
      attachMainWindow(window)
    } else {
      configureStatusItem()
    }
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
      button.imagePosition = .imageLeading
      button.imageScaling = .scaleProportionallyDown
      button.title = " FVM"
      button.font = .systemFont(ofSize: 12, weight: .medium)
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

  func attachMainWindow(_ window: MainFlutterWindow) {
    mainWindow = window
    configureStatusItem()
    configureStatusMenuChannel()
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
    window.makeKeyAndOrderFront(nil)
    NSApp.activate(ignoringOtherApps: true)
  }

  @objc private func quitApplication(_ sender: Any?) {
    NSApp.terminate(sender)
  }
}
