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
    // FirebaseAppDelegateProxyEnabled = true in Info.plist lets FCM auto-swizzle
    // the APNs delegate methods, but we still need to request registration.
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self
    }
    application.registerForRemoteNotifications()
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
  
  // APNs token received — pass to FCM (handled automatically when
  // FirebaseAppDelegateProxyEnabled = true, but included as a safety net)
  override func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    // firebase_messaging plugin auto-handles this when proxy is enabled
    // but calling super ensures the token is forwarded to FCM
    super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
  }
  
  // ── FOREGROUND NOTIFICATION PRESENTATION ──
  // iOS does NOT show a banner when a push arrives while the app is in the
  // foreground by default.  The system calls this delegate method and waits
  // for us to tell it what to display.  Without this, the notification is
  // silently swallowed even though the Dart onMessage listener fires.
  // We return [.banner, .sound, .badge] so the user sees the notification
  // just like they would if the app were backgrounded.
  @available(iOS 10.0, *)
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    completionHandler([.banner, .sound, .badge])
  }
}
