import Flutter
import UIKit
import UserNotifications

private final class EtaNotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
  func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    if #available(iOS 14.0, *) {
      completionHandler([.banner, .list, .sound])
    } else {
      completionHandler([.alert, .sound])
    }
  }
}

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private let etaNotificationDelegate = EtaNotificationDelegate()

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    UNUserNotificationCenter.current().delegate = etaNotificationDelegate

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    let channel = FlutterMethodChannel(
      name: "eta/system_notifications",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )

    channel.setMethodCallHandler { call, result in
      let center = UNUserNotificationCenter.current()

      switch call.method {
      case "requestPermission":
        center.requestAuthorization(options: [.alert, .sound]) { granted, error in
          DispatchQueue.main.async {
            if let error = error {
              result(FlutterError(
                code: "NOTIFICATION_PERMISSION_ERROR",
                message: error.localizedDescription,
                details: nil
              ))
            } else {
              result(granted)
            }
          }
        }

      case "showSharingStarted":
        guard let args = call.arguments as? [String: Any],
              let appointmentId = args["appointmentId"] as? Int else {
          result(FlutterError(
            code: "INVALID_ARGUMENTS",
            message: "약속 ID가 필요합니다.",
            details: nil
          ))
          return
        }

        let content = UNMutableNotificationContent()
        content.title = "이따 위치 공유 시작"
        content.body = "약속 도착 확인을 위해 위치 공유를 시작했어요."
        content.sound = .default

        let request = UNNotificationRequest(
          identifier: "eta-location-sharing-\(appointmentId)",
          content: content,
          trigger: nil
        )

        center.add(request) { error in
          DispatchQueue.main.async {
            if let error = error {
              result(FlutterError(
                code: "NOTIFICATION_ERROR",
                message: error.localizedDescription,
                details: nil
              ))
            } else {
              result(true)
            }
          }
        }

      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
}
