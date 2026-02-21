import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:doctor_store/features/product/domain/models/product_model.dart';

/// خدمة التخزين المؤقت للمنتجات (للعمل بدون إنترنت)
class ProductCacheService {
  static final ProductCacheService _instance = ProductCacheService._internal();
  factory ProductCacheService() => _instance;
  ProductCacheService._internal();

  SharedPreferences? _prefs;

  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  /// حفظ المنتجات في الذاكرة المحلية
  Future<void> cacheProducts(List<Product> products) async {
    await init();
    final productsJson = products.map((p) => p.toJson()).toList();
    await _prefs?.setString('cached_products', jsonEncode(productsJson));
    await _prefs?.setInt('cache_timestamp', DateTime.now().millisecondsSinceEpoch);
  }

  /// استرجاع المنتجات من الذاكرة المحلية
  Future<List<Product>> getCachedProducts() async {
    await init();
    final cachedString = _prefs?.getString('cached_products');
    if (cachedString == null || cachedString.isEmpty) {
      return [];
    }

    try {
      final productsJson = jsonDecode(cachedString) as List;
      return productsJson.map((json) => Product.fromJson(json)).toList();
    } catch (_) {
      return [];
    }
  }

  /// التحقق من صلاحية الكاش (أقل من 24 ساعة)
  Future<bool> isCacheValid({Duration maxAge = const Duration(hours: 24)}) async {
    await init();
    final timestamp = _prefs?.getInt('cache_timestamp');
    if (timestamp == null) return false;

    final cacheTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return DateTime.now().difference(cacheTime) < maxAge;
  }

  /// مسح الكاش
  Future<void> clearCache() async {
    await init();
    await _prefs?.remove('cached_products');
    await _prefs?.remove('cache_timestamp');
  }
}
