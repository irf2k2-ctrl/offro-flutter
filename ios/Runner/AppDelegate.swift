import Flutter
import UIKit

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
    // This is the official fix from firebase_messaging 16.5.0 README:
    // https://pub.dev/packages/firebase_messaging
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

    // Register for remote notifications - required for iOS push.
    NSLog("[IOS-NOTIF] APNS REGISTRATION: calling registerForRemoteNotifications()")
    application.registerForRemoteNotifications()

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
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
