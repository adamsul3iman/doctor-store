import 'dart:async';

import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:doctor_store/features/product/domain/models/product_model.dart';
import 'package:doctor_store/shared/services/supabase_service.dart';
import 'package:doctor_store/shared/utils/home_sections_provider.dart';
import 'package:doctor_store/shared/utils/image_url_helper.dart';
import 'package:doctor_store/shared/utils/product_nav_helper.dart';
import 'package:doctor_store/shared/widgets/app_network_image.dart';
import 'package:doctor_store/shared/widgets/image_shimmer_placeholder.dart';
import 'package:doctor_store/shared/widgets/responsive_center_wrapper.dart';

final modernFlashDealProductsProvider = FutureProvider<List<Product>>((ref) async {
  return SupabaseService().getFlashDealProducts();
});

class ModernFlashSaleBanner extends ConsumerStatefulWidget {
  const ModernFlashSaleBanner({super.key});

  @override
  ConsumerState<ModernFlashSaleBanner> createState() =>
      _ModernFlashSaleBannerState();
}

class _ModernFlashSaleBannerState extends ConsumerState<ModernFlashSaleBanner>
    with TickerProviderStateMixin {
  Timer? _timer;
  final ValueNotifier<Duration> _timeLeft =
      ValueNotifier<Duration>(const Duration(hours: 12, minutes: 45));
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      final next = _timeLeft.value - const Duration(seconds: 1);
      if (next.inSeconds >= 0) {
        _timeLeft.value = next;
      } else {
        _timer?.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _timeLeft.dispose();
    super.dispose();
  }

  void _setIndex(int index, int itemCount) {
    if (itemCount <= 0) return;
    final next = index.clamp(0, itemCount - 1);
    if (next == _currentIndex) return;
    setState(() => _currentIndex = next);
  }

  Widget _buildShopNowButton(BuildContext context, Product heroProduct) {
    return InkWell(
      onTap: () => context.push(
        buildProductDetailsPath(heroProduct),
        extra: heroProduct,
      ),
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          color: Colors.white,
          boxShadow: const [
            BoxShadow(
              color: Color(0x0A000000),
              blurRadius: 8,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'تسوق الآن',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color: const Color(0xFF0A2647),
              ),
            ),
            const SizedBox(width: 6),
            const Icon(
              Icons.arrow_back,
              size: 16,
              color: Color(0xFF0A2647),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sectionsAsync = ref.watch(homeSectionsProvider);
    final sectionsConfig = sectionsAsync.asData?.value;
    final flashAsync = ref.watch(modernFlashDealProductsProvider);

    String headerTitle = "عروض فلاش";
    String headerSubtitle = "سارع قبل نفاد الكمية";
    if (sectionsConfig != null) {
      final cfg = sectionsConfig[HomeSectionKeys.flashSale];
      final t = cfg?.title;
      final s = cfg?.subtitle;
      if (t != null && t.trim().isNotEmpty) headerTitle = t.trim();
      if (s != null && s.trim().isNotEmpty) headerSubtitle = s.trim();
    }

    return flashAsync.when(
      data: (products) {
        final visible = products.where((p) => p.imageUrl.isNotEmpty).toList();
        if (visible.isEmpty) return const SizedBox.shrink();

        if (_currentIndex >= visible.length) {
          _currentIndex = 0;
        }

        final heroProduct = visible[_currentIndex];
        final discountPercent = (heroProduct.oldPrice != null &&
                heroProduct.oldPrice! > heroProduct.price)
            ? (((heroProduct.oldPrice! - heroProduct.price) /
                        heroProduct.oldPrice!) *
                    100)
                .round()
            : 0;

        return LayoutBuilder(
          builder: (context, constraints) {
            final isDesktop = constraints.maxWidth >= 900;
            final bannerHeight = isDesktop ? 280.0 : 200.0;
            final imageWidth = isDesktop ? 200.0 : 120.0;
            final imageHeight = isDesktop ? 200.0 : 120.0;

            final banner = Container(
              height: bannerHeight,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFFFF6F00),
                    Color(0xFFD32F2F),
                    Color(0xFF7B1FA2),
                  ],
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x2ED32F2F),
                    blurRadius: 18,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: RadialGradient(
                              center: Alignment.topLeft,
                              radius: 1.3,
                              colors: [
                                Colors.white.withValues(alpha: 0.12),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (isDesktop)
                      Positioned(
                        top: 16,
                        left: 16,
                        child: ValueListenableBuilder<Duration>(
                          valueListenable: _timeLeft,
                          builder: (context, d, _) {
                            return _CountdownPills(
                              hours: d.inHours,
                              minutes: d.inMinutes.remainder(60),
                              seconds: d.inSeconds.remainder(60),
                              isDesktop: true,
                            );
                          },
                        ),
                      ),
                    Positioned.fill(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                          isDesktop ? 28 : 16,
                          isDesktop ? 22 : 16,
                          isDesktop ? 28 : 16,
                          isDesktop ? 20 : 16,
                        ),
                        child: Directionality(
                          textDirection: TextDirection.rtl,
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    if (!isDesktop)
                                      ValueListenableBuilder<Duration>(
                                        valueListenable: _timeLeft,
                                        builder: (context, d, _) {
                                          return _CountdownPills(
                                            hours: d.inHours,
                                            minutes: d.inMinutes.remainder(60),
                                            seconds: d.inSeconds.remainder(60),
                                            isDesktop: false,
                                          );
                                        },
                                      ),
                                    if (!isDesktop) const SizedBox(height: 12),
                                    AutoSizeText(
                                      headerTitle,
                                      maxLines: 1,
                                      minFontSize: isDesktop ? 20 : 16,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: isDesktop ? 28 : 20,
                                        fontWeight: FontWeight.w900,
                                        color: Colors.white,
                                        height: 1.2,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      headerSubtitle,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: isDesktop ? 16 : 13,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white.withValues(alpha: 0.90),
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    if (discountPercent > 0)
                                      Row(
                                        children: [
                                          Text(
                                            '$discountPercent%',
                                            style: TextStyle(
                                              fontSize: isDesktop ? 48 : 32,
                                              fontWeight: FontWeight.w900,
                                              color: Colors.white,
                                              height: 0.95,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            'خصم',
                                            style: TextStyle(
                                              fontSize: isDesktop ? 20 : 14,
                                              fontWeight: FontWeight.w800,
                                              color: Colors.white.withValues(alpha: 0.95),
                                            ),
                                          ),
                                        ],
                                      ),
                                    const SizedBox(height: 12),
                                    Flexible(
                                      child: AutoSizeText(
                                        heroProduct.title,
                                        maxLines: 2,
                                        minFontSize: 12,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: isDesktop ? 16 : 13,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    _buildShopNowButton(context, heroProduct),
                                  ],
                                ),
                              ),
                              if (isDesktop) const SizedBox(width: 20),
                              if (isDesktop)
                                Container(
                                  width: imageWidth,
                                  height: imageHeight,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: const [
                                      BoxShadow(
                                        color: Color(0x2A000000),
                                        blurRadius: 12,
                                        offset: Offset(0, 6),
                                      ),
                                    ],
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(16),
                                    child: AppNetworkImage(
                                      url: heroProduct.imageUrl,
                                      variant: ImageVariant.productCard,
                                      fit: BoxFit.cover,
                                      placeholder: const ShimmerImagePlaceholder(
                                        width: 200,
                                        height: 200,
                                      ),
                                      errorWidget: Container(
                                        width: imageWidth,
                                        height: imageHeight,
                                        decoration: BoxDecoration(
                                          color: Colors.grey.withValues(alpha: 0.2),
                                          borderRadius: BorderRadius.circular(16),
                                        ),
                                        child: const Icon(
                                          Icons.broken_image,
                                          color: Colors.white54,
                                          size: 40,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (!isDesktop)
                      Positioned(
                        bottom: 16,
                        right: 16,
                        child: Container(
                          width: imageWidth,
                          height: imageHeight,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x2A000000),
                                blurRadius: 10,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: AppNetworkImage(
                              url: heroProduct.imageUrl,
                              variant: ImageVariant.productCard,
                              fit: BoxFit.cover,
                              placeholder: const ShimmerImagePlaceholder(
                                width: 120,
                                height: 120,
                              ),
                              errorWidget: Container(
                                width: imageWidth,
                                height: imageHeight,
                                decoration: BoxDecoration(
                                  color: Colors.grey.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.broken_image,
                                  color: Colors.white54,
                                  size: 32,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    if (visible.length > 1)
                      Positioned(
                        bottom: 12,
                        left: 16,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: List.generate(visible.length, (i) {
                            final isActive = i == _currentIndex;
                            return InkWell(
                              onTap: () => _setIndex(i, visible.length),
                              borderRadius: BorderRadius.circular(999),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 220),
                                margin: const EdgeInsetsDirectional.only(end: 6),
                                width: isActive ? 16 : 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(999),
                                  color: isActive
                                      ? Colors.white
                                      : Colors.white.withValues(alpha: 0.40),
                                ),
                              ),
                            );
                          }),
                        ),
                      ),
                  ],
                ),
              ),
            );

            return ResponsiveCenterWrapper(
              maxWidth: 1100,
              child: banner,
            );
          },
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (e, s) => const SizedBox.shrink(),
    );
  }
}

class _CountdownPills extends StatelessWidget {
  final int hours;
  final int minutes;
  final int seconds;
  final bool isDesktop;

  const _CountdownPills({
    required this.hours,
    required this.minutes,
    required this.seconds,
    required this.isDesktop,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.20),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _TimeBox(value: hours, label: 'ساعة', isDesktop: isDesktop),
          const SizedBox(width: 4),
          _TimeBox(value: minutes, label: 'دقيقة', isDesktop: isDesktop),
          const SizedBox(width: 4),
          _TimeBox(value: seconds, label: 'ثانية', isDesktop: isDesktop),
        ],
      ),
    );
  }
}

class _TimeBox extends StatelessWidget {
  final int value;
  final String label;
  final bool isDesktop;

  const _TimeBox({
    required this.value,
    required this.label,
    required this.isDesktop,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value.toString().padLeft(2, '0'),
          style: TextStyle(
            fontSize: isDesktop ? 16 : 13,
            fontWeight: FontWeight.w900,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: isDesktop ? 10 : 8,
            fontWeight: FontWeight.w700,
            color: Colors.white.withValues(alpha: 0.80),
          ),
        ),
      ],
    );
  }
}
