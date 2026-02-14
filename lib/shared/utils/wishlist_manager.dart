import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:doctor_store/shared/services/analytics_service.dart';

final wishlistProvider = StateNotifierProvider<WishlistNotifier, List<String>>((ref) {
  return WishlistNotifier();
});

class WishlistNotifier extends StateNotifier<List<String>> {
  WishlistNotifier() : super([]) {
    _loadWishlist();
  }

  static const String _localKey = 'user_wishlist';

  SupabaseClient? _getClientOrNull() {
    try {
      return Supabase.instance.client;
    } catch (_) {
      // في بيئات الاختبار أو في حال عدم تهيئة Supabase نعمل على الوضع المحلي فقط
      return null;
    }
  }

  Future<void> _loadWishlist() async {
    final prefs = await SharedPreferences.getInstance();
    final localList = prefs.getStringList(_localKey) ?? [];
    state = localList;
    // التحميل من السيرفر يتم لاحقاً أو عند التحديث
  }

  // ✅ الدالة الناقصة التي يطلبها WelcomeDialog
  Future<void> refreshAfterLogin() async {
    final client = _getClientOrNull();
    if (client == null) {
      // في بيئات الاختبار أو قبل التهيئة
      return;
    }

    // ✅ بعد قرارك: المفضلة تُزامَن فقط بعد تسجيل الدخول
    final user = client.auth.currentUser;
    final email = user?.email;
    if (email == null || email.isEmpty) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();

    try {
      // 1) جلب مفضلة المستخدم من السيرفر
      final response = await client
          .from('wishlist')
          .select('product_id')
          .eq('user_email', email);

      final serverList =
          (response as List).map((e) => e['product_id'] as String).toList();

      // 2) دمج القائمة المحلية (ما أضافه كزائر) مع السيرفر
      final combined = {...state, ...serverList}.toList();
      state = combined;

      // 3) إضافة العناصر الجديدة فقط إلى السيرفر
      for (final pid in state) {
        if (!serverList.contains(pid)) {
          await client.from('wishlist').insert({
            'user_email': email,
            'product_id': pid,
          }).catchError((e) {
            debugPrint('Handled Error (wishlist refresh insert): $e');
          });
        }
      }

      // 4) حفظ النسخة النهائية محلياً
      await prefs.setStringList(_localKey, state);
    } catch (e) {
      debugPrint('Handled Error (wishlist refreshAfterLogin): $e');
    }
  }

  Future<void> toggleWishlist(String productId) async {
    final prefs = await SharedPreferences.getInstance();

    final client = _getClientOrNull();
    final user = client?.auth.currentUser;
    final email = user?.email;

    // ملاحظة: نسمح للزائر بحفظ المفضلة محلياً فقط.
    // المزامنة للسيرفر تتم بعد تسجيل الدخول عبر refreshAfterLogin().

    if (state.contains(productId)) {
      state = state.where((id) => id != productId).toList();
      if (email != null && email.isNotEmpty && client != null) {
        _removeFromCloud(client, email, productId);
      }
      AnalyticsService.instance
          .trackEvent('wishlist_remove', props: {'product_id': productId});
    } else {
      state = [...state, productId];
      if (email != null && email.isNotEmpty && client != null) {
        _addToCloud(client, email, productId);
      }
      AnalyticsService.instance
          .trackEvent('wishlist_add', props: {'product_id': productId});
    }

    await prefs.setStringList(_localKey, state);
  }

  Future<void> _addToCloud(SupabaseClient client, String email, String productId) async {
    try {
      await client.from('wishlist').insert({
        'user_email': email,
        'product_id': productId,
      });
    } catch (e) {
      debugPrint('Handled Error (wishlist _addToCloud): $e');
    }
  }

  Future<void> _removeFromCloud(
    SupabaseClient client,
    String email,
    String productId,
  ) async {
    try {
      await client
          .from('wishlist')
          .delete()
          .eq('user_email', email)
          .eq('product_id', productId);
    } catch (e) {
      debugPrint('Handled Error (wishlist _removeFromCloud): $e');
    }
  }
}