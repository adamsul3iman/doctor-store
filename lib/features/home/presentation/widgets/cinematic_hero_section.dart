import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:google_fonts/google_fonts.dart'; // ⚠️ REMOVED for smaller bundle
import 'package:shimmer/shimmer.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:doctor_store/shared/models/banner_model.dart';
import 'package:doctor_store/shared/utils/image_url_helper.dart';
import 'package:doctor_store/shared/widgets/app_network_image.dart';
import 'package:doctor_store/shared/repositories/banner_repository.dart';

// مزود لجلب البانرات المفعلة
final activeBannersProvider = FutureProvider<List<AppBanner>>((ref) async {
  return BannerRepository().fetchActiveBanners();
});

// مزود لـ Preload صور البانرات
final bannerImagesPreloaderProvider = FutureProvider.family<void, List<AppBanner>>((ref, banners) async {
  if (banners.isEmpty) return;
  
  // Preload image URLs into cache manager in parallel
  final cacheManager = DefaultCacheManager();
  final List<Future<dynamic>> preloadFutures = banners
      .where((b) => b.imageUrl.isNotEmpty)
      .map((b) => cacheManager.getSingleFile(b.imageUrl))
      .toList();
  
  // Use error-aware waiting - failures don't block successful loads
  await Future.wait(
    preloadFutures.map((f) => f.catchError((_) {})).toList(),
    eagerError: false,
  );
});

class CinematicHeroSection extends ConsumerStatefulWidget {
  const CinematicHeroSection({super.key});

  @override
  ConsumerState<CinematicHeroSection> createState() => _CinematicHeroSectionState();
}

