import Cocoa
import FlutterMacOS
import desktop_multi_window

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.styleMask.insert(.fullSizeContentView)
    self.titleVisibility = .hidden
    self.titlebarAppearsTransparent = true
    self.isMovableByWindowBackground = true
    self.backgroundColor = NSColor(red: 0.96, green: 0.97, blue: 0.98, alpha: 1.0) // #f5f7fa
    self.setFrame(windowFrame, display: true)

    let minimumContentSize = NSSize(width: 960, height: 640)
    self.contentMinSize = minimumContentSize
    let currentContentSize = self.contentLayoutRect.size
    if currentContentSize.width < minimumContentSize.width ||
        currentContentSize.height < minimumContentSize.height {
      self.setContentSize(
        NSSize(
          width: max(currentContentSize.width, minimumContentSize.width),
          height: max(currentContentSize.height, minimumContentSize.height)
        )
      )
    }

    RegisterGeneratedPlugins(registry: flutterViewController)

    FlutterMultiWindowPlugin.setOnWindowCreatedCallback { [weak self] controller in
      RegisterGeneratedPlugins(registry: controller)
      DispatchQueue.main.async { [weak self] in
        guard let childWindow = controller.view.window else { return }
        let size = NSSize(width: 1200, height: 800)
        // Always center against the original app window. NSApp.keyWindow may
        // still point at a previously opened console window.
        let referenceFrame = self?.frame
          ?? self?.screen?.visibleFrame
          ?? childWindow.screen?.visibleFrame
          ?? NSScreen.main?.visibleFrame
          ?? NSRect(origin: .zero, size: size)
        let origin = NSPoint(
          x: referenceFrame.midX - size.width / 2,
          y: referenceFrame.midY - size.height / 2
        )
        childWindow.setFrame(NSRect(origin: origin, size: size), display: true)
        childWindow.title = "控制台"
      }
    }

    super.awakeFromNib()

    // The XIB may finish creating the window before the application delegate's
    // launch callback. Attach on the next main-loop turn so the status item does
    // not depend on that lifecycle ordering.
    DispatchQueue.main.async { [weak self] in
      guard let self else { return }
      (NSApp.delegate as? AppDelegate)?.attachMainWindow(self)
    }
  }
}
