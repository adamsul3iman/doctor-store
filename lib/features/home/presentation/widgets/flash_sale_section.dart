import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:doctor_store/features/product/domain/models/product_model.dart';
import 'package:doctor_store/shared/utils/product_nav_helper.dart';
import 'package:doctor_store/shared/widgets/image_shimmer_placeholder.dart';
import 'package:doctor_store/shared/utils/home_sections_provider.dart';
import 'package:doctor_store/shared/utils/image_url_helper.dart';

class FlashSaleSection extends ConsumerStatefulWidget {
  const FlashSaleSection({super.key});

  @override
  ConsumerState<FlashSaleSection> createState() => _FlashSaleSectionState();
}

class _FlashSaleSectionState extends ConsumerState<FlashSaleSection> {
  late Timer _timer;
  Duration _timeLeft = const Duration(hours: 12, minutes: 45, seconds: 00);

  // نحتفظ بآخر بيانات ناجحة من الستريم لقسم عروض الفلاش
  List<Map<String, dynamic>>? _lastFlashSaleRaw;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel(); // ✅ حماية إضافية
        return;
      }

      setState(() {
        if (_timeLeft.inSeconds > 0) {
          _timeLeft = _timeLeft - const Duration(seconds: 1);
        } else {
          _timer.cancel();
        }
      });
    });
  }

  @override
  void dispose() {
    if (_timer.isActive) {
      _timer.cancel(); // ✅ إلغاء المؤقت ضروري جداً
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sectionsAsync = ref.watch(homeSectionsProvider);
    final sectionsConfig = sectionsAsync.asData?.value;

    String headerTitle = "عروض فلاش 🔥";
    String? headerSubtitle;
    if (sectionsConfig != null) {
      final cfg = sectionsConfig[HomeSectionKeys.flashSale];
      final t = cfg?.title;
      final s = cfg?.subtitle;
      if (t != null && t.trim().isNotEmpty) {
        headerTitle = t.trim();
      }
      if (s != null && s.trim().isNotEmpty) {
        headerSubtitle = s.trim();
      }
    }

    SupabaseClient? client;
    try {
      client = Supabase.instance.client;
    } catch (_) {
      // في حال لم يتم تهيئة Supabase (مثل بيئة الاختبارات) لا نعرض قسم الفلاش سيل
      client = null;
    }

    if (client == null) {
      return const SizedBox();
    }

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: client
          .from('products')
          .stream(primaryKey: ['id'])
          .eq('is_flash_deal', true)
          .order('created_at', ascending: false),
      builder: (context, snapshot) {
        // لا نظهر الخطأ للمستخدم، فقط نطبعه في الكونسول
        if (snapshot.hasError) {
          debugPrint('FlashSaleSection stream error: ${snapshot.error}');
        }

        List<Map<String, dynamic>>? rawProducts;

        if (snapshot.hasData && !snapshot.hasError) {
          rawProducts = snapshot.data;
          _lastFlashSaleRaw = snapshot.data;
        } else if (_lastFlashSaleRaw != null) {
          // في حال انقطاع مؤقت أو خطأ في Realtime نستخدم آخر بيانات ناجحة
          rawProducts = _lastFlashSaleRaw;
        }

        if (rawProducts == null || rawProducts.isEmpty) {
          return const SizedBox();
        }

        final products = rawProducts
            .map((e) => Product.fromJson(e))
            .where((p) => p.isActive)
            .toList();

        // فلترة المنتجات التي لا تحتوي على صورة صالحة حتى لا نعطي القائمة عناصر فارغة
        final visibleProducts = products
            .where((p) => p.imageUrl.isNotEmpty)
            .toList();

        if (visibleProducts.isEmpty) {
          return const SizedBox();
        }

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          FontAwesomeIcons.bolt,
                          color: Colors.orange,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            AutoSizeText(
                              headerTitle,
                              maxLines: 1,
                              minFontSize: 14,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontFamily: 'Almarai',
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0A2647),
                              ),
                            ),
                            if (headerSubtitle != null) ...[
                              const SizedBox(height: 2),
                              AutoSizeText(
                                headerSubtitle,
                                maxLines: 1,
                                minFontSize: 9,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontFamily: 'Almarai',
                                  fontSize: 11,
                                  color: Color(0xFF808080),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            CarouselSlider(
              options: CarouselOptions(
                height:
                    220, // زيادة الارتفاع لمنع الـ overflow مع التصميم الجديد
                autoPlay: true,
                autoPlayInterval: const Duration(seconds: 4),
                enlargeCenterPage: true,
                viewportFraction: 0.92,
                aspectRatio: 16 / 9,
              ),
              items: visibleProducts.map((product) {
                return _buildFlashCard(context, product);
              }).toList(),
            ),
          ],
        );
      },
    );
  }

  /// صورة كرت الفلاش مع معالجة الحالات الفارغة لتفادي أخطاء القوائم/الكاروسيل
  Widget _buildFlashImage(Product product) {
    final rawUrl = product.imageUrl;

    if (rawUrl.isEmpty) {
      return Container(
        color: Colors.grey[200],
        alignment: Alignment.center,
        child: const Icon(
          Icons.image_not_supported_outlined,
          color: Colors.grey,
        ),
      );
    }

    final optimizedUrl = buildOptimizedImageUrl(
      rawUrl,
      variant: ImageVariant.productCard,
    );

    return CachedNetworkImage(
      imageUrl: optimizedUrl,
      fit: BoxFit.cover,
      memCacheHeight: 320,
      fadeInDuration: const Duration(milliseconds: 180),
      fadeOutDuration: Duration.zero,
      placeholder: (c, u) => const ShimmerImagePlaceholder(),
      errorWidget: (c, u, e) => const Icon(Icons.error),
    );
  }

  Widget _buildTimerWidget() {
    final text =
        "${_timeLeft.inHours.toString().padLeft(2, '0')} : ${_timeLeft.inMinutes.remainder(60).toString().padLeft(2, '0')} : ${_timeLeft.inSeconds.remainder(60).toString().padLeft(2, '0')}";

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.timer_outlined, color: Colors.white, size: 14),
          const SizedBox(width: 4),
          Text(
            text,
            style: const TextStyle(
              fontFamily: 'Almarai',
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 11,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFlashCard(BuildContext context, Product product) {
    final double discountPercent = product.oldPrice != null
        ? ((product.oldPrice! - product.price) / product.oldPrice!) * 100
        : 0;

    return GestureDetector(
      onTap: () =>
          context.push(buildProductDetailsPath(product), extra: product),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        height: 200, // ارتفاع ثابت لضمان توحيد المقاس لكل الكروت
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF0F2027), Color(0xFF203A43)],
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 10,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              right: -30,
              bottom: -30,
              child: Icon(
                FontAwesomeIcons.gift,
                size: 150,
                color: Colors.white.withValues(alpha: 0.04),
              ),
            ),
            Row(
              children: [
                // الجانب الأيمن: صورة المنتج مع المؤقت فوقها
                Flexible(
                  flex: 9,
                  child: Padding(
                    padding: const EdgeInsetsDirectional.only(
                      start: 14,
                      top: 18,
                      bottom: 18,
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.8),
                          width: 1,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            _buildFlashImage(product),
                            // المؤقت في أسفل منتصف الصورة
                            Align(
                              alignment: Alignment.bottomCenter,
                              child: Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: _buildTimerWidget(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // الجانب الأيسر: المعلومات
                Flexible(
                  flex: 11,
                  child: Padding(
                    padding: const EdgeInsetsDirectional.only(
                      start: 12,
                      end: 16,
                      top: 18,
                      bottom: 18,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        if (discountPercent > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orange,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              "خصم ${discountPercent.toStringAsFixed(0)}%",
                              style: const TextStyle(
                                fontFamily: 'Almarai',
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),

                        // العنوان (حتى سطرين)
                        Flexible(
                          child: Text(
                            product.title,
                            style: const TextStyle(
                              fontFamily: 'Almarai',
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),

                        // الأسعار
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              "${product.price} د.أ",
                              style: const TextStyle(
                                color: Color(0xFFD4AF37),
                                fontWeight: FontWeight.w800,
                                fontSize: 22,
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (product.oldPrice != null)
                              Text(
                                "${product.oldPrice} د.أ",
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.5),
                                  decoration: TextDecoration.lineThrough,
                                  fontSize: 11,
                                ),
                              ),
                          ],
                        ),

                        // زر أطلب الآن
                        Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: TextButton(
                            onPressed: () => context.push(
                              buildProductDetailsPath(product),
                              extra: product,
                            ),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 18,
                                vertical: 8,
                              ),
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.black,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(999),
                              ),
                              textStyle: const TextStyle(
                                fontFamily: 'Almarai',
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            child: const Text('أطلب الآن'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
