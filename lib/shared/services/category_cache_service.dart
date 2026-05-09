import 'dart:convert';

import 'package:doctor_store/shared/utils/categories_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CategoryCacheService {
  static final CategoryCacheService _instance =
      CategoryCacheService._internal();
  factory CategoryCacheService() => _instance;
  CategoryCacheService._internal();

  SharedPreferences? _prefs;

  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  Future<void> cacheCategories(List<AppCategoryConfig> categories) async {
    await init();
    final jsonList = categories.map((c) => c.toJson()).toList();
    await _prefs?.setString('cached_categories', jsonEncode(jsonList));
    await _prefs?.setInt(
      'categories_cache_timestamp',
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  Future<List<AppCategoryConfig>> getCachedCategories() async {
    await init();
    final cachedString = _prefs?.getString('cached_categories');
    if (cachedString == null || cachedString.isEmpty) {
      return <AppCategoryConfig>[];
    }

    try {
      final list = jsonDecode(cachedString) as List;
      return list
          .whereType<Map<String, dynamic>>()
          .map(AppCategoryConfig.fromJson)
          .toList();
    } catch (_) {
      return <AppCategoryConfig>[];
    }
  }

  Future<bool> isCacheValid(
      {Duration maxAge = const Duration(hours: 24)}) async {
    await init();
    final timestamp = _prefs?.getInt('categories_cache_timestamp');
    if (timestamp == null) return false;

    final cacheTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return DateTime.now().difference(cacheTime) < maxAge;
  }

  Future<void> clearCache() async {
    await init();
    await _prefs?.remove('cached_categories');
    await _prefs?.remove('categories_cache_timestamp');
  }
}
