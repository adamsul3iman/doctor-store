import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

/// خدمة متكاملة لتتبع وتحليل بيانات المتجر
class AnalyticsService {
  AnalyticsService._();

  static final AnalyticsService instance = AnalyticsService._();

  // معرف فريد للزائر (يُخزن محلياً حتى بعد تسجيل الخروج)
  String? _visitorId;

  SupabaseClient? _getClientOrNull() {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  /// الحصول على معرف الزائر الفريد
  String getVisitorId() {
    if (_visitorId == null) {
      _visitorId = const Uuid().v4();
    }
    return _visitorId!;
  }

  // ============================================
  // تتبع الأحداث العامة
  // ============================================

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
        'visitor_id': getVisitorId(),
        'props': props,
      });
    } catch (e) {
      debugPrint('Analytics error for $name: $e');
    }
  }

  // ============================================
  // تتبع زيارات الموقع
  // ============================================

  Future<void> trackSiteVisit({
    required String pageUrl,
    String? referrer,
    String? country,
    String? deviceType,
    String? browser,
    String? os,
  }) async {
    try {
      final client = _getClientOrNull();
      if (client == null) return;

      final user = client.auth.currentUser;
      await client.from('site_visits').insert({
        'visitor_id': getVisitorId(),
        'user_id': user?.id,
        'page_url': pageUrl,
        'referrer': referrer,
        'country': country ?? 'Unknown',
        'device_type': deviceType ?? _detectDeviceType(),
        'browser': browser ?? 'Unknown',
        'os': os ?? 'Unknown',
        'session_start': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('Analytics error tracking visit: $e');
    }
  }

  // ============================================
  // تتبع مشاهدات المنتجات
  // ============================================

  Future<void> trackProductView({
    required String productId,
    String? categoryId,
    int? viewDurationSeconds,
  }) async {
    try {
      final client = _getClientOrNull();
      if (client == null) return;

      final user = client.auth.currentUser;
      final visitorId = getVisitorId();

      // استخدام upsert لتحديث عدد المشاهدات
      await client.from('product_views').upsert({
        'product_id': productId,
        'visitor_id': visitorId,
        'user_id': user?.id,
        'category_id': categoryId,
        'view_count': 1,
        'last_viewed_at': DateTime.now().toIso8601String(),
        'view_duration_seconds': viewDurationSeconds ?? 0,
      }, onConflict: 'product_id,visitor_id');
    } catch (e) {
      debugPrint('Analytics error tracking product view: $e');
    }
  }

  /// تتبع إضافة منتج للسلة
  Future<void> trackAddToCart(String productId) async {
    try {
      final client = _getClientOrNull();
      if (client == null) return;

      final visitorId = getVisitorId();

      await client.from('product_views').update({
        'added_to_cart': true,
      }).match({
        'product_id': productId,
        'visitor_id': visitorId,
      });

      await trackEvent('add_to_cart', props: {'product_id': productId});
    } catch (e) {
      debugPrint('Analytics error tracking add to cart: $e');
    }
  }

  /// تتبع شراء منتج
  Future<void> trackPurchase(String productId) async {
    try {
      final client = _getClientOrNull();
      if (client == null) return;

      final visitorId = getVisitorId();

      await client.from('product_views').update({
        'purchased': true,
      }).match({
        'product_id': productId,
        'visitor_id': visitorId,
      });

      await trackEvent('purchase', props: {'product_id': productId});
    } catch (e) {
      debugPrint('Analytics error tracking purchase: $e');
    }
  }

  // ============================================
  // دوال الحصول على الإحصائيات (للوحة التحكم)
  // ============================================

  /// الحصول على إحصائيات لوحة التحكم
  Future<Map<String, dynamic>?> getDashboardStats() async {
    try {
      final client = _getClientOrNull();
      if (client == null) return null;

      final response = await client.rpc('get_dashboard_stats');
      return response;
    } catch (e) {
      debugPrint('Error getting dashboard stats: $e');
      return null;
    }
  }

  /// الحصول على المنتجات الأكثر مشاهدة
  Future<List<Map<String, dynamic>>> getTopProducts({int limit = 10}) async {
    try {
      final client = _getClientOrNull();
      if (client == null) return [];

      final response = await client
          .from('top_products_view')
          .select()
          .limit(limit);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error getting top products: $e');
      return [];
    }
  }

  /// الحصول على إحصائيات آخر N يوم
  Future<List<Map<String, dynamic>>> getAnalyticsForDays(int days) async {
    try {
      final client = _getClientOrNull();
      if (client == null) return [];

      final response = await client.rpc(
        'get_analytics_for_days',
        params: {'days_count': days},
      );

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error getting analytics for days: $e');
      return [];
    }
  }

  /// الحصول على إحصائيات اليوم
  Future<Map<String, dynamic>?> getTodayStats() async {
    try {
      final client = _getClientOrNull();
      if (client == null) return null;

      final response = await client
          .from('today_stats_view')
          .select()
          .single();

      return response;
    } catch (e) {
      debugPrint('Error getting today stats: $e');
      return null;
    }
  }

  /// الحصول على عدد الزوار المتصلين الآن
  Future<int> getOnlineUsersCount() async {
    try {
      final client = _getClientOrNull();
      if (client == null) return 0;

      final response = await client
          .from('site_visits')
          .select('visitor_id')
          .gt('session_start', DateTime.now().subtract(const Duration(minutes: 5)).toIso8601String())
          .count(CountOption.exact);

      return response.count;
    } catch (e) {
      debugPrint('Error getting online users: $e');
      return 0;
    }
  }

  // ============================================
  // دوال مساعدة
  // ============================================

  String _detectDeviceType() {
    // يمكن تحسينها لاحقاً باستخدام device_info_plus
    return 'unknown';
  }
}
