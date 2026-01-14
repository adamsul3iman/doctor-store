import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// مفاتيح الأقسام في الصفحة الرئيسية
class HomeSectionKeys {
  static const hero = 'hero';
  static const categories = 'categories';
  static const flashSale = 'flash_sale';
  static const latest = 'latest';
  static const middleBanner = 'middle_banner';
  static const dining = 'dining';
  static const owner = 'owner_section';
  static const baby = 'baby_section';
}

/// إعداد قسم واحد في الهوم
class HomeSectionConfig {
  final String key;
  final bool enabled;
  final String? title;
  final String? subtitle;
  final int sortOrder;

  HomeSectionConfig({
    required this.key,
    required this.enabled,
    this.title,
    this.subtitle,
    required this.sortOrder,
  });

  factory HomeSectionConfig.fromMap(Map<String, dynamic> map) {
    return HomeSectionConfig(
      key: map['key'] as String,
      enabled: (map['enabled'] as bool?) ?? true,
      title: map['title'] as String?,
      subtitle: map['subtitle'] as String?,
      sortOrder: (map['sort_order'] as int?) ?? 0,
    );
  }
}

/// مزود يقوم بجلب إعدادات أقسام الصفحة الرئيسية من جدول `home_sections`.
/// باستخدام Stream حتى تنعكس تغييرات لوحة الأدمن مباشرة على الواجهة
/// بدون الحاجة لإعادة فتح الصفحة.
final homeSectionsProvider =
    StreamProvider<Map<String, HomeSectionConfig>>((ref) async* {
  final supabase = Supabase.instance.client;

  try {
    // نستخدم stream مع primaryKey حتى نضمن استلام التغييرات الحية
    final stream = supabase
        .from('home_sections')
        .stream(primaryKey: ['key']);

    await for (final data in stream) {
      final Map<String, HomeSectionConfig> result = {};
      for (final row in data) {
        final cfg = HomeSectionConfig.fromMap(row);
        result[cfg.key] = cfg;
      }
      yield result;
    }
  } catch (_) {
    // في حالة الخطأ نرجع خريطة فارغة، وسيتم اعتبار كل الأقسام مفعلة افتراضياً
    yield {};
  }
});
