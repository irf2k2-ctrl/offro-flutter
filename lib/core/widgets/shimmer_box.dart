// lib/core/widgets/shimmer_box.dart
//
// Shared shimmer placeholder used for the hero city image, admin banner and
// product/store loading skeletons. Extracted unchanged from main.dart
// (`_shimmerBox`). Reserves its final box size up front, so swapping it in
// for a flat box is a pure visual change, not a layout change.
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

Widget shimmerBox({double? width, double? height, BorderRadius? borderRadius}) {
  return Shimmer.fromColors(
    baseColor: const Color(0xFFE3E9E6),
    highlightColor: const Color(0xFFF3F6F4),
    child: Container(
      width: width,
      height: height,
      decoration: BoxDecoration(color: const Color(0xFFE3E9E6), borderRadius: borderRadius),
    ),
  );
}
