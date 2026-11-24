// Login layout fitting: pure logic (no widgets, no network). The widget-level checks are in login_layout_test.dart.
import 'package:flutter_test/flutter_test.dart';
import 'package:offro_user/screens/auth/login_layout.dart';

void main() {
  group('loginDeficit', () {
    test('0 when the lifted sheet ends inside the viewport', () {
      expect(loginDeficit(420, 400, 800), 0);
      expect(loginDeficit(420, 408, 800), 0);
    });
    test('the missing height otherwise (the sheet is painted kLoginSheetLift above its layout box)', () {
      expect(kLoginSheetLift, 28);
      expect(loginDeficit(500, 500, 800), 172);
    });
  });

  group('LoginSpacing', () {
    test('t = 0 is the original design', () {
      const s = LoginSpacing(0);
      expect([s.heroTop, s.afterLogo, s.afterEyebrow, s.afterTitle, s.afterBody, s.heroBottom], [28, 40, 12, 16, 16, 64]);
      expect([s.sheetTop, s.afterTabs, s.afterPhone, s.afterButton, s.afterOr, s.afterGuest, s.afterFollow], [24, 24, 16, 20, 20, 24, 10]);
      expect(s.headlineScale, 1);
    });
    test('spacing only tightens as t grows and the hero always keeps the sheet overlap', () {
      var prev = const LoginSpacing(0);
      for (final t in [0.25, 0.5, 0.75, 1.0, 1.5, 2.0]) {
        final s = LoginSpacing(t);
        expect(s.afterLogo <= prev.afterLogo && s.sheetTop <= prev.sheetTop && s.afterGuest <= prev.afterGuest, isTrue, reason: 't=$t');
        expect(s.heroBottom, greaterThan(kLoginSheetLift));
        prev = s;
      }
    });
    test('the headline only shrinks after spacing is used up, and never below 85%', () {
      expect(const LoginSpacing(1).headlineScale, 1);
      expect(const LoginSpacing(2).headlineScale, 0.85);
    });
    test('reducible matches the sum of what t = 1 gives back', () {
      const a = LoginSpacing(0), b = LoginSpacing(1);
      final sum = (a.heroTop - b.heroTop) + (a.afterLogo - b.afterLogo) + (a.afterEyebrow - b.afterEyebrow) + (a.afterTitle - b.afterTitle) +
          (a.afterBody - b.afterBody) + (a.heroBottom - b.heroBottom) + (a.sheetTop - b.sheetTop) + (a.afterTabs - b.afterTabs) +
          (a.afterPhone - b.afterPhone) + (a.afterButton - b.afterButton) + (a.afterOr - b.afterOr) + (a.afterGuest - b.afterGuest) +
          (a.afterFollow - b.afterFollow);
      expect(sum, LoginSpacing.reducible);
    });
  });

  group('loginNextT', () {
    test('no deficit: unchanged', () => expect(loginNextT(0.3, 0), 0.3));
    test('spacing absorbs exactly the missing height', () {
      expect(loginNextT(0, 40) * LoginSpacing.reducible, closeTo(40, 1e-6));
    });
    test('beyond the spacing budget the headline steps down, capped at maxT', () {
      expect(loginNextT(1, 10), 1.25);
      expect(loginNextT(1.9, 10), LoginSpacing.maxT);
      expect(loginNextT(LoginSpacing.maxT, 10), LoginSpacing.maxT);
      expect(loginNextT(0.9, 500), 1);
    });
  });
}
