import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:doctor_store/features/product/domain/models/product_model.dart';
import 'package:doctor_store/shared/services/analytics_service.dart';

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

  /// ✅ Helper: Get Supabase client or null
  SupabaseClient? _getClientOrNull() {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
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

  /// ✅ Sync wishlist to cloud (Supabase) for logged-in users
  Future<void> _syncToCloud(String productId) async {
    final client = _getClientOrNull();
    if (client == null) return;

    final user = client.auth.currentUser;
    final userId = user?.id;
    final email = user?.email;
    if (userId == null || userId.isEmpty) return;
    if (email == null || email.isEmpty) return;

    try {
      await client.from('wishlist').insert({
        'user_id': userId,
        'user_email': email,
        'product_id': productId,
      });
    } catch (e) {
      debugPrint('Handled Error (wishlist _syncToCloud): $e');
    }
  }

  /// ✅ Remove from cloud (Supabase)
  Future<void> _removeFromCloud(String productId) async {
    final client = _getClientOrNull();
    if (client == null) return;

    final user = client.auth.currentUser;
    final userId = user?.id;
    if (userId == null || userId.isEmpty) return;

    try {
      await client
          .from('wishlist')
          .delete()
          .eq('user_id', userId)
          .eq('product_id', productId);
    } catch (e) {
      debugPrint('Handled Error (wishlist _removeFromCloud): $e');
    }
  }

  /// ✅ Refresh and sync wishlist after login (merge local with server)
  Future<void> refreshAfterLogin() async {
    final client = _getClientOrNull();
    if (client == null) return;

    final user = client.auth.currentUser;
    final userId = user?.id;
    final email = user?.email;
    if (userId == null || userId.isEmpty) return;
    if (email == null || email.isEmpty) return;

    try {
      // 1) Fetch user's wishlist from server
      final response = await client
          .from('wishlist')
          .select('product_id')
          .eq('user_id', userId);

      final serverProductIds =
          (response as List).map((e) => e['product_id'] as String).toList();

      // 2) Get local product IDs
      final localProductIds = state.map((item) => item.product.id).toList();

      // 3) Find items that need to be synced to server (local but not on server)
      for (final item in state) {
        if (!serverProductIds.contains(item.product.id)) {
          await client.from('wishlist').insert({
            'user_id': userId,
            'user_email': email,
            'product_id': item.product.id,
          }).catchError((e) {
            debugPrint('Handled Error (wishlist refresh insert): $e');
          });
        }
      }

      // 4) Note: We keep local items as source of truth for product data
      // The server only stores IDs, full product data is always local
      debugPrint('Wishlist synced: ${state.length} items');
    } catch (e) {
      debugPrint('Handled Error (wishlist refreshAfterLogin): $e');
    }
  }

  void addToWishlist(Product product) {
    if (state.any((item) => item.product.id == product.id)) {
      return; // Already in wishlist
    }
    
    state = [...state, WishlistItem(product: product)];
    _saveWishlist();
    
    // ✅ Sync to cloud if user is logged in
    _syncToCloud(product.id);
    
    // ✅ Track analytics
    AnalyticsService.instance.trackEvent('wishlist_add', props: {
      'product_id': product.id,
    });
  }

  void removeFromWishlist(String productId) {
    state = state.where((item) => item.product.id != productId).toList();
    _saveWishlist();
    
    // ✅ Remove from cloud if user is logged in
    _removeFromCloud(productId);
    
    // ✅ Track analytics
    AnalyticsService.instance.trackEvent('wishlist_remove', props: {
      'product_id': productId,
    });
  }

  void toggleWishlist(Product product) {
    if (state.any((item) => item.product.id == product.id)) {
      removeFromWishlist(product.id);
    } else {
      addToWishlist(product);
    }
  }

  void clearWishlist() {
    // ✅ Remove all from cloud first
    final client = _getClientOrNull();
    if (client != null) {
      final user = client.auth.currentUser;
      final userId = user?.id;
      if (userId != null && userId.isNotEmpty) {
        for (final item in state) {
          _removeFromCloud(item.product.id);
        }
      }
    }
    
    state = [];
    _saveWishlist();
    
    AnalyticsService.instance.trackEvent('wishlist_clear');
  }

  void moveToCart(String productId, void Function(Product) onMove) {
    final item = state.firstWhere(
      (item) => item.product.id == productId,
      orElse: () => throw Exception('Product not in wishlist'),
    );
    
    removeFromWishlist(productId);
    onMove(item.product);
    
    AnalyticsService.instance.trackEvent('wishlist_move_to_cart', props: {
      'product_id': productId,
    });
  }
}
