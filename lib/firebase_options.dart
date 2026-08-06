// firebase_options.dart
// Generated iOS Firebase configuration for OffrO.
// This file provides platform-specific FirebaseOptions so that
// Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform)
// works correctly on iOS.
//
// Values sourced from ios/Runner/GoogleService-Info.plist and firebase.json.

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

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCluwPxR4wAU_XyIwhAnE0d0SmnXlImooQ',
    appId: '1:1013219872602:android:9125c77175778523bb6d63',
    messagingSenderId: '1013219872602',
    projectId: 'offro-e1d3c',
    storageBucket: 'offro-e1d3c.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCluwPxR4wAU_XyIwhAnE0d0SmnXlImooQ',
    appId: '1:1013219872602:ios:78eb762a21eeb397bb6d63',
    messagingSenderId: '1013219872602',
    projectId: 'offro-e1d3c',
    storageBucket: 'offro-e1d3c.firebasestorage.app',
    iosBundleId: 'com.offro.app',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyCluwPxR4wAU_XyIwhAnE0d0SmnXlImooQ',
    appId: '1:1013219872602:ios:78eb762a21eeb397bb6d63',
    messagingSenderId: '1013219872602',
    projectId: 'offro-e1d3c',
    storageBucket: 'offro-e1d3c.firebasestorage.app',
    iosBundleId: 'com.offro.app',
  );

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCluwPxR4wAU_XyIwhAnE0d0SmnXlImooQ',
    appId: '1:1013219872602:web:5a023a6b18799b12bb6d63',
    messagingSenderId: '1013219872602',
    projectId: 'offro-e1d3c',
    storageBucket: 'offro-e1d3c.firebasestorage.app',
  );
}
