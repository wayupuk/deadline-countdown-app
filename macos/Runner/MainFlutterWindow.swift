import Cocoa
import FlutterMacOS
import ServiceManagement

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    // launch_at_startup's macOS channel, answered with SMAppService (no extra Swift package needed).
    FlutterMethodChannel(name: "launch_at_startup", binaryMessenger: flutterViewController.engine.binaryMessenger)
      .setMethodCallHandler { call, result in
        guard #available(macOS 13.0, *) else {
          result(false)
          return
        }
        switch call.method {
        case "launchAtStartupIsEnabled":
          result(SMAppService.mainApp.status == .enabled)
        case "launchAtStartupSetEnabled":
          let enable = (call.arguments as? [String: Any])?["setEnabledValue"] as? Bool ?? false
          do {
            if enable { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            result(nil)
          } catch {
            result(FlutterError(code: "launch_at_login", message: error.localizedDescription, details: nil))
          }
        default:
          result(FlutterMethodNotImplemented)
        }
      }

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}
