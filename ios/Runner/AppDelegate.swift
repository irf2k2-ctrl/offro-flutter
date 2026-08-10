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
    // Calling FirebaseApp.configure() natively reads GoogleService-Info.plist
    // and crashes if the BUNDLE_ID in the plist doesn't match the app's bundle ID.
    
    // Register for remote notifications — required for iOS push notifications.
    // FirebaseAppDelegateProxyEnabled = true in Info.plist lets FCM auto-swizzle
    // the APNs delegate methods, but we still need to request registration.
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self as? UNUserNotificationCenterDelegate
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
}
