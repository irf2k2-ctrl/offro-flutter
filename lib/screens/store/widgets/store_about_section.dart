// lib/screens/store/widgets/store_about_section.dart
import 'package:flutter/material.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/store_hours.dart';

class StoreAboutSection extends StatefulWidget {
  final Map<String, dynamic> store;
  const StoreAboutSection({super.key, required this.store});
  @override
  State<StoreAboutSection> createState() => _StoreAboutSectionState();
}

class _StoreAboutSectionState extends State<StoreAboutSection> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final desc       = (widget.store['about']?.toString().isNotEmpty == true
        ? widget.store['about']?.toString()
        : widget.store['description']?.toString()) ?? '';
    final tags       = (widget.store['tags'] as List?)
            ?.map((t) => t.toString()).toList() ?? [];
    final openTime   = widget.store['open_time']?.toString()  ?? '';
    final closeTime  = widget.store['close_time']?.toString() ?? '';
    final address    = widget.store['address']?.toString()    ?? '';
    final area       = widget.store['area']?.toString()       ?? '';
    final city       = widget.store['city']?.toString()       ?? '';
    final phone      = widget.store['phone']?.toString()      ?? '';
    final costForTwo = widget.store['cost_for_two']?.toString() ?? '';
    final dineIn     = widget.store['dine_in'] == true;

    final locationText = [area, city]
        .where((x) => x.isNotEmpty).join(', ');
    final displayAddr  = address.isNotEmpty
        ? address
        : locationText;

    final hasContent = desc.isNotEmpty || openTime.isNotEmpty ||
        displayAddr.isNotEmpty || phone.isNotEmpty ||
        tags.isNotEmpty || costForTwo.isNotEmpty || dineIn;
    if (!hasContent) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),

            // Description
            if (desc.isNotEmpty) ...[
              AnimatedCrossFade(
                firstChild: Text(desc,
                    style: const TextStyle(
                        color: kMuted, fontSize: 13, height: 1.7),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis),
                secondChild: Text(desc,
                    style: const TextStyle(
                        color: kMuted, fontSize: 13, height: 1.7)),
                crossFadeState: _expanded
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                duration: const Duration(milliseconds: 250),
              ),
              if (desc.length > 120) ...[
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: () => setState(() => _expanded = !_expanded),
                  child: Text(
                    _expanded ? 'Show less' : 'Read more →',
                    style: const TextStyle(
                        color: kPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w700),
                  ),
                ),
              ],
              const SizedBox(height: 16),
            ],

            // ── Info rows (plain, no arrows) ──────────────────
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: kBorder, width: 1),
              ),
              child: Column(children: [
                // Open / Close — FIX: this used to hard-code the green dot
                // + "Open" text with no real time check at all, which is why
                // it could show "Open" here while the header badge (which
                // DID check the time) correctly showed "Closed" for the same
                // store. Now both use the same computeStoreOpenStatus() helper.
                if (openTime.isNotEmpty || closeTime.isNotEmpty)
                  Builder(builder: (_) {
                    final status = computeStoreOpenStatus(openTime, closeTime);
                    final bool isOpen = status?.isOpen ?? true;
                    final String sub  = status?.subLabel ?? '';
                    final Color dotColor = isOpen ? const Color(0xFF27AE60) : const Color(0xFFc0392b);
                    return _infoRow(
                      icon: Icons.access_time_rounded,
                      isFirst: true,
                      child: Row(children: [
                        Container(
                          width: 7, height: 7,
                          decoration: BoxDecoration(
                            color: dotColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(isOpen ? 'Open' : 'Closed',
                          style: TextStyle(
                            color: dotColor,
                            fontSize: 13,
                            fontWeight: FontWeight.w700)),
                        if (sub.isNotEmpty) ...[
                          const Text(' · ',
                            style: TextStyle(
                                color: kMuted, fontSize: 13)),
                          Text(sub,
                            style: const TextStyle(
                                color: kMuted,
                                fontSize: 13)),
                        ],
                      ]),
                    );
                  }),

                // Address — plain, no arrow
                if (displayAddr.isNotEmpty)
                  _infoRow(
                    icon: Icons.location_on_outlined,
                    isFirst: openTime.isEmpty && closeTime.isEmpty,
                    child: Text(displayAddr,
                      style: const TextStyle(
                          color: kText, fontSize: 13),
                    ),
                  ),

                // Phone — plain, no arrow
                if (phone.isNotEmpty)
                  _infoRow(
                    icon: Icons.phone_outlined,
                    isFirst: openTime.isEmpty &&
                        closeTime.isEmpty &&
                        displayAddr.isEmpty,
                    child: Text(phone,
                      style: const TextStyle(
                          color: kText, fontSize: 13),
                    ),
                  ),

                // Cost for two
                if (costForTwo.isNotEmpty)
                  _infoRow(
                    icon: Icons.currency_rupee_rounded,
                    isFirst: false,
                    child: Text('₹$costForTwo for two',
                      style: const TextStyle(
                          color: kText, fontSize: 13)),
                  ),

                // Dine-in
                if (dineIn)
                  _infoRow(
                    icon: Icons.restaurant_rounded,
                    isFirst: false,
                    child: const Text('Dine-in available',
                      style: TextStyle(
                          color: kText, fontSize: 13)),
                  ),
              ]),
            ),

            // Tags
            if (tags.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: tags.map((t) => Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: kLight.withValues(alpha: .5),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: kAccent.withValues(alpha: .4)),
                  ),
                  child: Text('#$t',
                    style: const TextStyle(
                        color: kPrimary,
                        fontSize: 11,
                        fontWeight: FontWeight.w600)),
                )).toList(),
              ),
            ],
          ]),
    );
  }

  Widget _infoRow({
    required IconData icon,
    required Widget child,
    required bool isFirst,
  }) =>
      Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          border: isFirst
              ? null
              : const Border(
                  top: BorderSide(color: kBorder, width: 1)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: kMuted, size: 16),
            const SizedBox(width: 12),
            Expanded(child: child),
            // NO arrow icon — removed per mockup
          ],
        ),
      );
}
