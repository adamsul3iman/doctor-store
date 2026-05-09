import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

/// إعدادات متقدمة لكاش الصور على Android
class ImageCacheConfig {
  static CacheManager? _cacheManager;

  /// Cache Manager مخصص بإعدادات محسّنة للـ Android
  static CacheManager get cacheManager {
    _cacheManager ??= CacheManager(
      Config(
        'doctor_store_image_cache',
        stalePeriod: const Duration(days: 7), // مدة صلاحية الكاش
        maxNrOfCacheObjects: 200, // عدد الصور المخزنة
        fileService: HttpFileService(),
      ),
    );
    return _cacheManager!;
  }

  /// تهيئة الكاش عند بدء التطبيق
  static Future<void> init() async {
    // تفريغ الكاش القديم إذا كان أكبر من 200MB
    await _cleanupOldCache();
  }

  /// تنظيف الكاش القديم
  static Future<void> _cleanupOldCache() async {
    try {
      final cacheDir = await getTemporaryDirectory();
      final imageCacheDir = Directory('${cacheDir.path}/libCachedImageData');

      if (await imageCacheDir.exists()) {
        int totalSize = 0;
        final files = await imageCacheDir.list().toList();

        for (final file in files) {
          if (file is File) {
            totalSize += await file.length();
          }
        }

        // إذا كان الكاش أكبر من 200MB، نمسح الأقدم
        if (totalSize > 200 * 1024 * 1024) {
          await cacheManager.emptyCache();
        }
      }
    } catch (_) {
      // Silent fail
    }
  }

  /// مسح الكاش كاملاً
  static Future<void> clearCache() async {
    await cacheManager.emptyCache();
    await DefaultCacheManager().emptyCache();
  }

  /// الحصول على حجم الكاش
  static Future<String> getCacheSize() async {
    try {
      final cacheDir = await getTemporaryDirectory();
      final imageCacheDir = Directory('${cacheDir.path}/libCachedImageData');

      if (!await imageCacheDir.exists()) return '0 MB';

      int totalSize = 0;
      await for (final file in imageCacheDir.list(recursive: true)) {
        if (file is File) {
          totalSize += await file.length();
        }
      }

      return '${(totalSize / (1024 * 1024)).toStringAsFixed(1)} MB';
    } catch (_) {
      return 'Unknown';
    }
  }
}
