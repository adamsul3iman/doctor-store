import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

/// Standard placeholder for network images.
///
/// Notes:
/// - Shimmer looks nice but can be expensive when many images are loading (especially on Web).
/// - We automatically fall back to a static placeholder when animations are disabled or on Web.
class ShimmerImagePlaceholder extends StatelessWidget {
  final double? width;
  final double? height;

  /// Force-enable shimmer (default: true).
  ///
  /// Even when true, shimmer will be disabled automatically when:
  /// - `kIsWeb == true`
  /// - `MediaQuery.disableAnimations == true`
  final bool enableShimmer;

  const ShimmerImagePlaceholder({
    super.key,
    this.width,
    this.height,
    this.enableShimmer = true,
  });

  @override
  Widget build(BuildContext context) {
    final bool shouldAnimate =
        enableShimmer && !kIsWeb && !MediaQuery.of(context).disableAnimations;

    final placeholder = Container(
      width: width,
      height: height,
      color: Colors.grey.shade300,
    );

    if (!shouldAnimate) return placeholder;

    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: placeholder,
    );
  }
}
