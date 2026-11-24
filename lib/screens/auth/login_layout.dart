/// Login screen layout fitting (pure Dart, no Flutter imports, so it can be unit-tested anywhere).
///
/// The login form sheet is lifted over the hero. When the page is shorter than the screen it fits as designed (t = 0, the original
/// spacing). On a shorter phone the social icons at the very bottom would sit below the fold, so the WHOLE layout's vertical spacing
/// (hero and form sheet) tightens by exactly the missing height - never the icons, content, colours or branding. Only if spacing alone is
/// not enough (t > 1) the big headline shrinks a little as well. The page still scrolls whatever the device.
// The form sheet is lifted over the hero by this much (Transform.translate), so it ends this far above its layout box.
const double kLoginSheetLift = 28;

double _l(double base, double min, double t) => base - (base - min) * t.clamp(0.0, 1.0);

/// All the vertical spacings of the Login tab for a compaction amount [t]: 0 = original design, 1 = tightest spacing, 2 = tightest + smaller headline.
class LoginSpacing {
  final double t;
  const LoginSpacing(this.t);

  // hero
  double get heroTop => _l(28, 8, t);
  double get afterLogo => _l(40, 4, t);
  double get afterEyebrow => _l(12, 2, t);
  double get afterTitle => _l(16, 4, t);       // gap between the headline and the body text
  double get afterBody => _l(16, 4, t);
  double get heroBottom => _l(64, 34, t);      // always > kLoginSheetLift, so the sheet still overlaps the hero as designed
  // form sheet
  double get sheetTop => _l(24, 10, t);
  double get afterTabs => _l(24, 10, t);
  double get afterPhone => _l(16, 6, t);
  double get afterButton => _l(20, 8, t);
  double get afterOr => _l(20, 8, t);
  double get afterGuest => _l(24, 10, t);
  double get afterFollow => _l(10, 4, t);
  /// Headline size factor (1 until spacing is used up).
  double get headlineScale => 1 - 0.15 * (t - 1).clamp(0.0, 1.0);

  /// Total height the spacings can give back (t from 0 to 1).
  static const double reducible = 20 + 36 + 10 + 12 + 12 + 30 + 14 + 14 + 10 + 12 + 12 + 14 + 6;
  static const double maxT = 2;
}

/// Height by which the lifted sheet ends below the viewport (0 = everything is visible). [heroHeight] and [sheetHeight] are the laid-out
/// heights; the sheet's own bottom padding already holds the system inset and the breathing room.
double loginDeficit(double heroHeight, double sheetHeight, double viewportHeight) {
  final d = heroHeight + sheetHeight - kLoginSheetLift - viewportHeight;
  return d > 0.5 ? d : 0;
}

/// The next compaction amount: spacing first (by exactly the missing height), then the headline in steps.
double loginNextT(double t, double deficit) {
  if (deficit <= 0 || t >= LoginSpacing.maxT) return t;
  if (t < 1) {
    final n = t + deficit / LoginSpacing.reducible;
    return n > 1 ? 1 : n;
  }
  final n = t + 0.25;
  return n > LoginSpacing.maxT ? LoginSpacing.maxT : n;
}
