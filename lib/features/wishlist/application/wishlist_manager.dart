import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:doctor_store/features/product/domain/models/product_model.dart';

// ================== الموديل (WishlistItem) ==================
class WishlistItem {
  final Product product;
  final DateTime addedAt;

  WishlistItem({
    required this.product,
    DateTime? addedAt,
  }) : addedAt = addedAt ?? DateTime.now();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WishlistItem &&
          runtimeType == other.runtimeType &&
          product.id == other.product.id;

  @override
  int get hashCode => product.id.hashCode;

  Map<String, dynamic> toJson() {
    return {
      'productId': product.id,
      'addedAt': addedAt.toIso8601String(),
      'productData': product.toJson(),
    };
  }

  factory WishlistItem.fromJson(Map<String, dynamic> json) {
    return WishlistItem(
      product: Product.fromJson(json['productData']),
      addedAt: DateTime.parse(json['addedAt']),
    );
  }
}

// ================== البروفايدر ==================

final wishlistProvider = StateNotifierProvider<WishlistNotifier, List<WishlistItem>>((ref) {
  return WishlistNotifier();
});

final wishlistCountProvider = Provider<int>((ref) {
  return ref.watch(wishlistProvider).length;
});

final isInWishlistProvider = Provider.family<bool, String>((ref, productId) {
  final wishlist = ref.watch(wishlistProvider);
  return wishlist.any((item) => item.product.id == productId);
});

// ================== الـ Notifier ==================

class WishlistNotifier extends StateNotifier<List<WishlistItem>> {
  static const String _storageKey = 'wishlist_items';
  bool _initialized = false;

  WishlistNotifier() : super([]) {
    _loadWishlist();
  }

  Future<void> _loadWishlist() async {
    if (_initialized) return;
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_storageKey);
      
      if (jsonString != null) {
        final List<dynamic> jsonList = jsonDecode(jsonString);
        final items = jsonList.map((json) => WishlistItem.fromJson(json)).toList();
        state = items;
      }
      _initialized = true;
    } catch (e) {
      debugPrint('Error loading wishlist: $e');
      state = [];
      _initialized = true;
    }
  }

  Future<void> _saveWishlist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = state.map((item) => item.toJson()).toList();
      await prefs.setString(_storageKey, jsonEncode(jsonList));
    } catch (e) {
      debugPrint('Error saving wishlist: $e');
    }
  }

  void addToWishlist(Product product) {
    if (state.any((item) => item.product.id == product.id)) {
      return; // Already in wishlist
    }
    
    state = [...state, WishlistItem(product: product)];
    _saveWishlist();
  }

  void removeFromWishlist(String productId) {
    state = state.where((item) => item.product.id != productId).toList();
    _saveWishlist();
  }

  void toggleWishlist(Product product) {
    if (state.any((item) => item.product.id == product.id)) {
      removeFromWishlist(product.id);
    } else {
      addToWishlist(product);
    }
  }

  void clearWishlist() {
    state = [];
    _saveWishlist();
  }

  void moveToCart(String productId, void Function(Product) onMove) {
    final item = state.firstWhere(
      (item) => item.product.id == productId,
      orElse: () => throw Exception('Product not in wishlist'),
    );
    
    removeFromWishlist(productId);
    onMove(item.product);
  }
}
