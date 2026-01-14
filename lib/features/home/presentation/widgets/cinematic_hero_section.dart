import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import 'package:go_router/go_router.dart'; // ✅ ضروري للتنقل
import 'package:doctor_store/shared/models/banner_model.dart';
import 'package:doctor_store/shared/utils/image_url_helper.dart';

// مزود لجلب البانرات المفعلة
final activeBannersProvider = FutureProvider<List<AppBanner>>((ref) async {
  SupabaseClient? supabase;
  try {
    supabase = Supabase.instance.client;
  } catch (_) {
    // في بيئات الاختبار أو قبل تهيئة Supabase نرجع قائمة فارغة
    return <AppBanner>[];
  }

  final data = await supabase
      .from('banners')
      .select()
      .eq('is_active', true)
      .order('sort_order', ascending: true);

  return data.map((e) => AppBanner.fromJson(e)).toList();
});

class CinematicHeroSection extends ConsumerStatefulWidget {
  const CinematicHeroSection({super.key});

  @override
  ConsumerState<CinematicHeroSection> createState() => _CinematicHeroSectionState();
}

class _CinematicHeroSectionState extends ConsumerState<CinematicHeroSection> {
  int _currentPage = 0;
  late PageController _pageController;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startAutoPlay();
    });
  }

  void _startAutoPlay() {
    // لا نبدأ التشغيل التلقائي إلا إذا كان هناك أكثر من بانر لتقليل العمل غير الضروري
    final state = ref.read(activeBannersProvider);
    final banners = state.value;
    if (banners == null || banners.length < 2) return;

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (!_pageController.hasClients) return;

      final currentState = ref.read(activeBannersProvider);
      final currentBanners = currentState.value;
      if (currentBanners == null || currentBanners.isEmpty) return;

      // استخدام modulo للتنقل السلس بين الصفحات بدون قفزات مفاجئة
      _currentPage = (_currentPage + 1) % currentBanners.length;
      _pageController.animateToPage(
        _currentPage,
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  // ✅ دالة للتنقل الذكي
  void _handleNavigation(String? target) {
    if (target != null && target.isNotEmpty) {
      // إذا كان الرابط موجوداً في البانر، اذهب إليه
      context.push(target);
    } else {
      // وإلا، اذهب لصفحة كل المنتجات كإجراء افتراضي
      context.push('/all_products');
    }
  }

  @override
  Widget build(BuildContext context) {
    final bannersAsync = ref.watch(activeBannersProvider);

    return SizedBox(
      height: 300, // ✅ زيادة طفيفة للارتفاع ليكون أكثر سينمائية
      child: bannersAsync.when(
        data: (banners) {
          if (banners.isEmpty) {
            return _buildFallbackHero(context);
          }
          
          if (_currentPage >= banners.length) {
             WidgetsBinding.instance.addPostFrameCallback((_) {
               if (_pageController.hasClients) {
                 _pageController.jumpToPage(0);
               }
             });
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
                  return _buildCinematicPage(context, banner, index % banners.length == _currentPage);
                },
              ),
              
              // المؤشرات (Dots)
              Positioned(
                bottom: 20, 
                left: 0, 
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(banners.length, (index) {
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: index == _currentPage ? 25 : 8, // تمدد المؤشر النشط
                      height: 6,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        color: index == _currentPage 
                            ? const Color(0xFFD4AF37) // لون ذهبي للتميز
                            : Colors.white.withValues(alpha: 0.5),
                      ),
                    );
                  }),
                ),
              ),
            ],
          );
        },
        loading: () => Shimmer.fromColors(
          baseColor: Colors.grey[300]!, highlightColor: Colors.grey[100]!,
          child: Container(color: Colors.white),
        ),
        error: (e, s) => const Center(child: Text("خطأ في تحميل البانرات")),
      ),
    );
  }

  Widget _buildCinematicPage(BuildContext context, AppBanner banner, bool isActive) {
    return GestureDetector(
      onTap: () => _handleNavigation(banner.linkTarget), // ✅ جعل الصورة كاملة قابلة للضغط
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 1. الصورة مع تأثير الزووم (Ken Burns Effect)
          AnimatedScale(
            scale: isActive ? 1.1 : 1.0,
            duration: const Duration(seconds: 6),
            curve: Curves.linear,
            child: CachedNetworkImage(
              imageUrl: buildOptimizedImageUrl(
                banner.imageUrl,
                variant: ImageVariant.heroBanner,
              ),
              fit: BoxFit.cover,
              memCacheHeight: 800,
              placeholder: (context, url) => Container(color: Colors.grey[200]),
              errorWidget: (context, url, error) => const Icon(Icons.broken_image, color: Colors.grey),
            ),
          ),
          
          // 2. تدرج لوني داكن للقراءة (Gradient Overlay)
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.black.withValues(alpha: 0.8), // أسود داكن في الأسفل
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.3)  // تظليل خفيف في الأعلى
                ],
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                stops: const [0.0, 0.6, 1.0],
              ),
            ),
          ),

          // 3. النصوص والأزرار
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 30.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end, // المحتوى في الأسفل
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // العنوان
                AnimatedOpacity(
                  duration: const Duration(milliseconds: 800),
                  opacity: isActive ? 1.0 : 0.0,
                  child: Transform.translate(
                     offset: isActive ? Offset.zero : const Offset(0, 20),
                     child: Text(
                      banner.title,
                      style: GoogleFonts.almarai(
                        fontSize: 26, 
                        fontWeight: FontWeight.w900, 
                        color: banner.textColor,
                        height: 1.2,
                        shadows: [
                          Shadow(offset: const Offset(0, 2), blurRadius: 4, color: Colors.black.withValues(alpha: 0.5))
                        ]
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: 8),
                
                // الوصف الفرعي
                AnimatedOpacity(
                  duration: const Duration(milliseconds: 1000),
                  opacity: isActive ? 1.0 : 0.0,
                   child: Transform.translate(
                     offset: isActive ? Offset.zero : const Offset(0, 20),
                     child: Text(
                      banner.subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.almarai(
                        fontSize: 15, 
                        color: banner.textColor.withValues(alpha: 0.9),
                        height: 1.5,
                      ),
                    ),
                   ),
                ),
                
                const SizedBox(height: 20),
                
                // الزر
                AnimatedOpacity(
                  duration: const Duration(milliseconds: 1200),
                  opacity: isActive ? 1.0 : 0.0,
                  child: SizedBox(
                    height: 45,
                    child: ElevatedButton(
                      onPressed: () => _handleNavigation(banner.linkTarget), // ✅ تفعيل الزر
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white, // زر أبيض نظيف
                        foregroundColor: const Color(0xFF0A2647),
                        padding: const EdgeInsets.symmetric(horizontal: 25),
                        elevation: 5,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      ),
                      child: Text(
                        banner.buttonText.isNotEmpty ? banner.buttonText : "تسوق الآن",
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20), // مسافة للمؤشرات
              ],
            ),
          ),
        ],
      ),
    );
  }

  // الحالة الافتراضية (عند عدم وجود بانرات)
  Widget _buildFallbackHero(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0A2647),
        image: DecorationImage(
          image: AssetImage('assets/images/logo.png'),
          opacity: 0.05, // شعار خفيف جداً في الخلفية
          fit: BoxFit.contain,
        ),
      ),
      child: Stack(
        children: [
          // تأثير إضاءة (Spotlight)
          Positioned(
            top: -100, right: -100,
            child: Container(
              width: 300, height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [const Color(0xFFD4AF37).withValues(alpha: 0.4), Colors.transparent],
                ),
              ),
            ),
          ),
          
          Center(
            child: Padding(
              padding: const EdgeInsets.all(30.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                   Image.asset('assets/images/logo.png', height: 70),
                   const SizedBox(height: 20),
                   Text(
                     "مرحباً بك في عالم الراحة",
                     textAlign: TextAlign.center,
                     style: GoogleFonts.almarai(
                       fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white
                     ),
                   ),
                   const SizedBox(height: 10),
                   Text(
                     "الجودة التي يستحقها منزلك.. بين يديك.",
                     textAlign: TextAlign.center,
                     style: GoogleFonts.almarai(
                       fontSize: 15, color: Colors.white70
                     ),
                   ),
                   const SizedBox(height: 30),
                   ElevatedButton.icon(
                     // ✅ تم إصلاح الزر هنا ليوجه لصفحة المنتجات
                     onPressed: () => context.push('/all_products'),
                     style: ElevatedButton.styleFrom(
                       backgroundColor: Colors.white,
                       foregroundColor: const Color(0xFF0A2647),
                       padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                     ),
                     icon: const Icon(Icons.explore, size: 20),
                     label: const Text("تصفح المجموعات", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
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