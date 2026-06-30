import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
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

    super.awakeFromNib()
  }
}
