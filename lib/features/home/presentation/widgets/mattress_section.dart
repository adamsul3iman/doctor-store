import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import 'package:doctor_store/features/product/domain/models/product_model.dart';
import 'package:doctor_store/shared/utils/image_url_helper.dart';
import 'package:doctor_store/shared/utils/product_nav_helper.dart';
import 'package:doctor_store/shared/widgets/image_shimmer_placeholder.dart';
import 'package:doctor_store/shared/widgets/app_network_image.dart';
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

          // إذا كان هناك فرشة واحدة فقط: نعرض بطاقة عريضة (Hero) لتفادي المساحة الفارغة
          if (mattresses.length == 1)
            _MattressHeroCard(product: mattresses.first)
          else
            SizedBox(
              height: 250,
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

class _MattressHeroCard extends StatelessWidget {
  final Product product;

  const _MattressHeroCard({required this.product});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ClipRRect(
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
              SizedBox(
                height: 190,
                width: double.infinity,
                child: _buildImage(),
              ),
              Padding(
                padding: const EdgeInsets.all(14.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'فرشة طبية',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            product.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.almarai(
                              fontWeight: FontWeight.w900,
                              fontSize: 15,
                              height: 1.15,
                              color: const Color(0xFF0A2647),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'مقاسات متعددة · دعم فِقري',
                            style: GoogleFonts.almarai(
                              fontSize: 11,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.secondary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _buildMattressPriceLabel(product),
                        style: GoogleFonts.almarai(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          color: theme.colorScheme.secondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _buildMattressPriceLabel(Product product) {
    if (product.category != 'mattresses') {
      if (product.price > 0) return '${product.price.toStringAsFixed(0)} د.أ';
      return 'تواصل للسعر';
    }

    final autoMin = product.mattressMinUnitPrice;
    if (autoMin != null && autoMin > 0) {
      return 'يبدأ من ${autoMin.toStringAsFixed(0)} د.أ';
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

    return 'تواصل للسعر';
  }

  Widget _buildImage() {
    final originalUrl = product.originalImageUrl;
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
            size: 48,
          ),
        ),
      );
    }

    return AppNetworkImage(
      url: originalUrl,
      variant: ImageVariant.mattressCard,
      fit: BoxFit.cover,
      placeholder: const ShimmerImagePlaceholder(),
      errorWidget: const Icon(
        Icons.image_not_supported_outlined,
        color: Colors.grey,
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
      width: 230,
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
                // صورة بعرض البطاقة بالكامل (بدون إطار/هوامش)
                SizedBox(
                  height: 140,
                  width: double.infinity,
                  child: _buildImage(),
                ),
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'فرشة طبية',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        product.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.almarai(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          height: 1.2,
                          color: const Color(0xFF0A2647),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _buildMattressPriceLabel(product),
                        style: GoogleFonts.almarai(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: theme.colorScheme.secondary,
                        ),
                      ),
                      const SizedBox(height: 6),
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
        return '${product.price.toStringAsFixed(0)} د.أ';
      }
      return 'تواصل للسعر';
    }

    // ✅ أولوية لتسعير الفرشات التلقائي إن وجد
    final autoMin = product.mattressMinUnitPrice;
    if (autoMin != null && autoMin > 0) {
      return 'يبدأ من ${autoMin.toStringAsFixed(0)} د.أ';
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

    // صورة بعرض الحاوية بالكامل
    return AppNetworkImage(
      url: originalUrl,
      variant: ImageVariant.mattressCard,
      fit: BoxFit.cover,
      alignment: Alignment.center,
      placeholder: const ShimmerImagePlaceholder(),
      errorWidget: const Icon(
        Icons.image_not_supported_outlined,
        color: Colors.grey,
      ),
    );
  }
}
