import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    // Mantiene una superficie mínima utilizable en escritorio y evita que las
    // vistas se compriman hasta superponerse o cortar la navegación.
    self.contentMinSize = NSSize(width: 1024, height: 720)

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}
