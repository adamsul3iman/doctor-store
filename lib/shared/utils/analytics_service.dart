import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// خدمة بسيطة لتتبع أحداث مسار الشراء بدون التأثير على تجربة المستخدم
class AnalyticsService {
  AnalyticsService._();

  static final AnalyticsService instance = AnalyticsService._();

  SupabaseClient? _getClientOrNull() {
    try {
      return Supabase.instance.client;
    } catch (_) {
      // في بيئات الاختبار أو قبل تهيئة Supabase نتجاهل التتبع بهدوء
      return null;
    }
  }

  Future<void> trackEvent(
    String name, {
    Map<String, dynamic>? props,
  }) async {
    try {
      final client = _getClientOrNull();
      if (client == null) return;

      final user = client.auth.currentUser;
      await client.from('events').insert({
        'name': name,
        'user_id': user?.id,
        'props': props,
      });
    } catch (e) {
      // لا نوقف التطبيق أبداً بسبب التتبع
      debugPrint('Analytics error for $name: $e');
    }
  }
}
