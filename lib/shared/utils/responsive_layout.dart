import 'dart:math' as math;

/// Helpers بسيطة لتخطيط متجاوب عبر الموبايل/التابلت/الويب.
class ResponsiveLayout {
  /// يحسب عدد الأعمدة المناسب لشبكات المنتجات/الأقسام بناءً على العرض.
  ///
  /// - [desiredItemWidth] عرض العنصر التقريبي بالـ px.
  /// - [minCount]/[maxCount] حدود لحماية الواجهة من عدد أعمدة غير مناسب.
  static int gridCountForWidth(
    double width, {
    double desiredItemWidth = 180,
    int minCount = 2,
    int maxCount = 6,
  }) {
    if (width.isNaN || width.isInfinite || width <= 0) return minCount;

    final raw = (width / desiredItemWidth).floor();
    return math.max(minCount, math.min(maxCount, raw));
  }

  static double productCardMainAxisExtent(
    double availableWidth, {
    required int crossAxisCount,
    double crossAxisSpacing = 12,
    required bool isCompact,
  }) {
    if (availableWidth.isNaN || availableWidth.isInfinite || availableWidth <= 0) {
      return isCompact ? 270 : 330;
    }
    if (crossAxisCount <= 0) return isCompact ? 270 : 330;

    final safeSpacing = math.max(0, crossAxisSpacing);
    final totalSpacing = safeSpacing * (crossAxisCount - 1);
    final itemWidth = math.max(0, (availableWidth - totalSpacing) / crossAxisCount);

    final imageAspectRatio = isCompact ? 1.0 : (4 / 3);
    final imageHeight = imageAspectRatio == 0 ? 0 : (itemWidth / imageAspectRatio);

    // ارتفاع ثابت تقريبي لمنطقة النص والأزرار داخل ProductCard.
    // الهدف: منع الـ overflow مع عدم وجود مساحة بيضاء زائدة.
    final detailsHeight = isCompact ? 78.0 : 112.0;

    final extent = imageHeight + detailsHeight;
    return extent.clamp(190.0, 360.0);
  }
}
