import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:doctor_store/shared/services/analytics_service.dart';

import 'package:doctor_store/features/product/presentation/widgets/product_card.dart';
import 'package:doctor_store/features/product/presentation/widgets/product_card_skeleton.dart';
import 'package:doctor_store/shared/widgets/empty_state_widget.dart';
import 'package:doctor_store/features/product/presentation/providers/products_provider.dart';
import 'package:doctor_store/features/product/domain/models/product_model.dart';
import 'package:doctor_store/shared/widgets/app_footer.dart';
import 'package:doctor_store/shared/utils/sub_categories_provider.dart';
import 'package:doctor_store/shared/widgets/custom_app_bar.dart';
import 'package:doctor_store/shared/utils/categories_provider.dart';
import 'package:doctor_store/shared/widgets/responsive_center_wrapper.dart';
import 'package:doctor_store/shared/utils/responsive_layout.dart';

class CategoryScreen extends ConsumerStatefulWidget {
  final String categoryId;
  final String categoryName;
  final Color themeColor;

  const CategoryScreen({
    super.key, 
    required this.categoryId, 
    required this.categoryName,
    required this.themeColor,
  });

  @override
  ConsumerState<CategoryScreen> createState() => _CategoryScreenState();
}

class _CategoryScreenState extends ConsumerState<CategoryScreen> {
  String _sortBy = 'newest'; // newest, price_low, price_high
  bool _onlyFeatured = false;
  bool _onlyOnOffer = false;
  String _searchQuery = '';
  String? _selectedSubCategoryId;
  late final int _startMs;
  bool _loadLogged = false;

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

