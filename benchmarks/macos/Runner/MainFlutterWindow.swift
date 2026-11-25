import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  private var performanceActivity: NSObjectProtocol?

  override func awakeFromNib() {
    if ProcessInfo.processInfo.environment["LEVIT_PERFORMANCE_RUN"] == "1" {
      performanceActivity = ProcessInfo.processInfo.beginActivity(
        options: [.userInitiated, .latencyCritical],
        reason: "Measuring native Levit profile/release performance"
      )
      NSLog("LEVIT_PERFORMANCE_ACTIVITY_ACTIVE")
    }
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
    if performanceActivity != nil {
      isRestorable = false
      if let measurementScreen = NSScreen.screens.max(by: {
        $0.backingScaleFactor < $1.backingScaleFactor
      }) {
        let bounds = measurementScreen.visibleFrame
        setFrameOrigin(NSPoint(x: bounds.minX + 32,
                               y: bounds.maxY - frame.height - 32))
      }
      // Occluded Flutter windows can stop delivering frames even with App Nap
      // disabled. Keep this measurement-only window visible without taking focus.
      level = .floating
      orderFrontRegardless()
    }
  }

  override func close() {
    if let activity = performanceActivity {
      ProcessInfo.processInfo.endActivity(activity)
      performanceActivity = nil
    }
    super.close()
  }
}
