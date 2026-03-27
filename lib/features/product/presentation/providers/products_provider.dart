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

/// تحميل كل المنتجات مرة واحدة (أسرع للويب) - تم تحويله من StreamProvider إلى FutureProvider
/// للاستخدام في صفحات الكاتالوج حيث لا نحتاج تحديثات فورية
final allProductsStreamProvider = FutureProvider<List<Product>>((ref) async {
  final supabase = Supabase.instance.client;

  final response = await supabase
      .from('products')
      .select('id, title, price, old_price, image_url, category, sub_category_id, is_featured, is_flash_deal, is_active, created_at, options, gallery, variants, rating_average, rating_count, slug, short_description, tags')
      .eq('is_active', true)
      .order('created_at', ascending: false)
      .limit(200);

  return (response as List)
      .map((row) => Product.fromJson(row))
      .toList();
});

/// تدفق لحظي لكل المنتجات - للوحة التحكم فقط (Admin)
/// يستخدم للتحديثات الفورية في لوحة الإدارة
final allProductsAdminStreamProvider = StreamProvider<List<Product>>((ref) {
  final supabase = Supabase.instance.client;

  final stream = supabase
      .from('products')
      .stream(primaryKey: ['id'])
      .eq('is_active', true)
      .order('created_at', ascending: false)
      .limit(200);

  return stream.map((rows) {
    return rows
        .map((row) => Product.fromJson(row))
        .toList();
  });
});

/// تحميل منتجات فئة معيّنة مرة واحدة (أسرع للويب) - تم تحويله من StreamProvider إلى FutureProvider
/// لتحسين الأداء على الويب حيث لا نحتاج إلى تحديثات فورية للكاتالوج
final productsByCategoryStreamProvider =
    FutureProvider.family<List<Product>, String>((ref, categoryId) async {
  final supabase = Supabase.instance.client;
  
  final response = await supabase
      .from('products')
      .select('id, title, price, old_price, image_url, category, sub_category_id, is_featured, is_flash_deal, is_active, created_at, options, gallery, variants, rating_average, rating_count, slug, short_description, tags')
      .eq('is_active', true)
      .eq('category', categoryId)
      .order('created_at', ascending: false);
  
  return (response as List)
      .map((row) => Product.fromJson(row))
      .toList();
});

/// تدفق لحظي لمنتجات فئة معيّنة - للوحة التحكم فقط (Admin)
/// يستخدم فقط عند الحاجة لتحديثات فورية في لوحة الإدارة
final productsByCategoryAdminStreamProvider =
    StreamProvider.family<List<Product>, String>((ref, categoryId) {
  final supabase = Supabase.instance.client;

  final stream = supabase
      .from('products')
      .stream(primaryKey: ['id'])
      .eq('is_active', true)
      .order('created_at', ascending: false);

  return stream.map((rows) {
    return rows
        .map((row) => Product.fromJson(row))
        .where((p) => p.category == categoryId)
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
