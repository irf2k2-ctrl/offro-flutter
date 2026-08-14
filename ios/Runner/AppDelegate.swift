import Flutter
import UIKit
import Firebase
import FirebaseMessaging

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // FirebaseAppDelegateProxyEnabled = false in Info.plist.
    // The FCM plugin does NOT auto-swizzle. We handle everything manually:
    //   - UNUserNotificationCenter.delegate = self (foreground banners)
    //   - didReceiveRemoteNotification (background delivery + onMessage)
    //   - Explicit completion handler calls (prevents iOS throttling)

    // Configure Firebase on the native side.
    // Safe to call — idempotent. Required for Messaging.shared() when proxy is disabled.
    // The Dart side also calls Firebase.initializeApp() which is fine.
    FirebaseApp.configure()

    // Set ourselves as the UNUserNotificationCenter delegate.
    // With proxy disabled, the FCM plugin won't set this — we must.
    UNUserNotificationCenter.current().delegate = self

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
    // CRITICAL: When proxy is disabled, we must manually set the APNs token
    // on Messaging so FCM can generate an FCM token.
    Messaging.messaging().apnsToken = deviceToken
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

  // ── Background notification handler ──
  // Called by iOS when content-available:1 is present and the app is in
  // background or terminated.
  //
  // CRITICAL: We call completionHandler(.newData) IMMEDIATELY after forwarding
  // to FCM. This prevents iOS from throttling subsequent notifications.
  // The previous proxy-based approach failed because the FCM swizzle wasn't
  // calling the completion handler reliably, causing iOS to throttle.
  override func application(
    _ application: UIApplication,
    didReceiveRemoteNotification userInfo: [AnyHashable : Any],
    fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
  ) {
    NSLog("[IOS-NOTIF] didReceiveRemoteNotification: forwarding to FCM")
    // Forward to FCM so onBackgroundMessage fires on the Dart side
    Messaging.messaging().appDidReceiveMessage(userInfo)
    // Call completion handler IMMEDIATELY — prevents iOS throttling
    completionHandler(.newData)
  }
}

// ── Foreground notification presentation ──
// With FirebaseAppDelegateProxyEnabled = false, we handle willPresent ourselves.
// We forward to FCM so onMessage fires on the Dart side, then show the banner.
extension AppDelegate: UNUserNotificationCenterDelegate {

  func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    NSLog("[IOS-NOTIF] willPresent: foreground notification received")
    // Forward to FCM so onMessage fires on the Dart side
    Messaging.messaging().appDidReceiveMessage(notification.request.content.userInfo)
    // Show banner + sound + badge in foreground
    completionHandler([.banner, .sound, .badge])
  }

  func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    NSLog("[IOS-NOTIF] didReceive: notification tapped")
    // Forward to FCM so onMessageOpenedApp fires on the Dart side
    Messaging.messaging().appDidReceiveMessage(response.notification.request.content.userInfo)
    completionHandler()
  }
}
