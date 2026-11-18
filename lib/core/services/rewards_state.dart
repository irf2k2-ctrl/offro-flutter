import 'package:flutter/foundation.dart';

/// Shared "reward points changed" signal.
///
/// The Home screen reads the points balance from `/user/wallet` only as part of its big
/// supplementary load, so a QR scan made on a screen pushed above Home (store detail ->
/// QR scanner) never reached Home. The scanner now calls [markChanged] after a successful
/// credit, and Home / the Rewards screen listen to [revision] and re-read the wallet.
class RewardsState {
  RewardsState._();
  static final RewardsState instance = RewardsState._();

  /// Bumped after every successful points credit.
  final ValueNotifier<int> revision = ValueNotifier<int>(0);

  void markChanged() => revision.value = revision.value + 1;

  /// Visit-points balance from a `/user/wallet` response, or null when the response does not
  /// carry one (failed request -> `{}`), so a failed refresh never overwrites a good balance with 0.
  static int? visitPointsFrom(Map<String, dynamic>? wallet) {
    final v = wallet == null ? null : wallet['visit_points'];
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v.trim());
    return null;
  }
}
