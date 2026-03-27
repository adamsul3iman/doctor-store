import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:doctor_store/shared/utils/image_url_helper.dart';
import 'package:doctor_store/shared/services/image_cache_config.dart';

/// خدمة تحميل الصور مسبقاً للأداء الأفضل
class ImagePreloadService {
  static final ImagePreloadService _instance = ImagePreloadService._internal();
  factory ImagePreloadService() => _instance;
  ImagePreloadService._internal();

  final Set<String> _preloadedUrls = {};

  /// تحميل صورة واحدة مسبقاً
  Future<void> preloadImage(BuildContext context, String url, ImageVariant variant) {
    if (url.isEmpty || _preloadedUrls.contains(url)) return Future.value();
    
    _preloadedUrls.add(url);
    final optimizedUrl = buildOptimizedImageUrl(url, variant: variant);
    
    return precacheImage(
      CachedNetworkImageProvider(
        optimizedUrl,
        cacheManager: ImageCacheConfig.cacheManager,
      ),
      context,
    );
  }

  /// تحميل قائمة صور مسبقاً (للمنتجات في القائمة)
  Future<void> preloadImages(
    BuildContext context,
    List<String> urls,
    ImageVariant variant, {
    int maxConcurrent = 3,
  }) async {
    final validUrls = urls
        .where((url) => url.isNotEmpty && !_preloadedUrls.contains(url))
        .take(10) // تحميل أول 10 صور فقط
        .toList();

    if (validUrls.isEmpty) return;

    // تحميل متزامن محدود
    for (var i = 0; i < validUrls.length; i += maxConcurrent) {
      final batch = validUrls.skip(i).take(maxConcurrent).toList();
      await Future.wait(
        batch.map((url) => preloadImage(context, url, variant)),
      );
    }
  }

  /// مسح قائمة التحميل المسبق
  void clearPreloadedCache() {
    _preloadedUrls.clear();
  }
}
