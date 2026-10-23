// lib/screens/home/explore_tab.dart
//
// Customer "Explore" tab (Figma redesign, Phase 2).
//
// Pure presentation: it filters the store list HomeScreen already loaded for
// the current city (real data, no extra API calls) and reports taps back
// through callbacks, so Store Detail navigation and the favourite API stay
// exactly where they were. Search matches the same four fields the old
// search page used: store name, category, area and offer.
import 'package:flutter/material.dart';

import '../../core/design/design.dart';
import '../../core/services/api_service.dart';
import '../../core/services/error_mapper.dart';
import '../../core/services/fav_state.dart';

class ExploreTab extends StatefulWidget {
  final List<Map<String, dynamic>> stores;
  final String city;
  final String token;
  final ValueChanged<Map<String, dynamic>> onStoreTap;

  const ExploreTab({
    super.key,
    required this.stores,
    required this.city,
    required this.token,
    required this.onStoreTap,
  });

  @override
  State<ExploreTab> createState() => _ExploreTabState();
}

class _ExploreTabState extends State<ExploreTab> {
  final TextEditingController _search = TextEditingController();
  String _query = '';
  String _category = 'All';
  String? _area;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  static String _s(dynamic v) {
    final t = (v ?? '').toString().trim();
    return t == 'null' ? '' : t;
  }

  /// Distinct values of [key] across the stores, most frequent first.
  List<MapEntry<String, int>> _counted(String key) {
    final counts = <String, int>{};
    for (final s in widget.stores) {
      final v = _s(s[key]);
      if (v.isNotEmpty) counts[v] = (counts[v] ?? 0) + 1;
    }
    final list = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return list;
  }

  List<Map<String, dynamic>> get _visible {
    final q = _query.trim().toLowerCase();
    final out = widget.stores.where((s) {
      if (_category != 'All' && _s(s['category']) != _category) return false;
      if (_area != null && _s(s['area']) != _area) return false;
      if (q.isEmpty) return true;
      return _s(s['store_name']).toLowerCase().contains(q) ||
          _s(s['category']).toLowerCase().contains(q) ||
          _s(s['area']).toLowerCase().contains(q) ||
          _s(s['offer']).toLowerCase().contains(q);
    }).toList();
    // Nearest first when distances are known (computed by Home).
    if (out.any((s) => s['distance_km'] != null)) {
      out.sort((a, b) {
        final da = (a['distance_km'] as num?)?.toDouble() ?? 9999.0;
        final db = (b['distance_km'] as num?)?.toDouble() ?? 9999.0;
        return da.compareTo(db);
      });
    }
    return out;
  }

  static String _distance(Map<String, dynamic> s) {
    final d = (s['distance_km'] as num?)?.toDouble();
    if (d == null) return '';
    return d < 1 ? '${(d * 1000).round()} m' : '${d.toStringAsFixed(1)} km';
  }

  static String _image(Map<String, dynamic> s) {
    for (final k in ['image_url', 'image_thumb', 'image', 'image2']) {
      final v = _s(s[k]);
      if (v.isNotEmpty) return v;
    }
    final imgs = s['images'];
    if (imgs is List && imgs.isNotEmpty) return imgs.first.toString();
    return '';
  }

