// lib/screens/home/widgets/home_background.dart
//
// Home screen background painter. Extracted unchanged from lib/main.dart
// (class was _OffroHomeBgPainter); only the class name became public.
import 'package:flutter/material.dart';

// ═══════════════════════════════════════════════════════════════
// OFFRO HOME BACKGROUND — premium abstract green gradient
// Light, modern, elegant: soft circles + flowing curved wave lines
// ═══════════════════════════════════════════════════════════════
class OffroHomeBgPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // ── Base gradient fill ──────────────────────────────────────
    // QA round: flat #E9F1ED mint (approved reference) instead of a
    // multi-stop gradient; the soft circles/waves below stay as before.
    final bgPaint = Paint()..color = const Color(0xFFE9F1ED);
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), bgPaint);

    // ── Large soft circle — top left ──────────────────────────
    final c1 = Paint()
      ..shader = RadialGradient(
        colors: const [Color(0x28A9CDBA), Color(0x00A9CDBA)],
        center: Alignment.topLeft,
        radius: 1.0,
      ).createShader(Rect.fromLTWH(-w * 0.1, -h * 0.05, w * 0.75, w * 0.75));
    canvas.drawCircle(Offset(w * 0.05, h * 0.08), w * 0.38, c1);

    // ── Medium circle — top right ────────────────────────────
    final c2 = Paint()
      ..shader = RadialGradient(
        colors: const [Color(0x223E5F55), Color(0x003E5F55)],
        center: Alignment.topRight,
        radius: 1.0,
      ).createShader(Rect.fromLTWH(w * 0.55, -h * 0.02, w * 0.55, w * 0.55));
    canvas.drawCircle(Offset(w * 0.85, h * 0.06), w * 0.28, c2);

    // ── Small accent circle — mid left ──────────────────────
    final c3 = Paint()
      ..shader = RadialGradient(
        colors: const [Color(0x1ACDEBD6), Color(0x00CDEBD6)],
      ).createShader(Rect.fromLTWH(0, h * 0.28, w * 0.4, w * 0.4));
    canvas.drawCircle(Offset(w * 0.08, h * 0.38), w * 0.22, c3);

    // ── Small circle — lower right ───────────────────────────
    final c4 = Paint()
      ..shader = RadialGradient(
        colors: const [Color(0x18A9CDBA), Color(0x00A9CDBA)],
      ).createShader(Rect.fromLTWH(w * 0.6, h * 0.55, w * 0.5, w * 0.5));
    canvas.drawCircle(Offset(w * 0.9, h * 0.68), w * 0.26, c4);

    // ── Dot grid (top right area) ────────────────────────────
    final dotPaint = Paint()..color = const Color(0x223E5F55);
    for (int row = 0; row < 5; row++) {
      for (int col = 0; col < 4; col++) {
        canvas.drawCircle(
          Offset(w * 0.68 + col * 14.0, h * 0.04 + row * 14.0),
          2.0, dotPaint);
      }
    }

    // ── Wave 1 — large sweeping curve (bottom third) ─────────
    final wave1 = Paint()
      ..shader = LinearGradient(
        colors: const [Color(0x1A3E5F55), Color(0x0A3E5F55)],
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
      ).createShader(Rect.fromLTWH(0, h * 0.5, w, h * 0.5))
      ..style = PaintingStyle.fill;
    final wPath1 = Path();
    wPath1.moveTo(0, h * 0.72);
    wPath1.cubicTo(w * 0.25, h * 0.60, w * 0.55, h * 0.84, w, h * 0.68);
    wPath1.lineTo(w, h);
    wPath1.lineTo(0, h);
    wPath1.close();
    canvas.drawPath(wPath1, wave1);

    // ── Wave 2 — lighter higher curve ───────────────────────
    final wave2 = Paint()
      ..color = const Color(0x0F3E5F55)
      ..style = PaintingStyle.fill;
    final wPath2 = Path();
    wPath2.moveTo(0, h * 0.62);
    wPath2.cubicTo(w * 0.30, h * 0.54, w * 0.65, h * 0.74, w, h * 0.58);
    wPath2.lineTo(w, h * 0.68);
    wPath2.cubicTo(w * 0.55, h * 0.84, w * 0.25, h * 0.60, 0, h * 0.72);
    wPath2.close();
    canvas.drawPath(wPath2, wave2);

    // ── Thin curved accent line ──────────────────────────────
    final linePaint = Paint()
      ..color = const Color(0x1A3E5F55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final linePath = Path();
    linePath.moveTo(0, h * 0.45);
    linePath.cubicTo(w * 0.2, h * 0.38, w * 0.75, h * 0.52, w, h * 0.42);
    canvas.drawPath(linePath, linePaint);
  }

  @override bool shouldRepaint(OffroHomeBgPainter old) => false;
}
