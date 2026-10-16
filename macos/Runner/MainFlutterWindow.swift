import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  private var platformChannel: FlutterMethodChannel?
  private var displayActivity: NSObjectProtocol?

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    contentViewController = flutterViewController
    // Keep the initial 16:9 content inside the selected display's visible area.
    // macOS can otherwise relocate an oversized window to another display.
    let visibleFrame = (screen ?? NSScreen.main)?.visibleFrame ?? frame
    let available = contentRect(forFrameRect: visibleFrame).size
    let width = min(1280, min(available.width, available.height * 16 / 9))
    setContentSize(NSSize(width: width, height: width * 9 / 16))
    minSize = NSSize(width: 640, height: 360)
    center()
    collectionBehavior.insert(.fullScreenPrimary)
    RegisterGeneratedPlugins(registry: flutterViewController)

    let channel = FlutterMethodChannel(
      name: "dchs_video_mapping/platform",
      binaryMessenger: flutterViewController.engine.binaryMessenger
    )
    platformChannel = channel
    channel.setMethodCallHandler { [weak self] call, result in
      switch call.method {
      case "output":
        guard let screen = self?.screen,
          let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber
        else {
          result(FlutterError(code: "no_display", message: "No display for the player window.", details: nil))
          return
        }
        let displayID = CGDirectDisplayID(number.uint32Value)
        let uuid = CGDisplayCreateUUIDFromDisplayID(displayID).takeRetainedValue()
        let identity = CFUUIDCreateString(nil, uuid) as String
        let mode = CGDisplayCopyDisplayMode(displayID)
        let pixelWidth = mode?.pixelWidth ?? CGDisplayPixelsWide(displayID)
        let pixelHeight = mode?.pixelHeight ?? CGDisplayPixelsHigh(displayID)
        let refresh = mode?.refreshRate ?? 0
        let key = "macos:\(identity):\(pixelWidth)x\(pixelHeight)@\(refresh):\(screen.backingScaleFactor)"
        result(["key": key])
      case "status", "start", "stop":
        // Full screen is presentation, not a managed kiosk lock.
        result(false)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    displayActivity = ProcessInfo.processInfo.beginActivity(
      options: [.idleDisplaySleepDisabled, .userInitiated],
      reason: "Video mapping playback"
    )
    super.awakeFromNib()
  }

  deinit {
    if let activity = displayActivity {
      ProcessInfo.processInfo.endActivity(activity)
    }
  }
}
