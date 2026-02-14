import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';

import 'package:doctor_store/features/product/domain/models/product_model.dart';
import 'package:doctor_store/shared/utils/image_url_helper.dart';
import 'package:doctor_store/shared/utils/product_nav_helper.dart';
import 'package:doctor_store/shared/widgets/image_shimmer_placeholder.dart';
import 'package:doctor_store/shared/widgets/app_network_image.dart';

/// شريط سحب سريع لعروض الوسائد (المخدات).
/// يعتمد على قائمة المنتجات القادمة من الصفحة الرئيسية بدون أي جلب بيانات إضافي.
class PillowCarousel extends StatelessWidget {
  final List<Product> products;

  const PillowCarousel({super.key, required this.products});

  @override
  Widget build(BuildContext context) {
    final pillows = products
        .where((p) => p.category == 'pillows')
        .toList();

    if (pillows.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // مسافة علوية بسيطة حتى لا يلتصق القسم بما قبله (مثل عروض فلاش)
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(
                    FontAwesomeIcons.cloudMoon,
                    color: Color(0xFF0A2647),
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'وسائد لنوم أحلى',
                    style: GoogleFonts.almarai(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0A2647),
                    ),
                  ),
                ],
              ),
              Text(
                'سحب سريع',
                style: GoogleFonts.almarai(
                  fontSize: 11,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // ارتفاع متوسط لبطاقة وسادة خفيفة بصرياً (زيادة بسيطة لمنع overflow في وضع debug)
        SizedBox(
          height: 200,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            cacheExtent: 800.0,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: pillows.length,
            itemBuilder: (context, index) {
              final product = pillows[index];
              return _PillowCard(product: product);
            },
          ),
        ),
      ],
    );
  }
}

class _PillowCard extends StatelessWidget {
  final Product product;

  const _PillowCard({required this.product});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 140,
      margin: const EdgeInsetsDirectional.only(end: 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
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
                // مساحة ثابتة لصورة الوسادة حتى تملأ العرض بالكامل بدون فراغ داخلي
                SizedBox(
                  height: 120,
                  width: double.infinity,
                  child: _buildImage(),
                ),
                const SizedBox(height: 4),
                Flexible(
                  fit: FlexFit.loose,
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'مخدة',
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
                            fontSize: 12,
                            height: 1.2,
                            color: const Color(0xFF0A2647),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${product.price.toStringAsFixed(0)} د.أ',
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 13,
                            color: Color(0xFF0A2647),
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

  Widget _buildImage() {
    final originalUrl = product.originalImageUrl;

    // ✅ معالجة حالة الصورة المفقودة أو الفارغة
    if (originalUrl.isEmpty) {
      return Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFE3F2FD), Color(0xFFBBDEFB)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: const Center(
          child: Icon(
            FontAwesomeIcons.cloud,
            color: Color(0xFF0A2647),
            size: 32,
          ),
        ),
      );
    }

    return AppNetworkImage(
      url: originalUrl,
      variant: ImageVariant.productCard,
      fit: BoxFit.cover,
      placeholder: const ShimmerImagePlaceholder(),
      errorWidget: const Icon(
        Icons.image_not_supported_outlined,
        color: Colors.grey,
      ),
    );
  }
}
