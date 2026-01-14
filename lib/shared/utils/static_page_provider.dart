import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// موديل بسيط لتمثيل صفحة ثابتة مثل سياسة الخصوصية أو الشروط والأحكام.
///
/// يفترض وجود جدول باسم `static_pages` في Supabase يحتوي على الأعمدة:
/// - key (text, primary key) مثل: `privacy`, `terms`
/// - title (text)
/// - content (text)
class AppStaticPage {
  final String key;
  final String title;
  final String content;

  AppStaticPage({
    required this.key,
    required this.title,
    required this.content,
  });

  factory AppStaticPage.fromMap(Map<String, dynamic> map) {
    return AppStaticPage(
      key: map['key'] ?? '',
      title: map['title'] ?? '',
      content: map['content'] ?? '',
    );
  }
}

/// مزود عام لجلب صفحة ثابتة حسب المفتاح (key)،
/// مثال الاستخدام: `ref.watch(staticPageProvider('privacy'))`.
final staticPageProvider =
    FutureProvider.family<AppStaticPage?, String>((ref, key) async {
  final supabase = Supabase.instance.client;

  final data = await supabase
      .from('static_pages')
      .select('key,title,content')
      .eq('key', key)
      .maybeSingle();

  if (data == null) return null;
  return AppStaticPage.fromMap(data);
});