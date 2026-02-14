import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:doctor_store/features/product/domain/models/product_model.dart';

/// Model for recently viewed item with timestamp
class RecentlyViewedItem {
  final Product product;
  final DateTime viewedAt;

  RecentlyViewedItem({
    required this.product,
    required this.viewedAt,
  });

  Map<String, dynamic> toJson() => {
    'product': product.toJson(),
    'viewedAt': viewedAt.toIso8601String(),
  };

  factory RecentlyViewedItem.fromJson(Map<String, dynamic> json) => RecentlyViewedItem(
    product: Product.fromJson(json['product'] as Map<String, dynamic>),
    viewedAt: DateTime.parse(json['viewedAt'] as String),
  );
}

/// StateNotifier for managing recently viewed products
class RecentlyViewedNotifier extends StateNotifier<List<RecentlyViewedItem>> {
  static const String _storageKey = 'recently_viewed_v1';
  static const int _maxItems = 20; // Keep last 20 viewed products
  
  bool _initialized = false;

  RecentlyViewedNotifier() : super([]) {
    _loadFromStorage();
  }

  /// Load recently viewed from SharedPreferences
  Future<void> _loadFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? jsonString = prefs.getString(_storageKey);
      
      if (jsonString != null) {
        final List<dynamic> jsonList = jsonDecode(jsonString);
        final items = jsonList
            .map((json) => RecentlyViewedItem.fromJson(json as Map<String, dynamic>))
            .toList();
        
        // Sort by most recent first
        items.sort((a, b) => b.viewedAt.compareTo(a.viewedAt));
        
        state = items;
      }
      
      _initialized = true;
    } catch (e) {
      debugPrint('Error loading recently viewed: $e');
      _initialized = true;
    }
  }

  /// Save to SharedPreferences
  Future<void> _saveToStorage() async {
    if (!_initialized) return;
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = jsonEncode(state.map((item) => item.toJson()).toList());
      await prefs.setString(_storageKey, jsonString);
    } catch (e) {
      debugPrint('Error saving recently viewed: $e');
    }
  }

  /// Add product to recently viewed
  void addToRecentlyViewed(Product product) {
    // Remove if already exists (to move it to top)
    final existingIndex = state.indexWhere((item) => item.product.id == product.id);
    
    List<RecentlyViewedItem> newState;
    
    if (existingIndex != -1) {
      // Remove existing and add new at the beginning
      newState = List.from(state)..removeAt(existingIndex);
    } else {
      newState = List.from(state);
    }
    
    // Add new item at the beginning
    newState.insert(0, RecentlyViewedItem(
      product: product,
      viewedAt: DateTime.now(),
    ));
    
    // Keep only max items
    if (newState.length > _maxItems) {
      newState = newState.sublist(0, _maxItems);
    }
    
    state = newState;
    _saveToStorage();
  }

  /// Remove from recently viewed
  void removeFromRecentlyViewed(String productId) {
    state = state.where((item) => item.product.id != productId).toList();
    _saveToStorage();
  }

  /// Clear all recently viewed
  void clearRecentlyViewed() {
    state = [];
    _saveToStorage();
  }

  /// Check if product is in recently viewed
  bool isInRecentlyViewed(String productId) {
    return state.any((item) => item.product.id == productId);
  }

  /// Get recently viewed products (sorted by most recent)
  List<Product> get recentlyViewedProducts {
    return state.map((item) => item.product).toList();
  }

  /// Get count
  int get count => state.length;
}

// Provider for the notifier
final recentlyViewedProvider = StateNotifierProvider<RecentlyViewedNotifier, List<RecentlyViewedItem>>((ref) {
  return RecentlyViewedNotifier();
});

// Provider for just the products list (for watching)
final recentlyViewedProductsProvider = Provider<List<Product>>((ref) {
  return ref.watch(recentlyViewedProvider).map((item) => item.product).toList();
});

// Provider for count
final recentlyViewedCountProvider = Provider<int>((ref) {
  return ref.watch(recentlyViewedProvider).length;
});

// Provider to check if a product is in recently viewed
final isInRecentlyViewedProvider = Provider.family<bool, String>((ref, productId) {
  return ref.watch(recentlyViewedProvider).any((item) => item.product.id == productId);
});
