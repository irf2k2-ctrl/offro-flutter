// firebase_options.dart
// Platform-specific Firebase configuration for OffrO.
//
// iOS bundle ID: com.mibtech.offro
// Android package: com.offro.app (UNCHANGED — Android app stays as-is)
//
// Values verified against:
//   - android/app/google-services.json         (Android — source of truth, UNCHANGED)
//   - ios/Runner/GoogleService-Info.plist (NEW) (iOS — source of truth for com.mibtech.offro)
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
        throw UnsupportedError(
          'DefaultFirebaseOptions are not configured for platform '
          '$defaultTargetPlatform.',
        );
    }
  }

  // ── Android ── UNCHANGED — sourced from android/app/google-services.json
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAFgW6Li-cLr-LiOuFGuR7aBfQtKzHXPZc',
    appId: '1:1013219872602:android:9125c77175778523bb6d63',
    messagingSenderId: '1013219872602',
    projectId: 'offro-e1d3c',
    storageBucket: 'offro-e1d3c.firebasestorage.app',
  );

  // ── iOS ── UPDATED — sourced from the NEW GoogleService-Info.plist
  //   (registered for bundle ID com.mibtech.offro in Firebase Console)
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCluwPxR4wAU_XyIwhAnE0d0SmnXlImooQ',
    appId: '1:1013219872602:ios:ca407cba236d3757bb6d63',
    messagingSenderId: '1013219872602',
    projectId: 'offro-e1d3c',
    storageBucket: 'offro-e1d3c.firebasestorage.app',
    iosBundleId: 'com.mibtech.offro',
  );

  // ── macOS ── same as iOS config (standard for Flutter Firebase)
  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyCluwPxR4wAU_XyIwhAnE0d0SmnXlImooQ',
    appId: '1:1013219872602:ios:ca407cba236d3757bb6d63',
    messagingSenderId: '1013219872602',
    projectId: 'offro-e1d3c',
    storageBucket: 'offro-e1d3c.firebasestorage.app',
    iosBundleId: 'com.mibtech.offro',
  );

  // ── Web ── from firebase.json — not currently used but included for completeness
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCluwPxR4wAU_XyIwhAnE0d0SmnXlImooQ',
    appId: '1:1013219872602:web:5a023a6b18799b12bb6d63',
    messagingSenderId: '1013219872602',
    projectId: 'offro-e1d3c',
    storageBucket: 'offro-e1d3c.firebasestorage.app',
  );
}
