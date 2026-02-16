import 'package:doctor_store/features/product/domain/models/product_model.dart';
import 'package:doctor_store/shared/utils/link_share_helper.dart';

/// يبني مسار صفحة المنتج للاستخدام مع GoRouter.
/// يستخدم دائماً صيغة /p/... للروابط النظيفة بدون query parameters
String buildProductDetailsPath(Product product) {
  // استخدام slug إذا كان متوفراً
  var slug = product.slug;
  
  // إنشاء slug من اسم المنتج إذا لم يكن متوفراً
  if (slug == null || slug.isEmpty) {
    slug = _generateSlugFromName(product.title);
  }
  
  // إذا فشل إنشاء slug من الاسم، استخدم ID في المسار مباشرة
  if (slug.isEmpty) {
    slug = product.id;
  }
  
  return '/p/$slug';
}

/// ينشئ slug من اسم المنتج
String _generateSlugFromName(String name) {
  return name
    .toLowerCase()
    .trim()
    .replaceAll(RegExp(r'[^\w\s-]'), '') // إزالة الرموز الخاصة
    .replaceAll(RegExp(r'\s+'), '-'); // استبدال المسافات بـ -
}

/// يبني رابط كامل (مع الدومين) لصفحة المنتج للاستخدام في المشاركة / QR.
String buildFullProductUrl(Product product) {
  final path = buildProductDetailsPath(product); // /p/slug
  return buildFullUrl(path);
}
