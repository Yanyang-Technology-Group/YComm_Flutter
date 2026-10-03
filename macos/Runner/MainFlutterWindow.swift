import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  private var accessibilityChannel: FlutterMethodChannel?
  private var accessibilityObserver: NSObjectProtocol?
  private var iconChannel: FlutterMethodChannel?

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    let icons = FlutterMethodChannel(name: "cn.yanyn.community/app_icon", binaryMessenger: flutterViewController.engine.binaryMessenger)
    iconChannel = icons
    icons.setMethodCallHandler { call, result in
      guard call.method == "setIcon", let args = call.arguments as? [String: Any] else {
        result(FlutterMethodNotImplemented)
        return
      }
      let file = (args["style"] as? String) == "classic" ? "app_icon_classic.png" : "app_icon.png"
      let key = FlutterDartProject.lookupKey(forAsset: "assets/\(file)")
      let path = Bundle.main.bundlePath + "/Contents/Frameworks/App.framework/Resources/\(key)"
      guard let image = NSImage(contentsOfFile: path) else {
        result(FlutterError(code: "ICON_NOT_FOUND", message: path, details: nil))
        return
      }
      NSApp.applicationIconImage = image
      result(nil)
    }

    if let observer = accessibilityObserver {
      NSWorkspace.shared.notificationCenter.removeObserver(observer)
    }
    accessibilityChannel?.setMethodCallHandler(nil)
    let registrar = flutterViewController.registrar(forPlugin: "AppleAccessibility")
    let channel = FlutterMethodChannel(
      name: "cn.yanyn.community/accessibility",
      binaryMessenger: registrar.messenger)
    accessibilityChannel = channel
    channel.setMethodCallHandler { call, result in
      guard call.method == "getPreferences" else {
        result(FlutterMethodNotImplemented)
        return
      }
      result(MainFlutterWindow.accessibilityPreferences())
    }
    accessibilityObserver = NSWorkspace.shared.notificationCenter.addObserver(
      forName: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification,
      object: NSWorkspace.shared,
      queue: .main
    ) { [weak self] _ in
      self?.accessibilityChannel?.invokeMethod(
        "preferencesChanged", arguments: MainFlutterWindow.accessibilityPreferences())
    }

    super.awakeFromNib()
  }

  private static func accessibilityPreferences() -> [String: Bool] {
    let workspace = NSWorkspace.shared
    return [
      "reduceMotion": workspace.accessibilityDisplayShouldReduceMotion,
      "reduceTransparency": workspace.accessibilityDisplayShouldReduceTransparency,
      "highContrast": workspace.accessibilityDisplayShouldIncreaseContrast,
    ]
  }

  deinit {
    if let observer = accessibilityObserver {
      NSWorkspace.shared.notificationCenter.removeObserver(observer)
    }
    accessibilityChannel?.setMethodCallHandler(nil)
  }
}
