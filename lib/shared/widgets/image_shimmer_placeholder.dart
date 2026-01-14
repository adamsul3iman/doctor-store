import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

/// Lightweight shimmer placeholder for images.
///
/// Used as a standard placeholder for network images across the app
/// to give an instant-loading feel without heavy layout cost.
class ShimmerImagePlaceholder extends StatelessWidget {
  final double? width;
  final double? height;

  const ShimmerImagePlaceholder({super.key, this.width, this.height});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: Container(
        width: width,
        height: height,
        color: Colors.grey.shade300,
      ),
    );
  }
}
