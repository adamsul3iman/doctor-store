import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:doctor_store/shared/utils/image_url_helper.dart';
import 'package:doctor_store/shared/widgets/image_shimmer_placeholder.dart';
import 'package:doctor_store/shared/services/image_cache_config.dart';

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
    this.fadeInDuration = Duration.zero,
    this.fadeOutDuration = Duration.zero,
  });

  /// Web-optimized cache sizes to reduce memory usage on Flutter Web
  ({int width, int height}) _cacheSizeForVariant(ImageVariant v) {
    // Smaller sizes for web to prevent memory spikes
    if (kIsWeb) {
      switch (v) {
        case ImageVariant.productCard:
        case ImageVariant.thumbnail:
          return (width: 150, height: 150); // Reduced from 300x300 for web
        case ImageVariant.mattressCard:
          return (width: 250, height: 200); // Reduced from 420x320 for web
        case ImageVariant.heroBanner:
          return (width: 600, height: 340); // Reduced from 800x450 for web
        case ImageVariant.homeBanner:
          return (width: 600, height: 300); // Reduced from 800x400 for web
        case ImageVariant.fullScreen:
          return (width: 800, height: 800); // Reduced from 1200x1200 for web
      }
    }
    
    // Mobile sizes (larger for retina displays)
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
        return (width: 1200, height: 1200);
    }
  }

  /// Get clean image URL without transformation parameters.
  /// Server-side transformations removed due to 400 errors and plan limitations.
  String _getOptimizedUrl(String originalUrl, ImageVariant variant) {
    // Just pass through to the helper which now returns clean URLs
    return buildOptimizedImageUrl(originalUrl, variant: variant);
  }

  @override
  Widget build(BuildContext context) {
    // Handle empty URL with smooth error fallback
    if (url.isEmpty) {
      return _buildErrorWidget();
    }

    final optimizedUrl = _getOptimizedUrl(url, variant);
    final cacheSize = _cacheSizeForVariant(variant);

    // For web: use smaller cache and lower filter quality to save memory
    final effectiveFilterQuality = kIsWeb 
        ? FilterQuality.low 
        : filterQuality;

    return CachedNetworkImage(
      imageUrl: optimizedUrl,
      cacheManager: kIsWeb ? null : ImageCacheConfig.cacheManager, // Use default on web
      fit: fit,
      alignment: alignment,
      filterQuality: effectiveFilterQuality,
      // Memory cache constraints - critical for web performance
      memCacheWidth: cacheSize.width,
      memCacheHeight: cacheSize.height,
      // Disk cache constraints for web to prevent storage bloat
      maxHeightDiskCache: kIsWeb ? cacheSize.height : null,
      maxWidthDiskCache: kIsWeb ? cacheSize.width : null,
      // Smooth fade animations
      fadeInDuration: kIsWeb ? const Duration(milliseconds: 100) : fadeInDuration,
      fadeOutDuration: kIsWeb ? const Duration(milliseconds: 50) : fadeOutDuration,
      // Placeholder with shimmer effect
      placeholder: (context, _) => placeholder ?? const ShimmerImagePlaceholder(),
      // Error handling with retry capability
      errorWidget: (context, url, error) {
        debugPrint('Image load error for $url: $error');
        return errorWidget ?? _buildErrorWidget();
      },
    );
  }

  /// Build consistent error widget with fallback UI
  Widget _buildErrorWidget() {
    return Container(
      color: Colors.grey[100],
      child: Center(
        child: Icon(
          Icons.image_not_supported_outlined,
          color: Colors.grey[400],
          size: 24,
        ),
      ),
    );
  }
}
