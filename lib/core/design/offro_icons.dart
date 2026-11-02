// lib/core/design/offro_icons.dart
//
// OffrO icon system (Figma redesign, Phase 1).
//
// The design uses a custom 24x24 outline icon set (1.8px stroke, round caps
// and joins). The path data below is copied from the prototype; a tiny SVG
// path parser draws it with a CustomPainter, so no new package is needed.
//
// Usage:  OffroIcon(OffroIcons.pin, size: 18, color: OffroColors.primary)
//         OffroIcon(OffroIcons.heart, filled: isSaved)
import 'package:flutter/material.dart';

import 'offro_tokens.dart';

/// One drawing primitive of an icon (all coordinates are in a 24x24 box).
abstract class OffroIconPrimitive {
  const OffroIconPrimitive();
  Path toPath();
}

class _P extends OffroIconPrimitive {
  final String d;
  const _P(this.d);
  @override
  Path toPath() => parseSvgPath(d);
}

class _C extends OffroIconPrimitive {
  final double cx, cy, r;
  const _C(this.cx, this.cy, this.r);
  @override
  Path toPath() => Path()..addOval(Rect.fromCircle(center: Offset(cx, cy), radius: r));
}

class _R extends OffroIconPrimitive {
  final double x, y, w, h, rx;
  const _R(this.x, this.y, this.w, this.h, this.rx);
  @override
  Path toPath() {
    final rect = Rect.fromLTWH(x, y, w, h);
    return rx > 0
        ? (Path()..addRRect(RRect.fromRectAndRadius(rect, Radius.circular(rx))))
        : (Path()..addRect(rect));
  }
}

/// Immutable description of an icon.
class OffroIconData {
  final List<OffroIconPrimitive> primitives;
  const OffroIconData(this.primitives);
}

/// The icon set (names match the design prototype).
class OffroIcons {
  OffroIcons._();