  Future<void> _toggleFav(String sid) async {
    if (sid.isEmpty || widget.token.isEmpty) return;
    if (!FavState.instance.tryLockStore(sid)) return;
    final prev = FavState.instance.hasStore(sid);
    FavState.instance.setStore(sid, !prev); // optimistic
    try {
      final confirmed = await Api.toggleFavorite(widget.token, sid);
      FavState.instance.setStore(sid, confirmed);
    } catch (e) {
      FavState.instance.setStore(sid, prev);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("Couldn't save favorite: ${friendlyError(e)}"),
          backgroundColor: Colors.red.shade700,
          duration: const Duration(seconds: 12),
          showCloseIcon: true,
        ));
      }
    } finally {
      FavState.instance.unlockStore(sid);
    }
  }

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    final categories = _counted('category').take(4).map((e) => e.key).toList();
    final areas = _counted('area').take(6).toList();
    final visible = _visible;
    final cityLabel = widget.city.isNotEmpty ? widget.city : 'your city';

    return ListView(
      padding: EdgeInsets.only(top: topPad, bottom: 124),
      physics: const BouncingScrollPhysics(),
      children: [
        OffroScreenHeader(
          eyebrow: 'Discover $cityLabel',
          title: 'Explore nearby',
          description:
              'Find independent businesses, useful services and local favourites around you.',
        ),
        // ── Search ──
        Padding(
          padding: const EdgeInsets.fromLTRB(OffroSpacing.gutter, 20, OffroSpacing.gutter, 0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: OffroColors.surface,
                borderRadius: BorderRadius.circular(OffroRadii.input),
                boxShadow: const [BoxShadow(color: Color(0x0F345148), blurRadius: 30, offset: Offset(0, 8))],
              ),
              child: Row(children: [
                const OffroIcon(OffroIcons.search, size: 18, color: Color(0x80345148)),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _search,
                    onChanged: (v) => setState(() => _query = v),
                    style: OffroText.body.copyWith(fontSize: 13, color: OffroColors.text),
                    cursorColor: OffroColors.primary,
                    decoration: InputDecoration(
                      hintText: 'Search stores, categories or areas',
                      hintStyle: OffroText.body.copyWith(fontSize: 13, color: OffroColors.secondarySolid),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      filled: false,
                      contentPadding: const EdgeInsets.symmetric(vertical: 15),
                    ),
                  ),
                ),
                if (_query.isNotEmpty)
                  GestureDetector(
                    onTap: () {
                      _search.clear();
                      setState(() => _query = '');
                    },
                    child: const Icon(Icons.close_rounded, size: 18, color: OffroColors.primary),
                  )
                else
                  const OffroIcon(OffroIcons.sliders, size: 17, color: OffroColors.primary),
              ]),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text('Searches business names, store categories and neighbourhoods.',
                style: OffroText.caption.copyWith(fontSize: 10, fontWeight: FontWeight.w400, color: OffroColors.textFaint)),
            ),
          ]),
        ),
        // ── Category chips (real store categories) ──
        if (categories.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: OffroSpacing.gutterH,
              child: Row(children: [
                for (final c in ['All', ...categories])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _FilterChip(
                      label: c,
                      selected: _category == c,
                      onTap: () => setState(() => _category = c),
                    ),
                  ),
              ]),
            ),
          ),
        // ── Explore by area (real areas from the stores) ──
        if (areas.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(top: 28),
            child: OffroSectionTitle(
              eyebrow: 'Explore by area',
              title: 'Neighbourhoods in $cityLabel',
            ),
          ),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: OffroSpacing.gutterH,
            child: Row(children: [
              for (final a in areas)
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: _AreaCard(
                    name: a.key,
                    count: a.value,
                    selected: _area == a.key,
                    onTap: () => setState(() => _area = _area == a.key ? null : a.key),
                  ),
                ),
            ]),
          ),
        ],
        // ── Results ──
        Padding(
          padding: const EdgeInsets.only(top: 32),
          child: OffroSectionTitle(
            eyebrow: _area == null ? 'Around you' : 'Neighbourhood',
            title: _area == null
                ? '${visible.length} ${visible.length == 1 ? 'place' : 'places'} nearby'
                : 'Stores in $_area',
          ),
        ),
        const SizedBox(height: 16),
        if (visible.isEmpty)
          Padding(
            padding: OffroSpacing.gutterH,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: OffroColors.borderStrong),
              ),
              child: Column(children: [
                Text('No matching stores yet',
                  style: OffroText.cardTitle.copyWith(fontSize: 13)),
                const SizedBox(height: 4),
                Text('Try another business name, category or neighbourhood.',
                  textAlign: TextAlign.center,
                  style: OffroText.caption.copyWith(fontSize: 11, fontWeight: FontWeight.w400, color: OffroColors.textSubtle)),
              ]),
            ),
          )
        else
          Padding(
            padding: OffroSpacing.gutterH,
            child: Column(children: [
              for (int i = 0; i < visible.length; i++) ...[
                if (i > 0) const SizedBox(height: 12),
                _storeRow(visible[i]),
              ],
            ]),
          ),
      ],
    );
  }

  Widget _storeRow(Map<String, dynamic> s) {
    final sid = _s(s['_id']).isNotEmpty ? _s(s['_id']) : _s(s['id']);
    final name = _s(s['store_name']);
    final category = _s(s['category']);
    final dist = _distance(s);
    final offer = _s(s['offer']);
    final rating = (s['rating'] as num?)?.toDouble() ?? 0.0;
    final meta = [if (category.isNotEmpty) category, if (dist.isNotEmpty) dist].join(' · ');

    return GestureDetector(
      key: sid.isEmpty ? null : ValueKey('explore_store_$sid'),
      onTap: () => widget.onStoreTap(s),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: OffroColors.surface,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          OffroNetworkImage(
            url: _image(s),
            width: 88,
            height: 88,
            borderRadius: BorderRadius.circular(18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SizedBox(
              height: 88,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(name, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: OffroText.cardTitle.copyWith(fontSize: 12)),
                      if (meta.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(meta, maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: OffroText.caption.copyWith(fontSize: 11, fontWeight: FontWeight.w400, color: OffroColors.textSubtle)),
                        ),
                    ]),
                  ),
                  GestureDetector(
                    onTap: () => _toggleFav(sid),
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 8, bottom: 8),
                      child: ValueListenableBuilder<bool>(
                        valueListenable: FavState.instance.storeListenable(sid),
                        builder: (_, fav, __) => OffroIcon(OffroIcons.heart,
                          size: 16, color: OffroColors.primary, filled: fav),
                      ),
                    ),
                  ),
                ]),
                const Spacer(),
                Row(children: [
                  if (offer.isNotEmpty)
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0x99B8D9C3),
                          borderRadius: OffroRadii.pillRadius,
                        ),
                        child: Text('Offer · $offer', maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: OffroText.caption.copyWith(fontSize: 10, fontWeight: FontWeight.w600, color: OffroColors.primary)),
                      ),
                    ),
                  const Spacer(),
                  if (rating > 0)
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      const OffroIcon(OffroIcons.star, size: 10, color: OffroColors.amber, filled: true),
                      const SizedBox(width: 4),
                      Text(rating.toStringAsFixed(1),
                        style: OffroText.caption.copyWith(fontSize: 10, fontWeight: FontWeight.w600)),
                    ]),
                ]),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}

