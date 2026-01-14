import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:ui' as dbo;

// المشروع
import 'package:doctor_store/shared/services/supabase_service.dart';
import 'package:doctor_store/features/product/domain/models/product_model.dart';
import 'package:doctor_store/shared/utils/analytics_service.dart';
import 'package:doctor_store/features/product/presentation/widgets/product_card.dart';
// import 'package:doctor_store/shared/utils/product_nav_helper.dart'; // لم نعد نستخدمه في v2
import 'package:doctor_store/features/cart/application/cart_manager.dart';
import 'package:doctor_store/shared/utils/settings_provider.dart';
import 'package:doctor_store/features/product/presentation/widgets/product_search_bottom_sheet.dart';
import 'package:doctor_store/shared/widgets/app_footer.dart';
import 'package:doctor_store/shared/utils/home_sections_provider.dart';
import 'package:doctor_store/shared/utils/seo_pages_provider.dart';
import 'package:doctor_store/shared/utils/seo_manager.dart';
import 'package:doctor_store/features/auth/application/user_data_manager.dart';
import 'package:doctor_store/shared/utils/image_url_helper.dart';
import 'package:doctor_store/shared/widgets/custom_app_bar.dart';
import 'package:doctor_store/providers/products_provider.dart';

// Widgets خاصة بالهوم
import '../widgets/dining_table_section.dart';
import '../widgets/cinematic_hero_section.dart';
import '../widgets/home_banner.dart';
import '../widgets/mattress_section.dart';
import '../widgets/pillow_carousel.dart';
import 'package:doctor_store/features/product/presentation/widgets/product_card_skeleton.dart';
import '../widgets/flash_sale_section.dart';
import '../widgets/owner_section.dart';

/// مزوّد المنتجات المستخدم في تبويبات "الكل / مفارش / فرشات ..." يعتمد الآن على
/// allProductsStreamProvider لضمان توفر منتجات من جميع الأقسام وليس آخر 6 فقط.
final latestProductsProviderV2 = allProductsStreamProvider;

final diningProductsProviderV2 = StreamProvider<List<Product>>((ref) {
  return SupabaseService().getDiningProductsStream();
});

/// بيانات الـ Quick Grid (أعلى 8 أقسام) – مستوحاة من ModernCategorySection
class _QuickCategory {
  final String id;
  final String name;
  final String subtitle;
  final IconData icon;
  final Color color;

  const _QuickCategory({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.icon,
    required this.color,
  });
}

const List<_QuickCategory> _quickCategories = [
  _QuickCategory(
    id: 'bedding',
    name: 'بياضات ومفارش',
    subtitle: 'راحة وفخامة',
    icon: FontAwesomeIcons.bed,
    color: Color(0xFF5C6BC0),
  ),
  _QuickCategory(
    id: 'dining_table',
    name: 'طاولات سفرة',
    subtitle: 'تجمعات العائلة',
    icon: Icons.table_restaurant_rounded,
    color: Color(0xFF8D6E63),
  ),
  _QuickCategory(
    id: 'baby_supplies',
    name: 'عالم الأطفال',
    subtitle: 'أمان وراحة',
    icon: FontAwesomeIcons.baby,
    color: Color(0xFFEC407A),
  ),
  _QuickCategory(
    id: 'carpets',
    name: 'سجاد فاخر',
    subtitle: 'لمسة دافئة',
    icon: FontAwesomeIcons.rug,
    color: Color(0xFF26A69A),
  ),
  _QuickCategory(
    id: 'pillows',
    name: 'وسائد طبية',
    subtitle: 'نوم صحي',
    icon: FontAwesomeIcons.cloud,
    color: Color(0xFF78909C),
  ),
  _QuickCategory(
    id: 'furniture',
    name: 'أثاث منزلي',
    subtitle: 'تجديد شامل',
    icon: FontAwesomeIcons.couch,
    color: Color(0xFFFFA726),
  ),
  _QuickCategory(
    id: 'home_decor',
    name: 'ديكورات',
    subtitle: 'لمسات فنية',
    icon: FontAwesomeIcons.leaf,
    color: Color(0xFF66BB6A),
  ),
  _QuickCategory(
    id: 'towels',
    name: 'مناشف',
    subtitle: 'نعومة وانتعاش',
    icon: FontAwesomeIcons.shower,
    color: Color(0xFF26C6DA),
  ),
];

