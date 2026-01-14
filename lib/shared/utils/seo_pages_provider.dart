import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// موديل بسيط لتمثيل إعدادات SEO لصفحة معينة
///
/// يفترض وجود جدول `seo_pages` في Supabase يحتوي على الأعمدة:
/// - key (text, primary key) مثل: home, about, contact, terms, privacy
/// - title (text)
/// - description (text)
/// - image_url (text, nullable) لاستخدام صورة مخصصة للمشاركة
class AppSeoPage {
  final String key;
  final String title;
  final String description;
  final String? imageUrl;

  AppSeoPage({
    required this.key,
    required this.title,
    required this.description,
    this.imageUrl,
  });

  factory AppSeoPage.fromMap(Map<String, dynamic> map) {
    return AppSeoPage(
      key: map['key'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      imageUrl: map['image_url'] as String?,
    );
  }
}

/// مزود لجلب إعدادات SEO لصفحة معينة حسب المفتاح.
/// مثال: ref.watch(seoPageProvider('home'))
final seoPageProvider =
    FutureProvider.family<AppSeoPage?, String>((ref, key) async {
  final supabase = Supabase.instance.client;

  try {
    final data = await supabase
        .from('seo_pages')
        .select('key,title,description,image_url')
        .eq('key', key)
        .maybeSingle();

    // في حال عدم وجود سجل، نعيد null بدون رمي استثناء (مثلاً 404 من Supabase)
    if (data == null) return null;

    return AppSeoPage.fromMap(data);
  } on PostgrestException catch (e) {
    // إذا كان الخطأ من نوع "الصفحة غير موجودة" (PGRST116 مثلاً)، نتعامل معه كعدم وجود سجل
    if (e.code == 'PGRST116') {
      return null;
    }
    rethrow;
  }
});