/// Figma filter pill: solid primary when selected, white with a soft border otherwise.
class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _FilterChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? OffroColors.primary : OffroColors.surface,
          borderRadius: OffroRadii.pillRadius,
          border: selected ? null : Border.all(color: OffroColors.border),
        ),
        child: Text(label,
          style: OffroText.caption.copyWith(
            fontSize: 12, fontWeight: FontWeight.w500,
            color: selected ? Colors.white : OffroColors.text)),
      ),
    );
  }
}

class _AreaCard extends StatelessWidget {
  final String name;
  final int count;
  final bool selected;
  final VoidCallback onTap;
  const _AreaCard({required this.name, required this.count, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minWidth: 142),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? const Color(0x66B8D9C3) : OffroColors.surface,
          borderRadius: BorderRadius.circular(19),
          border: Border.all(color: selected ? OffroColors.primary : OffroColors.border),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 32, height: 32,
            alignment: Alignment.center,
            decoration: const BoxDecoration(color: Color(0xA6B8D9C3), shape: BoxShape.circle),
            child: const OffroIcon(OffroIcons.pin, size: 14, color: OffroColors.primary, filled: true),
          ),
          const SizedBox(height: 12),
          Text(name, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: OffroText.caption.copyWith(fontSize: 12, fontWeight: FontWeight.w600, color: OffroColors.text)),
          const SizedBox(height: 4),
          Text('$count ${count == 1 ? 'store' : 'stores'}',
            style: OffroText.caption.copyWith(fontSize: 10, fontWeight: FontWeight.w400, color: OffroColors.textSubtle)),
        ]),
      ),
    );
  }
}
