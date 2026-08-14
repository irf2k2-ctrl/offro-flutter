import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // NOTE: Do NOT call FirebaseApp.configure() here.
    // Firebase is initialized from Dart side using explicit options
    // (DefaultFirebaseOptions.currentPlatform) with full error handling.

    // FirebaseAppDelegateProxyEnabled = true in Info.plist.
    //
    // The FCM plugin auto-swizzles ALL APNs delegate methods:
    //   - UNUserNotificationCenter.delegate  (for willPresent - foreground banners)
    //   - application:didReceiveRemoteNotification:fetchCompletionHandler:
    //     (for onMessage / onBackgroundMessage)
    //   - Completion handler calls (prevents iOS background-notification throttling)
    //
    // We must NOT manually set the delegate or override didReceiveRemoteNotification.
    // Doing so conflicts with the swizzle and causes handlers to misfire or not fire
    // at all. This was the root cause of iOS notifications not being saved to the
    // in-app Notifications folder.
    //
    // The Dart side controls foreground banner display via:
    //   FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
    //     alert: true, badge: true, sound: true)
    // which tells the swizzled delegate to show banners when the app is open.

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

  // REMOVED: didReceiveRemoteNotification override
  // Previously we overrode this and called super, which forwarded to the FCM plugin.
  // But with FirebaseAppDelegateProxyEnabled = true, the FCM plugin ALREADY swizzles
  // this method. Our override created a conflict:
  //   1. The swizzle wraps our override (or vice versa)
  //   2. The completion handler may be called twice or not at all
  //   3. iOS throttles didReceiveRemoteNotification after a mishandled call
  //   4. onMessage (foreground) and onBackgroundMessage (background) stop firing
  //
  // By NOT overriding, the FCM plugin's swizzle handles everything cleanly:
  //   - Fires onMessage when app is in foreground
  //   - Fires onBackgroundMessage when app is in background/terminated
  //   - Calls the completion handler correctly (no throttling)
  //   - Shows banners via setForegroundNotificationPresentationOptions

  // REMOVED: willPresent override
  // Previously we manually set UNUserNotificationCenter.current().delegate = self
  // and overrode willPresent to show [.banner, .sound, .badge].
  // But with FirebaseAppDelegateProxyEnabled = true, the FCM plugin sets its
  // own delegate via swizzle. Our manual delegate setting competed with the
  // FCM plugin, and our willPresent might never be called or might shadow
  // the FCM plugin's willPresent.
  //
  // The Dart-side setForegroundNotificationPresentationOptions(alert: true,
  // badge: true, sound: true) already tells the FCM plugin's swizzled
  // delegate to show foreground banners. No native override needed.
}