  static const OffroIconData pin = OffroIconData([_P('M20 10c0 5-8 11-8 11S4 15 4 10a8 8 0 1 1 16 0Z'), _C(12, 10, 2.5)]);
  static const OffroIconData bell = OffroIconData([_P('M18 9a6 6 0 0 0-12 0c0 7-3 7-3 7h18s-3 0-3-7Z'), _P('M10 20h4')]);
  static const OffroIconData search = OffroIconData([_C(10.5, 10.5, 6.5), _P('m15.5 15.5 4.5 4.5')]);
  static const OffroIconData sliders = OffroIconData([_P('M4 7h10M18 7h2M4 17h2M10 17h10'), _C(16, 7, 2), _C(8, 17, 2)]);
  static const OffroIconData restaurant = OffroIconData([_P('M7 3v7M4 3v5a2 2 0 0 0 2 2h2a2 2 0 0 0 2-2V3M7 10v11M16 3c3 2 4 5 4 9h-4V3Zm0 9v9')]);
  static const OffroIconData grocery = OffroIconData([_P('M4 7h16l-1.5 9h-13L4 7Zm2-3 2 3M16 7l2-3'), _C(8, 20, 1), _C(16, 20, 1)]);
  static const OffroIconData pharmacy = OffroIconData([_P('M9 4h6v16H9zM4 9h16v6H4z')]);
  static const OffroIconData fashion = OffroIconData([_P('m8 5 4-2 4 2 4 4-3 3-2-2v11H9V10l-2 2-3-3 4-4Z')]);
  static const OffroIconData electronics = OffroIconData([_R(5, 3, 14, 18, 2), _P('M9 6h6M11 18h2')]);
  static const OffroIconData salon = OffroIconData([_C(7, 7, 3), _C(7, 17, 3), _P('m9 9 11 8M9 15l11-8')]);
  static const OffroIconData fitness = OffroIconData([_P('M4 9v6M7 7v10M17 7v10M20 9v6M7 12h10')]);
  static const OffroIconData doctor = OffroIconData([_P('M8 3v4a4 4 0 0 0 8 0V3M12 11v3a5 5 0 0 0 5 5h1'), _C(19, 18, 2)]);
  static const OffroIconData heart = OffroIconData([_P('M20.5 8.8c0 5.2-8.5 10-8.5 10s-8.5-4.8-8.5-10A4.6 4.6 0 0 1 12 6.4a4.6 4.6 0 0 1 8.5 2.4Z')]);
  static const OffroIconData star = OffroIconData([_P('m12 3 2.7 5.5 6 .9-4.4 4.3 1 6-5.3-2.8-5.3 2.8 1-6-4.4-4.3 6-.9L12 3Z')]);
  static const OffroIconData arrow = OffroIconData([_P('M5 12h14m-5-5 5 5-5 5')]);
  static const OffroIconData home = OffroIconData([_P('m3.5 10 8.5-7 8.5 7v10H15v-6H9v6H3.5V10Z')]);
  static const OffroIconData compass = OffroIconData([_C(12, 12, 9), _P('m15.5 8.5-2 5-5 2 2-5 5-2Z')]);
  static const OffroIconData tag = OffroIconData([_P('M20 13 13 20l-9-9V4h7l9 9Z'), _C(8.5, 8.5, 1.5)]);
  static const OffroIconData gift = OffroIconData([_P('M3 10h18v11H3zM2 6h20v4H2zM12 6v15'), _P('M12 6H8.5A2.5 2.5 0 1 1 11 3.5L12 6Zm0 0h3.5A2.5 2.5 0 1 0 13 3.5L12 6Z')]);
  static const OffroIconData user = OffroIconData([_C(12, 8, 4), _P('M4.5 21c.7-4.5 3.2-6.7 7.5-6.7s6.8 2.2 7.5 6.7')]);
  static const OffroIconData clock = OffroIconData([_C(12, 12, 9), _P('M12 7v5l3 2')]);
  static const OffroIconData chevron = OffroIconData([_P('m9 18 6-6-6-6')]);
  static const OffroIconData phone = OffroIconData([_P('M6.5 3h3l1.3 4-2.2 1.8a16 16 0 0 0 6.6 6.6l1.8-2.2 4 1.3v3c0 1.9-1.6 3.5-3.5 3.3C9.7 20 4 14.3 3.2 6.5 3 4.6 4.6 3 6.5 3Z')]);
  static const OffroIconData message = OffroIconData([_P('M20 11.5a8 8 0 0 1-11.8 7L4 20l1.5-4.1A8 8 0 1 1 20 11.5Z'), _P('M9 9.5c.8 2.2 2.2 3.6 4.5 4.5')]);
  static const OffroIconData route = OffroIconData([_C(6, 18, 2.5), _C(18, 6, 2.5), _P('M8.5 18h2c5 0 1-12 5-12')]);
  static const OffroIconData back = OffroIconData([_P('m15 18-6-6 6-6')]);
  static const OffroIconData check = OffroIconData([_P('m5 12 4 4L19 6')]);
  static const OffroIconData store = OffroIconData([_P('M4 10v10h16V10M3 10l2-6h14l2 6'), _P('M3 10a3 3 0 0 0 5 2 3 3 0 0 0 4 0 3 3 0 0 0 4 0 3 3 0 0 0 5-2M9 20v-5h6v5')]);
  static const OffroIconData sparkles = OffroIconData([_P('m12 3 1.2 3.8L17 8l-3.8 1.2L12 13l-1.2-3.8L7 8l3.8-1.2L12 3Z'), _P('m18.5 14 .7 2.3 2.3.7-2.3.7-.7 2.3-.7-2.3-2.3-.7 2.3-.7.7-2.3ZM5 13l.8 2.2L8 16l-2.2.8L5 19l-.8-2.2L2 16l2.2-.8L5 13Z')]);
  static const OffroIconData shield = OffroIconData([_P('M12 3 5 6v5c0 4.5 2.8 7.8 7 10 4.2-2.2 7-5.5 7-10V6l-7-3Z'), _P('m9 12 2 2 4-4')]);
  static const OffroIconData share = OffroIconData([_C(18, 5, 2.5), _C(6, 12, 2.5), _C(18, 19, 2.5), _P('m8.2 10.8 7.6-4.5M8.2 13.2l7.6 4.5')]);
  static const OffroIconData play = OffroIconData([_P('m9 7 8 5-8 5V7Z')]);
  static const OffroIconData scan = OffroIconData([_P('M4 8V4h4M16 4h4v4M20 16v4h-4M8 20H4v-4'), _P('M8 8h3v3H8zM14 8h2v2h-2zM8 14h2v2H8zM13 13h3v3h-3z')]);