class HomeScreenV2 extends ConsumerStatefulWidget {
  const HomeScreenV2({super.key});

  @override
  ConsumerState<HomeScreenV2> createState() => _HomeScreenV2State();
}

class _HomeScreenV2State extends ConsumerState<HomeScreenV2> {
  late final int _homeStartMs;
  bool _homeLatestLogged = false;
  bool _didPrecacheHomeImages = false;

  @override
  void initState() {
    super.initState();
    _homeStartMs = DateTime.now().millisecondsSinceEpoch;

    // نفس حدث الزيارة المستخدم في الهوم الأصلية
    AnalyticsService.instance.trackEvent('home_visit');
  }

  Future<void> _launchSocial(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    final latestProductsAsync = ref.watch(latestProductsProviderV2);
    final diningProductsAsync = ref.watch(diningProductsProviderV2);

    final cartItems = ref.watch(cartProvider);
    final user = ref.watch(userProfileProvider);
    final cartCount = cartItems.fold<int>(
      0,
      (sum, item) => sum + item.quantity,
    );
    final settingsAsync = ref.watch(settingsProvider);
    final sectionsAsync = ref.watch(homeSectionsProvider);
    final seoHomeAsync = ref.watch(seoPageProvider('home'));

    // Pre-cache أهم صور المنتجات في الصفحة الرئيسية (أول مرة فقط)
    _precacheHomeImages(latestProductsAsync);

    final sectionsConfig = sectionsAsync.asData?.value;
    bool isSectionEnabled(String key) =>
        sectionsConfig == null ? true : (sectionsConfig[key]?.enabled ?? true);

    // تحديث SEO للصفحة الرئيسية (ويب فقط) كما في الهوم الحالية
    seoHomeAsync.whenData((page) {
      SeoManager.setPageSeo(
        title: (page?.title.isNotEmpty ?? false)
            ? page!.title
            : 'متجر الدكتور - حلول النوم والراحة',
        description: (page?.description.isNotEmpty ?? false)
            ? page!.description
            : 'متجر الدكتور يقدم فرشات طبية، مفارش، وسائد وإكسسوارات نوم بجودة عالية وتجربة شراء سهلة عبر الويب والواتساب.',
        imageUrl: page?.imageUrl,
      );
    });

    return Scaffold(
      backgroundColor: Colors.white,

      // زر الـ FAB كما هو
      floatingActionButton: settingsAsync.when(
        data: (settings) {
          if (cartItems.isNotEmpty) {
            return FloatingActionButton.extended(
              onPressed: () => context.push('/cart'),
              backgroundColor: const Color(0xFF0A2647),
              label: Text(
                "إتمام الطلب ($cartCount)",
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              icon: const Icon(
                Icons.shopping_cart_checkout,
                color: Colors.white,
              ),
            );
          } else {
            return FloatingActionButton(
              onPressed: () =>
                  _launchSocial('https://wa.me/${settings.whatsapp}'),
              backgroundColor: const Color(0xFF25D366),
              child: const FaIcon(
                FontAwesomeIcons.whatsapp,
                color: Colors.white,
              ),
            );
          }
        },
        loading: () => null,
        error: (error, stack) => null,
      ),

      body: CustomScrollView(
        cacheExtent: 800.0,
        slivers: [
          // ================= 1) شريط العنوان (كما هو تقريباً) =================
          SliverAppBar(
            pinned: true,
            floating: true,
            snap: true,
            elevation: 0,
            scrolledUnderElevation: 0,
            backgroundColor: Colors.transparent,
            toolbarHeight: 64,
            bottom: _buildTopBanner(context, user),
            flexibleSpace: ClipRRect(
              child: BackdropFilter(
                filter: dbo.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.75),
                    border: Border(
                      bottom: BorderSide(
                        color: Colors.grey.withValues(alpha: 0.1),
                        width: 1,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            automaticallyImplyLeading: false,
            centerTitle: true,
            title: CustomAppBarContent(
              isHome: true,
              centerWidget: Hero(
                tag: 'app_logo_home_unique_v2',
                child: Image.asset(
                  'assets/images/logo.png',
                  height: 40,
                  fit: BoxFit.contain,
                ),
              ),
              // لا نحتاج أيقونة بحث مستقلة في الهيدر، الاكتفاء بمربع البحث أسفل الهيدر
              showSearch: false,
              sharePath: '/',
              shareTitle: 'متجر الدكتور - الصفحة الرئيسية',
            ),
          ),

          // ================= 2) Header: Search Bar + Hero =================
          SliverToBoxAdapter(
            child: Column(
              children: [
                const SizedBox(height: 12),
                _buildInlineSearchBar(context),
                const SizedBox(height: 12),

                // يمكن اعتبار CinematicHeroSection كبانر سينمائي في الأعلى
                if (isSectionEnabled(HomeSectionKeys.hero))
                  const CinematicHeroSection(),

                const SizedBox(height: 12),
              ],
            ),
          ),

          // ================= 3) Quick Grid (Top 8 Categories) =================
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            sliver: SliverToBoxAdapter(
              child: Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'تصفح سريع',
                  style: GoogleFonts.almarai(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0A2647),
                  ),
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                // نجعل الخلية أطول قليلاً حتى لا يحدث Overflow بسيط في بعض الأجهزة الصغيرة
                childAspectRatio: 0.8,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final cat = _quickCategories[index];
                  return _QuickCategoryTile(category: cat);
                },
                childCount: _quickCategories.length > 8
                    ? 8
                    : _quickCategories.length,
              ),
            ),
          ),

          // ================= 4) Flash Sale Section (قبل التبويبات) =================
          if (isSectionEnabled(HomeSectionKeys.flashSale))
            SliverToBoxAdapter(
              child: Column(
                children: const [
                  SizedBox(height: 12),
                  FlashSaleSection(),
                  SizedBox(height: 8),
                ],
              ),
            ),

          // ================= 5) وصل حديثاً (قائمة أفقية بسيطة) =================
          SliverToBoxAdapter(
            child: latestProductsAsync.when(
              data: (products) {
                if (products.isEmpty) {
                  return const SizedBox.shrink();
                }

                // تسجيل حدث Analytics مرة واحدة عند تحميل المنتجات الجديدة
                if (!_homeLatestLogged) {
                  _homeLatestLogged = true;
                  final durationMs =
                      DateTime.now().millisecondsSinceEpoch - _homeStartMs;
                  AnalyticsService.instance.trackEvent(
                    'home_latest_loaded',
                    props: {
                      'duration_ms': durationMs,
                      'count': products.length,
                    },
                  );
                }

                final latest = products.take(12).toList();

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'وصل حديثاً',
                            style: GoogleFonts.almarai(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF0A2647),
                            ),
                          ),
                          TextButton(
                            onPressed: () => context.push('/all_products?sort=new'),
                            child: Text(
                              'عرض الكل',
                              style: GoogleFonts.almarai(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF0A2647),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 260,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: latest.length,
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          separatorBuilder: (_, __) => const SizedBox(width: 12),
                          itemBuilder: (context, index) {
                            final product = latest[index];
                            return SizedBox(
                              width: 170,
                              child: ProductCard(
                                product: product,
                                isCompact: true,
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                );
              },
              loading: () => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: SizedBox(
                  height: 220,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: 4,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (_, __) => const SizedBox(
                      width: 170,
                      child: ProductCardSkeleton(),
                    ),
                  ),
                ),
              ),
              error: (e, s) => const SizedBox.shrink(),
            ),
          ),

          // ================= 6) الأقسام التسويقية الرئيسية (كما في الهوم الأصلية) =================
          SliverToBoxAdapter(
            child: Column(
              children: [
                // قسم الفرشات الطبية (يعتمد على أحدث المنتجات)
                latestProductsAsync.when(
                  data: (products) => MattressSection(products: products),
                  loading: () => const SizedBox.shrink(),
                  error: (e, s) => const SizedBox.shrink(),
                ),

                // شريط المخدات (وسائد) كسحب سريع للعروض
                latestProductsAsync.when(
                  data: (products) => PillowCarousel(products: products),
                  loading: () => const SizedBox.shrink(),
                  error: (e, s) => const SizedBox.shrink(),
                ),

                // قسم طاولات السفرة
                if (isSectionEnabled(HomeSectionKeys.dining))
                  diningProductsAsync.when(
                    data: (products) => DiningTableSection(
                      products: products,
                      title: _resolveSectionTitle(
                        sectionsConfig,
                        HomeSectionKeys.dining,
                        'طاولات سفرة فاخرة',
                      ),
                      subtitle: _resolveSectionSubtitle(
                        sectionsConfig,
                        HomeSectionKeys.dining,
                        'تشكيلة مختارة لطاولات سفرة تجمع العائلة بأجواء دافئة.',
                      ),
                    ),
                    loading: () => const SizedBox.shrink(),
                    error: (e, s) => const SizedBox.shrink(),
                  ),
              ],
            ),
          ),

          // ================= 8) الأقسام السفلية + الفوتر =================
          SliverList(
            delegate: SliverChildListDelegate([
              const SizedBox(height: 20),

              // بانر منتصف الصفحة إن كان مفعّلاً من لوحة التحكم
              if (isSectionEnabled(HomeSectionKeys.middleBanner))
                const HomeBanner(position: 'middle'),

              if (isSectionEnabled(HomeSectionKeys.owner))
                const OwnerSection(),

              if (isSectionEnabled(HomeSectionKeys.baby))
                _buildFeaturedSection(
                  context,
                  title: _resolveSectionTitle(
                    sectionsConfig,
                    HomeSectionKeys.baby,
                    "عالم الطفل السعيد 👶",
                  ),
                  subtitle: _resolveSectionSubtitle(
                    sectionsConfig,
                    HomeSectionKeys.baby,
                    "كل ما يحتاجه طفلك لنوم هادئ وآمن.",
                  ),
                  category: "baby_supplies",
                  bgColor: const Color(0xFFFFF0F5),
                ),

              const AppFooter(),
              const SizedBox(height: 80),
            ]),
          ),
        ],
      ),
    );
  }

