/// Cart repository - responsible for cart persistence only.
/// Handles local (SharedPreferences) and remote (Supabase) storage.
/// No state management, no UI knowledge, no Riverpod dependencies.
library;

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:doctor_store/features/cart/application/cart_manager.dart'
    show CartItem;

/// Result of loading cart from storage
class CartLoadResult {
  final List<CartItem> items;
  final String? source; // 'local', 'remote', 'merged'

  const CartLoadResult({required this.items, this.source});
}

/// Cart persistence repository
class CartRepository {
  final SharedPreferences? _prefs;
  final SupabaseClient? _client;

  CartRepository({
    SharedPreferences? prefs,
    SupabaseClient? client,
  })  : _prefs = prefs,
        _client = client;

  /// Factory constructor that creates repository with current instances
  factory CartRepository.current() {
    SupabaseClient? client;
    try {
      client = Supabase.instance.client;
    } catch (_) {
      // Supabase not initialized (testing or early app startup)
      client = null;
    }
    return CartRepository(client: client);
  }

  // ================== Local Storage (SharedPreferences) ==================

  /// Load cart from local storage
  Future<List<CartItem>> loadLocalCart() async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    final String? cartString = prefs.getString('cart_items');

    if (cartString == null || cartString.isEmpty) {
      return [];
    }

    try {
      final List<dynamic> decoded = jsonDecode(cartString);
      return decoded.map((e) => CartItem.fromJson(e)).toList();
    } catch (e) {
      // Invalid cached data, return empty cart
      return [];
    }
  }

  /// Save cart to local storage
  Future<void> saveLocalCart(List<CartItem> items) async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    final String encoded = jsonEncode(items.map((e) => e.toJson()).toList());
    await prefs.setString('cart_items', encoded);
  }

  /// Clear local cart
  Future<void> clearLocalCart() async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    await prefs.remove('cart_items');
  }

  // ================== Remote Storage (Supabase) ==================

  /// Load cart from Supabase for current user
  Future<List<CartItem>> loadRemoteCart(String userId) async {
    if (_client == null) return [];

    try {
      final data = await _client
          .from('user_carts')
          .select('items')
          .eq('user_id', userId)
          .maybeSingle();

      if (data != null && data['items'] is List) {
        return (data['items'] as List)
            .map((e) => CartItem.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      }
      return [];
    } catch (e) {
      // Return empty on error, let caller handle logging
      return [];
    }
  }

  /// Sync cart to Supabase for current user
  Future<void> syncRemoteCart(String userId, List<CartItem> items) async {
    if (_client == null) return;

    try {
      await _client.from('user_carts').upsert({
        'user_id': userId,
        'items': items.map((e) => e.toJson()).toList(),
      }, onConflict: 'user_id');
    } catch (e) {
      // Silent failure - cart remains in local storage
      rethrow; // Let caller decide on error handling
    }
  }

  /// Delete remote cart (optional - for logout scenarios)
  Future<void> deleteRemoteCart(String userId) async {
    if (_client == null) return;

    try {
      await _client.from('user_carts').delete().eq('user_id', userId);
    } catch (e) {
      // Silent failure
    }
  }

  // ================== Merge Logic ==================

  /// Merge two carts, summing quantities for identical items
  static List<CartItem> mergeCarts(List<CartItem> a, List<CartItem> b) {
    final Map<CartItem, int> map = {};
    for (final item in [...a, ...b]) {
      map[item] = (map[item] ?? 0) + item.quantity;
    }
    return map.entries
        .map((entry) => CartItem(
              product: entry.key.product,
              quantity: entry.value,
              selectedColor: entry.key.selectedColor,
              selectedSize: entry.key.selectedSize,
              variantPrice: entry.key.variantPrice,
            ))
        .toList();
  }

  // ================== Combined Operations ==================

  /// Load cart with automatic local/remote resolution
  /// Returns remote if available, otherwise local
  Future<CartLoadResult> loadCart({String? userId}) async {
    final localItems = await loadLocalCart();

    // If no user, return local only
    if (userId == null || _client == null) {
      return CartLoadResult(items: localItems, source: 'local');
    }

    try {
      final remoteItems = await loadRemoteCart(userId);

      if (remoteItems.isNotEmpty) {
        return CartLoadResult(items: remoteItems, source: 'remote');
      } else {
        return CartLoadResult(items: localItems, source: 'local');
      }
    } catch (e) {
      // Fallback to local on error
      return CartLoadResult(items: localItems, source: 'local');
    }
  }

  /// Load and merge local + remote carts (for login scenario)
  Future<CartLoadResult> loadAndMergeCarts(String userId) async {
    final localItems = await loadLocalCart();

    if (_client == null) {
      return CartLoadResult(items: localItems, source: 'local');
    }

    try {
      final remoteItems = await loadRemoteCart(userId);
      final merged = mergeCarts(localItems, remoteItems);
      return CartLoadResult(items: merged, source: 'merged');
    } catch (e) {
      return CartLoadResult(items: localItems, source: 'local');
    }
  }

  /// Save cart to both local and remote
  Future<void> saveCart({
    required List<CartItem> items,
    String? userId,
  }) async {
    // Always save locally
    await saveLocalCart(items);

    // Save remotely if user is logged in
    if (userId != null && _client != null) {
      try {
        await syncRemoteCart(userId, items);
      } catch (e) {
        // Remote sync failed, but local is saved
        // This is acceptable - will retry on next save
      }
    }
  }

  /// Clear cart from both local and remote
  Future<void> clearCart({String? userId}) async {
    await clearLocalCart();

    if (userId != null && _client != null) {
      try {
        await deleteRemoteCart(userId);
      } catch (e) {
        // Ignore remote delete errors
      }
    }
  }
}
