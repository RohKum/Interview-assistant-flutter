import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    // Hide the window from screen sharing/recording
    self.sharingType = .none
    
    // Keep window always on top (useful for an interview assistant)
    self.level = .floating

    // Make the window transparent
    self.isOpaque = false
    self.backgroundColor = .clear
    flutterViewController.backgroundColor = .clear
    // Optional: make the title bar blend in nicely
    self.titlebarAppearsTransparent = true
    self.styleMask.insert(.fullSizeContentView)
    self.titleVisibility = .hidden

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}
