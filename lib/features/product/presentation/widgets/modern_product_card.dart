import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
// import 'package:google_fonts/google_fonts.dart'; // ⚠️ REMOVED for smaller bundle
import 'package:auto_size_text/auto_size_text.dart';
import 'package:doctor_store/features/product/domain/models/product_model.dart';
import 'package:doctor_store/features/cart/application/cart_manager.dart';
import 'package:doctor_store/shared/utils/image_url_helper.dart';
import 'package:doctor_store/shared/utils/product_nav_helper.dart';
import 'package:doctor_store/shared/widgets/image_shimmer_placeholder.dart';
import 'package:doctor_store/shared/widgets/app_network_image.dart';
import 'package:doctor_store/core/theme/app_theme.dart';

class ModernProductCard extends ConsumerWidget {
  final Product product;
  final bool isCompact;

  const ModernProductCard({super.key, required this.product, this.isCompact = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final product = this.product;
    final isCompact = this.isCompact;

    int discount = 0;
    if (product.oldPrice != null && product.oldPrice! > product.price) {
      discount = ((product.oldPrice! - product.price) / product.oldPrice! * 100).round();
    }

    return RepaintBoundary(
      child: GestureDetector(
        onTap: () => context.push(
          buildProductDetailsPath(product),
          extra: product,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AspectRatio(
                aspectRatio: 3 / 4,
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      AppNetworkImage(
                        url: product.originalImageUrl,
                        variant: ImageVariant.productCard,
                        fit: BoxFit.cover,
                        placeholder: const ShimmerImagePlaceholder(),
                        errorWidget: const Icon(
                          Icons.image_not_supported_outlined,
                          color: Colors.grey,
                        ),
                      ),
                      if (discount > 0)
                        Positioned(
                          top: 8,
                          left: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.red[600],
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              "-$discount%",
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
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // العنوان فقط
                      AutoSizeText(
                        product.title,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: isCompact ? 12 : 14,
                          height: 1.3,
                          color: const Color(0xFF0A2647),
                        ),
                        maxLines: 2,
                        minFontSize: isCompact ? 11 : 13,
                        overflow: TextOverflow.ellipsis,
                      ),
                      
                      // السعر وزر السلة
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (product.oldPrice != null && product.oldPrice! > product.price)
                                  Text(
                                    product.oldPrice!.toStringAsFixed(0),
                                    style: TextStyle(
                                      decoration: TextDecoration.lineThrough,
                                      color: Colors.grey[400],
                                      fontSize: 11,
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                Text(
                                  "${product.price.toStringAsFixed(0)} د.أ",
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: AppTheme.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () {
                                final product = this.product;
                                final hasColors = product.hasColorOptions;
                                final hasSizes = product.hasSizeOptions;

                                if (hasColors || hasSizes) {
                                  context.push(
                                    buildProductDetailsPath(product),
                                    extra: product,
                                  );
                                  return;
                                }

                                ref.read(cartProvider.notifier).addItem(product);
                                ScaffoldMessenger.of(context)
                                  ..hideCurrentSnackBar()
                                  ..showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        "تمت الإضافة للسلة",
                                        style: TextStyle(),
                                      ),
                                      duration: const Duration(milliseconds: 1500),
                                      backgroundColor: const Color(0xFF0A2647),
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppTheme.primary,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppTheme.primary.withValues(alpha: 0.3),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.add_shopping_cart,
                                  size: 20,
                                  color: Colors.white,
                                ),
                              ),
                            ),
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
    );
  }
}
