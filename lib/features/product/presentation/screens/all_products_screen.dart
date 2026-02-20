import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
// import 'package:google_fonts/google_fonts.dart'; // ⚠️ REMOVED for smaller bundle
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import 'package:doctor_store/features/product/domain/models/product_model.dart';
import 'package:doctor_store/features/product/presentation/widgets/product_card.dart';
import 'package:doctor_store/features/product/presentation/widgets/product_card_skeleton.dart';
import 'package:doctor_store/features/product/presentation/widgets/product_search_bottom_sheet.dart';
import 'package:doctor_store/features/product/presentation/providers/products_provider.dart';
import 'package:doctor_store/shared/utils/responsive_layout.dart';
import 'package:doctor_store/shared/utils/app_constants.dart';
import 'package:doctor_store/shared/utils/categories_provider.dart';
import 'package:doctor_store/shared/widgets/app_footer.dart';
import 'package:doctor_store/shared/widgets/custom_app_bar.dart';
import 'package:doctor_store/shared/widgets/responsive_center_wrapper.dart';

class AllProductsScreen extends ConsumerStatefulWidget {
  final String? initialSort; // new, best, offers, or null

  const AllProductsScreen({super.key, this.initialSort});

  @override
  ConsumerState<AllProductsScreen> createState() => _AllProductsScreenState();
}

class _AllProductsScreenState extends ConsumerState<AllProductsScreen> {
  // للتحكم في الترتيب العام
  String _sortBy = 'newest'; // newest, price_low, price_high, best, offers
  String? _selectedCategoryId; // فلتر سريع حسب الفئة (الكل افتراضياً)
  final ScrollController _scrollController = ScrollController();

  // إعدادات الفئات الافتراضية (fallback) لعرضها كسكاشن أفقية (ستايل Netflix)
  // إذا كانت هناك بيانات في جدول الأقسام (categories) سيتم استخدامه بدلاً منها.
  final List<Map<String, dynamic>> _categories = [
    {
      'id': AppConstants.catBedding,
      'name': 'بياضات ومفارش',
      'subtitle': 'راحة وفخامة لغرفة نومك',
      'icon': FontAwesomeIcons.bed,
      'color': const Color(0xFF5C6BC0),
    },
    {
      'id': AppConstants.catMattresses,
      'name': 'فرشات نوم',
      'subtitle': 'دعم صحي وراحة عميقة',
      'icon': FontAwesomeIcons.bed,
      'color': const Color(0xFF42A5F5),
    },
    {
      'id': AppConstants.catPillows,
      'name': 'وسائد طبية',
      'subtitle': 'نوم صحي ورقبة مريحة',
      'icon': FontAwesomeIcons.cloud,
      'color': const Color(0xFF78909C),
    },
    {
      'id': AppConstants.catFurniture,
      'name': 'أثاث منزلي',
      'subtitle': 'تجديد كامل لبيت أنيق',
      'icon': FontAwesomeIcons.couch,
      'color': const Color(0xFFFFA726),
    },
    {
      'id': AppConstants.catDining,
      'name': 'طاولات سفرة',
      'subtitle': 'تجمعات عائلية دافئة',
      'icon': Icons.table_restaurant_rounded,
      'color': const Color(0xFF8D6E63),
    },
    {
      'id': AppConstants.catCarpets,
      'name': 'سجاد فاخر',
      'subtitle': 'لمسة دفء وأناقة',
      'icon': FontAwesomeIcons.rug,
      'color': const Color(0xFF26A69A),
    },
    {
      'id': AppConstants.catBaby,
      'name': 'عالم الأطفال',
      'subtitle': 'أمان وراحة لصغيرك',
      'icon': FontAwesomeIcons.baby,
      'color': const Color(0xFFEC407A),
    },
    {
      'id': AppConstants.catDecor,
      'name': 'ديكورات منزلية',
      'subtitle': 'لمسات فنية لكل زاوية',
      'icon': FontAwesomeIcons.leaf,
      'color': const Color(0xFF66BB6A),
    },
    {
      'id': AppConstants.catTowels,
      'name': 'مناشف',
      'subtitle': 'نعومة وامتصاص عالي',
      'icon': Icons.local_laundry_service_rounded,
      'color': const Color(0xFF26C6DA),
    },
  ];

