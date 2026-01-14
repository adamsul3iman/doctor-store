import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import 'package:doctor_store/features/product/domain/models/product_model.dart';
import 'package:doctor_store/shared/utils/image_url_helper.dart';
import 'package:doctor_store/shared/utils/product_nav_helper.dart';
import 'package:doctor_store/shared/widgets/image_shimmer_placeholder.dart';
import 'package:go_router/go_router.dart';

/// قسم مخصص لعرض الفرشات بتصميم طبي مريح.
/// يعتمد فقط على قائمة المنتجات القادمة من الصفحة الرئيسية
/// بدون أي عمليات جلب بيانات إضافية.
class MattressSection extends StatelessWidget {
  final List<Product> products;

  const MattressSection({super.key, required this.products});

  @override
  Widget build(BuildContext context) {
    // نتأكد أن القائمة تحتوي فعلياً على فرشات
    final mattresses = products
        .where((p) => p.category == 'mattresses')
        .toList();

    if (mattresses.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0A2647), Color(0xFF193A5C)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  FontAwesomeIcons.bed,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'فرشات طبية مريحة',
                    style: GoogleFonts.almarai(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'طبقات دعم متعددة لراحة ظهرك ونوم أعمق.',
                    style: GoogleFonts.almarai(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 12,
                    ),
                  ),
                ],
              )
            ],
          ),
          const SizedBox(height: 16),
          // ارتفاع أقل لبطاقات الفرشات مع الحفاظ على تناسب جميل للصورة والنص
          SizedBox(
            height: 230,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              cacheExtent: 800.0,
              itemCount: mattresses.length,
              itemBuilder: (context, index) {
                final product = mattresses[index];
                return _MattressCard(product: product);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _MattressCard extends StatelessWidget {
  final Product product;

  const _MattressCard({required this.product});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: 200,
      margin: const EdgeInsetsDirectional.only(end: 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Material(
          color: Colors.white,
          child: InkWell(
            onTap: () => context.push(
              buildProductDetailsPath(product),
              extra: product,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: _buildImage(),
                ),
                Expanded(
                  flex: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(10.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'فرشة طبية',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey[600],
                          ),
                        ),
                        Text(
                          product.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.almarai(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            height: 1.2,
                            color: const Color(0xFF0A2647),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _buildMattressPriceLabel(product),
                          style: GoogleFonts.almarai(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: theme.colorScheme.secondary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'مقاسات متعددة · دعم فِقري',
                          style: GoogleFonts.almarai(
                            fontSize: 10,
                            color: Colors.grey[500],
                          ),
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

  /// منطق عرض السعر الخاص بالفرشات:
  /// - لا نعرض سعراً ثابتاً أو 0
  /// - إن وُجد سعر في المتغيرات نعرض "يبدأ من ..."
  /// - وإلا نعرض "تواصل للسعر"
  String _buildMattressPriceLabel(Product product) {
    // نتأكد أننا نتعامل مع فرشة
    if (product.category != 'mattresses') {
      // fallback احتياطي في حال تم تمرير منتج آخر بالخطأ
      if (product.price > 0) {
        return '${product.price} د.أ';
      }
      return 'تواصل للسعر';
    }

    double? minVariantPrice;
    if (product.variants.isNotEmpty) {
      for (final v in product.variants) {
        if (v.price > 0) {
          if (minVariantPrice == null || v.price < minVariantPrice) {
            minVariantPrice = v.price;
          }
        }
      }
    }

    if (minVariantPrice != null) {
      return 'يبدأ من ${minVariantPrice.toStringAsFixed(0)} د.أ';
    }

    // في حال لم يكن هناك أي سعر صالح، نطلب التواصل للسعر
    return 'تواصل للسعر';
  }

  Widget _buildImage() {
    final originalUrl = product.originalImageUrl;

    // ✅ معالجة حالة الصورة المفقودة أو الفارغة
    if (originalUrl.isEmpty) {
      return Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF283C63), Color(0xFF2B5876)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: const Center(
          child: Icon(
            FontAwesomeIcons.bedPulse,
            color: Colors.white70,
            size: 40,
          ),
        ),
      );
    }

    return CachedNetworkImage(
      imageUrl: buildOptimizedImageUrl(
        originalUrl,
        variant: ImageVariant.productCard,
      ),
      fit: BoxFit.cover,
      memCacheHeight: 320,
      placeholder: (context, url) => const ShimmerImagePlaceholder(),
      errorWidget: (context, url, error) => const Icon(
        Icons.image_not_supported_outlined,
        color: Colors.grey,
      ),
    );
  }
}
