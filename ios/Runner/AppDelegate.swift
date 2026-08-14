import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // NOTE: Do NOT call FirebaseApp.configure() here.
    // Firebase is initialized from Dart side using explicit options
    // (DefaultFirebaseOptions.currentPlatform) with full error handling.
    // Calling FirebaseApp.configure() natively reads GoogleService-Info.plist
    // and crashes if the BUNDLE_ID in the plist doesn't match the app's bundle ID.

    // Register for remote notifications — required for iOS push notifications.
    // FirebaseAppDelegateProxyEnabled = false in Info.plist means FCM does NOT
    // auto-swizzle the APNs delegate methods. We must set the delegate and
    // register manually.
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self
    }
    NSLog("[IOS-NOTIF] APNS REGISTRATION: calling registerForRemoteNotifications()")
    application.registerForRemoteNotifications()

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }

  // ── APNs token received — pass to FCM ──
  override func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    let tokenParts = deviceToken.map { data in String(format: "%02.2hhx", data) }
    let tokenString = tokenParts.joined()
    NSLog("[IOS-NOTIF] APNS TOKEN: registration SUCCESS — token=%@", tokenString)
    super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
  }

  // ── APNs registration FAILED ──
  override func application(
    _ application: UIApplication,
    didFailToRegisterForRemoteNotificationsWithError error: Error
  ) {
    NSLog("[IOS-NOTIF] ERROR: APNs registration FAILED: %@", error.localizedDescription)
    super.application(application, didFailToRegisterForRemoteNotificationsWithError: error)
  }

  // ── CRITICAL: Background/foreground notification data delivery ──
  // With FirebaseAppDelegateProxyEnabled = false, the FCM plugin does NOT
  // auto-swizzle. iOS only calls this method when the APNs payload contains
  // "content-available": 1. The backend must include this flag. When called,
  // FlutterAppDelegate forwards to the FCM plugin (FlutterPluginAppLifeCycleDelegate),
  // which fires onMessage (foreground) or onBackgroundMessage (background).
  //
  // Without this override, FlutterAppDelegate still forwards — but adding
  // explicit logging makes the notification lifecycle visible in Console.app
  // and guarantees the super call is never accidentally removed.
  override func application(
    _ application: UIApplication,
    didReceiveRemoteNotification userInfo: [AnyHashable: Any],
    fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
  ) {
    NSLog("[IOS-NOTIF] didReceiveRemoteNotification: userInfo keys=%@", userInfo.keys.map { String(describing: $0) })
    super.application(application, didReceiveRemoteNotification: userInfo, fetchCompletionHandler: completionHandler)
    NSLog("[IOS-NOTIF] didReceiveRemoteNotification: forwarded to FCM plugin")
  }

  // ── FOREGROUND NOTIFICATION PRESENTATION ──
  // iOS does NOT show a banner when a push arrives while the app is in the
  // foreground by default. The system calls this delegate method and waits
  // for us to tell it what to display.
  // We return [.banner, .sound, .badge] so the user sees the notification
  // just like they would if the app were backgrounded.
  //
  // NOTE: We do NOT call super here because the FCM plugin's onMessage is
  // fired separately via didReceiveRemoteNotification (which iOS calls when
  // content-available:1 is set in the aps payload). willPresent is purely
  // for display — the data delivery path is didReceiveRemoteNotification.
  @available(iOS 10.0, *)
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    NSLog("[IOS-NOTIF] willPresent: title=%@", notification.request.content.title ?? "(none)")
    completionHandler([.banner, .sound, .badge])
  }
}