  @override
  void initState() {
    super.initState();
    // قراءة sort القادم من الراوتر مرة واحدة عند فتح الصفحة
    final sort = widget.initialSort;
    if (sort == 'new') {
      _sortBy = 'newest';
    } else if (sort == 'best') {
      _sortBy = 'best';
    } else if (sort == 'offers') {
      _sortBy = 'offers';
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  // قائمة الأقسام الفعّالة بعد دمج بيانات لوحة التحكم مع الأيقونات الافتراضية
  List<Map<String, dynamic>> get _effectiveCategories {
    final catsAsync = ref.watch(categoriesConfigProvider);
    final data = catsAsync.asData?.value;

    // في حال عدم توفر جدول الأقسام نستخدم القائمة الافتراضية
    if (data == null || data.isEmpty) {
      return _categories;
    }

    return data
        .where((c) => c.isActive)
        .map((c) => {
              'id': c.id,
              'name': c.name,
              'subtitle': c.subtitle.isNotEmpty
                  ? c.subtitle
                  : 'منتجات مختارة من هذا القسم',
              'icon': _iconForCategory(c.id),
              'color': c.color,
            })
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final allProductsAsync = ref.watch(allProductsStreamProvider);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: CustomAppBar(
        isHome: false,
        title: 'اكتشف مجموعتنا',
        showSearch: true,
        onSearchTap: () => showProductSearchBottomSheet(context),
        showShare: false,
        moveCartNextToSearch: true,
      ),
      body: CustomScrollView(
        controller: _scrollController,
        cacheExtent: 800.0,
        slivers: [
          // 1. عرض ذكي لكل الفئات كسكاشن أفقية (ستايل Netflix)
          SliverResponsiveCenterPadding(
            minSidePadding: 0,
            sliver: allProductsAsync.when(
              data: (products) => _buildAllProductsSliver(products),
              loading: () => _buildLoadingSliver(),
              error: (err, stack) => _buildErrorSliver(err),
            ),
          ),

          // مساحة في الأسفل + Footer موحّد
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

  Widget _buildSmartIntro(
      int total, int offersCount, int bestCount, int activeCategoriesCount) {
    String sortLabel;
    switch (_sortBy) {
      case 'price_low':
        sortLabel = 'الأقل سعراً';
        break;
      case 'price_high':
        sortLabel = 'الأعلى سعراً';
        break;
      case 'best':
        sortLabel = 'الأكثر مبيعاً';
        break;
      case 'offers':
        sortLabel = 'العروض';
        break;
      default:
        sortLabel = 'الأحدث';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [Color(0xFF0A2647), Color(0xFF144272)],
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'كل مجموعات النوم في مكان واحد',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'تصفح $total منتجاً عبر $activeCategoriesCount فئة مختلفة من تشكيلتنا – مع فلاتر ذكية للوصول لما يناسبك بسرعة.',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.6,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.tune, size: 14, color: Colors.white),
                    const SizedBox(width: 4),
                    Text(
                      'فرز حسب: $sortLabel',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (offersCount > 0)
                    _buildMetricPill(
                        Icons.local_offer, '$offersCount عرض متاح'),
                  if (bestCount > 0) ...[
                    const SizedBox(width: 6),
                    _buildMetricPill(Icons.star, '$bestCount منتج بتقييم عالٍ'),
                  ],
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricPill(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.amberAccent),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  /// زر واحد مرتب يفتح نافذة سفلية لاختيار طريقة الترتيب.
  Widget _buildSortFilterButton() {
    String currentLabel;
    switch (_sortBy) {
      case 'price_low':
        currentLabel = 'الأقل سعراً';
        break;
      case 'price_high':
        currentLabel = 'الأعلى سعراً';
        break;
      case 'best':
        currentLabel = 'الأكثر مبيعاً';
        break;
      case 'offers':
        currentLabel = 'العروض';
        break;
      default:
        currentLabel = 'الأحدث';
    }

    return OutlinedButton.icon(
      onPressed: _openSortBottomSheet,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
        ),
        side: BorderSide(
          color: Colors.grey.withValues(alpha: 0.4),
          width: 1,
        ),
      ),
      icon: const Icon(Icons.tune_rounded, size: 18, color: Color(0xFF0A2647)),
      label: Text(
        currentLabel,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: const Color(0xFF0A2647),
        ),
      ),
    );
  }

  /// نافذة سفلية بسيطة لاختيار نوع الترتيب بطريقة احترافية.
  void _openSortBottomSheet() {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        String tempSort = _sortBy;
        return StatefulBuilder(
          builder: (context, setModalState) {
            Widget buildOption(String id, String label, IconData icon) {
              final selected = tempSort == id;
              return ListTile(
                onTap: () => setModalState(() => tempSort = id),
                leading: Icon(
                  icon,
                  color:
                      selected ? const Color(0xFF0A2647) : Colors.grey[500],
                ),
                title: Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight:
                        selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
                trailing: selected
                    ? const Icon(Icons.check, color: Color(0xFF0A2647))
                    : null,
              );
            }

            return SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    Text(
                      'ترتيب المنتجات',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    buildOption('newest', 'الأحدث', Icons.fiber_new_rounded),
                    buildOption(
                        'price_low', 'الأقل سعراً', Icons.arrow_downward_rounded),
                    buildOption(
                        'price_high', 'الأعلى سعراً', Icons.arrow_upward_rounded),
                    buildOption('best', 'الأكثر مبيعاً', Icons.star_rate_rounded),
                    buildOption(
                        'offers', 'العروض', Icons.local_offer_rounded),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0A2647),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 10,
                          ),
                        ),
                        onPressed: () {
                          setState(() => _sortBy = tempSort);
                          Navigator.of(ctx).pop();
                        },
                        child: Text(
                          'تطبيق الترتيب',
                          style: TextStyle(fontSize: 13),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// اختيار أيقونة مناسبة لقسم معيّن
  IconData _iconForCategory(String id) {
    switch (id) {
      case AppConstants.catBedding:
        return FontAwesomeIcons.bed;
      case AppConstants.catMattresses:
        return FontAwesomeIcons.bed;
      case AppConstants.catPillows:
        return FontAwesomeIcons.cloud;
      case AppConstants.catFurniture:
        return FontAwesomeIcons.couch;
      case AppConstants.catDining:
        return Icons.table_restaurant_rounded;
      case AppConstants.catCarpets:
        return FontAwesomeIcons.rug;
      case AppConstants.catBaby:
        return FontAwesomeIcons.baby;
      case AppConstants.catDecor:
        return FontAwesomeIcons.leaf;
      case AppConstants.catTowels:
        return Icons.local_laundry_service_rounded;
      default:
        return Icons.category_outlined;
    }
  }

  /// فلاتر سريعة حسب الفئة (الكل + فئات رئيسية)
  Widget _buildCategoryFilterChips() {
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
                Text('كل الفئات'),
              ],
            ),
            selected: _selectedCategoryId == null,
            onSelected: (_) => setState(() => _selectedCategoryId = null),
            selectedColor: const Color(0xFF0A2647),
            backgroundColor: Colors.grey.shade100,
            labelStyle: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: _selectedCategoryId == null
                  ? Colors.white
                  : const Color(0xFF0A2647),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ),
          const SizedBox(width: 8),
          ..._effectiveCategories.map((cat) {
            final id = cat['id'] as String;
            final name = cat['name'] as String;
            final color = cat['color'] as Color;
            final isSelected = _selectedCategoryId == id;
            return Padding(
              padding: const EdgeInsetsDirectional.only(end: 8.0),
              child: ChoiceChip(
                label: Text(name),
                selected: isSelected,
                onSelected: (_) => setState(() => _selectedCategoryId = id),
                selectedColor: color,
                backgroundColor: color.withValues(alpha: 0.08),
                labelStyle: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? Colors.white : const Color(0xFF0A2647),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildAllProductsSliver(List<Product> products) {
    if (products.isEmpty) {
      return SliverToBoxAdapter(
        child: Container(
          height: 400,
          alignment: Alignment.center,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.search_off, size: 80, color: Colors.grey[300]),
              const SizedBox(height: 16),
              Text(
                "لا توجد منتجات متاحة حالياً",
                style: TextStyle(color: Colors.grey, fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }

    final total = products.length;
    final offersCount = products.where((p) => p.hasOffers).length;
    final bestCount = products.where((p) => p.ratingCount > 0).length;

    final Map<String, List<Product>> grouped = {};
    for (final p in products) {
      grouped.putIfAbsent(p.category, () => []).add(p);
    }
    final activeCategoriesCount =
        grouped.values.where((list) => list.isNotEmpty).length;

    final sectionWidgets = <Widget>[
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSmartIntro(
                total, offersCount, bestCount, activeCategoriesCount),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _buildCategoryFilterChips()),
                const SizedBox(width: 8),
                _buildSortFilterButton(),
              ],
            ),
          ],
        ),
      ),
    ];

    sectionWidgets.addAll(_buildCategorySections(grouped));

    if (sectionWidgets.length == 1) {
      sectionWidgets.add(
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 40),
          child: Center(
            child: Text(
              "لم يتم العثور على منتجات ضمن الفئات الحالية.",
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),
          ),
        ),
      );
    }

    return SliverList(
      delegate: SliverChildListDelegate(sectionWidgets),
    );
  }

  Widget _buildLoadingSliver() {
    return SliverPadding(
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

          return SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              mainAxisExtent: isCompact ? 270 : 330,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) => const ProductCardSkeleton(),
              childCount: 6,
            ),
          );
        },
      ),
    );
  }

  Widget _buildErrorSliver(Object error) {
    return SliverToBoxAdapter(
      child: Container(
        height: 200,
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "حدث خطأ بسيط أثناء تحميل المنتجات.",
              style: TextStyle(
                color: Colors.redAccent,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              "تأكد من اتصالك بالإنترنت ثم حاول مرة أخرى.",
              style: TextStyle(
                color: Colors.grey,
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildCategorySections(
      Map<String, List<Product>> groupedProducts) {
    final List<Widget> sections = [];

    for (final cat in _effectiveCategories) {
      final id = cat['id'] as String;

      // في حال اختيار فئة معينة من الفلاتر، نظهر هذه الفئة فقط
      if (_selectedCategoryId != null && id != _selectedCategoryId) {
        continue;
      }

      final rawList = groupedProducts[id];
      if (rawList == null || rawList.isEmpty) continue;

      var catProducts = List<Product>.from(rawList);

      if (_sortBy == 'price_low') {
        catProducts.sort((a, b) => a.price.compareTo(b.price));
      } else if (_sortBy == 'price_high') {
        catProducts.sort((a, b) => b.price.compareTo(a.price));
      } else if (_sortBy == 'best') {
        catProducts.sort((a, b) => b.ratingCount.compareTo(a.ratingCount));
      } else if (_sortBy == 'offers') {
        catProducts = catProducts.where((p) => p.hasOffers).toList();
      }

      if (catProducts.isEmpty) continue;

      // تحديد حد أقصى لكل سكشن لتحسين الأداء
      catProducts = catProducts.take(12).toList();

      sections.add(
        _buildCategoryRowSection(
          id: id,
          title: cat['name'] as String,
          subtitle: cat['subtitle'] as String,
          color: cat['color'] as Color,
          icon: cat['icon'] as IconData,
          products: catProducts,
        ),
      );
      sections.add(const SizedBox(height: 24));
    }

    return sections;
  }

  Widget _buildCategoryRowSection({
    required String id,
    required String title,
    required String subtitle,
    required Color color,
    required IconData icon,
    required List<Product> products,
  }) {
    final theme = Theme.of(context);
    final primaryTitleColor =
        theme.textTheme.titleLarge?.color ?? Colors.black87;
    final baseSubtitleColor =
        theme.textTheme.bodySmall?.color ?? Colors.black54;
    final subtitleColor = baseSubtitleColor.withValues(alpha: 0.7);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // نلف الجزء الأيسر بـ Expanded حتى يتمكن النص من الالتفاف بدون Overflow
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 4,
                      height: 22,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        icon,
                        size: 16,
                        color: color,
                      ),
                    ),
                    const SizedBox(width: 8),
                    // النصوص يمكن أن تلتف داخل المساحة المتاحة
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: primaryTitleColor,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            style: TextStyle(
                              fontSize: 11,
                              color: subtitleColor,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () => context.push(
                  '/category/$id',
                  extra: {'name': title, 'color': color},
                ),
                child: Row(
                  children: [
                    Text(
                      'عرض الكل',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: primaryTitleColor,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.arrow_forward_ios,
                        size: 12, color: primaryTitleColor),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 280,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: products.length,
            itemBuilder: (context, index) {
              final product = products[index];
              return Container(
                width: 170,
                margin: EdgeInsetsDirectional.only(
                  end: index == products.length - 1 ? 0 : 12,
                ),
                child: ProductCard(
                  product: product,
                  heroTag: 'all_${id}_${product.id}',
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
