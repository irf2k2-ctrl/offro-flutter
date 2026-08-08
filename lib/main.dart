// MINIMAL DIAGNOSTIC main.dart — ZERO plugin calls
// If this crashes: the issue is in native plugin registration (before Dart runs)
// If this works: the issue is in a specific plugin call from Dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  
  // NO Firebase, NO notifications, NO messaging, NO SharedPreferences
  // Just render a simple screen
  
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));
  
  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: Scaffold(
      backgroundColor: Color(0xFFFDFBF6),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('OFFRO', style: TextStyle(fontSize: 48, fontWeight: FontWeight.w900, color: Color(0xFF3E5F55))),
            SizedBox(height: 20),
            Text('Diagnostic Build — plugins not loaded', style: TextStyle(fontSize: 14, color: Color(0xFF6b8c7e))),
            SizedBox(height: 40),
            Icon(Icons.check_circle, color: Color(0xFF3E5F55), size: 48),
            SizedBox(height: 12),
            Text('If you see this screen, the crash\nis in a plugin call, not registration.', 
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Color(0xFF6b8c7e)),
            ),
          ],
        ),
      ),
    ),
  ));
}
