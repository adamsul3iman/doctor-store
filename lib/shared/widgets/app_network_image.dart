import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'package:doctor_store/shared/utils/image_url_helper.dart';
import 'package:doctor_store/shared/widgets/image_shimmer_placeholder.dart';

class AppNetworkImage extends StatelessWidget {
  final String url;
  final ImageVariant variant;
  final BoxFit fit;
  final Alignment alignment;
  final FilterQuality filterQuality;
  final Widget? placeholder;
  final Widget? errorWidget;
  final Duration fadeInDuration;
  final Duration fadeOutDuration;

  const AppNetworkImage({
    super.key,
    required this.url,
    required this.variant,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
    this.filterQuality = FilterQuality.low,
    this.placeholder,
    this.errorWidget,
    this.fadeInDuration = Duration.zero, // إزالة fade للسرعة
    this.fadeOutDuration = Duration.zero,
  });

  ({int width, int height}) _cacheSizeForVariant(ImageVariant v) {
    switch (v) {
      case ImageVariant.productCard:
      case ImageVariant.thumbnail:
        return (width: 300, height: 300);
      case ImageVariant.mattressCard:
        return (width: 420, height: 320);
      case ImageVariant.heroBanner:
        return (width: 800, height: 450);
      case ImageVariant.homeBanner:
        return (width: 800, height: 400);
      case ImageVariant.fullScreen:
        return (width: 800, height: 800);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (url.isEmpty) {
      return errorWidget ??
          const Icon(
            Icons.image_not_supported_outlined,
            color: Colors.grey,
          );
    }

    final optimizedUrl = buildOptimizedImageUrl(url, variant: variant);
    final cacheSize = _cacheSizeForVariant(variant);

    return CachedNetworkImage(
      imageUrl: optimizedUrl,
      fit: fit,
      alignment: alignment,
      filterQuality: filterQuality,
      memCacheWidth: cacheSize.width,
      memCacheHeight: cacheSize.height,
      maxHeightDiskCache: cacheSize.height,
      maxWidthDiskCache: cacheSize.width,
      fadeInDuration: fadeInDuration,
      fadeOutDuration: fadeOutDuration,
      placeholder: (context, _) => placeholder ?? const ShimmerImagePlaceholder(),
      errorWidget: (context, _, __) => errorWidget ??
          const Icon(
            Icons.image_not_supported_outlined,
            color: Colors.grey,
          ),
    );
  }
}
