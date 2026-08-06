// firebase_options.dart
// Platform-specific Firebase configuration for OffrO.
//
// Values verified against:
//   - android/app/google-services.json    (Android — source of truth)
//   - ios/Runner/GoogleService-Info.plist  (iOS — source of truth)
//
// Both platforms point to the same Firebase project: offro-e1d3c

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      default:
        throw UnsupportedException(
          'DefaultFirebaseOptions are not configured for platform '
          '$defaultTargetPlatform.',
        );
    }
  }

  // ── Android ──
  // Sourced from: android/app/google-services.json
  //   client_info.mobilesdk_app_id → appId
  //   client_info.android_client_info.package_name → (implicit, not in FirebaseOptions)
  //   api_key[0].current_key → apiKey
  //   project_info.project_number → messagingSenderId
  //   project_info.project_id → projectId
  //   project_info.storage_bucket → storageBucket
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAFgW6Li-cLr-LiOuFGuR7aBfQtKzHXPZc',
    appId: '1:1013219872602:android:9125c77175778523bb6d63',
    messagingSenderId: '1013219872602',
    projectId: 'offro-e1d3c',
    storageBucket: 'offro-e1d3c.firebasestorage.app',
  );

  // ── iOS ──
  // Sourced from: ios/Runner/GoogleService-Info.plist
  //   GOOGLE_APP_ID → appId
  //   BUNDLE_ID → iosBundleId
  //   API_KEY → apiKey
  //   GCM_SENDER_ID → messagingSenderId
  //   PROJECT_ID → projectId
  //   STORAGE_BUCKET → storageBucket
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCluwPxR4wAU_XyIwhAnE0d0SmnXlImooQ',
    appId: '1:1013219872602:ios:e20e14a7fbebba7bbb6d63',
    messagingSenderId: '1013219872602',
    projectId: 'offro-e1d3c',
    storageBucket: 'offro-e1d3c.firebasestorage.app',
    iosBundleId: 'com.offro.app',
  );

  // ── macOS ── (uses same iOS config — standard for Flutter Firebase)
  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyCluwPxR4wAU_XyIwhAnE0d0SmnXlImooQ',
    appId: '1:1013219872602:ios:e20e14a7fbebba7bbb6d63',
    messagingSenderId: '1013219872602',
    projectId: 'offro-e1d3c',
    storageBucket: 'offro-e1d3c.firebasestorage.app',
    iosBundleId: 'com.offro.app',
  );

  // ── Web ── (from firebase.json — not currently used but included for completeness)
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCluwPxR4wAU_XyIwhAnE0d0SmnXlImooQ',
    appId: '1:1013219872602:web:5a023a6b18799b12bb6d63',
    messagingSenderId: '1013219872602',
    projectId: 'offro-e1d3c',
    storageBucket: 'offro-e1d3c.firebasestorage.app',
  );
}