class _CinematicHeroSectionState extends ConsumerState<CinematicHeroSection>
    with TickerProviderStateMixin {
  int _currentPage = 0;
  late PageController _pageController;
  Timer? _timer;
  late AnimationController _floatingController;
  late AnimationController _glowController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
    
    // ✅ تحسين: تعطيل Animations على Web للأداء الأفضل
    final isWeb = kIsWeb;
    _floatingController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    
    // ✅ تشغيل الأنيميشن فقط إذا لم يكن Web
    if (!isWeb) {
      _floatingController.repeat(reverse: true);
      _glowController.repeat(reverse: true);
    }
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startAutoPlay();
    });
  }

  void _startAutoPlay() {
    // تعطيل التشغيل التلقائي على جميع المنصات للأداء الأفضل
    return;
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    _floatingController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  void _handleNavigation(String? target) {
    if (target != null && target.isNotEmpty) {
      context.push(target);
    } else {
      context.push('/all_products');
    }
  }

  @override
  Widget build(BuildContext context) {
    final bannersAsync = ref.watch(activeBannersProvider);
    
    // Preload banner images when data is loaded
    bannersAsync.whenData((banners) {
      if (banners.isNotEmpty) {
        ref.read(bannerImagesPreloaderProvider(banners));
      }
    });

    return SizedBox(
      height: 320,
      child: bannersAsync.when(
        data: (banners) {
          if (banners.isEmpty) {
            return _buildFallbackHero(context);
          }

          return Stack(
            children: [
              PageView.builder(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index % banners.length;
                  });
                },
                itemBuilder: (context, index) {
                  final banner = banners[index % banners.length];
                  return _buildModernHeroPage(context, banner, index % banners.length == _currentPage);
                },
              ),
              
              // مؤشرات احترافية
              Positioned(
                bottom: 24,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(banners.length, (index) {
                    final isActive = index == _currentPage;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.easeOutCubic,
                      width: isActive ? 32 : 8,
                      height: 8,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        color: isActive 
                            ? const Color(0xFFD4AF37)
                            : Colors.white.withValues(alpha: 0.4),
                        boxShadow: isActive ? [
                          BoxShadow(
                            color: const Color(0xFFD4AF37).withValues(alpha: 0.5),
                            blurRadius: 8,
                            spreadRadius: 1,
                          ),
                        ] : null,
                      ),
                    );
                  }),
                ),
              ),
            ],
          );
        },
        loading: () => Shimmer.fromColors(
          baseColor: Colors.grey[300]!,
          highlightColor: Colors.grey[100]!,
          child: Container(color: Colors.white),
        ),
        error: (e, s) => const Center(child: Text("خطأ في تحميل البانرات")),
      ),
    );
  }

  Widget _buildModernHeroPage(BuildContext context, AppBanner banner, bool isActive) {
    final disableEffects = kIsWeb || MediaQuery.of(context).disableAnimations;

    return GestureDetector(
      onTap: () => _handleNavigation(banner.linkTarget),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // الخلفية مع تأثير التكبير البطيء
          AnimatedScale(
            scale: disableEffects ? 1.0 : (isActive ? 1.08 : 1.0),
            duration: disableEffects ? Duration.zero : const Duration(seconds: 8),
            curve: Curves.easeOutQuad,
            child: AppNetworkImage(
              url: banner.imageUrl,
              variant: ImageVariant.heroBanner,
              fit: BoxFit.cover,
              placeholder: Container(color: Colors.grey[200]),
              errorWidget: const Icon(Icons.broken_image, color: Colors.grey),
            ),
          ),
          
          // تدرج متدرج غير متماثل
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF0A2647).withValues(alpha: 0.9),
                  const Color(0xFF0A2647).withValues(alpha: 0.4),
                  Colors.transparent,
                  const Color(0xFF0A2647).withValues(alpha: 0.2),
                ],
                begin: Alignment.bottomLeft,
                end: Alignment.topRight,
                stops: const [0.0, 0.3, 0.6, 1.0],
              ),
            ),
          ),

          // شكل منحني زخرفي
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 120,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFFF8F9FA).withValues(alpha: 0.3),
                    Colors.transparent,
                  ],
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                ),
              ),
            ),
          ),

          // المحتوى الرئيسي - كارت زجاجي
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // شارة عائمة
                AnimatedBuilder(
                  animation: _floatingController,
                  builder: (context, child) {
                    return Transform.translate(
                      offset: Offset(0, math.sin(_floatingController.value * math.pi) * 4),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              const Color(0xFFD4AF37),
                              const Color(0xFFB8960C),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFD4AF37).withValues(alpha: 0.4),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.local_offer_rounded, color: Colors.white, size: 14),
                            const SizedBox(width: 6),
                            Text(
                              'عرض خاص',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 12),

                // كارت زجاجي للنصوص
                ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.white.withValues(alpha: 0.15),
                          Colors.white.withValues(alpha: 0.05),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.2),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // العنوان
                        AnimatedOpacity(
                          duration: const Duration(milliseconds: 600),
                          opacity: isActive ? 1.0 : 0.0,
                          child: Text(
                            banner.title,
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              height: 1.2,
                              shadows: [
                                Shadow(
                                  offset: const Offset(0, 4),
                                  blurRadius: 12,
                                  color: Colors.black.withValues(alpha: 0.3),
                                ),
                              ],
                            ),
                          ),
                        ),
                        
                        const SizedBox(height: 8),
                        
                        // الوصف
                        AnimatedOpacity(
                          duration: const Duration(milliseconds: 800),
                          opacity: isActive ? 1.0 : 0.0,
                          child: Text(
                            banner.subtitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white.withValues(alpha: 0.9),
                              height: 1.5,
                            ),
                          ),
                        ),
                        
                        const SizedBox(height: 12),
                        
                        // زر احترافي متوهج
                        AnimatedBuilder(
                          animation: _glowController,
                          builder: (context, child) {
                            return Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(30),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFFD4AF37).withValues(
                                      alpha: 0.3 + (_glowController.value * 0.3),
                                    ),
                                    blurRadius: 15 + (_glowController.value * 10),
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: ElevatedButton.icon(
                                onPressed: () => _handleNavigation(banner.linkTarget),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: const Color(0xFF0A2647),
                                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                ),
                                icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                                label: Text(
                                  banner.buttonText.isNotEmpty ? banner.buttonText : 'اكتشف المزيد',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFallbackHero(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF0A2647),
            const Color(0xFF144272),
            const Color(0xFF0A2647),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          // دوائر زخرفية متحركة
          Positioned(
            top: -50,
            right: -50,
            child: AnimatedBuilder(
              animation: _floatingController,
              builder: (context, child) {
                return Transform.scale(
                  scale: 1.0 + (_floatingController.value * 0.1),
                  child: Container(
                    width: 200,
                    height: 200,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          const Color(0xFFD4AF37).withValues(alpha: 0.3),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          
          Center(
            child: Padding(
              padding: const EdgeInsets.all(30.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset('assets/images/logo.png', height: 60),
                  const SizedBox(height: 24),
                  Text(
                    'أفضل مستلزمات المنزل',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      shadows: [
                        Shadow(
                          offset: const Offset(0, 4),
                          blurRadius: 12,
                          color: Colors.black.withValues(alpha: 0.3),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'جودة عالية، أسعار مميزة، توصيل سريع',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 30),
                  ElevatedButton.icon(
                    onPressed: () => context.push('/all_products'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD4AF37),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    icon: const Icon(Icons.explore, size: 20),
                    label: Text(
                      'تصفح المنتجات',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}