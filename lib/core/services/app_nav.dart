import 'package:flutter/material.dart';

/// Navigation globals — set by main.dart before runApp(), used by home_screen.dart.
/// Avoids circular imports between main.dart and home_screen.dart.

// ignore_for_file: library_private_types_in_public_api

void Function(String tok, String nm, String ph, String uid, String role)?
    appGoSwitchMode;
void Function()? appGoOnboarding;
void Function()? appGoLogin;
GlobalKey<NavigatorState>? appNavigatorKey;
