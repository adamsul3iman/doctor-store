import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:auto_size_text/auto_size_text.dart';

import 'package:doctor_store/features/product/domain/models/product_model.dart';
import 'package:doctor_store/features/wishlist/application/wishlist_manager.dart';
import 'package:doctor_store/shared/utils/product_nav_helper.dart';
import 'package:doctor_store/shared/widgets/image_shimmer_placeholder.dart';
import 'package:doctor_store/shared/widgets/app_network_image.dart';
import 'package:doctor_store/shared/utils/image_url_helper.dart';
import 'package:doctor_store/shared/utils/categories_provider.dart';

class ProductCard extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final product = this.product;
    final isCompact = this.isCompact;

    // اسم القسم (محسوب بخريطة جاهزة لتقليل العمل داخل كل كرت)
    final categoryLabel =
        ref.watch(categoryLabelByIdProvider.select((labels) => labels[product.category])) ??
            product.categoryArabic;

    return RepaintBoundary(
      child: GestureDetector(
        onTap: () => context.push(
          buildProductDetailsPath(product),
          extra: product,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 12,
                offset: const Offset(0, 4),
                spreadRadius: -2,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // الجزء العلوي: صورة بنسبة ثابتة داخل الكرت
                AspectRatio(
                  aspectRatio: isCompact ? 1 : 4 / 3,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: AppNetworkImage(
                          url: product.originalImageUrl,
                          variant: ImageVariant.productCard,
                          fit: BoxFit.cover,
                          placeholder: const ShimmerImagePlaceholder(),
                          errorWidget: const Icon(
                            Icons.image_not_supported_outlined,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                      // زر المفضلة (أعلى اليمين)
                      Positioned(
                        top: 10,
                        right: 10,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.9),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.1),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                          child: _WishlistButton(product: product),
                        ),
                      ),
                    ],
                  ),
                ),

                // الجزء السفلي: تفاصيل مضغوطة بنفس ستايل "وصل حديثاً"
                Expanded(
                  flex: isCompact ? 3 : 2,
                  child: Padding(
                    padding: EdgeInsets.all(isCompact ? 4.0 : 8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        Text(
                          categoryLabel,
                          style: TextStyle(
                            fontSize: isCompact ? 9 : 10,
                            color: Colors.grey[500],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        AutoSizeText(
                          product.title,
                          style: TextStyle(
                            fontFamily: 'Almarai',
                            fontWeight: FontWeight.bold,
                            fontSize: isCompact ? 11 : 12,
                            height: 1.2,
                          ),
                          maxLines: 1,
                          minFontSize: isCompact ? 9 : 10,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: isCompact ? 4 : 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                if (product.oldPrice != null)
                                  Text(
                                    '${product.oldPrice!.toStringAsFixed(0)} د.أ',
                                    style: const TextStyle(
                                      decoration:
                                          TextDecoration.lineThrough,
                                      color: Colors.grey,
                                      fontSize: 10,
                                    ),
                                  ),
                                Text(
                                  '${product.price.toStringAsFixed(0)} د.أ',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: isCompact ? 13 : 14,
                                    color: const Color(0xFF0A2647),
                                  ),
                                ),
                              ],
                            ),
                            // أيقونة التقييم إن وجدت
                            if (product.ratingAverage > 0)
                              Row(
                                children: [
                                  const Icon(
                                    Icons.star,
                                    size: 12,
                                    color: Color(0xFFFFA726),
                                  ),
                                  const SizedBox(width: 2),
                                  Text(
                                    product.ratingAverage.toStringAsFixed(1),
                                    style: TextStyle(
                                      fontSize: isCompact ? 10 : 11,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF0A2647),
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

class _WishlistButton extends ConsumerWidget {
  final Product product;

  const _WishlistButton({required this.product});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isInWishlist = ref.watch(isInWishlistProvider(product.id));
    final wishlistNotifier = ref.read(wishlistProvider.notifier);

    return GestureDetector(
      onTap: () {
        wishlistNotifier.toggleWishlist(product);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isInWishlist ? 'تم إزالة المنتج من المفضلة' : 'تم إضافة المنتج للمفضلة',
              style: const TextStyle(fontFamily: 'Almarai'),
            ),
            backgroundColor: const Color(0xFF0A2647),
            duration: const Duration(seconds: 1),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.9),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 4,
            ),
          ],
        ),
        child: Icon(
          isInWishlist ? Icons.favorite : Icons.favorite_border,
          size: 16,
          color: isInWishlist ? Colors.red : Colors.grey[600],
        ),
      ),
    );
  }
}

class LatestProductCard extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final product = this.product;

    final int discount =
        (product.oldPrice != null && product.oldPrice! > product.price)
            ? ((product.oldPrice! - product.price) / product.oldPrice! * 100)
                .round()
            : 0;

    return RepaintBoundary(
      child: GestureDetector(
        onTap: onTap,
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
                        child: AppNetworkImage(
                          url: product.originalImageUrl,
                          variant: ImageVariant.productCard,
                          fit: BoxFit.cover,
                          placeholder: const ShimmerImagePlaceholder(),
                          errorWidget: const Icon(
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
                        Builder(
                          builder: (context) {
                            final categoryLabel = ref.watch(
                                  categoryLabelByIdProvider.select(
                                    (labels) => labels[product.category],
                                  ),
                                ) ??
                                product.categoryArabic;

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
                                    '${product.oldPrice!.toStringAsFixed(0)} د.أ',
                                    style: const TextStyle(
                                      decoration:
                                          TextDecoration.lineThrough,
                                      color: Colors.grey,
                                      fontSize: 10,
                                    ),
                                  ),
                                Text(
                                  '${product.price.toStringAsFixed(0)} د.أ',
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
