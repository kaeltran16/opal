import Flutter
import UIKit

/// U25/U26 — forwards incoming `opal://` URLs to the native intents bridge so
/// GoRouter can route them. Two sources land here:
///   * Live-Activity / Dynamic-Island taps → `opal://session/<routineId>`
///   * AppIntents that return `OpenURLIntent` → `opal://entry/new`, `opal://move/start`
///
/// `super` is called first so `FlutterSceneDelegate` keeps setting up the
/// FlutterViewController (on connect) and forwarding URLs to any URL-handling
/// plugins; `OpalIntentsBridge.handleDeepLink` ignores non-`opal` schemes.
class SceneDelegate: FlutterSceneDelegate {
  override func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    super.scene(scene, willConnectTo: session, options: connectionOptions)
    // Cold launch from a Live-Activity / intent tap: the URL arrives here.
    // The bridge buffers it until Flutter calls `consumeInitialDeepLink`.
    for context in connectionOptions.urlContexts {
      OpalIntentsBridge.shared.handleDeepLink(context.url)
    }
  }

  override func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
    super.scene(scene, openURLContexts: URLContexts)
    for context in URLContexts {
      OpalIntentsBridge.shared.handleDeepLink(context.url)
    }
  }
}
