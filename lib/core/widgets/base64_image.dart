// lib/core/widgets/base64_image.dart
import 'dart:collection';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';

/// Safely decode a base64 (optionally `data:image/...;base64,`-prefixed) image
/// string; returns [fallback] on any decode error. Extracted unchanged from
/// main.dart (`_b64Img`). Decoding now goes through [decodeBase64ImageCached].
Widget base64Image(String src, Widget fallback) {
  try {
    return Image.memory(decodeBase64ImageCached(src), fit: BoxFit.cover);
  } catch (_) {
    return fallback;
  }
}

/// Decodes a `data:image/...;base64,<payload>` string (or a bare base64
/// payload) to bytes, reusing the result for repeated calls with the same
/// string.
///
/// Why: `Image.memory(base64Decode(...))` inside `build()` allocated a brand
/// new byte array on every rebuild. Besides repeating the base64 decode, the
/// new array is a new `MemoryImage` key, so Flutter's decoded-image cache
/// never hit and the picture was decoded again (and could flash). Returning
/// the SAME `Uint8List` instance for the same source keeps the key stable.
///
/// Behaviour is otherwise identical to the old inline
/// `base64Decode(src.split(",").last)`: the same bytes come back, and an
/// invalid payload throws the same [FormatException] (nothing is cached for
/// it), so existing `try/catch` fallbacks keep working unchanged.
Uint8List decodeBase64ImageCached(String src) {
  final hit = _Base64ImageCache.instance.get(src);
  if (hit != null) return hit;
  final bytes = base64Decode(src.split(",").last);
  _Base64ImageCache.instance.put(src, bytes);
  return bytes;
}

/// Bounded LRU cache of decoded base64 image bytes.
///
///  * Key: the source string itself (exact match, so two different images can
///    never be confused). Callers pass the same string instance that lives in
///    the store/product maps, so the key does not duplicate that memory; it
///    is still counted in the budget below to stay conservative.
///  * Limits: at most [_maxEntries] entries AND [_maxCost] bytes, where an
///    entry's cost is `bytes.length + key.length`. Least-recently-used entries
///    are evicted first; a hit moves the entry to the most-recent end.
///  * An entry that alone costs more than [_maxEntryCost] is returned to the
///    caller but not stored, so one huge image cannot flush everything else.
///  * Memory pressure: the cache clears itself when the OS reports it
///    ([didHaveMemoryPressure]). Flutter's own image cache is trimmed by the
///    framework at the same time.
class _Base64ImageCache with WidgetsBindingObserver {
  _Base64ImageCache._();
  static final _Base64ImageCache instance = _Base64ImageCache._();

  static const int _maxEntries = 64;
  static const int _maxCost = 24 * 1024 * 1024; // 24 MiB (bytes + key chars)
  static const int _maxEntryCost = 6 * 1024 * 1024; // 6 MiB

  // LinkedHashMap keeps insertion order: first key == least recently used.
  final LinkedHashMap<String, Uint8List> _map = LinkedHashMap<String, Uint8List>();
  int _cost = 0;
  bool _observing = false;

  Uint8List? get(String key) {
    final v = _map.remove(key);
    if (v == null) return null;
    _map[key] = v; // re-insert as most recently used
    return v;
  }

  void put(String key, Uint8List bytes) {
    final entryCost = bytes.length + key.length;
    if (entryCost > _maxEntryCost) return;
    _ensureObserving();
    final old = _map.remove(key);
    if (old != null) _cost -= old.length + key.length;
    _map[key] = bytes;
    _cost += entryCost;
    while ((_cost > _maxCost || _map.length > _maxEntries) && _map.isNotEmpty) {
      final oldestKey = _map.keys.first;
      final removed = _map.remove(oldestKey)!;
      _cost -= removed.length + oldestKey.length;
    }
  }

  void clear() {
    _map.clear();
    _cost = 0;
  }

  void _ensureObserving() {
    if (_observing) return;
    try {
      WidgetsBinding.instance.addObserver(this);
      _observing = true;
    } catch (_) {
      // Binding not ready (e.g. unit tests) — the size limits still apply.
    }
  }

  @override
  void didHaveMemoryPressure() => clear();
}
