import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:doctor_store/shared/utils/analytics_service.dart';

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
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString('user_email'); // أو نجلبه من Auth مباشرة
    
    if (email != null && email.isNotEmpty) {
      final client = _getClientOrNull();
      if (client == null) {
        // لا يوجد اتصال بـ Supabase (مثلاً في الاختبارات) → نكتفي بالقائمة المحلية
        return;
      }
      try {
        // 1. جلب مفضلة المستخدم من السيرفر
        final response = await client
            .from('wishlist')
            .select('product_id')
            .eq('user_email', email);
            
        final serverList = (response as List).map((e) => e['product_id'] as String).toList();
        
        // 2. دمج القائمة المحلية (ما اضافه وهو زائر) مع السيرفر
        final combined = {...state, ...serverList}.toList();
        state = combined;
        
        // 3. تحديث السيرفر بالقيم الجديدة المدمجة (للأسف Supabase لا يدعم bulk insert with ignore بسهولة، لذا سنضيف الجديد فقط)
        for (var pid in state) {
          if (!serverList.contains(pid)) {
            await client
                .from('wishlist')
                .insert({'user_email': email, 'product_id': pid})
                .catchError((e) {
              debugPrint('Handled Error (wishlist refresh insert): $e');
            });
          }
        }

        // 4. حفظ النسخة النهائية محلياً
        await prefs.setStringList(_localKey, state);
        
      } catch (e) {
        debugPrint('Handled Error (wishlist refreshAfterLogin): $e');
      }
    }
  }

  Future<void> toggleWishlist(String productId) async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString('user_email'); // نعتمد على المخزن محلياً لتسريع العملية

    if (state.contains(productId)) {
      state = state.where((id) => id != productId).toList();
      if (email != null && _getClientOrNull() != null) {
        _removeFromCloud(email, productId);
      }
      AnalyticsService.instance
          .trackEvent('wishlist_remove', props: {'product_id': productId});
    } else {
      state = [...state, productId];
      if (email != null && _getClientOrNull() != null) {
        _addToCloud(email, productId);
      }
      AnalyticsService.instance
          .trackEvent('wishlist_add', props: {'product_id': productId});
    }
    
    await prefs.setStringList(_localKey, state);
  }

  Future<void> _addToCloud(String email, String productId) async {
    final client = _getClientOrNull();
    if (client == null) return;
    try {
      await client.from('wishlist').insert({
        'user_email': email,
        'product_id': productId,
      });
    } catch (e) {
      debugPrint('Handled Error (wishlist _addToCloud): $e');
    }
  }

  Future<void> _removeFromCloud(String email, String productId) async {
    final client = _getClientOrNull();
    if (client == null) return;
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