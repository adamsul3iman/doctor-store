import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'dart:async';
import 'package:doctor_store/features/product/domain/models/product_model.dart';
import 'package:doctor_store/shared/utils/image_url_helper.dart';
import 'package:doctor_store/shared/utils/product_nav_helper.dart';
import 'package:doctor_store/shared/widgets/image_shimmer_placeholder.dart';
import 'package:doctor_store/shared/widgets/app_network_image.dart';

class UrgencyDealsSection extends ConsumerStatefulWidget {
  final List<Product> products;
  final DateTime? dealEndTime;

  const UrgencyDealsSection({
    super.key,
    required this.products,
    this.dealEndTime,
  });

  @override
  ConsumerState<UrgencyDealsSection> createState() =>
      _UrgencyDealsSectionState();
}

class _UrgencyDealsSectionState extends ConsumerState<UrgencyDealsSection> {
  Timer? _timer;
  Duration _remaining = Duration.zero;

  @override
  void initState() {
    super.initState();
    _calculateRemaining();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          _calculateRemaining();
        });
      }
    });
  }

  void _calculateRemaining() {
    final endTime = widget.dealEndTime ??
        DateTime.now().add(const Duration(hours: 6)); // 6 ساعات افتراضياً
    _remaining = endTime.difference(DateTime.now());
    if (_remaining.isNegative) {
      _remaining = Duration.zero;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.products.isEmpty) {
      return const SizedBox.shrink();
    }

    final hours = _remaining.inHours;
    final minutes = _remaining.inMinutes.remainder(60);
    final seconds = _remaining.inSeconds.remainder(60);

    // نعرض فقط أول 6 منتجات
    final displayProducts = widget.products.take(6).toList();

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFFD32F2F),
            Color(0xFFFF6F00),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFD32F2F).withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          // الهيدر مع العداد التنازلي
          Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.local_fire_department,
                      color: Colors.white,
                      size: 24,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'عروض محدودة - لا تفوتك الفرصة!',
                        style: GoogleFonts.almarai(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // العداد التنازلي
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'ينتهي العرض خلال:',
                      style: GoogleFonts.almarai(
                        fontSize: 13,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _buildTimeUnit(hours, 'ساعة'),
                    _buildTimeSeparator(),
                    _buildTimeUnit(minutes, 'دقيقة'),
                    _buildTimeSeparator(),
                    _buildTimeUnit(seconds, 'ثانية'),
                  ],
                ),
              ],
            ),
          ),
          // المنتجات
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: SizedBox(
              height: 220,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                itemCount: displayProducts.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final product = displayProducts[index];
                  return _buildDealCard(context, product);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeUnit(int value, String label) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.3),
              width: 2,
            ),
          ),
          child: Text(
            value.toString().padLeft(2, '0'),
            style: GoogleFonts.almarai(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.almarai(
            fontSize: 10,
            color: Colors.white.withValues(alpha: 0.8),
          ),
        ),
      ],
    );
  }

  Widget _buildTimeSeparator() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        ':',
        style: GoogleFonts.almarai(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildDealCard(BuildContext context, Product product) {
    final discount = product.oldPrice != null && product.oldPrice! > product.price
        ? ((product.oldPrice! - product.price) / product.oldPrice! * 100).round()
        : 0;

    return GestureDetector(
      onTap: () => context.push(
        buildProductDetailsPath(product),
        extra: product,
      ),
      child: Container(
        width: 160,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color(0xFFD32F2F).withValues(alpha: 0.3),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // الصورة
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(10),
                  ),
                  child: SizedBox(
                    height: 120,
                    width: double.infinity,
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
                ),
                if (discount > 0)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD32F2F),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '-$discount%',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            // التفاصيل
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.title,
                    style: GoogleFonts.almarai(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF0A2647),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (product.oldPrice != null)
                        Text(
                          '${product.oldPrice!.toStringAsFixed(0)} د.أ',
                          style: const TextStyle(
                            fontSize: 10,
                            decoration: TextDecoration.lineThrough,
                            color: Colors.grey,
                          ),
                        ),
                      const SizedBox(width: 4),
                      Text(
                        '${product.price.toStringAsFixed(0)} د.أ',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFD32F2F),
                        ),
                      ),
                    ],
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
