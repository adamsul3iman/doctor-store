import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:cached_network_image/cached_network_image.dart';

// المشروع
import 'package:doctor_store/shared/services/supabase_service.dart';
import 'package:doctor_store/features/product/domain/models/product_model.dart';
import 'package:doctor_store/shared/services/analytics_service.dart';
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
import 'package:doctor_store/features/product/presentation/providers/products_provider.dart';
import 'package:doctor_store/shared/utils/categories_provider.dart';
import 'package:doctor_store/shared/utils/responsive_layout.dart';
import 'package:doctor_store/shared/widgets/responsive_center_wrapper.dart';

// Widgets خاصة بالهوم
import '../widgets/dining_table_section.dart';
import '../widgets/cinematic_hero_section.dart';
import '../widgets/home_banner.dart';
import '../widgets/mattress_section.dart';
import '../widgets/pillow_carousel.dart';
import 'package:doctor_store/features/product/presentation/widgets/product_card_skeleton.dart';
import '../widgets/owner_section.dart';
import '../widgets/urgency_deals_section.dart';
import '../widgets/live_activity_section.dart';
import '../widgets/personalized_section.dart';

/// مزوّد المنتجات المستخدم في تبويبات "الكل / مفارش / فرشات ..." يعتمد الآن على
/// allProductsStreamProvider لضمان توفر منتجات من جميع الأقسام وليس آخر 6 فقط.
final latestProductsProviderV2 = allProductsProvider;

