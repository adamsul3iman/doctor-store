import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'dart:async';
import 'dart:math' as math;
import 'package:doctor_store/features/product/domain/models/product_model.dart';
import 'package:doctor_store/shared/utils/image_url_helper.dart';
import 'package:doctor_store/shared/utils/product_nav_helper.dart';
import 'package:doctor_store/shared/widgets/app_network_image.dart';
import 'package:doctor_store/shared/widgets/image_shimmer_placeholder.dart';

class LiveActivitySection extends ConsumerStatefulWidget {
  final List<Product> products;

  const LiveActivitySection({
    super.key,
    required this.products,
  });

  @override
  ConsumerState<LiveActivitySection> createState() =>
      _LiveActivitySectionState();
}

class _LiveActivitySectionState extends ConsumerState<LiveActivitySection> {
  Timer? _timer;
  int _currentIndex = 0;
  final _random = math.Random();

  // أسماء عربية شائعة
  static const _names = [
    'أحمد',
    'محمد',
    'سارة',
    'فاطمة',
    'علي',
    'مريم',
    'خالد',
    'نور',
    'يوسف',
    'هدى',
    'عمر',
    'ريم',
    'حسن',
    'لينا',
    'كريم',
  ];

  // مدن أردنية
  static const _cities = [
    'عمان',
    'إربد',
    'الزرقاء',
    'السلط',
    'العقبة',
    'مادبا',
    'جرش',
    'عجلون',
    'الكرك',
    'معان',
  ];

  // أنواع النشاطات
  static const _activities = [
    'اشترى',
    'أضاف للسلة',
    'يشاهد',
  ];

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 8), (_) {
      if (mounted && widget.products.isNotEmpty) {
        setState(() {
          _currentIndex = (_currentIndex + 1) % widget.products.length;
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _generateActivity() {
    final name = _names[_random.nextInt(_names.length)];
    final city = _cities[_random.nextInt(_cities.length)];
    final activity = _activities[_random.nextInt(_activities.length)];
    final minutesAgo = _random.nextInt(30) + 1;

    return '$name من $city $activity هذا المنتج منذ $minutesAgo دقيقة';
  }

  @override
  Widget build(BuildContext context) {
    if (widget.products.isEmpty) {
      return const SizedBox.shrink();
    }

    final displayProducts = widget.products.take(5).toList();
    final currentProduct =
        displayProducts[_currentIndex % displayProducts.length];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF4CAF50).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.circle,
                  size: 12,
                  color: Color(0xFF4CAF50),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'نشاط حي - الطلبات الأخيرة',
                style: GoogleFonts.almarai(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF0A2647),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 500),
            transitionBuilder: (child, animation) {
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.1),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              );
            },
            child: _buildActivityCard(
              context,
              currentProduct,
              key: ValueKey(_currentIndex),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityCard(
    BuildContext context,
    Product product, {
    Key? key,
  }) {
    return GestureDetector(
      key: key,
      onTap: () => context.push(
        buildProductDetailsPath(product),
        extra: product,
      ),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color(0xFF4CAF50).withValues(alpha: 0.3),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF4CAF50).withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // صورة المنتج
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 60,
                height: 60,
                child: AppNetworkImage(
                  url: product.originalImageUrl,
                  variant: ImageVariant.thumbnail,
                  fit: BoxFit.cover,
                  placeholder: const ShimmerImagePlaceholder(),
                  errorWidget: Container(
                    width: 60,
                    height: 60,
                    color: Colors.grey[200],
                    child: const Icon(
                      Icons.image_not_supported_outlined,
                      color: Colors.grey,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // معلومات النشاط
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF4CAF50),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'نشاط جديد',
                          style: GoogleFonts.almarai(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _generateActivity(),
                    style: GoogleFonts.almarai(
                      fontSize: 12,
                      color: const Color(0xFF0A2647),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    product.title,
                    style: GoogleFonts.almarai(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF0A2647),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            // السعر
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFF0A2647).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${product.price.toStringAsFixed(0)} د.أ',
                style: GoogleFonts.almarai(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF0A2647),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
