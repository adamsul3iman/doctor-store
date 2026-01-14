import 'package:flutter/foundation.dart';

/// أنماط جاهزة لاستعمال الصور حسب السياق (بانر، كارد، ثامبنايل، ...).
enum ImageVariant {
  heroBanner, // بانرات سينمائية كبيرة
  homeBanner, // بانرات متوسطة في الصفحة الرئيسية
  productCard, // كروت المنتجات في القوائم
  thumbnail, // ثامبنايل صغيرة (معرض الصور)
  fullScreen, // عرض صورة كاملة في شاشة التفاصيل
}

/// توليد رابط صورة مضغوط مع الحفاظ على الجودة قدر الإمكان.
///
/// لا يغيّر الرابط إذا لم يكن من Supabase أو لم نرد استخدام التحويلات.
String buildOptimizedImageUrl(
  String originalUrl, {
  required ImageVariant variant,
}) {
  if (originalUrl.isEmpty) return originalUrl;

  final lower = originalUrl.toLowerCase();
  final isSupabase = lower.contains('supabase.co/storage') ||
      lower.contains('supabase.in/storage');

  // إذا لم تكن الصورة من Supabase Storage نعيد الرابط كما هو
  if (!isSupabase) return originalUrl;

  int width;
  int? height;
  int quality;
  String resizeMode;

  // استخدام API التحويل في Supabase حسب نوع الاستخدام
  // - ثامبنايلات وكروت المنتجات: مربعة 300x300 مع cover
  // - تفاصيل المنتجات والبانرات: عرض 800 مع contain
  switch (variant) {
    case ImageVariant.heroBanner:
    case ImageVariant.homeBanner:
      // بانرات وتفاصيل عامة: عرض 800 مع contain
      width = 800;
      height = null;
      resizeMode = 'contain';
      quality = 70;
      break;
    case ImageVariant.productCard:
    case ImageVariant.thumbnail:
      // كروت المنتجات / ثامبنايل – مربعة صغيرة وسريعة
      width = 300;
      height = 300;
      resizeMode = 'cover';
      quality = 60;
      break;
    case ImageVariant.fullScreen:
      // عرض التفاصيل / المعرض الكامل – أكبر قليلاً لكن ما زال مع contain
      width = 800;
      height = null;
      resizeMode = 'contain';
      quality = 75;
      break;
  }

  // على الويب نفضّل webp، على باقي المنصات نترك الفورمات الافتراضي
  final useWebp = kIsWeb;

  // إذا كان الرابط يحتوي مسبقاً على معاملات التحسين (width / height / format / resize)
  // نُعيده كما هو لتجنّب تكرار المعاملات أكثر من مرة.
  final lowerUrl = originalUrl.toLowerCase();
  if (lowerUrl.contains('width=') ||
      lowerUrl.contains('height=') ||
      lowerUrl.contains('format=webp') ||
      lowerUrl.contains('resize=')) {
    return originalUrl;
  }

  final separator = originalUrl.contains('?') ? '&' : '?';
  final buffer = StringBuffer(originalUrl)
    ..write(separator)
    ..write('width=$width');

  if (height != null) {
    buffer.write('&height=$height');
  }

  buffer
    ..write('&quality=$quality')
    ..write('&resize=$resizeMode');

  if (useWebp) {
    buffer.write('&format=webp');
  }

  return buffer.toString();
}
