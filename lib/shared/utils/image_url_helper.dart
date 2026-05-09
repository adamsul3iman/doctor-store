/// أنماط جاهزة لاستعمال الصور حسب السياق (بانر، كارد، ثامبنايل، ...).
enum ImageVariant {
  heroBanner, // بانرات سينمائية كبيرة
  homeBanner, // بانرات متوسطة في الصفحة الرئيسية
  productCard, // كروت المنتجات في القوائم (مربعة - cover)
  mattressCard, // كرت الفرشات في الصفحة الرئيسية (بدون قص - contain)
  thumbnail, // ثامبنايل صغيرة (معرض الصور)
  fullScreen, // عرض صورة كاملة في شاشة التفاصيل
}

/// يُزيل جميع معاملات الاستعلام من رابط URL، ويعيد الرابط النظيف.
///
/// يُستخدم لتنظيف الروابط الملوثة التي قد تحتوي على معاملات
/// Supabase transformation مكررة (مثل ?format=webp&quality=80...).
String cleanImageUrl(String? url) {
  if (url == null || url.isEmpty) return '';
  // نأخذ الجزء قبل علامة الاستفهام فقط
  final index = url.indexOf('?');
  if (index == -1) return url;
  return url.substring(0, index);
}

/// توليد رابط صورة نظيف بدون معاملات تحويل.
///
/// تم إزالة تحويلات Supabase server-side لأنها تسبب أخطاء 400
/// وغير مفعلة في الخطة المجانية. Flutter يتولى التحجيم محلياً.
String buildOptimizedImageUrl(
  String originalUrl, {
  required ImageVariant variant,
}) {
  // نُعيد الرابط النظيف بدون أي معاملات تحويل
  return cleanImageUrl(originalUrl);
}
