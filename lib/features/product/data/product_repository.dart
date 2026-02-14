import 'package:doctor_store/features/product/domain/models/product_model.dart';
import 'package:doctor_store/shared/services/supabase_service.dart';

class ProductRepository {
  final SupabaseService _service;

  ProductRepository({SupabaseService? service}) : _service = service ?? SupabaseService();

  Future<List<Product>> fetchAll({int limit = 200}) async {
    final items = await _service.getAllProducts();
    if (items.length <= limit) return items;
    return items.take(limit).toList();
  }

  Future<List<Product>> fetchByCategory({required String categoryId, int limit = 200}) {
    return _service.getProductsByCategory(categoryId: categoryId, limit: limit);
  }

  Future<List<Product>> fetchSimilar({
    required String categoryId,
    required String excludeId,
    int limit = 6,
  }) {
    return _service.getSimilarProducts(
      categoryId: categoryId,
      excludeId: excludeId,
      limit: limit,
    );
  }

  Future<List<Product>> fetchSimilarSmart({
    required String categoryId,
    required String excludeId,
    int limit = 6,
  }) async {
    final byCategory = await fetchSimilar(
      categoryId: categoryId,
      excludeId: excludeId,
      limit: limit,
    );
    if (byCategory.isNotEmpty) return byCategory;

    final featured = await _service.getFeaturedProducts(
      excludeId: excludeId,
      limit: limit,
    );
    if (featured.isNotEmpty) return featured;

    return _service.getLatestActiveProducts(
      excludeId: excludeId,
      limit: limit,
    );
  }
}
