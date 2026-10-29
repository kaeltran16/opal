import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var reduceTransparencyObserver: NSObjectProtocol?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    let pluginRegistry = engineBridge.pluginRegistry
    GeneratedPluginRegistrant.register(with: pluginRegistry)

    // U25/U26 — register the native bridges on the engine's messenger so the
    // `opal/live_activity`, `opal/intents`, `opal/widget_sync` and `opal/health`
    // MethodChannels resolve. We borrow a registrar purely for its binaryMessenger
    // (the bridges aren't plugins).
    if let registrar = pluginRegistry.registrar(forPlugin: "OpalNativeBridges") {
      let messenger = registrar.messenger()
      OpalLiveActivityBridge.register(with: messenger)
      OpalIntentsBridge.shared.register(with: messenger)
      OpalWidgetSyncBridge.register(with: messenger)
      OpalHealthBridge.register(with: messenger)

      // flutter's MediaQuery has no Reduce Transparency flag, so GlassSurface
      // reads it here and hears about changes without an app restart.
      let accessibility = FlutterMethodChannel(
        name: "opal/accessibility", binaryMessenger: messenger)
      accessibility.setMethodCallHandler { call, result in
        if call.method == "isReduceTransparencyEnabled" {
          result(UIAccessibility.isReduceTransparencyEnabled)
        } else {
          result(FlutterMethodNotImplemented)
        }
      }
      reduceTransparencyObserver = NotificationCenter.default.addObserver(
        forName: UIAccessibility.reduceTransparencyStatusDidChangeNotification,
        object: nil,
        queue: .main
      ) { _ in
        accessibility.invokeMethod(
          "reduceTransparencyChanged",
          arguments: UIAccessibility.isReduceTransparencyEnabled)
      }
    }
  }
}
