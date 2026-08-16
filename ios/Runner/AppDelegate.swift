import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // ── UIScene + firebase_messaging 16.x FIX ──
    // With the UIScene lifecycle, Flutter plugins are registered AFTER
    // didFinishLaunchingWithOptions returns (via didInitializeImplicitFlutterEngine).
    // But Apple requires UNUserNotificationCenter.delegate to be set BEFORE
    // this method returns. If no delegate is set, iOS will NOT call willPresent
    // for foreground notifications → FirebaseMessaging.onMessage never fires.
    //
    // firebase_messaging 16.5.0 added configureNotificationCenterDelegate() to
    // solve this: it sets up the FCM plugin's notification delegate early,
    // before the method returns, so iOS can deliver foreground notifications.
    //
    // We use the dynamic NSClassFromString approach to avoid bridging header
    // or non-modular header import issues.
    if let pluginClass = NSClassFromString("FLTFirebaseMessagingPlugin") as? NSObject.Type {
      pluginClass.perform(NSSelectorFromString("configureNotificationCenterDelegate"))
      NSLog("[IOS-NOTIF] FLTFirebaseMessagingPlugin.configureNotificationCenterDelegate() called OK")
    } else {
      NSLog("[IOS-NOTIF] WARNING: FLTFirebaseMessagingPlugin class not found — onMessage will NOT fire in foreground")
    }

    // NOTE: Do NOT call FirebaseApp.configure() here.
    // Firebase is initialized from Dart side using explicit options
    // (DefaultFirebaseOptions.currentPlatform) with full error handling.

    // FirebaseAppDelegateProxyEnabled = true in Info.plist.
    // The FCM plugin auto-swizzles ALL APNs delegate methods.
    // The configureNotificationCenterDelegate() call above ensures the
    // UNUserNotificationCenter.delegate is set before this method returns
    // (Apple's requirement for UIScene apps).

    // ── FIX 1: Disable native foreground presentation ──
    // setForegroundNotificationPresentationOptions is set to (alert: false,
    // badge: false, sound: false) from Dart side. This prevents iOS from
    // showing a native banner in the foreground (which would duplicate the
    // showLocalNotification() call in the onMessage handler). The Dart-side
    // flutter_local_notifications handles foreground banner display.

    // Register for remote notifications - required for iOS push.
    NSLog("[IOS-NOTIF] APNS REGISTRATION: calling registerForRemoteNotifications()")
    application.registerForRemoteNotifications()

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    // ── FIX 2: Badge clearing method channel ──
    // When the user reads all notifications or presses "Clear All",
    // Dart side calls this channel to reset the iOS app icon badge to 0.
    // The backend sends badge:1 in the APNs payload, so the badge shows 1
    // when a notification arrives. This channel clears it when appropriate.
    //
    // FlutterImplicitEngineBridge exposes the application-level binary
    // messenger through applicationRegistrar.messenger. It does not expose
    // an "engine" property.
    let messenger = engineBridge.applicationRegistrar.messenger
    let badgeChannel = FlutterMethodChannel(name: "offro/badge", binaryMessenger: messenger)
    badgeChannel.setMethodCallHandler { call, result in
      if call.method == "clearBadge" {
        DispatchQueue.main.async {
          if #available(iOS 16.0, *) {
            UNUserNotificationCenter.current().setBadgeCount(0) { error in
              if let error = error {
                NSLog("[IOS-NOTIF] setBadgeCount(0) error: %@", error.localizedDescription)
                result(false)
              } else {
                NSLog("[IOS-NOTIF] Badge cleared to 0 via UNUserNotificationCenter")
                result(true)
              }
            }
          } else {
            UIApplication.shared.applicationIconBadgeNumber = 0
            NSLog("[IOS-NOTIF] Badge cleared to 0 via applicationIconBadgeNumber")
            result(true)
          }
        }
      } else if call.method == "setBadge" {
        let count = (call.arguments as? Int) ?? 0
        DispatchQueue.main.async {
          if #available(iOS 16.0, *) {
            UNUserNotificationCenter.current().setBadgeCount(count) { _ in
              result(true)
            }
          } else {
            UIApplication.shared.applicationIconBadgeNumber = count
            result(true)
          }
        }
      } else {
        result(FlutterMethodNotImplemented)
      }
    }
    NSLog("[IOS-NOTIF] Badge method channel 'offro/badge' registered")
  }

  // APNs token received - pass to FCM + log
  override func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    let tokenParts = deviceToken.map { data in String(format: "%02.2hhx", data) }
    let tokenString = tokenParts.joined()
    NSLog("[IOS-NOTIF] APNS TOKEN: registration SUCCESS - token=%@", tokenString)
    super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
  }

  // APNs registration FAILED
  override func application(
    _ application: UIApplication,
    didFailToRegisterForRemoteNotificationsWithError error: Error
  ) {
    NSLog("[IOS-NOTIF] ERROR: APNs registration FAILED: %@", error.localizedDescription)
    super.application(application, didFailToRegisterForRemoteNotificationsWithError: error)
  }
}
