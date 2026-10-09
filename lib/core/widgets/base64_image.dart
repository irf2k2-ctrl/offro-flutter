// lib/core/widgets/base64_image.dart
import 'dart:convert';
import 'package:flutter/material.dart';

/// Safely decode a base64 (optionally `data:image/...;base64,`-prefixed) image
/// string; returns [fallback] on any decode error. Extracted unchanged from
/// main.dart (`_b64Img`).
Widget base64Image(String src, Widget fallback) {
  try {
    return Image.memory(base64Decode(src.split(",").last), fit: BoxFit.cover);
  } catch (_) {
    return fallback;
  }
}
