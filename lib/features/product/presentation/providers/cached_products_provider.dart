import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:doctor_store/features/product/domain/models/product_model.dart';
import 'package:doctor_store/shared/services/supabase_service.dart';
import 'package:doctor_store/shared/services/product_cache_service.dart';
import 'package:doctor_store/shared/services/network_service.dart';

/// حالة تحميل المنتجات مع دعم الكاش
class ProductsState {
  final List<Product> products;
  final bool isLoading;
  final bool isOffline;
  final String? errorMessage;
  final bool hasError;

  const ProductsState({
    this.products = const [],
    this.isLoading = false,
    this.isOffline = false,
    this.errorMessage,
    this.hasError = false,
  });

  ProductsState copyWith({
    List<Product>? products,
    bool? isLoading,
    bool? isOffline,
    String? errorMessage,
    bool? hasError,
  }) {
    return ProductsState(
      products: products ?? this.products,
      isLoading: isLoading ?? this.isLoading,
      isOffline: isOffline ?? this.isOffline,
      errorMessage: errorMessage,
      hasError: hasError ?? this.hasError,
    );
  }
}

/// Notifier يدير المنتجات مع دعم الكاش والعمل بدون إنترنت
class ProductsNotifier extends StateNotifier<ProductsState> {
  final SupabaseService _service;
  final ProductCacheService _cache;
  final NetworkService _network;

  ProductsNotifier()
      : _service = SupabaseService(),
        _cache = ProductCacheService(),
        _network = NetworkService(),
        super(const ProductsState(isLoading: true)) {
    _network.init();
    loadProducts();
  }

  /// تحميل المنتجات مع دعم الكاش
  Future<void> loadProducts() async {
    state = state.copyWith(isLoading: true, hasError: false, errorMessage: null);

    try {
      // محاولة جلب من Supabase
      final products = await _service.getAllProducts();

      if (products.isNotEmpty) {
        // حفظ في الكاش
        await _cache.cacheProducts(products);
        state = ProductsState(
          products: products,
          isLoading: false,
          isOffline: false,
          hasError: false,
        );
        return;
      }
    } catch (e) {
      // خطأ في الاتصال - نحاول الكاش
      if (kDebugMode) debugPrint('Error loading products: $e');
    }

    // إذا فشل الاتصال، استخدم الكاش
    final cachedProducts = await _cache.getCachedProducts();
    final isConnected = _network.isConnected;

    if (cachedProducts.isNotEmpty) {
      state = ProductsState(
        products: cachedProducts,
        isLoading: false,
        isOffline: !isConnected,
        hasError: !isConnected,
        errorMessage: isConnected ? null : 'لا يوجد اتصال بالإنترنت. يتم عرض المنتجات المخزنة مؤقتاً.',
      );
    } else {
      state = ProductsState(
        products: [],
        isLoading: false,
        isOffline: !isConnected,
        hasError: true,
        errorMessage: 'تعذر تحميل المنتجات. يرجى التحقق من الاتصال بالإنترنت.',
      );
    }
  }

  /// إعادة المحاولة
  Future<void> retry() async {
    await loadProducts();
  }

  @override
  void dispose() {
    _network.dispose();
    super.dispose();
  }
}

/// Provider للمنتجات مع دعم الكاش
final cachedProductsProvider = StateNotifierProvider<ProductsNotifier, ProductsState>((ref) {
  return ProductsNotifier();
});
