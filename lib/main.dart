// DIAGNOSTIC BUILD — Live step-by-step status screen.
// Each risky native plugin call is preceded by a status update.
// If the app crashes, the LAST status line visible on screen (before
// the crash) tells us exactly which call caused it — no restart needed.

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_options.dart';

final ValueNotifier<List<String>> diagLog = ValueNotifier<List<String>>([]);

void _log(String msg) {
  debugPrint('[DIAG] $msg');
  diagLog.value = [...diagLog.value, msg];
}

@pragma('vm:entry-point')
Future<void> _bgHandler(RemoteMessage message) async {}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (FlutterErrorDetails details) {
    _log('FlutterError: ${details.exception}');
  };

  // Render the diagnostic screen FIRST — before any risky native calls.
  runApp(const DiagnosticApp());

  // Give the engine time to paint the first frame so whatever we see on
  // screen right before a crash is accurate.
  await Future.delayed(const Duration(milliseconds: 400));

  _log('STEP 1: Calling Firebase.initializeApp()...');
  bool firebaseReady = false;
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    firebaseReady = true;
    _log('STEP 1: OK — Firebase initialized');
  } catch (e) {
    _log('STEP 1: FAILED — $e');
  }
  await Future.delayed(const Duration(milliseconds: 400));

  _log('STEP 2: Registering FirebaseMessaging.onBackgroundMessage...');
  try {
    if (firebaseReady) FirebaseMessaging.onBackgroundMessage(_bgHandler);
    _log('STEP 2: OK');
  } catch (e) {
    _log('STEP 2: FAILED — $e');
  }
  await Future.delayed(const Duration(milliseconds: 400));

  _log('STEP 3: SharedPreferences.getInstance()...');
  try {
    await SharedPreferences.getInstance();
    _log('STEP 3: OK');
  } catch (e) {
    _log('STEP 3: FAILED — $e');
  }
  await Future.delayed(const Duration(milliseconds: 400));

  _log('STEP 4: FlutterLocalNotificationsPlugin().initialize()...');
  try {
    final plugin = FlutterLocalNotificationsPlugin();
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await plugin.initialize(
      const InitializationSettings(android: android, iOS: ios),
      onDidReceiveNotificationResponse: (resp) {},
    );
    _log('STEP 4: OK — local notifications plugin initialized');
  } catch (e) {
    _log('STEP 4: FAILED — $e');
  }
  await Future.delayed(const Duration(milliseconds: 400));

  _log('STEP 5: setForegroundNotificationPresentationOptions()...');
  try {
    if (firebaseReady) {
      await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
        alert: true, badge: true, sound: true,
      );
    }
    _log('STEP 5: OK');
  } catch (e) {
    _log('STEP 5: FAILED — $e');
  }
  await Future.delayed(const Duration(milliseconds: 400));

  _log('STEP 6: FirebaseMessaging.instance.requestPermission()...');
  try {
    if (firebaseReady) {
      await FirebaseMessaging.instance.requestPermission(
        alert: true, badge: true, sound: true,
        announcement: false, carPlay: false, criticalAlert: false, provisional: false,
      );
    }
    _log('STEP 6: OK');
  } catch (e) {
    _log('STEP 6: FAILED — $e');
  }
  await Future.delayed(const Duration(milliseconds: 400));

  _log('STEP 7: FirebaseMessaging.instance.getInitialMessage()...');
  try {
    if (firebaseReady) await FirebaseMessaging.instance.getInitialMessage();
    _log('STEP 7: OK');
  } catch (e) {
    _log('STEP 7: FAILED — $e');
  }
  await Future.delayed(const Duration(milliseconds: 400));

  _log('STEP 8: SystemChrome.setSystemUIOverlayStyle()...');
  try {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));
    _log('STEP 8: OK');
  } catch (e) {
    _log('STEP 8: FAILED — $e');
  }

  _log('ALL STEPS COMPLETE ✅ — if you see this, none of the tested');
  _log('plugin calls crashed the app. Take a screenshot of this list.');
}

class DiagnosticApp extends StatelessWidget {
  const DiagnosticApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xFFFDFBF6),
        appBar: AppBar(
          backgroundColor: const Color(0xFF3E5F55),
          title: const Text('OFFRO — Diagnostic', style: TextStyle(color: Colors.white)),
        ),
        body: SafeArea(
          child: ValueListenableBuilder<List<String>>(
            valueListenable: diagLog,
            builder: (context, log, _) {
              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: log.length,
                itemBuilder: (context, i) {
                  final line = log[i];
                  final isFail = line.contains('FAILED');
                  final isOk = line.contains('OK');
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(
                      line,
                      style: TextStyle(
                        fontSize: 13,
                        fontFamily: 'monospace',
                        color: isFail
                            ? const Color(0xFFc0392b)
                            : isOk
                                ? const Color(0xFF3E5F55)
                                : const Color(0xFF2c3e35),
                        fontWeight: line.startsWith('STEP') ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}
