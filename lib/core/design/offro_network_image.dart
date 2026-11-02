// lib/core/design/offro_network_image.dart
//
// OffrO network image (Figma redesign, Phase 1): rounded cover image with a
// shimmer placeholder, a calm fallback tile and an optional dark scrim for
// text/pills drawn on top. It reuses the existing image plumbing:
//   * resolveImageUrl / isDataImage  (core/utils/image_url.dart)
//   * decodeBase64ImageCached        (core/widgets/base64_image.dart)
//   * shimmerBox                     (core/widgets/shimmer_box.dart)
//   * cached_network_image           (already a dependency)
// so http(s) URLs, server-relative paths and base64 `data:image` values all
// behave exactly as they do elsewhere in the app.
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../utils/image_url.dart';
import '../widgets/base64_image.dart';
import '../widgets/shimmer_box.dart';
import 'offro_icons.dart';
import 'offro_tokens.dart';

class OffroNetworkImage extends StatelessWidget {
  final String? url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final Alignment alignment;
  /// Adds the design's dark bottom-to-top scrim over the image.
  final bool scrim;
  final Widget? placeholder;
  final Widget? errorWidget;

  const OffroNetworkImage({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.alignment = Alignment.center,
    this.scrim = false,
    this.placeholder,
    this.errorWidget,
  });

  Widget _fallback() {
    return errorWidget ??
        Container(
          width: width,
          height: height,
          color: OffroColors.mintSoft,
          child: const Center(child: OffroIcon(OffroIcons.store, size: 28, color: OffroColors.sage)),
        );
  }

  @override
  Widget build(BuildContext context) {
    final resolved = resolveImageUrl(url);
    Widget image;

    if (resolved.isEmpty) {
      image = _fallback();
    } else if (isDataImage(resolved)) {
      try {
        image = Image.memory(
          decodeBase64ImageCached(resolved),
          width: width,
          height: height,
          fit: fit,
          alignment: alignment,
          gaplessPlayback: true,
          errorBuilder: (_, __, ___) => _fallback(),
        );
      } catch (_) {
        image = _fallback();
      }
    } else {
      image = CachedNetworkImage(
        imageUrl: resolved,
        width: width,
        height: height,
        fit: fit,
        alignment: alignment,
        placeholder: (_, __) =>
            placeholder ?? shimmerBox(width: width, height: height),
        errorWidget: (_, __, ___) => _fallback(),
      );
    }

    if (scrim) {
      image = Stack(
        fit: StackFit.passthrough,
        children: [
          image,
          const Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Color(0x73000000), Color(0x00000000), Color(0x0D000000)],
                    stops: [0.0, 0.55, 1.0],
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    }

    if (borderRadius != null) {
      image = ClipRRect(borderRadius: borderRadius!, child: image);
    }
    return image;
  }
}
