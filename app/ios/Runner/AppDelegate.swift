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
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    guard let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "SplitMindDevicePosture") else {
      return
    }
    let channel = FlutterEventChannel(
      name: "app.splitmind/device_posture",
      binaryMessenger: registrar.messenger()
    )
    channel.setStreamHandler(DevicePostureStreamHandler.shared)
  }
}

/// Native half of the Dart `PlatformFoldableDeviceAdapter`.
///
/// Emits `["isFoldable": Bool, "hingeAngle": Double?]` whenever the posture
/// changes. The Dart side turns this into FoldState values, so nothing above
/// this class knows how the angle was obtained.
final class DevicePostureStreamHandler: NSObject, FlutterStreamHandler {
  static let shared = DevicePostureStreamHandler()

  private var eventSink: FlutterEventSink?

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    eventSink = events
    events(currentPosture())
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    eventSink = nil
    return nil
  }

  /// Call from the hinge-sensor callback once one is wired up.
  func postureDidChange() {
    eventSink?(currentPosture())
  }

  private func currentPosture() -> [String: Any] {
    // TODO(iPhone Duo): read the hinge angle here and call postureDidChange()
    // from its change notification. No public iOS hinge-angle API was known
    // when this was written; confirm against Apple's SDK for the device.
    // Until then every device reports as non-foldable, and the app picks its
    // layout from screen width (plus Flutter DisplayFeatures, if exposed).
    return ["isFoldable": false]
  }
}
