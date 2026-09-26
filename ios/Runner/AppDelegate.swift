import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var accessibilityChannel: FlutterMethodChannel?
  private var accessibilityObservers: [NSObjectProtocol] = []

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    for observer in accessibilityObservers {
      NotificationCenter.default.removeObserver(observer)
    }
    accessibilityObservers.removeAll()
    accessibilityChannel?.setMethodCallHandler(nil)
    guard let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "AppleAccessibility") else {
      return
    }
    let channel = FlutterMethodChannel(
      name: "cn.yanyn.community/accessibility",
      binaryMessenger: registrar.messenger())
    accessibilityChannel = channel
    channel.setMethodCallHandler { call, result in
      guard call.method == "getPreferences" else {
        result(FlutterMethodNotImplemented)
        return
      }
      result(AppDelegate.accessibilityPreferences())
    }

    for name in [
      UIAccessibility.reduceMotionStatusDidChangeNotification,
      UIAccessibility.reduceTransparencyStatusDidChangeNotification,
      UIAccessibility.darkerSystemColorsStatusDidChangeNotification,
    ] {
      let observer = NotificationCenter.default.addObserver(
        forName: name, object: nil, queue: .main
      ) { [weak self] _ in
        self?.accessibilityChannel?.invokeMethod(
          "preferencesChanged", arguments: AppDelegate.accessibilityPreferences())
      }
      accessibilityObservers.append(observer)
    }
  }

  private static func accessibilityPreferences() -> [String: Bool] {
    [
      "reduceMotion": UIAccessibility.isReduceMotionEnabled,
      "reduceTransparency": UIAccessibility.isReduceTransparencyEnabled,
      "highContrast": UIAccessibility.isDarkerSystemColorsEnabled,
    ]
  }

  deinit {
    for observer in accessibilityObservers {
      NotificationCenter.default.removeObserver(observer)
    }
    accessibilityChannel?.setMethodCallHandler(nil)
  }
}
