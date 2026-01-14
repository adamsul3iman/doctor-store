import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:doctor_store/features/product/domain/models/product_model.dart';

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
  
  // دالة لجلب كل المنتجات (نحتاجها لصفحة الكل)
  Future<List<Product>> getAllProducts() async {
    final client = _getClientOrNull();
    if (client == null) {
      return <Product>[];
    }

    try {
      final response = await client
            .from('products')
            .select()
            .eq('is_active', true)
            .order('created_at', ascending: false);
      return (response as List).map((e) => Product.fromJson(e)).toList();
    } catch (_) {
      // في حال انقطاع النت أو أي استثناء آخر نرجع قائمة فاضية
      return <Product>[];
    }
  }
}
