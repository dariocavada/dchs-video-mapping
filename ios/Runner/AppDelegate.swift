import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var platformChannel: FlutterMethodChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    application.isIdleTimerDisabled = true
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let channel = FlutterMethodChannel(
      name: "dchs_video_mapping/platform",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    platformChannel = channel
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "output":
        // Use the scene that owns this app, rather than an unrelated external scene.
        guard let scene = UIApplication.shared.connectedScenes
          .compactMap({ $0 as? UIWindowScene })
          .first(where: { $0.activationState == .foregroundActive })
        else {
          result(FlutterError(code: "no_display", message: "No active display scene.", details: nil))
          return
        }
        let screen = scene.screen
        let bounds = screen.nativeBounds
        let key = "ios:\(UIDevice.current.model):\(Int(bounds.width))x\(Int(bounds.height))@\(screen.maximumFramesPerSecond):\(screen.nativeScale)"
        result(["key": key])
      case "status", "start", "stop":
        // Guided Access / supervised Single App Mode is configured outside the app.
        result(false)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
}
