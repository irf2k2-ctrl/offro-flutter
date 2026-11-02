// lib/core/design/offro_toast.dart
//
// OffrO toast (Figma redesign, Phase 1): a dark pill message that floats
// above the bottom navigation. Built on the framework SnackBar so it needs
// no overlay plumbing and no new package.
import 'package:flutter/material.dart';

import 'offro_tokens.dart';
import 'offro_typography.dart';

class OffroToast {
  OffroToast._();

  /// Shows [message] as a floating dark pill. [bottomOffset] lifts it above
  /// the floating bottom navigation (default clears the 76px bar).
  static void show(
    BuildContext context,
    String message, {
    Duration duration = const Duration(milliseconds: 2200),
    double bottomOffset = 100,
    bool isError = false,
  }) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            message,
            textAlign: TextAlign.center,
            style: OffroText.caption.copyWith(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: isError ? OffroColors.error : OffroColors.text,
          elevation: 6,
          duration: duration,
          margin: EdgeInsets.fromLTRB(40, 0, 40, bottomOffset),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          shape: const StadiumBorder(),
        ),
      );
  }
}
