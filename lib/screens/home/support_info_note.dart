// lib/screens/home/support_info_note.dart
//
// The short "contact support to update your profile" message shown directly
// below the green identity block on BOTH the Customer and Merchant profile
// screens. Presentation only - no behaviour, no navigation.
import 'package:flutter/material.dart';

import '../../core/design/design.dart';
import '../../core/l10n/l10n.dart';

/// Exact wording required for the profile screens.
const String kProfileSupportNote =
    'Need to update your profile? Contact support, we will help you right away.';

class SupportInfoNote extends StatelessWidget {
  /// Outer spacing. The Customer profile passes its gutter padding; the Merchant
  /// profile sits inside a padded column and passes only vertical spacing.
  final EdgeInsetsGeometry padding;
  const SupportInfoNote({super.key, this.padding = const EdgeInsets.fromLTRB(OffroSpacing.gutter, 12, OffroSpacing.gutter, 0)});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: OffroColors.mintSoft,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          Container(
            width: 32, height: 32,
            alignment: Alignment.center,
            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
            child: const Icon(Icons.support_agent_rounded, size: 18, color: OffroColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              context.l10n.profileSupportNote,
              style: OffroText.caption.copyWith(
                fontSize: 12, fontWeight: FontWeight.w500, height: 1.4, color: OffroColors.primary),
            ),
          ),
        ]),
      ),
    );
  }
}
