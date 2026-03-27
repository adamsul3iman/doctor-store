import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:doctor_store/shared/services/category_cache_service.dart';
import 'package:doctor_store/shared/services/network_service.dart';
import 'package:doctor_store/shared/utils/categories_provider.dart';

class CategoriesState {
  final List<AppCategoryConfig> categories;
  final bool isLoading;
  final bool isOffline;
  final String? errorMessage;
  final bool hasError;

  const CategoriesState({
    this.categories = const <AppCategoryConfig>[],
    this.isLoading = false,
    this.isOffline = false,
    this.errorMessage,
    this.hasError = false,
  });

  CategoriesState copyWith({
    List<AppCategoryConfig>? categories,
    bool? isLoading,
    bool? isOffline,
    String? errorMessage,
    bool? hasError,
  }) {
    return CategoriesState(
      categories: categories ?? this.categories,
      isLoading: isLoading ?? this.isLoading,
      isOffline: isOffline ?? this.isOffline,
      errorMessage: errorMessage,
      hasError: hasError ?? this.hasError,
    );
  }
}

class CategoriesNotifier extends StateNotifier<CategoriesState> {
  final CategoryCacheService _cache;
  final NetworkService _network;

  CategoriesNotifier()
      : _cache = CategoryCacheService(),
        _network = NetworkService(),
        super(const CategoriesState(isLoading: true)) {
    _network.init();
    loadCategories();
  }

  Future<void> loadCategories() async {
    state = state.copyWith(isLoading: true, hasError: false, errorMessage: null);

    try {
      SupabaseClient? supabase;
      try {
        supabase = Supabase.instance.client;
      } catch (_) {
        supabase = null;
      }

      if (supabase != null) {
        final data = await supabase
            .from('categories')
            .select('id,name,subtitle,color_value,icon_name,is_active,sort_order')
            .eq('is_active', true)
            .order('sort_order', ascending: true);

        final cats = data
            .whereType<Map<String, dynamic>>()
            .map(AppCategoryConfig.fromMap)
            .toList();

        if (cats.isNotEmpty) {
          await _cache.cacheCategories(cats);
          state = CategoriesState(
            categories: cats,
            isLoading: false,
            isOffline: false,
            hasError: false,
          );
          return;
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Error loading categories: $e');
    }

    final cached = await _cache.getCachedCategories();
    final isConnected = _network.isConnected;

    if (cached.isNotEmpty) {
      state = CategoriesState(
        categories: cached,
        isLoading: false,
        isOffline: !isConnected,
        hasError: !isConnected,
        errorMessage: isConnected
            ? null
            : 'لا يوجد اتصال بالإنترنت. يتم عرض الأقسام المخزنة مؤقتاً.',
      );
    } else {
      state = CategoriesState(
        categories: const <AppCategoryConfig>[],
        isLoading: false,
        isOffline: !isConnected,
        hasError: true,
        errorMessage: 'تعذر تحميل الأقسام. يرجى التحقق من الاتصال بالإنترنت.',
      );
    }
  }

  Future<void> retry() async {
    await loadCategories();
  }

  @override
  void dispose() {
    _network.dispose();
    super.dispose();
  }
}

final cachedCategoriesProvider =
    StateNotifierProvider<CategoriesNotifier, CategoriesState>((ref) {
  return CategoriesNotifier();
});