  @override
  void initState() {
    super.initState();
    _startMs = DateTime.now().millisecondsSinceEpoch;
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync =
        ref.watch(productsByCategoryStreamProvider(widget.categoryId));
    final subCatsAsync =
        ref.watch(subCategoriesByParentProvider(widget.categoryId));

    final List<Widget> productSlivers = productsAsync.when<List<Widget>>(
      data: (products) {
        if (!_loadLogged) {
          _loadLogged = true;
          final durationMs = DateTime.now().millisecondsSinceEpoch - _startMs;
          
          // تتبع زيارة صفحة القسم
          AnalyticsService.instance.trackSiteVisit(
            pageUrl: '/category/${widget.categoryId}',
            deviceType: _detectDeviceType(),
            country: 'Kuwait',
          );
          
          AnalyticsService.instance.trackEvent('category_products_loaded', props: {
            'duration_ms': durationMs,
            'count': products.length,
            'category': widget.categoryId,
          });
        }

        if (products.isEmpty) {
          return [
            SliverFillRemaining(
              hasScrollBody: false,
              child: EmptyStateWidget(
                icon: FontAwesomeIcons.boxOpen,
                title: "لا توجد منتجات حالياً",
                subtitle: "لم يتم إضافة منتجات لهذا القسم بعد.\nعد لاحقاً!",
                buttonText: "تصفح أقسام أخرى",
                onButtonPressed: () => context.pop(),
              ),
            ),
          ];
        }

        // تطبيق البحث الذكي + الفلاتر محلياً
        var filteredProducts = List<Product>.from(products);

        if (_searchQuery.trim().isNotEmpty) {
          final q = _searchQuery.trim().toLowerCase();
          filteredProducts = filteredProducts.where((p) {
            final text = (
              '${p.title} ${p.description} ${p.categoryArabic} ${p.tags.join(' ')}'
            ).toLowerCase();
            return text.contains(q);
          }).toList();
        }

        if (_onlyFeatured) {
          filteredProducts =
              filteredProducts.where((p) => p.isFeatured).toList();
        }
        if (_onlyOnOffer) {
          filteredProducts =
              filteredProducts.where((p) => p.hasOffers).toList();
        }
        if (_selectedSubCategoryId != null) {
          filteredProducts = filteredProducts
              .where((p) => p.subCategoryId == _selectedSubCategoryId)
              .toList();
        }

        if (filteredProducts.isEmpty) {
          return [
            SliverFillRemaining(
              hasScrollBody: false,
              child: EmptyStateWidget(
                icon: Icons.search_off,
                title: "لم نجد نتائج مطابقة",
                subtitle: "جرّب إزالة بعض الفلاتر أو تغيير طريقة الترتيب.",
                buttonText: "إلغاء الفلاتر",
                onButtonPressed: () => setState(() {
                  _onlyFeatured = false;
                  _onlyOnOffer = false;
                }),
              ),
            ),
          ];
        }

        if (_sortBy == 'price_low') {
          filteredProducts.sort((a, b) => a.price.compareTo(b.price));
        } else if (_sortBy == 'price_high') {
          filteredProducts.sort((a, b) => b.price.compareTo(a.price));
        }
        // 'newest' هو الترتيب الافتراضي من قاعدة البيانات

        return [
          SliverResponsiveCenterPadding(
            minSidePadding: 0,
            sliver: SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: _buildCategoryIntro(filteredProducts.length),
              ),
            ),
          ),
          SliverResponsiveCenterPadding(
            minSidePadding: 0,
            sliver: SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              sliver: SliverLayoutBuilder(
                builder: (context, constraints) {
                  final crossAxisCount = ResponsiveLayout.gridCountForWidth(
                    constraints.crossAxisExtent,
                    desiredItemWidth: 120,
                    minCount: 3,
                    maxCount: 5,
                  );
                  final isCompact = crossAxisCount >= 3;
                  const spacing = 12.0;
                  final mainAxisExtent = ResponsiveLayout.productCardMainAxisExtent(
                    constraints.crossAxisExtent,
                    crossAxisCount: crossAxisCount,
                    crossAxisSpacing: spacing,
                    isCompact: isCompact,
                  );

                  return SliverGrid(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      mainAxisSpacing: spacing,
                      crossAxisSpacing: spacing,
                      mainAxisExtent: mainAxisExtent,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => ProductCard(
                        product: filteredProducts[index],
                        isCompact: isCompact,
                      ),
                      childCount: filteredProducts.length,
                      addAutomaticKeepAlives: false,
                    ),
                  );
                },
              ),
            ),
          ),
        ];
      },
      loading: () => [
        SliverResponsiveCenterPadding(
          minSidePadding: 0,
          sliver: SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverLayoutBuilder(
              builder: (context, constraints) {
                final crossAxisCount = ResponsiveLayout.gridCountForWidth(
                  constraints.crossAxisExtent,
                  desiredItemWidth: 120,
                  minCount: 3,
                  maxCount: 5,
                );
                final isCompact = crossAxisCount >= 3;
                const spacing = 12.0;
                final mainAxisExtent = ResponsiveLayout.productCardMainAxisExtent(
                  constraints.crossAxisExtent,
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: spacing,
                  isCompact: isCompact,
                );

                return SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    mainAxisSpacing: spacing,
                    crossAxisSpacing: spacing,
                    mainAxisExtent: mainAxisExtent,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => const ProductCardSkeleton(),
                    childCount: 6,
                  ),
                );
              },
            ),
          ),
        ),
      ],
      error: (err, stack) => [
        SliverResponsiveCenterPadding(
          minSidePadding: 0,
          sliver: SliverFillRemaining(
            child: EmptyStateWidget(
              icon: Icons.wifi_off,
              title: "خطأ في الاتصال",
              subtitle: "تأكد من اتصالك بالإنترنت وحاول مجدداً",
              buttonText: "إعادة المحاولة",
              onButtonPressed: () => ref
                  .refresh(productsByCategoryStreamProvider(widget.categoryId)),
            ),
          ),
        ),
      ],
    );

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      body: CustomScrollView(
        cacheExtent: 800.0,
        slivers: [
          // 1. الشريط العلوي القابل للتمدد (SliverAppBar)
          SliverAppBar(
            expandedHeight: 120,
            pinned: true,
            backgroundColor: widget.themeColor,
            foregroundColor: Colors.white,
            centerTitle: true,
            automaticallyImplyLeading: false,
            title: CustomAppBarContent(
              isHome: false,
              title: widget.categoryName,
              showSearch: false,
              sharePath: '/category/${widget.categoryId}',
              shareTitle:
                  'تصفح قسم ${widget.categoryName} في متجر الدكتور',
              iconColor: Colors.white,
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      widget.themeColor,
                      widget.themeColor.withValues(alpha: 0.8),
                    ],
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      right: -30,
                      top: -20,
                      child: Icon(
                        FontAwesomeIcons.shapes,
                        size: 150,
                        color: Colors.white.withValues(alpha: 0.1),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(70),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
                child: Material(
                  color: Colors.white,
                  elevation: 4,
                  borderRadius: BorderRadius.circular(999),
                  clipBehavior: Clip.antiAlias,
                  child: Container(
                    height: 46,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: TextField(
                      onChanged: (value) =>
                          setState(() => _searchQuery = value),
                      textInputAction: TextInputAction.search,
                      textAlignVertical: TextAlignVertical.center,
                      style: GoogleFonts.almarai(
                        fontSize: 13,
                        color: const Color(0xFF0A2647),
                      ),
                      cursorColor: widget.themeColor,
                      decoration: InputDecoration(
                        hintText:
                            'ابحث داخل هذا القسم عن منتج أو نوع قماش أو لون...',
                        hintStyle: GoogleFonts.almarai(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                        ),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        disabledBorder: InputBorder.none,
                        errorBorder: InputBorder.none,
                        focusedErrorBorder: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 0,
                        ),
                        prefixIcon: const Icon(
                          Icons.search,
                          color: Colors.grey,
                          size: 20,
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            Icons.tune_rounded,
                            color: widget.themeColor,
                            size: 20,
                          ),
                          onPressed: () {
                            final subCatsValue =
                                subCatsAsync.value ?? const <AppSubCategory>[];
                            _openFiltersSheet(subCatsValue);
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // 2. شريط الفلترة والبحث – تصميم احترافي ومتماسك
          SliverToBoxAdapter(
            child: Container(
              color: Colors.grey.shade50,
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
              child: Card(
                elevation: 1.5,
                shadowColor: Colors.black12,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ترويسة مخفية حاليًا (يمكن إضافة نص توضيحي لاحقًا إن لزم)
                      const SizedBox(height: 4),

                      // صف مختصر يعرض الترتيب الحالي
                      Row(
                        children: [
                          const Icon(Icons.sort,
                              size: 18, color: Colors.grey),
                          const SizedBox(width: 6),
                          Text(
'ترتيب حسب: $_currentSortLabel',
                            style: GoogleFonts.almarai(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF0A2647),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 10),

                      // الفئات الفرعية (أيقونات فرعية مميزة في الصفحة)
                      subCatsAsync.when(
                        data: (subCats) {
                          if (subCats.isEmpty) return const SizedBox.shrink();
                          return SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                ChoiceChip(
                                  label: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: const [
                                      Icon(Icons.grid_view_rounded, size: 16),
                                      SizedBox(width: 4),
                                      Text('الكل'),
                                    ],
                                  ),
                                  selected: _selectedSubCategoryId == null,
                                  onSelected: (_) {
                                    setState(() => _selectedSubCategoryId = null);
                                  },
                                  selectedColor: widget.themeColor,
                                  backgroundColor: Colors.grey.shade100,
                                  labelStyle: GoogleFonts.almarai(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: _selectedSubCategoryId == null
                                        ? Colors.white
                                        : const Color(0xFF0A2647),
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                ...subCats.map(
                                  (s) => Padding(
                                    padding: const EdgeInsetsDirectional.only(
                                        start: 8),
                                    child: ChoiceChip(
                                      label: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.label_rounded,
                                            size: 16,
                                            color: _selectedSubCategoryId == s.id
                                                ? Colors.white
                                                : widget.themeColor,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(s.name),
                                        ],
                                      ),
                                      selected: _selectedSubCategoryId == s.id,
                                      onSelected: (_) {
                                        setState(() =>
                                            _selectedSubCategoryId = s.id);
                                      },
                                      selectedColor: widget.themeColor,
                                      backgroundColor:
                                          widget.themeColor.withValues(
                                              alpha: 0.05),
                                      labelStyle: GoogleFonts.almarai(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: _selectedSubCategoryId == s.id
                                            ? Colors.white
                                            : const Color(0xFF0A2647),
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                        loading: () =>
                            const LinearProgressIndicator(minHeight: 2),
                        error: (_, __) => const SizedBox.shrink(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // 3. شبكة المنتجات (Slivers) — بناء كسول لتحسين الأداء
          ...productSlivers,

          const SliverResponsiveCenterPadding(
            minSidePadding: 0,
            sliver: SliverToBoxAdapter(child: SizedBox(height: 30)),
          ),
          const SliverResponsiveCenterPadding(
            minSidePadding: 0,
            sliver: SliverToBoxAdapter(child: AppFooter()),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryIntro(int count) {
    final hasFilter = _onlyFeatured || _onlyOnOffer;
    final countLabel = hasFilter ? 'نتائج مختارة: $count' : '$count منتج متوفر';
    final tagline = _getCategoryTagline(widget.categoryId);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [
            widget.themeColor.withValues(alpha: 0.12),
            widget.themeColor.withValues(alpha: 0.03),
          ],
        ),
        border: Border.all(color: widget.themeColor.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.9),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: widget.themeColor.withValues(alpha: 0.25),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Icon(FontAwesomeIcons.shapes, size: 18, color: widget.themeColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.categoryName,
                  style: GoogleFonts.almarai(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0A2647),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  tagline,
                  style: GoogleFonts.almarai(
                    fontSize: 12,
                    color: Colors.grey.shade700,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                countLabel,
                style: GoogleFonts.almarai(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF0A2647),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                hasFilter ? 'مع تطبيق فلاتر مخصصة' : 'يمكنك استخدام الفلاتر بالأعلى',
                style: GoogleFonts.almarai(
                  fontSize: 11,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String get _currentSortLabel {
    switch (_sortBy) {
      case 'price_low':
        return 'الأقل سعراً';
      case 'price_high':
        return 'الأعلى سعراً';
      default:
        return 'الأحدث';
    }
  }

  void _openFiltersSheet(List<AppSubCategory> subCats) {
    String tempSortBy = _sortBy;
    bool tempOnlyFeatured = _onlyFeatured;
    bool tempOnlyOnOffer = _onlyOnOffer;
    String? tempSelectedSubCategoryId = _selectedSubCategoryId;

    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: StatefulBuilder(
            builder: (context, setModalState) {
              final hasAnyFilter = tempOnlyFeatured ||
                  tempOnlyOnOffer ||
                  tempSelectedSubCategoryId != null;

              return ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 520),
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'الفرز والفلترة',
                              style: GoogleFonts.almarai(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF0A2647),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () => Navigator.of(ctx).pop(),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'الترتيب',
                          style: GoogleFonts.almarai(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children: [
                            ChoiceChip(
                              label: const Text('الأحدث'),
                              selected: tempSortBy == 'newest',
                              onSelected: (_) =>
                                  setModalState(() => tempSortBy = 'newest'),
                            ),
                            ChoiceChip(
                              label: const Text('الأقل سعراً'),
                              selected: tempSortBy == 'price_low',
                              onSelected: (_) =>
                                  setModalState(() => tempSortBy = 'price_low'),
                            ),
                            ChoiceChip(
                              label: const Text('الأعلى سعراً'),
                              selected: tempSortBy == 'price_high',
                              onSelected: (_) =>
                                  setModalState(() => tempSortBy = 'price_high'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'الفلاتر',
                          style: GoogleFonts.almarai(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children: [
                            FilterChip(
                              label: const Text('منتجات مميزة'),
                              selected: tempOnlyFeatured,
                              onSelected: (val) => setModalState(
                                  () => tempOnlyFeatured = val),
                              avatar: const Icon(Icons.star_rounded,
                                  size: 16, color: Colors.amber),
                            ),
                            FilterChip(
                              label: const Text('عروض وتخفيضات'),
                              selected: tempOnlyOnOffer,
                              onSelected: (val) => setModalState(
                                  () => tempOnlyOnOffer = val),
                              avatar: const Icon(Icons.local_offer_rounded,
                                  size: 16, color: Colors.redAccent),
                            ),
                          ],
                        ),
                        if (subCats.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          Text(
                            'الفئات الفرعية',
                            style: GoogleFonts.almarai(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                ChoiceChip(
                                  label: const Text('الكل'),
                                  selected: tempSelectedSubCategoryId == null,
                                  onSelected: (_) => setModalState(
                                      () => tempSelectedSubCategoryId = null),
                                ),
                                const SizedBox(width: 8),
                                ...subCats.map(
                                  (s) => Padding(
                                    padding: const EdgeInsetsDirectional.only(
                                        start: 8),
                                    child: ChoiceChip(
                                      label: Text(s.name),
                                      selected:
                                          tempSelectedSubCategoryId == s.id,
                                      onSelected: (_) => setModalState(
                                          () => tempSelectedSubCategoryId = s.id),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            TextButton(
                              onPressed: () {
                                setModalState(() {
                                  tempSortBy = 'newest';
                                  tempOnlyFeatured = false;
                                  tempOnlyOnOffer = false;
                                  tempSelectedSubCategoryId = null;
                                });
                              },
                              child: Text(
                                'مسح الكل',
                                style: GoogleFonts.almarai(
                                  fontSize: 12,
                                  color: Colors.redAccent,
                                ),
                              ),
                            ),
                            const Spacer(),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: widget.themeColor,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                              ),
                              onPressed: () {
                                setState(() {
                                  _sortBy = tempSortBy;
                                  _onlyFeatured = tempOnlyFeatured;
                                  _onlyOnOffer = tempOnlyOnOffer;
                                  _selectedSubCategoryId =
                                      tempSelectedSubCategoryId;
                                });
                                Navigator.of(ctx).pop();
                              },
                              child: Text(
                                hasAnyFilter ? 'تطبيق الفلاتر' : 'إغلاق',
                                style: GoogleFonts.almarai(fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  String _getCategoryTagline(String id) {
    // نحاول أولاً جلب الوصف القصير من جدول الأقسام الديناميكي
    final catsAsync = ref.read(categoriesConfigProvider);
    final cats = catsAsync.asData?.value;
    if (cats != null) {
      for (final c in cats) {
        if (c.id == id && c.subtitle.trim().isNotEmpty) {
          return c.subtitle.trim();
        }
      }
    }

    // في حال لم نجد قسماً مطابقاً نستخدم النصوص الافتراضية القديمة
    switch (id) {
      case 'bedding':
        return 'مفارش فاخرة تمنحك نومًا عميقًا وتضفي لمسة أناقة على غرفتك.';
      case 'mattresses':
        return 'مجموعة مختارة من الفرشات المريحة لصحة ظهرك وراحة نومك.';
      case 'pillows':
        return 'وسائد ناعمة بمستويات دعم مختلفة تناسب أسلوب نومك.';
      case 'furniture':
        return 'قطع أثاث عملية وعصرية لتنسيق بيت أنيق ومريح.';
      case 'dining_table':
        return 'طاولات سفرة تجمع العائلة على أجمل اللحظات.';
      case 'carpets':
        return 'سجاد بتصاميم أنيقة يكمّل ديكور منزلك ويزيده دفئًا.';
      case 'baby_supplies':
        return 'مستلزمات أطفال مختارة بعناية لراحة وسلامة صغيرك.';
      case 'home_decor':
        return 'إكسسوارات وديكورات تضيف روحًا خاصة لكل زاوية في منزلك.';
      default:
        return 'منتجات منتقاة بعناية لتناسب ذوقك وتكمل أسلوب حياتك.';
    }
  }
}
