import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:doctor_store/features/product/domain/models/product_model.dart';
import 'package:doctor_store/features/recently_viewed/application/recently_viewed_manager.dart';
import 'package:doctor_store/shared/widgets/app_network_image.dart';
import 'package:doctor_store/shared/utils/image_url_helper.dart';
import 'package:doctor_store/shared/utils/responsive_layout.dart';

class RecentlyViewedScreen extends ConsumerWidget {
  const RecentlyViewedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recentlyViewed = ref.watch(recentlyViewedProductsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF0A2647),
        foregroundColor: Colors.white,
        centerTitle: true,
        title: Text(
          'شاهدتها مؤخراً',
          style: GoogleFonts.almarai(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          if (recentlyViewed.isNotEmpty)
            TextButton(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text(
                      'مسح السجل',
                      style: GoogleFonts.almarai(fontWeight: FontWeight.bold),
                    ),
                    content: Text(
                      'هل تريد مسح جميع المنتجات المعروضة مؤخراً؟',
                      style: GoogleFonts.almarai(),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(
                          'إلغاء',
                          style: GoogleFonts.almarai(),
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          ref.read(recentlyViewedProvider.notifier).clearRecentlyViewed();
                          Navigator.pop(context);
                        },
                        child: Text(
                          'مسح',
                          style: GoogleFonts.almarai(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                );
              },
              child: Text(
                'مسح الكل',
                style: GoogleFonts.almarai(
                  color: Colors.white70,
                  fontSize: 12,
                ),
              ),
            ),
        ],
      ),
      body: recentlyViewed.isEmpty
          ? _buildEmptyState(context)
          : _buildProductGrid(context, ref, recentlyViewed),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.history_outlined,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'لم تشاهد أي منتجات بعد',
            style: GoogleFonts.almarai(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'تصفح منتجاتنا لتظهر هنا',
            style: GoogleFonts.almarai(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => context.go('/'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0A2647),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'تصفح المنتجات',
              style: GoogleFonts.almarai(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductGrid(BuildContext context, WidgetRef ref, List<Product> products) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              '${products.length} منتج',
              style: GoogleFonts.almarai(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverLayoutBuilder(
            builder: (context, constraints) {
              final crossAxisCount = ResponsiveLayout.gridCountForWidth(
                constraints.crossAxisExtent,
                desiredItemWidth: 120,
                minCount: 3,
                maxCount: 5,
              );
              final isCompact = crossAxisCount >= 3;
              const spacing = 10.0;
              final mainAxisExtent = ResponsiveLayout.productCardMainAxisExtent(
                constraints.crossAxisExtent,
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: spacing,
                isCompact: isCompact,
              );

              return SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  mainAxisSpacing: spacing,
                  crossAxisSpacing: spacing,
                  mainAxisExtent: mainAxisExtent,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final product = products[index];
                    return _RecentlyViewedItemCard(
                      product: product,
                      onRemove: () {
                        ref
                            .read(recentlyViewedProvider.notifier)
                            .removeFromRecentlyViewed(product.id);
                      },
                    );
                  },
                  childCount: products.length,
                ),
              );
            },
          ),
        ),
        const SliverPadding(padding: EdgeInsets.only(bottom: 32)),
      ],
    );
  }
}

class _RecentlyViewedItemCard extends StatelessWidget {
  final Product product;
  final VoidCallback onRemove;

  const _RecentlyViewedItemCard({
    required this.product,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/product/${product.id}', extra: product),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product Image
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: AspectRatio(
                aspectRatio: 1,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: AppNetworkImage(
                        url: product.thumbnailUrl,
                        variant: ImageVariant.thumbnail,
                        fit: BoxFit.cover,
                      ),
                    ),
                    // Remove button
                    Positioned(
                      top: 8,
                      right: 8,
                      child: GestureDetector(
                        onTap: onRemove,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.9),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.close,
                            size: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Product Info
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.almarai(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${product.price.toStringAsFixed(0)} د.أ',
                    style: GoogleFonts.almarai(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF0A2647),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
