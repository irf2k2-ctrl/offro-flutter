// lib/screens/notification_diagnostics.dart
// OFFRO — iOS Notification Diagnostics Screen
// TEMPORARY: In-app diagnostics for push notification registration chain.
// No tokens are permanently stored or sent to third parties.

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class NotificationDiagnosticsScreen extends StatefulWidget {
  const NotificationDiagnosticsScreen({super.key});

  @override
  State<NotificationDiagnosticsScreen> createState() =>
      _NotificationDiagnosticsScreenState();
}

class _NotificationDiagnosticsScreenState
    extends State<NotificationDiagnosticsScreen> {
  // ── Diagnostic results ──
  String _platform = 'Unknown';
  String _appVersion = '1.0.1 (30)';
  String _permissionStatus = 'Checking...';
  String _firebaseInitStatus = 'Checking...';
  String _apnsRegistrationStatus = 'Checking...';
  String _apnsTokenStatus = 'Checking...';
  String _apnsTokenPreview = '-';
  String _fcmTokenStatus = 'Checking...';
  String _fcmTokenPreview = '-';
  String _tokenRefreshStatus = 'NOT RECEIVED';
  String _apnsError = '-';
  String _fcmTokenError = '-';
  bool _isRunning = false;

  // ── MethodChannel for native APNs events ──
  static const _channel = MethodChannel('com.mibtech.offro/notif_diag');
  String? _nativeAPNsToken;
  String? _nativeAPNsError;
  bool? _nativeAPNsSuccess;

  @override
  void initState() {
    super.initState();
    _setupMethodChannel();
    _runDiagnostics();
  }

  void _setupMethodChannel() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'apnsStatusUpdate') {
        final args = call.arguments as Map?;
        if (args != null) {
          setState(() {
            _nativeAPNsSuccess = args['success'] as bool?;
            _nativeAPNsToken = args['token'] as String?;
            _nativeAPNsError = args['error'] as String?;
          });
          _updateNativeStatus();
        }
      }
    });
    _queryStoredAPNsStatus();
  }

  Future<void> _queryStoredAPNsStatus() async {
    try {
      final result = await _channel.invokeMethod('getStoredAPNsStatus');
      if (result != null && result is Map) {
        setState(() {
          _nativeAPNsSuccess = result['success'] as bool?;
          _nativeAPNsToken = result['token'] as String?;
          _nativeAPNsError = result['error'] as String?;
        });
        _updateNativeStatus();
      }
    } catch (e) {
      debugPrint('[IOS-NOTIF] MethodChannel query failed: $e');
    }
  }

  void _updateNativeStatus() {
    if (_nativeAPNsSuccess == true) {
      _apnsRegistrationStatus = 'SUCCESS';
      _apnsError = '-';
    } else if (_nativeAPNsSuccess == false) {
      _apnsRegistrationStatus = 'FAILED';
      _apnsError = _nativeAPNsError ?? 'Unknown error';
    }
    if (_nativeAPNsToken != null && _nativeAPNsToken!.isNotEmpty) {
      _apnsTokenStatus = 'AVAILABLE';
      _apnsTokenPreview = _formatToken(_nativeAPNsToken!);
    }
  }

  String _formatToken(String token) {
    if (token.length <= 20) return token;
    return '${token.substring(0, 10)}...${token.substring(token.length - 10)} (len=${token.length})';
  }

  Future<void> _runDiagnostics() async {
    setState(() => _isRunning = true);

    _platform = Platform.isIOS ? 'iOS' : 'Android';

    await _queryStoredAPNsStatus();

    try {
      if (Firebase.apps.isNotEmpty) {
        _firebaseInitStatus = 'SUCCESS';
      } else {
        _firebaseInitStatus = 'FAILED (Firebase.apps is empty)';
      }
    } catch (e) {
      _firebaseInitStatus = 'FAILED ($e)';
    }

    try {
      final settings =
          await FirebaseMessaging.instance.getNotificationSettings();
      _permissionStatus = settings.authorizationStatus.toString();
    } catch (e) {
      _permissionStatus = 'ERROR ($e)';
    }

    try {
      if (Platform.isIOS) {
        String? apnsToken;
        for (int i = 1; i <= 3; i++) {
          apnsToken = await FirebaseMessaging.instance
              .getAPNSToken()
              .timeout(const Duration(seconds: 3));
          if (apnsToken != null) break;
          if (i < 3) await Future.delayed(const Duration(seconds: 2));
        }
        if (apnsToken != null) {
          _apnsTokenStatus = 'AVAILABLE';
          _apnsTokenPreview = _formatToken(apnsToken);
        } else {
          _apnsTokenStatus = 'NULL';
          _apnsTokenPreview = '-';
        }
      } else {
        _apnsTokenStatus = 'N/A (Android)';
        _apnsTokenPreview = '-';
      }
    } catch (e) {
      _apnsTokenStatus = 'ERROR';
      _apnsTokenPreview = '-';
      _apnsError = e.toString();
    }

    try {
      String? fcmToken;
      try {
        fcmToken = await FirebaseMessaging.instance
            .getToken()
            .timeout(const Duration(seconds: 10));
      } catch (e) {
        _fcmTokenError = e.toString();
      }
      if (fcmToken != null) {
        _fcmTokenStatus = 'AVAILABLE';
        _fcmTokenPreview = _formatToken(fcmToken);
        _fcmTokenError = '-';
      } else {
        _fcmTokenStatus = 'NULL';
        _fcmTokenPreview = '-';
      }
    } catch (e) {
      _fcmTokenStatus = 'ERROR';
      _fcmTokenPreview = '-';
      _fcmTokenError = e.toString();
    }

    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
      if (mounted) {
        setState(() {
          _tokenRefreshStatus = 'RECEIVED';
        });
      }
    });

    _updateNativeStatus();

    if (mounted) {
      setState(() {
        _isRunning = false;
      });
    }
  }

  String _buildDiagnosticsText() {
    final lines = <String>[
      '=== iOS NOTIFICATION DIAGNOSTICS ===',
      'Generated: ${DateTime.now().toIso8601String()}',
      '',
      'Platform: $_platform',
      'App version/build: $_appVersion',
      '',
      'Notification permission: $_permissionStatus',
      'Firebase initialization: $_firebaseInitStatus',
      'APNs registration: $_apnsRegistrationStatus',
      'APNs token: $_apnsTokenStatus',
      'APNs token preview: $_apnsTokenPreview',
      'FCM token: $_fcmTokenStatus',
      'FCM token preview: $_fcmTokenPreview',
      'FCM token refresh: $_tokenRefreshStatus',
      '',
      'APNs registration error: $_apnsError',
      'FCM token error: $_fcmTokenError',
      '',
      '=== END DIAGNOSTICS ===',
    ];
    return lines.join('\n');
  }

  void _copyDiagnostics() {
    final text = _buildDiagnosticsText();
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Diagnostics copied to clipboard'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Widget _diagRow(String label, String value, {bool? success}) {
    Color valueColor = Colors.black87;
    IconData icon = Icons.help_outline;
    Color iconColor = Colors.grey;

    if (success == true) {
      icon = Icons.check_circle;
      iconColor = Colors.green;
    } else if (success == false) {
      icon = Icons.cancel;
      iconColor = Colors.red;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 13, color: Colors.grey)),
                const SizedBox(height: 2),
                Text(value,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notification Diagnostics'),
        backgroundColor: const Color(0xFF3E5F55),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              children: [
                const SizedBox(height: 12),
                _diagRow('Platform', _platform),
                _diagRow('App version/build', _appVersion),
                const Divider(),
                _diagRow(
                    'Notification permission',
                    _permissionStatus,
                    success: _permissionStatus.contains('authorized')
                        ? true
                        : _permissionStatus.contains('denied')
                            ? false
                            : null),
                _diagRow(
                    'Firebase initialization',
                    _firebaseInitStatus,
                    success: _firebaseInitStatus.contains('SUCCESS')
                        ? true
                        : _firebaseInitStatus.contains('FAILED')
                            ? false
                            : null),
                const Divider(),
                _diagRow(
                    'APNs registration',
                    _apnsRegistrationStatus,
                    success: _apnsRegistrationStatus == 'SUCCESS'
                        ? true
                        : _apnsRegistrationStatus == 'FAILED'
                            ? false
                            : null),
                _diagRow(
                    'APNs token',
                    _apnsTokenStatus,
                    success: _apnsTokenStatus == 'AVAILABLE'
                        ? true
                        : _apnsTokenStatus == 'NULL'
                            ? false
                            : null),
                _diagRow('APNs token preview', _apnsTokenPreview),
                const Divider(),
                _diagRow(
                    'FCM token',
                    _fcmTokenStatus,
                    success: _fcmTokenStatus == 'AVAILABLE'
                        ? true
                        : _fcmTokenStatus == 'NULL'
                            ? false
                            : null),
                _diagRow('FCM token preview', _fcmTokenPreview),
                _diagRow(
                    'FCM token refresh',
                    _tokenRefreshStatus,
                    success: _tokenRefreshStatus == 'RECEIVED' ? true : null),
                const Divider(),
                _diagRow('APNs registration error', _apnsError,
                    success: _apnsError != '-' ? false : null),
                _diagRow('FCM token error', _fcmTokenError,
                    success: _fcmTokenError != '-' ? false : null),
                const SizedBox(height: 20),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isRunning ? null : _runDiagnostics,
                    icon: _isRunning
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh),
                    label: Text(_isRunning ? 'Checking...' : 'Refresh'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3E5F55),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _copyDiagnostics,
                    icon: const Icon(Icons.copy),
                    label: const Text('Copy'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFA9CDBA),
                      foregroundColor: const Color(0xFF2c3e35),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