  void _precacheHomeImages(AsyncValue<List<Product>> latestProductsAsync) {
    if (_didPrecacheHomeImages) return;

    final products = latestProductsAsync.asData?.value;
    if (products == null || products.isEmpty) return;

    _didPrecacheHomeImages = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      // نكتفي بأول 4 منتجات لتخفيف التحميل الأولي على الشبكة
      for (final product in products.take(4)) {
        final optimizedUrl = buildOptimizedImageUrl(
          product.originalImageUrl,
          variant: ImageVariant.productCard,
        );

        precacheImage(CachedNetworkImageProvider(optimizedUrl), context);
      }
    });
  }

  // --- أدوات المساعدة (نفس الموجودة في الهوم الأصلية تقريباً) ---

  String _resolveSectionTitle(
    Map<String, HomeSectionConfig>? config,
    String key,
    String fallback,
  ) {
    final cfg = config?[key];
    final t = cfg?.title;
    if (t != null && t.trim().isNotEmpty) return t.trim();
    return fallback;
  }

  String _resolveSectionSubtitle(
    Map<String, HomeSectionConfig>? config,
    String key,
    String fallback,
  ) {
    final cfg = config?[key];
    final s = cfg?.subtitle;
    if (s != null && s.trim().isNotEmpty) return s.trim();
    return fallback;
  }

  PreferredSizeWidget? _buildTopBanner(BuildContext context, UserProfile user) {
    // شريط دعوة إنشاء حساب للزائرين
    if (user.isGuest) {
      return const PreferredSize(
        preferredSize: Size.fromHeight(44),
        child: _GuestSignupBannerV2(),
      );
    }

    // تنبيه إكمال البيانات
    final bool needsProfileCompletion =
        !user.isGuest && (user.name.trim().isEmpty || user.phone.trim().isEmpty);

    if (!needsProfileCompletion) return null;

    return PreferredSize(
      preferredSize: const Size.fromHeight(52),
      child: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0A2647), Color(0xFF144272)],
            begin: Alignment.centerRight,
            end: Alignment.centerLeft,
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: SafeArea(
          top: false,
          bottom: false,
          child: Row(
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.5),
                    width: 1,
                  ),
                ),
                child: const Icon(
                  Icons.info_outline,
                  color: Colors.white,
                  size: 16,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'اكتمل تسجيلك تقريباً! أضِف اسمك ورقم هاتفك لتسريع التواصل والتوصيل.',
                  style: GoogleFonts.almarai(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: () => context.push('/profile'),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  foregroundColor: const Color(0xFF0A2647),
                  backgroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                child: Text(
                  'إكمال البيانات',
                  style: GoogleFonts.almarai(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInlineSearchBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GestureDetector(
        onTap: () => showProductSearchBottomSheet(context),
        child: Container(
          height: 48,
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: Colors.grey.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Icon(
                Icons.search,
                color: Colors.grey[600],
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'ابحث عن منتج، قسم أو عرض...',
                  style: GoogleFonts.almarai(
                    fontSize: 13,
                    color: Colors.grey[600],
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Icon(
                Icons.tune_rounded,
                size: 20,
                color: Color(0xFF0A2647),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeaturedSection(
    BuildContext context, {
    required String title,
    String? subtitle,
    required String category,
    required Color bgColor,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AutoSizeText(
                  title,
                  maxLines: 1,
                  minFontSize: 18,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.almarai(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.pinkAccent,
                  ),
                ),
                const SizedBox(height: 8),
                AutoSizeText(
                  subtitle ?? "كل ما يحتاجه طفلك لنوم هادئ وآمن.",
                  maxLines: 2,
                  minFontSize: 11,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.black54,
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () => context.push(
                    '/category/$category',
                    extra: {
                      'name': 'مستلزمات أطفال',
                      'color': Colors.pinkAccent,
                    },
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.pinkAccent,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text("تصفح القسم"),
                ),
              ],
            ),
          ),
          Icon(
            FontAwesomeIcons.babyCarriage,
            size: 80,
            color: Colors.pinkAccent.withValues(alpha: 0.2),
          ),
        ],
      ),
    );
  }
}

/// عنصر واحد في الـ Quick Grid
class _QuickCategoryTile extends StatelessWidget {
  final _QuickCategory category;

  const _QuickCategoryTile({required this.category});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        context.push('/category/${category.id}', extra: {
          'name': category.name,
          'color': category.color,
        });
      },
      child: Container(
        decoration: BoxDecoration(
          color: category.color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: category.color.withValues(alpha: 0.35),
            width: 0.8,
          ),
        ),
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: category.color.withValues(alpha: 0.18),
                shape: BoxShape.circle,
              ),
              child: Icon(
                category.icon,
                size: 20,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 6),
            AutoSizeText(
              category.name,
              maxLines: 2,
              minFontSize: 9,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: GoogleFonts.almarai(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF0A2647),
              ),
            ),
            const SizedBox(height: 2),
            AutoSizeText(
              category.subtitle,
              maxLines: 1,
              minFontSize: 8,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: GoogleFonts.almarai(
                fontSize: 9,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// نسخة مستقلة من شريط "إنشاء حساب" حتى لا نعتمد على الـ private widget في الملف القديم
class _GuestSignupBannerV2 extends StatelessWidget
    implements PreferredSizeWidget {
  const _GuestSignupBannerV2();

  @override
  Size get preferredSize => const Size.fromHeight(44);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0A2647), Color(0xFF144272)],
          begin: Alignment.centerRight,
          end: Alignment.centerLeft,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      child: SafeArea(
        top: false,
        bottom: false,
        child: Row(
          children: [
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.5),
                  width: 1,
                ),
              ),
              child: const Icon(
                Icons.person_add_alt_1_rounded,
                color: Colors.white,
                size: 16,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'أنشئ حساباً مجانياً لحفظ مفضلتك وتتبع طلباتك بسهولة.',
                style: GoogleFonts.almarai(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: () => context.go('/login'),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                foregroundColor: const Color(0xFF0A2647),
                backgroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              child: Text(
                'إنشاء حساب',
                style: GoogleFonts.almarai(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
