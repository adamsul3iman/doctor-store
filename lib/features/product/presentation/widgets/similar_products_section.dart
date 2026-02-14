import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:doctor_store/features/product/presentation/widgets/product_card.dart';
import 'package:doctor_store/features/product/presentation/widgets/product_card_skeleton.dart';
import 'package:doctor_store/features/cart/application/cart_manager.dart';
import 'package:doctor_store/shared/utils/product_nav_helper.dart';
import 'package:doctor_store/shared/utils/image_url_helper.dart';
import 'package:doctor_store/shared/widgets/image_shimmer_placeholder.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:doctor_store/shared/utils/responsive_layout.dart';
import 'package:doctor_store/shared/widgets/app_network_image.dart';
import 'package:doctor_store/features/product/presentation/providers/products_provider.dart';
import 'package:doctor_store/features/product/domain/models/similar_products_query.dart';

class SimilarProductsSection extends StatefulWidget {
  final String categoryId;
  final String currentProductId;

  const SimilarProductsSection({
    super.key,
    required this.categoryId,
    required this.currentProductId,
  });

  @override
  State<SimilarProductsSection> createState() => _SimilarProductsSectionState();
}

class _SimilarProductsSectionState extends State<SimilarProductsSection> {
  @override
  Widget build(BuildContext context) {
    const double tileHeight = 260; // ارتفاع تقريبي لكل كرت في الشبكة

    return Consumer(
      builder: (context, ref, _) {
        final async = ref.watch(
          similarProductsProvider(
            SimilarProductsQuery(
              categoryId: widget.categoryId,
              excludeId: widget.currentProductId,
              limit: 6,
            ),
          ),
        );

        return async.when(
          loading: () => LayoutBuilder(
            builder: (context, constraints) {
              final crossAxisCount = ResponsiveLayout.gridCountForWidth(
                constraints.maxWidth,
                desiredItemWidth: 120,
                minCount: 3,
                maxCount: 4,
              );
              final isCompact = crossAxisCount >= 3;

              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  mainAxisExtent: isCompact ? 255 : tileHeight,
                ),
                itemCount: 4,
                itemBuilder: (_, __) => const ProductCardSkeleton(),
              );
            },
          ),
          error: (e, s) => const SizedBox.shrink(),
          data: (products) {
            if (products.isEmpty) return const SizedBox.shrink();

            return LayoutBuilder(
              builder: (context, constraints) {
                final crossAxisCount = ResponsiveLayout.gridCountForWidth(
                  constraints.maxWidth,
                  desiredItemWidth: 120,
                  minCount: 3,
                  maxCount: 4,
                );
                final isCompact = crossAxisCount >= 3;

                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    mainAxisExtent: isCompact ? 255 : tileHeight,
                  ),
                  itemCount: products.length,
                  itemBuilder: (context, index) {
                    final product = products[index];
                    return ProductCard(
                      product: product,
                      isCompact: isCompact,
                      heroTag: 'similar_${product.id}',
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }
}

/// شريط مبسّط يعرض صوراً مصغّرة ومنتجات مقترَحة
/// للاستخدام داخل صفحة تفاصيل المنتج (تحت الكمية المطلوبة).
class InlineSimilarProductsStrip extends ConsumerStatefulWidget {
  final String categoryId;
  final String currentProductId;

  const InlineSimilarProductsStrip({
    super.key,
    required this.categoryId,
    required this.currentProductId,
  });

  @override
  ConsumerState<InlineSimilarProductsStrip> createState() => _InlineSimilarProductsStripState();
}

class _InlineSimilarProductsStripState extends ConsumerState<InlineSimilarProductsStrip> {
  @override
  Widget build(BuildContext context) {
    final async = ref.watch(
      similarProductsProvider(
        SimilarProductsQuery(
          categoryId: widget.categoryId,
          excludeId: widget.currentProductId,
          limit: 10,
        ),
      ),
    );

    final products = async.asData?.value;
    if (products == null || products.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'منتجات مقترحة لك',
          style: GoogleFonts.almarai(
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 120,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: products.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final product = products[index];
              return SizedBox(
                width: 100,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    context.push(
                      buildProductDetailsPath(product),
                      extra: product,
                    );
                  },
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: AspectRatio(
                            aspectRatio: 1,
                            child: AppNetworkImage(
                              url: product.thumbnailUrl,
                              variant: ImageVariant.thumbnail,
                              fit: BoxFit.cover,
                              placeholder: const ShimmerImagePlaceholder(),
                              errorWidget: const Icon(
                                Icons.image_not_supported_outlined,
                                color: Colors.grey,
                              ),
                              fadeInDuration: const Duration(milliseconds: 150),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Text(
                              '${product.price.toStringAsFixed(0)} د.أ',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.almarai(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          IconButton(
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            iconSize: 18,
                            tooltip: 'إضافة للسلة',
                            icon: const Icon(Icons.add_shopping_cart_rounded,
                                color: Colors.green, size: 18),
                            onPressed: () {
                              final hasColors = product.hasColorOptions;
                              final hasSizes = product.hasSizeOptions;

                              if (hasColors || hasSizes) {
                                // منتج يحتاج اختيار لون/مقاس → نفتح صفحة التفاصيل لاختيارها أولاً
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
                                  const SnackBar(
                                    content: Text('تمت إضافة المنتج للسلة'),
                                    duration: Duration(seconds: 1),
                                  ),
                                );
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