  /// Icon for a store category name (case-insensitive, substring match).
  /// Unknown categories fall back to [store].
  static OffroIconData forCategory(String name) {
    final n = name.toLowerCase();
    if (n.contains('restaurant') || n.contains('cafe') || n.contains('food') || n.contains('bakery')) return restaurant;
    if (n.contains('grocery') || n.contains('supermarket') || n.contains('kirana')) return grocery;
    if (n.contains('pharm') || n.contains('medical') || n.contains('chemist')) return pharmacy;
    if (n.contains('fashion') || n.contains('cloth') || n.contains('apparel') || n.contains('boutique')) return fashion;
    if (n.contains('electronic') || n.contains('mobile') || n.contains('gadget')) return electronics;
    if (n.contains('salon') || n.contains('spa') || n.contains('beauty')) return salon;
    if (n.contains('fitness') || n.contains('gym') || n.contains('sport')) return fitness;
    if (n.contains('doctor') || n.contains('clinic') || n.contains('hospital') || n.contains('dental')) return doctor;
    return store;
  }

  /// Pastel tone for a store category name (same matching as [forCategory]).
  static OffroTone toneForCategory(String name) {
    final i = forCategory(name);
    if (identical(i, restaurant)) return OffroTones.restaurant;
    if (identical(i, grocery)) return OffroTones.grocery;
    if (identical(i, pharmacy)) return OffroTones.pharmacy;
    if (identical(i, fashion)) return OffroTones.fashion;
    if (identical(i, electronics)) return OffroTones.electronics;
    if (identical(i, salon)) return OffroTones.salon;
    if (identical(i, fitness)) return OffroTones.fitness;
    if (identical(i, doctor)) return OffroTones.doctor;
    return OffroTones.neutral;
  }
}

/// Draws an [OffroIconData] at [size] x [size].
class OffroIcon extends StatelessWidget {
  final OffroIconData data;
  final double size;
  final Color? color;
  final bool filled;
  final double strokeWidth;
  final String? semanticLabel;

  const OffroIcon(
    this.data, {
    super.key,
    this.size = 20,
    this.color,
    this.filled = false,
    this.strokeWidth = 1.8,
    this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? IconTheme.of(context).color ?? OffroColors.text;
    final painter = CustomPaint(
      size: Size(size, size),
      painter: _OffroIconPainter(data, c, filled, strokeWidth),
    );
    final box = SizedBox(width: size, height: size, child: painter);
    if (semanticLabel == null) return ExcludeSemantics(child: box);
    return Semantics(label: semanticLabel, image: true, child: box);
  }
}

class _OffroIconPainter extends CustomPainter {
  final OffroIconData data;
  final Color color;
  final bool filled;
  final double strokeWidth;

