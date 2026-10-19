import 'package:flutter/foundation.dart';

/// Real-time favourite state shared across all screens.
/// All screens read from and write to this singleton so heart icons
/// stay in sync without requiring a full page reload.
class FavState extends ChangeNotifier {
  FavState._();
  static final FavState instance = FavState._();

  final Set<String> _storeIds   = {};
  final Set<String> _productIds = {};
  final Set<String> _influencerIds = {};

  // Per-store notifiers so a single store's heart can rebuild on its own,
  // without rebuilding the whole Home (see storeListenable).
  final Map<String, ValueNotifier<bool>> _storeNotifiers = {};
  // Store ids with a favourite request currently in flight.
  final Set<String> _pendingStores = {};

  /// Bumps whenever the product favourite set changes. Home listens to this
  /// (instead of every FavState change) because only its product hearts are
  /// drawn from Home's own build; store hearts listen per store.
  final ValueNotifier<int> productRevision = ValueNotifier<int>(0);

  // Store favourites
  bool hasStore(String id) => _storeIds.contains(id);

  /// Listenable that changes only when this one store's favourite state changes.
  ValueListenable<bool> storeListenable(String id) =>
      _storeNotifiers.putIfAbsent(id, () => ValueNotifier<bool>(_storeIds.contains(id)));

  void _syncStoreNotifiers() {
    _storeNotifiers.forEach((id, n) => n.value = _storeIds.contains(id));
  }

  /// Marks a store as having a favourite request in flight. Returns false if
  /// one is already pending (caller should ignore the tap).
  bool tryLockStore(String id) => _pendingStores.add(id);
  void unlockStore(String id) => _pendingStores.remove(id);
  bool isStorePending(String id) => _pendingStores.contains(id);

  /// Replace entire store favourite set (called after API load).
  void initStores(Iterable<String> ids) {
    final next = ids.toSet();
    final changed = next.length != _storeIds.length || !_storeIds.containsAll(next);
    _storeIds..clear()..addAll(next);
    _syncStoreNotifiers();
    if (changed) notifyListeners();
  }

  /// Optimistic toggle - call before API, revert on error if needed.
  void toggleStore(String id) {
    if (_storeIds.contains(id)) { _storeIds.remove(id); } else { _storeIds.add(id); }
    _syncStoreNotifiers();
    notifyListeners();
  }

  /// Set a specific store's favourite state (called after API confirmation).
  void setStore(String id, bool fav) {
    final had = _storeIds.contains(id);
    if (fav) { _storeIds.add(id); } else { _storeIds.remove(id); }
    if (had != _storeIds.contains(id)) {
      _storeNotifiers[id]?.value = _storeIds.contains(id);
      notifyListeners();
    }
  }

  // Product favourites
  bool hasProduct(String id) => _productIds.contains(id);

  /// Replace entire product favourite set (called after API load).
  void initProducts(Iterable<String> ids) {
    final next = ids.toSet();
    final changed = next.length != _productIds.length || !_productIds.containsAll(next);
    _productIds..clear()..addAll(next);
    if (changed) { productRevision.value++; notifyListeners(); }
  }

  void toggleProduct(String id) {
    if (_productIds.contains(id)) { _productIds.remove(id); } else { _productIds.add(id); }
    productRevision.value++;
    notifyListeners();
  }

  void setProduct(String id, bool fav) {
    final had = _productIds.contains(id);
    if (fav) { _productIds.add(id); } else { _productIds.remove(id); }
    if (had != _productIds.contains(id)) { productRevision.value++; notifyListeners(); }
  }

  // Influencer favourites — same exact pattern as Store/Product above, so
  // the Influencer heart on the public profile screen behaves identically
  // (instant, cross-screen sync via this singleton, optimistic-toggle +
  // server-confirmed revert handled by the caller).
  bool hasInfluencer(String id) => _influencerIds.contains(id);

  /// Replace entire influencer favourite set (called after API load).
  void initInfluencers(Iterable<String> ids) {
    _influencerIds..clear()..addAll(ids);
    notifyListeners();
  }

  void toggleInfluencer(String id) {
    if (_influencerIds.contains(id)) { _influencerIds.remove(id); } else { _influencerIds.add(id); }
    notifyListeners();
  }

  void setInfluencer(String id, bool fav) {
    final had = _influencerIds.contains(id);
    if (fav) { _influencerIds.add(id); } else { _influencerIds.remove(id); }
    if (had != _influencerIds.contains(id)) notifyListeners();
  }
}
