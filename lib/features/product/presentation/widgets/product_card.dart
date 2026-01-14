import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:doctor_store/features/product/domain/models/product_model.dart';
import 'package:doctor_store/shared/utils/image_url_helper.dart';
import 'package:doctor_store/shared/utils/product_nav_helper.dart';
import 'package:doctor_store/shared/widgets/image_shimmer_placeholder.dart';
import 'package:doctor_store/shared/utils/categories_provider.dart';

class ProductCard extends ConsumerStatefulWidget {
  final Product product;
  final bool isCompact;
  final String? heroTag; // حالياً للاستخدام المستقبلي إذا احتجنا Hero مخصص

  const ProductCard({
    super.key,
    required this.product,
    this.isCompact = false,
    this.heroTag,
  });

  @override
  ConsumerState<ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends ConsumerState<ProductCard>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final product = widget.product;

    // محاولة جلب اسم القسم ديناميكياً من جدول الأقسام (categories)
    final categoriesAsync = ref.watch(categoriesConfigProvider);
    String categoryLabel = product.categoryArabic;
    final categories = categoriesAsync.asData?.value;
    if (categories != null) {
      for (final c in categories) {
        if (c.id == product.category && c.name.trim().isNotEmpty) {
          categoryLabel = c.name.trim();
          break;
        }
      }
    }

    // نفس منطق الخصم المستخدم في قسم "وصل حديثاً"
    int discount = 0;
    if (product.oldPrice != null && product.oldPrice! > product.price) {
      discount =
          ((product.oldPrice! - product.price) / product.oldPrice! * 100).round();
    }

    return RepaintBoundary(
      child: GestureDetector(
        onTap: () => context.push(
          buildProductDetailsPath(product),
          extra: product,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Material(
            color: Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // الجزء العلوي: صورة بنسبة ثابتة داخل الكرت
                Expanded(
                  flex: 3,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: CachedNetworkImage(
                          imageUrl: buildOptimizedImageUrl(
                            product.originalImageUrl,
                            variant: ImageVariant.productCard,
                          ),
                          fit: BoxFit.cover,
                          filterQuality: FilterQuality.low,
                          // ارتفاع أقل في الكاش لتقليل استهلاك الذاكرة على الويب
                          memCacheHeight: 320,
                          fadeInDuration:
                              const Duration(milliseconds: 180),
                          fadeOutDuration: Duration.zero,
                          placeholder: (context, url) =>
                              const ShimmerImagePlaceholder(),
                          errorWidget: (context, url, error) =>
                              const Icon(
                            Icons.image_not_supported_outlined,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                      if (discount > 0)
                        Positioned(
                          top: 8,
                          left: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFD32F2F),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '-$discount%',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                // الجزء السفلي: تفاصيل مضغوطة بنفس ستايل "وصل حديثاً"
                Expanded(
                  flex: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          categoryLabel,
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey[500],
                          ),
                        ),
                        AutoSizeText(
                          product.title,
                          style: const TextStyle(
                            fontFamily: 'Almarai',
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            height: 1.2,
                          ),
                          maxLines: 2,
                          minFontSize: 12,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.start,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                if (product.oldPrice != null)
                                  Text(
                                    '${product.oldPrice} د.أ',
                                    style: const TextStyle(
                                      decoration:
                                          TextDecoration.lineThrough,
                                      color: Colors.grey,
                                      fontSize: 10,
                                    ),
                                  ),
                                Text(
                                  '${product.price} د.أ',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 14,
                                    color: Color(0xFF0A2647),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class LatestProductCard extends StatefulWidget {
  final Product product;
  final VoidCallback onTap;
  final VoidCallback onAddToCart;

  const LatestProductCard({
    super.key,
    required this.product,
    required this.onTap,
    required this.onAddToCart,
  });

  @override
  State<LatestProductCard> createState() => _LatestProductCardState();
}

class _LatestProductCardState extends State<LatestProductCard>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final product = widget.product;

    final int discount =
        (product.oldPrice != null && product.oldPrice! > product.price)
            ? ((product.oldPrice! - product.price) / product.oldPrice! * 100)
                .round()
            : 0;

    return RepaintBoundary(
      child: GestureDetector(
        onTap: widget.onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Material(
            color: Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // الجزء العلوي: صورة بنسبة ثابتة داخل الكرت
                Expanded(
                  flex: 3,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: CachedNetworkImage(
                          imageUrl: buildOptimizedImageUrl(
                            product.originalImageUrl,
                            variant: ImageVariant.productCard,
                          ),
                          fit: BoxFit.cover,
                          filterQuality: FilterQuality.low,
                          memCacheHeight: 300,
                          placeholder: (c, u) =>
                              const ShimmerImagePlaceholder(),
                          errorWidget: (c, u, e) => const Icon(
                            Icons.image_not_supported_outlined,
                          ),
                        ),
                      ),
                      if (discount > 0)
                        Positioned(
                          top: 8,
                          left: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFD32F2F),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '-$discount%',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                // الجزء السفلي: تفاصيل مضغوطة
                Expanded(
                  flex: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Consumer(
                          builder: (context, ref, _) {
                            // محاولة جلب اسم القسم ديناميكياً من جدول الأقسام (categories)
                            String categoryLabel = product.categoryArabic;
                            final catsAsync = ref.watch(categoriesConfigProvider);
                            final cats = catsAsync.asData?.value;
                            if (cats != null) {
                              for (final c in cats) {
                                if (c.id == product.category &&
                                    c.name.trim().isNotEmpty) {
                                  categoryLabel = c.name.trim();
                                  break;
                                }
                              }
                            }

                            return Text(
                              categoryLabel,
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey[500],
                              ),
                            );
                          },
                        ),
                        AutoSizeText(
                          product.title,
                          style: const TextStyle(
                            fontFamily: 'Almarai',
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            height: 1.2,
                          ),
                          maxLines: 2,
                          minFontSize: 12,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.start,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                if (product.oldPrice != null)
                                  Text(
                                    '${product.oldPrice} د.أ',
                                    style: const TextStyle(
                                      decoration:
                                          TextDecoration.lineThrough,
                                      color: Colors.grey,
                                      fontSize: 10,
                                    ),
                                  ),
                                Text(
                                  '${product.price} د.أ',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 14,
                                    color: Color(0xFF0A2647),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
