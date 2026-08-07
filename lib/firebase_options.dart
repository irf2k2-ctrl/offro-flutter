// firebase_options.dart
// Platform-specific Firebase configuration for OffrO.
//
// ⚠️ UPDATED: Bundle ID changed from com.offro.app to com.mibtech.offro
//
// Values verified against:
//   - android/app/google-services.json    (Android — source of truth)
//   - ios/Runner/GoogleService-Info.plist  (iOS — source of truth)
//
// Both platforms point to the same Firebase project: offro-e1d3c
//
// NOTE: You MUST register com.mibtech.offro as a new app in Firebase Console
// and download new google-services.json + GoogleService-Info.plist.
// The API key, app IDs, and other credentials will change.

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
  // ⚠️ After registering com.mibtech.offro in Firebase Console, update the
  //    apiKey, appId with the NEW values from the regenerated google-services.json
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAFgW6Li-cLr-LiOuFGuR7aBfQtKzHXPZc',
    appId: '1:1013219872602:android:9125c77175778523bb6d63',
    messagingSenderId: '1013219872602',
    projectId: 'offro-e1d3c',
    storageBucket: 'offro-e1d3c.firebasestorage.app',
  );

  // ── iOS ──
  // Sourced from: ios/Runner/GoogleService-Info.plist
  // ⚠️ After registering com.mibtech.offro in Firebase Console, update the
  //    apiKey, appId with the NEW values from the regenerated GoogleService-Info.plist
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCluwPxR4wAU_XyIwhAnE0d0SmnXlImooQ',
    appId: '1:1013219872602:ios:e20e14a7fbebba7bbb6d63',
    messagingSenderId: '1013219872602',
    projectId: 'offro-e1d3c',
    storageBucket: 'offro-e1d3c.firebasestorage.app',
    iosBundleId: 'com.mibtech.offro',
  );

  // ── macOS ── (uses same iOS config)
  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyCluwPxR4wAU_XyIwhAnE0d0SmnXlImooQ',
    appId: '1:1013219872602:ios:e20e14a7fbebba7bbb6d63',
    messagingSenderId: '1013219872602',
    projectId: 'offro-e1d3c',
    storageBucket: 'offro-e1d3c.firebasestorage.app',
    iosBundleId: 'com.mibtech.offro',
  );

  // ── Web ── (from firebase.json — not currently used)
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCluwPxR4wAU_XyIwhAnE0d0SmnXlImooQ',
    appId: '1:1013219872602:web:5a023a6b18799b12bb6d63',
    messagingSenderId: '1013219872602',
    projectId: 'offro-e1d3c',
    storageBucket: 'offro-e1d3c.firebasestorage.app',
  );
}
