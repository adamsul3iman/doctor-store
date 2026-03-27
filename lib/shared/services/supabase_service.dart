import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:doctor_store/features/product/domain/models/product_model.dart';

/// Helper function to parse product JSON in background isolate
/// This prevents UI jank when parsing large lists of products
List<Product> _parseProducts(List<dynamic> jsonList) {
  return jsonList.map((e) => Product.fromJson(e as Map<String, dynamic>)).toList();
}

class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();
  factory SupabaseService() => _instance;
  SupabaseService._internal();

  /// يرجع SupabaseClient إن كان مهيأ، أو null في بيئات مثل الاختبارات
  SupabaseClient? _getClientOrNull() {
    try {
      return Supabase.instance.client;
    } catch (_) {
      // في حال لم يتم استدعاء Supabase.initialize بعد (مثل بيئة الاختبار)
      return null;
    }
  }

  Future<List<Product>> getFeaturedProducts({
    required String excludeId,
    int limit = 6,
  }) async {
    final client = _getClientOrNull();
    if (client == null) {
      return <Product>[];
    }

    try {
      final response = await client
          .from('products')
          .select('id, title, price, old_price, image_url, category, sub_category_id, is_featured, is_flash_deal, is_active, created_at, options, gallery, variants, rating_average, rating_count, slug, short_description, tags')
          .eq('is_featured', true)
          .eq('is_active', true)
          .neq('id', excludeId)
          .order('created_at', ascending: false)
          .limit(limit);

      // Offload JSON parsing to background isolate to prevent UI blocking
      final products = await compute(_parseProducts, response as List<dynamic>);
      return products;
    } catch (_) {
      return <Product>[];
    }
  }

  Future<List<Product>> getLatestActiveProducts({
    required String excludeId,
    int limit = 6,
  }) async {
    final client = _getClientOrNull();
    if (client == null) {
      return <Product>[];
    }

    try {
      final response = await client
          .from('products')
          .select('id, title, price, old_price, image_url, category, sub_category_id, is_featured, is_flash_deal, is_active, created_at, options, gallery, variants, rating_average, rating_count, slug, short_description, tags')
          .eq('is_active', true)
          .neq('id', excludeId)
          .order('created_at', ascending: false)
          .limit(limit);

      // Offload JSON parsing to background isolate to prevent UI blocking
      final products = await compute(_parseProducts, response as List<dynamic>);
      return products;
    } catch (_) {
      return <Product>[];
    }
  }

  Future<List<Product>> getDiningProducts({int limit = 20}) async {
    final client = _getClientOrNull();
    if (client == null) {
      return <Product>[];
    }

    try {
      final response = await client
          .from('products')
          .select('id, title, price, old_price, image_url, category, sub_category_id, is_featured, is_flash_deal, is_active, created_at, options, gallery, variants, rating_average, rating_count, slug, short_description, tags')
          .eq('is_active', true)
          .order('created_at', ascending: false)
          .limit(limit);

      // Offload JSON parsing to background isolate to prevent UI blocking
      final products = await compute(_parseProducts, response as List<dynamic>);
      return products
          .where((p) => ['dining_table', 'furniture'].contains(p.category))
          .toList();
    } catch (_) {
      return <Product>[];
    }
  }

  Future<List<Product>> getFlashDealProducts({int limit = 20}) async {
    final client = _getClientOrNull();
    if (client == null) {
      return <Product>[];
    }

    try {
      final response = await client
          .from('products')
          .select('id, title, price, old_price, image_url, category, sub_category_id, is_featured, is_flash_deal, is_active, created_at, options, gallery, variants, rating_average, rating_count, slug, short_description, tags')
          .eq('is_flash_deal', true)
          .eq('is_active', true)
          .order('created_at', ascending: false)
          .limit(limit);

      // Offload JSON parsing to background isolate to prevent UI blocking
      final products = await compute(_parseProducts, response as List<dynamic>);
      return products;
    } catch (_) {
      return <Product>[];
    }
  }

  // 1. بث مباشر لأحدث المنتجات (تحديث فوري)
  Stream<List<Product>> getLatestProductsStream() {
    final client = _getClientOrNull();
    if (client == null) {
      // في الاختبارات أو في حال عدم التهيئة نرجع Stream فارغ بدلاً من كسر التطبيق
      return const Stream.empty();
    }

    try {
      return client
          .from('products')
          .stream(primaryKey: ['id']) // يجب تحديد المفتاح الأساسي
          .eq('is_active', true) // فلترة المنتجات غير الفعّالة مباشرة في Supabase
          .order('created_at', ascending: false)
          .limit(6)
          .map((data) => data
              .map((json) => Product.fromJson(json))
              .toList())
          .handleError((error, stackTrace) {
        // في حال انقطاع الانترنت أو خطأ من Supabase لا ننهار
      });
    } catch (_) {
      // في حالة استثناء متزامن (نادر) نرجع Stream فارغ
      return const Stream.empty();
    }
  }

  // 2. بث مباشر لقسم السفرة
  Stream<List<Product>> getDiningProductsStream() {
    // ملاحظة: stream في Supabase لا يدعم الفلترة المعقدة جداً مثل inFilter بمرونة عالية
    // لذلك سنجلب المنتجات ونفلترها، أو نستخدم معادلة أبسط.
    // هنا سنجلب الكل ونفلتر (مقبول لأن العدد محدود بـ limit)
    final client = _getClientOrNull();
    if (client == null) {
      return const Stream.empty();
    }

    try {
      return client
          .from('products')
          .stream(primaryKey: ['id'])
          .eq('is_active', true) // عرض المنتجات المفعّلة فقط
          .order('created_at', ascending: false)
          .limit(20) // نزيد العدد قليلاً لضمان وجود منتجات بعد الفلترة
          .map((data) {
            final products = data
                .map((json) => Product.fromJson(json))
                .toList();
            // الفلترة يدوياً هنا لضمان الدقة
            return products
                .where((p) =>
                    ['dining_table', 'furniture'].contains(p.category))
                .toList();
          })
          .handleError((error, stackTrace) {
        // في حال انقطاع الانترنت أو خطأ من Supabase لا ننهار
      });
    } catch (_) {
      return const Stream.empty();
    }
  }
  
  // دالة لجلب كل المنتجات مع ترحيل لتحسين الأداء
  Future<List<Product>> getAllProducts({
    int page = 0,
    int limit = 20,
  }) async {
    final client = _getClientOrNull();
    if (client == null) {
      return <Product>[];
    }

    try {
      final response = await client
            .from('products')
            .select('id, title, price, old_price, image_url, category, sub_category_id, is_featured, is_flash_deal, is_active, created_at, options, gallery, variants, rating_average, rating_count, slug, short_description, tags')
            .eq('is_active', true)
            .order('created_at', ascending: false)
            .range(page * limit, (page + 1) * limit - 1);
      // Offload JSON parsing to background isolate to prevent UI blocking
      final products = await compute(_parseProducts, response as List<dynamic>);
      return products;
    } catch (_) {
      // في حال انقطاع النت أو أي استثناء آخر نرجع قائمة فاضية
      return <Product>[];
    }
  }

  // دالة لجلب منتجات فئة معيّنة مع ترحيل لتحسين الأداء
  Future<List<Product>> getProductsByCategory({
    required String categoryId,
    int page = 0,
    int limit = 20,
  }) async {
    final client = _getClientOrNull();
    if (client == null) {
      return <Product>[];
    }

    try {
      final response = await client
          .from('products')
          .select('id, title, price, old_price, image_url, category, sub_category_id, is_featured, is_flash_deal, is_active, created_at, options, gallery, variants, rating_average, rating_count, slug, short_description, tags')
          .eq('is_active', true)
          .eq('category', categoryId)
          .order('created_at', ascending: false)
          .range(page * limit, (page + 1) * limit - 1);

      // Offload JSON parsing to background isolate to prevent UI blocking
      final products = await compute(_parseProducts, response as List<dynamic>);
      return products;
    } catch (_) {
      return <Product>[];
    }
  }

  // دالة لجلب منتجات مشابهة من نفس القسم
  Future<List<Product>> getSimilarProducts({
    required String categoryId,
    required String excludeId,
    int limit = 6,
  }) async {
    final client = _getClientOrNull();
    if (client == null) {
      return <Product>[];
    }

    try {
      final response = await client
            .from('products')
            .select('id, title, price, old_price, image_url, category, sub_category_id, is_featured, is_flash_deal, is_active, created_at, options, gallery, variants, rating_average, rating_count, slug, short_description, tags')
            .eq('category', categoryId)
            .eq('is_active', true)
            .neq('id', excludeId)
            .order('created_at', ascending: false)
            .limit(limit);
      // Offload JSON parsing to background isolate to prevent UI blocking
      final products = await compute(_parseProducts, response as List<dynamic>);
      return products;
    } catch (_) {
      return <Product>[];
    }
  }
}
