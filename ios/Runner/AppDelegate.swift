import Flutter
import UIKit

@objc(MainViewController)
class MainViewController: FlutterViewController {
  override var preferredScreenEdgesDeferringSystemGestures: UIRectEdge {
    return .all
  }

  override var prefersHomeIndicatorAutoHidden: Bool {
    return true
  }

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    setNeedsUpdateOfScreenEdgesDeferringSystemGestures()
    setNeedsUpdateOfHomeIndicatorAutoHidden()
  }
}

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let result = super.application(application, didFinishLaunchingWithOptions: launchOptions)
    window?.rootViewController?.setNeedsUpdateOfScreenEdgesDeferringSystemGestures()
    window?.rootViewController?.setNeedsUpdateOfHomeIndicatorAutoHidden()
    return result
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