  _OffroIconPainter(this.data, this.color, this.filled, this.strokeWidth);

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 24.0;
    canvas.save();
    canvas.scale(scale, scale);
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final fill = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    for (final p in data.primitives) {
      final path = p.toPath();
      if (filled) canvas.drawPath(path, fill);
      canvas.drawPath(path, stroke);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_OffroIconPainter old) =>
      old.data != data || old.color != color || old.filled != filled || old.strokeWidth != strokeWidth;
}

final RegExp _svgToken = RegExp(r'[a-zA-Z]|-?(?:\d+\.?\d*|\.\d+)(?:[eE][-+]?\d+)?');

/// Minimal SVG path-data parser: M m L l H h V v C c S s Q q A a Z z.
/// (Enough for the icon set above.) Unknown commands are skipped.
Path parseSvgPath(String d) {
  final path = Path();
  final tokens = _svgToken.allMatches(d).map((m) => m.group(0)!).toList();
  var i = 0;
  var cmd = '';
  double cx = 0, cy = 0, sx = 0, sy = 0;
  double? lastCtrlX, lastCtrlY; // last cubic control point (for S)

  bool isCmd(String t) {
    final u = t.codeUnitAt(0);
    return (u >= 65 && u <= 90) || (u >= 97 && u <= 122);
  }

  double next() => double.parse(tokens[i++]);

  while (i < tokens.length) {
    if (isCmd(tokens[i])) {
      cmd = tokens[i++];
      if (cmd == 'Z' || cmd == 'z') {
        path.close();
        cx = sx;
        cy = sy;
        lastCtrlX = lastCtrlY = null;
        continue;
      }
    } else if (cmd.isEmpty) {
      i++; // stray number before any command
      continue;
    }
    final rel = cmd == cmd.toLowerCase();
    switch (cmd.toUpperCase()) {
      case 'M':
        {
          final x = next() + (rel ? cx : 0);
          final y = next() + (rel ? cy : 0);
          path.moveTo(x, y);
          cx = sx = x;
          cy = sy = y;
          cmd = rel ? 'l' : 'L'; // following pairs are implicit line-tos
          lastCtrlX = lastCtrlY = null;
          break;
        }
      case 'L':
        {
          final x = next() + (rel ? cx : 0);
          final y = next() + (rel ? cy : 0);
          path.lineTo(x, y);
          cx = x;
          cy = y;
          lastCtrlX = lastCtrlY = null;
          break;
        }
      case 'H':
        {
          final x = next() + (rel ? cx : 0);
          path.lineTo(x, cy);
          cx = x;
          lastCtrlX = lastCtrlY = null;
          break;
        }
      case 'V':
        {
          final y = next() + (rel ? cy : 0);
          path.lineTo(cx, y);
          cy = y;
          lastCtrlX = lastCtrlY = null;
          break;
        }
      case 'C':
        {
          final x1 = next() + (rel ? cx : 0);
          final y1 = next() + (rel ? cy : 0);
          final x2 = next() + (rel ? cx : 0);
          final y2 = next() + (rel ? cy : 0);
          final x = next() + (rel ? cx : 0);
          final y = next() + (rel ? cy : 0);
          path.cubicTo(x1, y1, x2, y2, x, y);
          lastCtrlX = x2;
          lastCtrlY = y2;
          cx = x;
          cy = y;
          break;
        }
      case 'S':
        {
          final x1 = lastCtrlX != null ? 2 * cx - lastCtrlX : cx;
          final y1 = lastCtrlY != null ? 2 * cy - lastCtrlY : cy;
          final x2 = next() + (rel ? cx : 0);
          final y2 = next() + (rel ? cy : 0);
          final x = next() + (rel ? cx : 0);
          final y = next() + (rel ? cy : 0);
          path.cubicTo(x1, y1, x2, y2, x, y);
          lastCtrlX = x2;
          lastCtrlY = y2;
          cx = x;
          cy = y;
          break;
        }
      case 'Q':
        {
          final x1 = next() + (rel ? cx : 0);
          final y1 = next() + (rel ? cy : 0);
          final x = next() + (rel ? cx : 0);
          final y = next() + (rel ? cy : 0);
          path.quadraticBezierTo(x1, y1, x, y);
          lastCtrlX = lastCtrlY = null;
          cx = x;
          cy = y;
          break;
        }
      case 'A':
        {
          final rx = next();
          final ry = next();
          final rot = next();
          final large = next() != 0;
          final sweep = next() != 0;
          final x = next() + (rel ? cx : 0);
          final y = next() + (rel ? cy : 0);
          path.arcToPoint(
            Offset(x, y),
            radius: Radius.elliptical(rx, ry),
            rotation: rot,
            largeArc: large,
            clockwise: sweep,
          );
          cx = x;
          cy = y;
          lastCtrlX = lastCtrlY = null;
          break;
        }
      default:
        i++; // unsupported command: skip a token so we always make progress
        break;
    }
  }
  return path;
}
