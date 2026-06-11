import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
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
    // `opal/live_activity`, `opal/intents` and `opal/widget_sync` MethodChannels
    // resolve. We borrow a registrar purely for its binaryMessenger (the bridges
    // aren't plugins).
    if let registrar = pluginRegistry.registrar(forPlugin: "OpalNativeBridges") {
      let messenger = registrar.messenger()
      OpalLiveActivityBridge.register(with: messenger)
      OpalIntentsBridge.shared.register(with: messenger)
      OpalWidgetSyncBridge.register(with: messenger)
    }
  }
}
