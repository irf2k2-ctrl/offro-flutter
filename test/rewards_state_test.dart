import 'package:flutter_test/flutter_test.dart';
import 'package:offro_user/core/services/rewards_state.dart';

void main() {
  group('RewardsState.visitPointsFrom (Home balance from /user/wallet)', () {
    test('reads the visit points', () {
      expect(RewardsState.visitPointsFrom({'visit_points': 120, 'pool_points': 5}), 120);
      expect(RewardsState.visitPointsFrom({'visit_points': 120.0}), 120);
      expect(RewardsState.visitPointsFrom({'visit_points': '75'}), 75);
      expect(RewardsState.visitPointsFrom({'visit_points': 0}), 0);
    });
    test('a failed / empty wallet response is NOT a balance, so Home keeps what it shows', () {
      expect(RewardsState.visitPointsFrom(<String, dynamic>{}), isNull);
      expect(RewardsState.visitPointsFrom(null), isNull);
      expect(RewardsState.visitPointsFrom({'visit_points': null}), isNull);
      expect(RewardsState.visitPointsFrom({'visit_points': 'abc'}), isNull);
    });
  });

  group('RewardsState.markChanged (QR scan -> Home / Rewards refresh)', () {
    test('every successful credit notifies listeners once', () {
      final s = RewardsState.instance;
      var calls = 0;
      void l() => calls++;
      s.revision.addListener(l);
      final before = s.revision.value;
      s.markChanged();
      s.markChanged();
      expect(calls, 2);
      expect(s.revision.value, before + 2);
      s.revision.removeListener(l);
      s.markChanged();
      expect(calls, 2);
    });
  });
}
