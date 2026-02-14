import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:doctor_store/features/product/domain/models/product_model.dart';
import 'package:doctor_store/features/product/data/product_repository.dart';
import 'package:doctor_store/features/product/domain/models/similar_products_query.dart';

final productRepositoryProvider = Provider<ProductRepository>((ref) {
  return ProductRepository();
});

/// عدّاد مشاهدات المنتج (يشمل الزوّار غير المسجلين)
final productViewsProvider = FutureProvider.family<int, String>((ref, productId) async {
  final supabase = Supabase.instance.client;

  // نستخدم count() من Supabase v2 للحصول على عدد الصفوف فقط
  final response = await supabase
      .from('events')
      .select('id')
      .eq('name', 'product_view')
      .contains('props', {'id': productId})
      .count(CountOption.exact);

  // في حال فشل العد لأي سبب نعيد 0 بشكل آمن
  final count = response.count;
  return count;
});

/// تحميل منتجات فئة معيّنة مرة واحدة (أسرع للويب) مع كاش تلقائي من Riverpod.
final productsByCategoryProvider = FutureProvider.family<List<Product>, String>((ref, categoryId) async {
  final repo = ref.watch(productRepositoryProvider);
  return repo.fetchByCategory(categoryId: categoryId);
});

/// تحميل كل المنتجات مرة واحدة (أسرع للويب) مع كاش تلقائي من Riverpod.
final allProductsProvider = FutureProvider<List<Product>>((ref) async {
  final repo = ref.watch(productRepositoryProvider);
  return repo.fetchAll();
});

final similarProductsProvider = FutureProvider.family<List<Product>, SimilarProductsQuery>((ref, q) async {
  final repo = ref.watch(productRepositoryProvider);
  return repo.fetchSimilarSmart(
    categoryId: q.categoryId,
    excludeId: q.excludeId,
    limit: q.limit,
  );
});

/// تدفق لحظي لكل المنتجات مع دعم Realtime (INSERT/UPDATE/DELETE)
final allProductsStreamProvider = StreamProvider<List<Product>>((ref) {
  final supabase = Supabase.instance.client;

  final stream = supabase
      .from('products')
      .stream(primaryKey: ['id'])
      .eq('is_active', true) // فلترة المنتجات غير الفعّالة على مستوى قاعدة البيانات
      .order('created_at', ascending: false)
      // نكتفي بعدد معقول من أحدث المنتجات لتحسين الأداء في صفحة كل المنتجات
      .limit(200);

  return stream.map((rows) {
    return rows
        .map((row) => Product.fromJson(row))
        .toList();
  });
});

/// تدفق لحظي لمنتجات فئة معيّنة
final productsByCategoryStreamProvider =
    StreamProvider.family<List<Product>, String>((ref, categoryId) {
  final supabase = Supabase.instance.client;

  final stream = supabase
      .from('products')
      .stream(primaryKey: ['id'])
      .eq('is_active', true) // عرض المنتجات المفعّلة فقط
      .order('created_at', ascending: false);

  return stream.map((rows) {
    return rows
        .map((row) => Product.fromJson(row))
        .where((p) => p.category == categoryId) // فلترة على مستوى Dart حسب الفئة
        .toList();
  });
});

/// تدفق لحظي لمنتج واحد (لاستخدامه في صفحة التفاصيل)
final productByIdStreamProvider =
    StreamProvider.family<Product?, String>((ref, productId) {
  final supabase = Supabase.instance.client;

  final stream = supabase
      .from('products')
      .stream(primaryKey: ['id'])
      .eq('id', productId)
      .limit(1);

  return stream.map((rows) {
    if (rows.isEmpty) return null;
    return Product.fromJson(rows.first);
  });
});
