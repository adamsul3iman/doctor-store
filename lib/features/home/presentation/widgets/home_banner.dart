import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';
import 'package:doctor_store/shared/utils/image_url_helper.dart';

class HomeBanner extends StatefulWidget {
  final String position; // 'top' or 'middle'
  const HomeBanner({super.key, this.position = 'top'});

  @override
  State<HomeBanner> createState() => _HomeBannerState();
}

class _HomeBannerState extends State<HomeBanner> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  List<Map<String, dynamic>> _banners = [];
  Timer? _timer;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchBanners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _fetchBanners() async {
    try {
      final data = await Supabase.instance.client
          .from('banners')
          .select()
          .eq('is_active', true)
          .eq('position', widget.position)
          .order('sort_order', ascending: true);

      if (mounted) {
        setState(() {
          _banners = List<Map<String, dynamic>>.from(data);
          _isLoading = false;
        });
        if (_banners.length > 1) _startAutoScroll();
      }
    } catch (e) {
      debugPrint("Error fetching banners: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _startAutoScroll() {
    _timer = Timer.periodic(const Duration(seconds: 5), (Timer timer) {
      if (_currentPage < _banners.length - 1) {
        _currentPage++;
      } else {
        _currentPage = 0;
      }
      if (_pageController.hasClients) {
        _pageController.animateToPage(
          _currentPage,
          duration: const Duration(milliseconds: 800),
          curve: Curves.fastOutSlowIn,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return _buildShimmerLoading();
    }

    if (_banners.isEmpty) {
      return const SizedBox.shrink();
    }

    // ارتفاع البانر يختلف حسب مكانه
    final double height = widget.position == 'top' ? 220 : 160;

    return SizedBox(
      height: height,
      child: Stack(
        children: [
          // 1. الصور (PageView)
          PageView.builder(
            controller: _pageController,
            itemCount: _banners.length,
            onPageChanged: (index) => setState(() => _currentPage = index),
            itemBuilder: (context, index) {
              final banner = _banners[index];
              return _buildBannerItem(banner);
            },
          ),

          // 2. المؤشرات (Indicators) - تظهر فقط إذا كان هناك أكثر من صورة
          if (_banners.length > 1)
            Positioned(
              bottom: 15,
              left: 20, // أو right حسب التصميم
              child: Row(
                children: List.generate(_banners.length, (index) {
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.only(right: 6),
                    height: 4,
                    width: _currentPage == index ? 25 : 8, // توسيع المؤشر النشط
                    decoration: BoxDecoration(
                      color: _currentPage == index 
                          ? const Color(0xFFD4AF37) // لون ذهبي للنشط
                          : Colors.white.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  );
                }),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBannerItem(Map<String, dynamic> banner) {
    return GestureDetector(
      onTap: () {
        if (banner['link_target'] != null && banner['link_target'].toString().isNotEmpty) {
          context.push(banner['link_target']);
        }
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5), // حواف جانبية
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20), // زوايا دائرية ناعمة
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // أ. الصورة الخلفية
              CachedNetworkImage(
                imageUrl: buildOptimizedImageUrl(
                  banner['image_url'] as String,
                  variant: ImageVariant.homeBanner,
                ),
                fit: BoxFit.cover,
                filterQuality: FilterQuality.low,
                memCacheHeight: 580,
                fadeInDuration: const Duration(milliseconds: 200),
                fadeOutDuration: Duration.zero,
                placeholder: (context, url) => Container(color: Colors.grey[200]),
                errorWidget: (context, url, error) => const Icon(Icons.error),
              ),

              // ب. التدرج اللوني (Gradient) لضمان وضوح النص
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.1),
                      Colors.black.withValues(alpha: 0.7), // سواد في الأسفل للنص
                    ],
                    stops: const [0.4, 0.7, 1.0],
                  ),
                ),
              ),

              // ج. النصوص والأزرار (المحتوى)
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (banner['title'] != null && banner['title'].toString().isNotEmpty)
                      Text(
                        banner['title'],
                        style: GoogleFonts.almarai(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w900, // خط عريض جداً
                          height: 1.2,
                          shadows: [const Shadow(blurRadius: 10, color: Colors.black45, offset: Offset(0, 2))],
                        ),
                      ),
                    
                    if (banner['subtitle'] != null && banner['subtitle'].toString().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          banner['subtitle'],
                          style: GoogleFonts.almarai(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),

                    // زر (Call to Action) اختياري
                    if (widget.position == 'top' && banner['button_text'] != null)
                      Container(
                        margin: const EdgeInsets.only(top: 12),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          banner['button_text'] ?? 'تسوق الآن',
                          style: GoogleFonts.almarai(
                            color: Colors.black,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
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

  // تأثير التحميل (Shimmer)
  Widget _buildShimmerLoading() {
    return Container(
      height: widget.position == 'top' ? 220 : 160,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Shimmer.fromColors(
        baseColor: Colors.grey[300]!,
        highlightColor: Colors.grey[100]!,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
        ),
      ),
    );
  }
}