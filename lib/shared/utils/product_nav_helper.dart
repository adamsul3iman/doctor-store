import 'package:doctor_store/features/product/domain/models/product_model.dart';
import 'package:doctor_store/shared/utils/app_constants.dart';

/// يبني مسار صفحة المنتج للتنقل الداخلي مع GoRouter.
/// يستخدم صيغة /p/... (بدون #، GoRouter يتعامل مع الـ # تلقائياً)
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

/// يبني رابط كامل (مع الدومين والـ #) لصفحة المنتج للاستخدام في المشاركة / QR.
/// يستخدم صيغة https://domain.com/#/p/slug للـ Hash URL Strategy
String buildFullProductUrl(Product product) {
  final path = buildProductDetailsPath(product); // /p/slug
  const base = AppConstants.webBaseUrl;
  
  if (base.isEmpty) {
    return '/#$path';
  }
  
  return '$base/#$path';
}
