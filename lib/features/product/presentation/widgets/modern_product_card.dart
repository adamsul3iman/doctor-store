import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:doctor_store/features/product/domain/models/product_model.dart';
import 'package:doctor_store/features/cart/application/cart_manager.dart';
import 'package:doctor_store/shared/utils/image_url_helper.dart';
import 'package:doctor_store/shared/utils/product_nav_helper.dart';
import 'package:doctor_store/shared/widgets/image_shimmer_placeholder.dart';
import 'package:doctor_store/core/theme/app_theme.dart';
import 'package:doctor_store/shared/utils/categories_provider.dart';

class ModernProductCard extends ConsumerStatefulWidget {
  final Product product;
  final bool isCompact;

  const ModernProductCard({super.key, required this.product, this.isCompact = false});

  @override
  ConsumerState<ModernProductCard> createState() => _ModernProductCardState();
}

class _ModernProductCardState extends ConsumerState<ModernProductCard>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final product = widget.product;
    final isCompact = widget.isCompact;

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
                      CachedNetworkImage(
                        imageUrl: buildOptimizedImageUrl(
                          product.originalImageUrl,
                          variant: ImageVariant.productCard,
                        ),
                        fit: BoxFit.cover,
                        filterQuality: FilterQuality.low,
                        memCacheHeight: 340,
                        placeholder: (context, url) => const ShimmerImagePlaceholder(),
                        errorWidget: (context, url, error) => const Icon(
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
                  padding: const EdgeInsets.all(10.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            categoryLabel,
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey[500],
                            ),
                          ),
                          const SizedBox(height: 2),
                          AutoSizeText(
                            product.title,
                            style: GoogleFonts.almarai(
                              fontWeight: FontWeight.bold,
                              fontSize: isCompact ? 11 : 13,
                              height: 1.2,
                            ),
                            maxLines: 2,
                            minFontSize: isCompact ? 10 : 12,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                      const Spacer(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (product.oldPrice != null)
                                Text(
                                  "${product.oldPrice} د.أ",
                                  style: const TextStyle(
                                    decoration: TextDecoration.lineThrough,
                                    color: Colors.grey,
                                    fontSize: 10,
                                  ),
                                ),
                              Text(
                                "${product.price} د.أ",
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: AppTheme.primary,
                                ),
                              ),
                            ],
                          ),
                          InkWell(
                            onTap: () {
                              ref.read(cartProvider.notifier).addItem(widget.product);
                              ScaffoldMessenger.of(context).hideCurrentSnackBar();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text("تمت الإضافة للسلة"),
                                  duration: Duration(seconds: 1),
                                  backgroundColor: Color(0xFF0A2647),
                                ),
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: AppTheme.primary.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.add_shopping_cart,
                                size: 18,
                                color: AppTheme.primary,
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