final diningProductsProviderV2 = FutureProvider<List<Product>>((ref) async {
  return SupabaseService().getDiningProducts();
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
  bool _listenersRegistered = false;

  @override
  void initState() {
    super.initState();
    _homeStartMs = DateTime.now().millisecondsSinceEpoch;

    // تتبع حدث الزيارة للتحليلات
    AnalyticsService.instance.trackEvent('home_visit');
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    
    // تتبع شامل لزيارة الصفحة الرئيسية (بعد تحميل الـ context)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        AnalyticsService.instance.trackSiteVisit(
          pageUrl: '/home',
          deviceType: _detectDeviceType(),
          country: 'Kuwait', // يمكن تحسينه لاحقاً باستخدام IP
        );
      }
    });
  }

  // دالة لاكتشاف نوع الجهاز
  String _detectDeviceType() {
    final data = MediaQuery.of(context);
    if (data.size.width < 768) {
      return 'mobile';
    } else if (data.size.width < 1024) {
      return 'tablet';
    } else {
      return 'desktop';
    }
  }

  Future<void> _launchSocial(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_listenersRegistered) {
      _listenersRegistered = true;

      // Riverpod v2.6: ref.listen يجب أن يكون داخل build.
      // نسجلها مرة واحدة فقط لتجنب التكرار.
      ref.listen<AsyncValue<List<Product>>>(
        latestProductsProviderV2,
        (previous, next) {
          next.whenData((products) {
            _precacheHomeImages(products);
          });
        },
      );

      ref.listen<AsyncValue<dynamic>>(
        seoPageProvider('home'),
        (previous, next) {
          next.whenData((page) {
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
        },
      );
    }

    final latestProductsAsync = ref.watch(
      latestProductsProviderV2.select((p) => p),
    );
    final diningProductsAsync = ref.watch(
      diningProductsProviderV2.select((p) => p),
    );

    final cartCount = ref.watch(
      cartProvider.select(
        (items) => items.fold<int>(0, (sum, item) => sum + item.quantity),
      ),
    );
    final cartHasItems = ref.watch(cartProvider.select((items) => items.isNotEmpty));
    final user = ref.watch(
      userProfileProvider.select((u) => u),
    );
    final settingsAsync = ref.watch(
      settingsProvider.select((s) => s),
    );
    final sectionsAsync = ref.watch(
      homeSectionsProvider.select((s) => s),
    );

    final sectionsConfig = sectionsAsync.asData?.value;
    bool isSectionEnabled(String key) =>
        sectionsConfig == null ? true : (sectionsConfig[key]?.enabled ?? true);

    final orderedSectionKeys = _resolveOrderedHomeSectionKeys(sectionsConfig);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),

      // زر الـ FAB كما هو
      floatingActionButton: settingsAsync.when(
        data: (settings) {
          if (cartHasItems) {
            return Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30),
                gradient: const LinearGradient(
                  colors: [Color(0xFF0A2647), Color(0xFF1A3A5F)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0A2647).withValues(alpha: 0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                    spreadRadius: -2,
                  ),
                ],
              ),
              child: FloatingActionButton.extended(
                onPressed: () => context.push('/cart'),
                backgroundColor: Colors.transparent,
                elevation: 0,
                highlightElevation: 0,
                label: Row(
                  children: [
                    const Icon(
                      Icons.shopping_cart_checkout,
                      color: Colors.white,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      "إتمام الطلب",
                      style: GoogleFonts.almarai(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        "$cartCount",
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
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

      body: RefreshIndicator(
        onRefresh: () async {
          // Invalidate all providers to refresh data
          ref.invalidate(latestProductsProviderV2);
          ref.invalidate(diningProductsProviderV2);
          ref.invalidate(categoriesConfigProvider);
          ref.invalidate(homeSectionsProvider);
          
          // Wait for the refresh to complete
          await Future.delayed(const Duration(milliseconds: 500));
          
          // Track analytics
          AnalyticsService.instance.trackEvent('home_pull_to_refresh');
        },
        color: const Color(0xFF0A2647),
        backgroundColor: Colors.white,
        displacement: 60,
        child: CustomScrollView(
        cacheExtent: 800.0,
        slivers: [
          // ================= 1) شريط العنوان: أبيض أنيق مع أيقونات واضحة =================
          SliverAppBar(
            pinned: true,
            floating: true,
            snap: true,
            elevation: 0,
            scrolledUnderElevation: 2,
            backgroundColor: Colors.white,
            toolbarHeight: 64,
            bottom: _buildTopBanner(context, user),
            iconTheme: const IconThemeData(color: Color(0xFF0A2647)),
            actionsIconTheme: const IconThemeData(color: Color(0xFF0A2647)),
            flexibleSpace: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0A2647).withValues(alpha: 0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 2),
                  ),
                ],
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
                  height: 42,
                  fit: BoxFit.contain,
                ),
              ),
              showSearch: false,
              sharePath: '/',
              shareTitle: 'متجر الدكتور - الصفحة الرئيسية',
            ),
          ),

          // ================= 2) Header: Search Bar + Hero =================
          SliverResponsiveCenterPadding(
            minSidePadding: 0,
            sliver: SliverToBoxAdapter(
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  _buildInlineSearchBar(context),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),

          ...orderedSectionKeys.expand((key) {
            if (!isSectionEnabled(key)) return const <Widget>[];

            if (key == HomeSectionKeys.hero) {
              return <Widget>[
                SliverResponsiveCenterPadding(
                  minSidePadding: 0,
                  sliver: SliverToBoxAdapter(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final isWide = constraints.maxWidth >= 900;
                        return SizedBox(
                          height: isWide ? 420 : null,
                          child: const CinematicHeroSection(),
                        );
                      },
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 12)),
              ];
            }

            if (key == HomeSectionKeys.categories) {
              return <Widget>[
                SliverToBoxAdapter(
                  child: _buildSectionHeader(
                    context,
                    title: 'تصفح سريع',
                    actionText: 'عرض الكل',
                    actionIcon: Icons.grid_view_rounded,
                    onActionTap: () => context.push('/browse_all'),
                  ),
                ),
                SliverResponsiveCenterPadding(
                  minSidePadding: 0,
                  sliver: _buildCategoriesGrid(ref),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 16)),
              ];
            }

            if (key == HomeSectionKeys.flashSale) {
              return <Widget>[
                SliverResponsiveCenterPadding(
                  minSidePadding: 0,
                  sliver: SliverToBoxAdapter(
                    child: latestProductsAsync.when(
                      data: (products) {
                        final flashProducts =
                            products.where((p) => p.isFlashDeal).toList();
                        if (flashProducts.isEmpty) {
                          return const SizedBox.shrink();
                        }
                        return UrgencyDealsSection(
                          products: flashProducts,
                          dealEndTime:
                              DateTime.now().add(const Duration(hours: 6)),
                        );
                      },
                      loading: () => const SizedBox.shrink(),
                      error: (e, s) => const SizedBox.shrink(),
                    ),
                  ),
                ),
              ];
            }

            if (key == HomeSectionKeys.latest) {
              return <Widget>[
                SliverToBoxAdapter(
                  child: _buildSectionHeader(
                    context,
                    title: 'وصل حديثاً',
                    actionText: 'عرض الكل',
                    onActionTap: () => context.push('/all_products?sort=new'),
                  ),
                ),
                SliverResponsiveCenterPadding(
                  minSidePadding: 0,
                  sliver: SliverToBoxAdapter(
                    child: latestProductsAsync.when(
                      data: (products) {
                        if (products.isEmpty) {
                          return const SizedBox.shrink();
                        }

                        if (!_homeLatestLogged) {
                          _homeLatestLogged = true;
                          final durationMs =
                              DateTime.now().millisecondsSinceEpoch -
                                  _homeStartMs;
                          AnalyticsService.instance.trackEvent(
                            'home_latest_loaded',
                            props: {
                              'duration_ms': durationMs,
                              'count': products.length,
                            },
                          );
                        }

                        final latest = products.take(12).toList();
                        return SizedBox(
                          height: 280,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: latest.length,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            separatorBuilder: (_, __) =>
                                const SizedBox(width: 16),
                            addAutomaticKeepAlives: false,
                            addRepaintBoundaries: false,
                            cacheExtent: 100,
                            itemBuilder: (context, index) {
                              final product = latest[index];
                              return SizedBox(
                                width: 180,
                                child: ProductCard(
                                  product: product,
                                  isCompact: true,
                                ),
                              );
                            },
                          ),
                        );
                      },
                      loading: () => SizedBox(
                        height: 240,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: 4,
                          separatorBuilder: (_, __) =>
                              const SizedBox(width: 16),
                          itemBuilder: (_, __) => const SizedBox(
                            width: 180,
                            child: ProductCardSkeleton(),
                          ),
                        ),
                      ),
                      error: (e, s) => const SizedBox.shrink(),
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 24)),
              ];
            }

            if (key == HomeSectionKeys.dining) {
              return <Widget>[
                SliverResponsiveCenterPadding(
                  minSidePadding: 0,
                  sliver: SliverToBoxAdapter(
                    child: diningProductsAsync.when(
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
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 24)),
              ];
            }

            if (key == HomeSectionKeys.middleBanner) {
              return const <Widget>[
                SliverToBoxAdapter(child: SizedBox(height: 24)),
                SliverResponsiveCenterPadding(
                  minSidePadding: 0,
                  sliver: SliverToBoxAdapter(child: HomeBanner(position: 'middle')),
                ),
              ];
            }

            if (key == HomeSectionKeys.owner) {
              return const <Widget>[
                SliverResponsiveCenterPadding(
                  minSidePadding: 0,
                  sliver: SliverToBoxAdapter(child: OwnerSection()),
                ),
              ];
            }

            if (key == HomeSectionKeys.baby) {
              return <Widget>[
                SliverResponsiveCenterPadding(
                  minSidePadding: 0,
                  sliver: SliverToBoxAdapter(
                    child: _buildFeaturedSection(
                      context,
                      title: _resolveSectionTitle(
                        sectionsConfig,
                        HomeSectionKeys.baby,
                        'عالم الطفل السعيد 👶',
                      ),
                      subtitle: _resolveSectionSubtitle(
                        sectionsConfig,
                        HomeSectionKeys.baby,
                        'كل ما يحتاجه طفلك لنوم هادئ وآمن.',
                      ),
                      category: 'baby_supplies',
                      bgColor: const Color(0xFFFFF0F5),
                    ),
                  ),
                ),
              ];
            }

            return const <Widget>[];
          }),

          // أقسام ثابتة حالياً خارج نظام الإدارة
          SliverResponsiveCenterPadding(
            minSidePadding: 0,
            sliver: SliverToBoxAdapter(
              child: latestProductsAsync.when(
                data: (products) {
                  if (products.isEmpty) return const SizedBox.shrink();
                  return LiveActivitySection(products: products);
                },
                loading: () => const SizedBox.shrink(),
                error: (e, s) => const SizedBox.shrink(),
              ),
            ),
          ),
          const SliverResponsiveCenterPadding(
            minSidePadding: 0,
            sliver: SliverToBoxAdapter(child: PersonalizedSection()),
          ),

          SliverResponsiveCenterPadding(
            minSidePadding: 0,
            sliver: SliverToBoxAdapter(
              child: Column(
                children: [
                  latestProductsAsync.when(
                    data: (products) => MattressSection(products: products),
                    loading: () => const SizedBox.shrink(),
                    error: (e, s) => const SizedBox.shrink(),
                  ),
                  const SizedBox(height: 24),
                  latestProductsAsync.when(
                    data: (products) => PillowCarousel(products: products),
                    loading: () => const SizedBox.shrink(),
                    error: (e, s) => const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
          ),

          SliverResponsiveCenterPadding(
            minSidePadding: 0,
            sliver: SliverToBoxAdapter(
              child: Column(
                children: const [
                  SizedBox(height: 24),
                  AppFooter(),
                  SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
  }

  List<String> _resolveOrderedHomeSectionKeys(
    Map<String, HomeSectionConfig>? config,
  ) {
    const defaultOrder = <String>[
      HomeSectionKeys.hero,
      HomeSectionKeys.categories,
      HomeSectionKeys.flashSale,
      HomeSectionKeys.latest,
      HomeSectionKeys.middleBanner,
      HomeSectionKeys.dining,
      HomeSectionKeys.owner,
      HomeSectionKeys.baby,
    ];

    if (config == null || config.isEmpty) return defaultOrder;

    final configuredKeys = config.keys.toSet();
    final keys = <String>[...configuredKeys];
    keys.sort((a, b) {
      final sa = config[a]?.sortOrder ?? 0;
      final sb = config[b]?.sortOrder ?? 0;
      return sa.compareTo(sb);
    });

    for (final k in defaultOrder) {
      if (!keys.contains(k)) keys.add(k);
    }
    return keys;
  }

  void _precacheHomeImages(List<Product> products) {
    if (_didPrecacheHomeImages) return;
    if (products.isEmpty) return;

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
          height: 52,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: const Color(0xFF0A2647).withValues(alpha: 0.15),
              width: 1.5,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0D000000),
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Icon(
                Icons.search_rounded,
                color: const Color(0xFF0A2647).withValues(alpha: 0.6),
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'ابحث عن منتج، قسم أو عرض...',
                  style: GoogleFonts.almarai(
                    fontSize: 14,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF0A2647).withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.tune_rounded,
                  size: 20,
                  color: Color(0xFF0A2647),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// عنوان سكشن موحّد مع فاصل أنيق
  Widget _buildSectionHeader(
    BuildContext context, {
    required String title,
    String? actionText,
    VoidCallback? onActionTap,
    IconData? actionIcon,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 24,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0A2647),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: GoogleFonts.almarai(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0A2647),
                      letterSpacing: -0.3,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          if (actionText != null && onActionTap != null)
            TextButton.icon(
              onPressed: onActionTap,
              icon: Icon(
                actionIcon ?? Icons.arrow_forward_ios_rounded,
                size: 14,
                color: const Color(0xFF0A2647),
              ),
              label: Text(
                actionText,
                style: GoogleFonts.almarai(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF0A2647),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
        ],
      ),
    );
  }

  /// بناء شبكة الأقسام الديناميكية من قاعدة البيانات
  Widget _buildCategoriesGrid(WidgetRef ref) {
    final categoriesAsync = ref.watch(categoriesConfigProvider);

    return categoriesAsync.when(
      data: (categories) {
        if (categories.isEmpty) {
          // إذا لم تكن هناك أقسام في قاعدة البيانات، نستخدم الأقسام الثابتة
          return _buildStaticCategoriesGrid();
        }

        // نعرض أول 8 أقسام نشطة فقط
        final displayCategories = categories.take(8).toList();

        return SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          sliver: SliverLayoutBuilder(
            builder: (context, constraints) {
              final crossAxisCount = ResponsiveLayout.gridCountForWidth(
                constraints.crossAxisExtent,
                desiredItemWidth: 92,
                minCount: 3,
                maxCount: 6,
              );

              return SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 0.75,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final category = displayCategories[index];
                    return _CategoryTileFromDB(category: category);
                  },
                  childCount: displayCategories.length,
                ),
              );
            },
          ),
        );
      },
      loading: () => SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        sliver: SliverLayoutBuilder(
          builder: (context, constraints) {
            final crossAxisCount = ResponsiveLayout.gridCountForWidth(
              constraints.crossAxisExtent,
              desiredItemWidth: 92,
              minCount: 3,
              maxCount: 6,
            );

            return SliverGrid(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 0.75,
              ),
              delegate: SliverChildBuilderDelegate(
                (_, __) => const _CategoryTileSkeleton(),
                childCount: 8,
              ),
            );
          },
        ),
      ),
      error: (error, stack) {
        // في حالة الخطأ، نعرض الأقسام الثابتة
        return _buildStaticCategoriesGrid();
      },
    );
  }

  /// شبكة الأقسام الثابتة (احتياطية)
  Widget _buildStaticCategoriesGrid() {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      sliver: SliverLayoutBuilder(
        builder: (context, constraints) {
          final crossAxisCount = ResponsiveLayout.gridCountForWidth(
            constraints.crossAxisExtent,
            desiredItemWidth: 92,
            minCount: 3,
            maxCount: 6,
          );

          return SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 0.75,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final category = _quickCategories[index];
                return _QuickCategoryTile(category: category);
              },
              childCount: _quickCategories.length,
            ),
          );
        },
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

/// عنصر واحد في الـ Quick Grid من قاعدة البيانات - محسّن بتدرج وظل
class _CategoryTileFromDB extends StatelessWidget {
  final AppCategoryConfig category;

  const _CategoryTileFromDB({required this.category});

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
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white,
              category.color.withValues(alpha: 0.08),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: category.color.withValues(alpha: 0.25),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: category.color.withValues(alpha: 0.15),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    category.color.withValues(alpha: 0.8),
                    category.color,
                  ],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: category.color.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Icon(
                category.icon,
                size: 24,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 6),
            AutoSizeText(
              category.name,
              maxLines: 2,
              minFontSize: 10,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: GoogleFonts.almarai(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF0A2647),
                height: 1.2,
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
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Skeleton للأقسام أثناء التحميل - نسخة سريعة بدون animation
class _CategoryTileSkeleton extends StatelessWidget {
  const _CategoryTileSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(16),
      ),
    );
  }
}

/// عنصر واحد في الـ Quick Grid (الثابت - احتياطي) - محسّن بتدرج وظل
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
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white,
              category.color.withValues(alpha: 0.08),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: category.color.withValues(alpha: 0.25),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: category.color.withValues(alpha: 0.15),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    category.color.withValues(alpha: 0.8),
                    category.color,
                  ],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: category.color.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Icon(
                category.icon,
                size: 24,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 6),
            AutoSizeText(
              category.name,
              maxLines: 2,
              minFontSize: 10,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: GoogleFonts.almarai(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF0A2647),
                height: 1.2,
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
                fontWeight: FontWeight.w500,
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
