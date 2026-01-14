import 'package:doctor_store/features/product/domain/models/product_model.dart';
import 'package:doctor_store/shared/utils/link_share_helper.dart';

/// يبني مسار صفحة المنتج للاستخدام مع GoRouter.
/// يفضّل استخدام الـ slug لروابط أقصر وأفضل للسيو،
/// ويستخدم id كـ fallback عند عدم توفر slug.
String buildProductDetailsPath(Product product) {
  final slug = product.slug;
  if (slug != null && slug.isNotEmpty) {
    return '/p/$slug';
  }
  return '/product_details?id=${product.id}';
}

/// يبني رابط كامل (مع الدومين) لصفحة المنتج للاستخدام في المشاركة / QR.
String buildFullProductUrl(Product product) {
  final path = buildProductDetailsPath(product); // /p/slug أو /product_details?id=
  return buildFullUrl(path);
}
