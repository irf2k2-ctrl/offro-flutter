// lib/core/design/offro_states.dart
//
// OffrO empty and error states (Figma redesign, Phase 1). The prototype only
// shows empty states; the error state follows the same visual language
// (round tinted icon, short title, muted message, optional action).
import 'package:flutter/material.dart';

import 'offro_button.dart';
import 'offro_icons.dart';
import 'offro_tokens.dart';
import 'offro_typography.dart';

class _StateBody extends StatelessWidget {
  final OffroIconData icon;
  final Color iconBackground;
  final Color iconColor;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _StateBody({
    required this.icon,
    required this.iconBackground,
    required this.iconColor,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(color: iconBackground, shape: BoxShape.circle),
              child: Center(child: OffroIcon(icon, size: 24, color: iconColor)),
            ),
            const SizedBox(height: 20),
            Text(title, textAlign: TextAlign.center,
                style: OffroText.cardTitle.copyWith(fontSize: 18)),
            if (message != null) ...[
              const SizedBox(height: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 260),
                child: Text(message!, textAlign: TextAlign.center,
                    style: OffroText.bodySmall.copyWith(color: OffroColors.textSubtle, height: 1.6)),
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 20),
              OffroButton.small(label: actionLabel!, onPressed: onAction),
            ],
          ],
        ),
      ),
    );
  }
}

/// "Nothing here yet" state, e.g. "You're all caught up".
class OffroEmptyState extends StatelessWidget {
  final OffroIconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const OffroEmptyState({
    super.key,
    this.icon = OffroIcons.bell,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return _StateBody(
      icon: icon,
      iconBackground: OffroColors.mintSoft,
      iconColor: OffroColors.primary,
      title: title,
      message: message,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }
}

/// "Something went wrong" state with an optional Retry action.
class OffroErrorState extends StatelessWidget {
  final String title;
  final String? message;
  final VoidCallback? onRetry;
  final String retryLabel;

  const OffroErrorState({
    super.key,
    this.title = "Couldn't load this",
    this.message = 'Check your connection and try again.',
    this.onRetry,
    this.retryLabel = 'Try again',
  });

  @override
  Widget build(BuildContext context) {
    return _StateBody(
      icon: OffroIcons.clock,
      iconBackground: const Color(0xFFF7E1DA),
      iconColor: OffroColors.error,
      title: title,
      message: message,
      actionLabel: onRetry == null ? null : retryLabel,
      onAction: onRetry,
    );
  }
}
