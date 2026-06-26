// lib/core/widgets/brand_logo.dart
// OFFRO — Brand logo widget helpers

import 'package:flutter/material.dart';

/// Full-width brand logo (image asset with text fallback)
Widget buildImageLogo({double height = 60, bool white = false}) {
  final path = white ? 'assets/logo_white.png' : 'assets/logo_green.png';
  return Image.asset(
    path,
    height: height,
    fit: BoxFit.contain,
    errorBuilder: (_, __, ___) {
      return SizedBox(
        height: height,
        child: Center(
          child: RichText(text: TextSpan(children: [
            TextSpan(text: "Offr", style: TextStyle(color: white ? Colors.white : const Color(0xFF1B4332), fontWeight: FontWeight.w900, fontSize: height * 0.36, letterSpacing: 0.5)),
            TextSpan(text: "O",    style: TextStyle(color: white ? const Color(0xFFA9CDBA) : const Color(0xFF2D6A4F), fontWeight: FontWeight.w900, fontSize: height * 0.36)),
          ])),
        ),
      );
    },
  );
}

/// Circular icon badge — used in store image placeholders and small widgets
Widget buildLogo(double size, Color color) {
  return Container(
    width: size, height: size,
    decoration: BoxDecoration(shape: BoxShape.circle, color: color.withOpacity(0.2)),
    child: Center(
      child: RichText(
        text: TextSpan(children: [
          TextSpan(text: "O", style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: size * 0.45)),
        ]),
      ),
    ),
  );
}
