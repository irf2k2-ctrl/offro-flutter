// lib/core/design/offro_bottom_nav.dart
//
// OffrO floating bottom navigation (Figma redesign, Phase 1).
//
// Customer: Home | Explore | Deals | Rewards | Profile
// Merchant: Home | Deals | Invoices | Activity | Profile
// Both use the same floating pill bar; the merchant variant only uses a
// slightly smaller icon/label, as in the design. The bar owns no routing -
// the screen passes [currentIndex] and handles [onTap].
import 'package:flutter/material.dart';

import 'offro_icons.dart';
import 'offro_tokens.dart';
import 'offro_typography.dart';

enum OffroNavVariant { customer, merchant }

class OffroNavItem {
  final String label;
  final OffroIconData icon;
  /// Fill the glyph while selected (the design fills only Home).
  final bool fillWhenActive;
  /// Optional custom widget for the icon slot (e.g. a profile avatar).
  /// Receives whether the item is selected.
  final Widget Function(bool active)? iconBuilder;

  const OffroNavItem({
    required this.label,
    required this.icon,
    this.fillWhenActive = false,
    this.iconBuilder,
  });
}

class OffroBottomNav extends StatelessWidget {
  final List<OffroNavItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;
  final OffroNavVariant variant;

  const OffroBottomNav({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onTap,
    this.variant = OffroNavVariant.customer,
  });

  /// Ready-made customer items in the approved order.
  static const List<OffroNavItem> customerItems = [
    OffroNavItem(label: 'Home', icon: OffroIcons.home, fillWhenActive: true),
    OffroNavItem(label: 'Explore', icon: OffroIcons.compass),
    OffroNavItem(label: 'Deals', icon: OffroIcons.tag),
    OffroNavItem(label: 'Rewards', icon: OffroIcons.gift),
    OffroNavItem(label: 'Profile', icon: OffroIcons.user),
  ];

  /// Ready-made merchant items.
  static const List<OffroNavItem> merchantItems = [
    OffroNavItem(label: 'Home', icon: OffroIcons.home, fillWhenActive: true),
    OffroNavItem(label: 'Deals', icon: OffroIcons.tag),
    OffroNavItem(label: 'Invoices', icon: OffroIcons.gift),
    OffroNavItem(label: 'Activity', icon: OffroIcons.clock),
    OffroNavItem(label: 'Profile', icon: OffroIcons.user),
  ];

  @override
  Widget build(BuildContext context) {
    final merchant = variant == OffroNavVariant.merchant;
    final double iconSize = merchant ? 18 : 19;

    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(
        OffroSpacing.navInset, 0, OffroSpacing.navInset, OffroSpacing.navInset),
      child: Container(
        height: OffroSpacing.navHeight,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: const Color(0xF2FFFFFF), // white @ 95%
          borderRadius: OffroRadii.navRadius,
          border: Border.all(color: OffroColors.borderSoft),
          boxShadow: OffroShadows.nav,
        ),
        child: Row(
          children: [
            for (var i = 0; i < items.length; i++)
              Expanded(
                child: _NavButton(
                  item: items[i],
                  active: i == currentIndex,
                  iconSize: iconSize,
                  onTap: () => onTap(i),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  final OffroNavItem item;
  final bool active;
  final double iconSize;
  final VoidCallback onTap;

  const _NavButton({
    required this.item,
    required this.active,
    required this.iconSize,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = active ? OffroColors.primary : const Color(0x4D000000); // black @ 30%
    return Semantics(
      button: true,
      selected: active,
      label: item.label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: OffroRadii.navRadius,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                item.iconBuilder != null
                    ? item.iconBuilder!(active)
                    : OffroIcon(item.icon, size: iconSize, color: color, filled: active && item.fillWhenActive),
                const SizedBox(height: 6),
                Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: OffroText.navLabel.copyWith(color: color),
                ),
              ],
            ),
            if (active)
              Positioned(
                top: 10,
                child: Container(
                  width: 20,
                  height: 2,
                  decoration: BoxDecoration(
                    color: OffroColors.primary,
                    borderRadius: OffroRadii.pillRadius,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
