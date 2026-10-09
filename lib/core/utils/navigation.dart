// lib/core/utils/navigation.dart
import 'package:flutter/material.dart';

/// Standard page route used across the app (plain MaterialPageRoute).
/// Extracted unchanged from main.dart (`_route`).
PageRoute appRoute(Widget w) => MaterialPageRoute(builder: (_) => w);
