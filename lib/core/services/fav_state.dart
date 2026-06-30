import 'package:flutter/foundation.dart';

/// Real-time favourite state shared across all screens.
/// All screens read from and write to this singleton so heart icons
/// stay in sync without requiring a full page reload.
class FavState extends ChangeNotifier {
  FavState._();
  static final FavState instance = FavState._();

  final Set<String> _storeIds   = {};
  final Set<String> _productIds = {};

  // Store favourites
  bool hasStore(String id) => _storeIds.contains(id);

  /// Replace entire store favourite set (called after API load).
  void initStores(Iterable<String> ids) {
    _storeIds..clear()..addAll(ids);
    notifyListeners();
  }

  /// Optimistic toggle - call before API, revert on error if needed.
  void toggleStore(String id) {
    if (_storeIds.contains(id)) { _storeIds.remove(id); } else { _storeIds.add(id); }
    notifyListeners();
  }

  /// Set a specific store's favourite state (called after API confirmation).
  void setStore(String id, bool fav) {
    final had = _storeIds.contains(id);
    if (fav) { _storeIds.add(id); } else { _storeIds.remove(id); }
    if (had != _storeIds.contains(id)) notifyListeners();
  }

  // Product favourites
  bool hasProduct(String id) => _productIds.contains(id);

  /// Replace entire product favourite set (called after API load).
  void initProducts(Iterable<String> ids) {
    _productIds..clear()..addAll(ids);
    notifyListeners();
  }

  void toggleProduct(String id) {
    if (_productIds.contains(id)) { _productIds.remove(id); } else { _productIds.add(id); }
    notifyListeners();
  }

  void setProduct(String id, bool fav) {
    final had = _productIds.contains(id);
    if (fav) { _productIds.add(id); } else { _productIds.remove(id); }
    if (had != _productIds.contains(id)) notifyListeners();
  }
}
