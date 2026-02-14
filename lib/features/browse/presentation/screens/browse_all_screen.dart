import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import 'package:doctor_store/shared/utils/categories_provider.dart';
import 'package:doctor_store/shared/utils/product_nav_helper.dart';
import 'package:doctor_store/shared/utils/responsive_layout.dart';
import 'package:doctor_store/features/product/presentation/providers/products_provider.dart';
import 'package:doctor_store/shared/widgets/custom_app_bar.dart';

/// صفحة التصفح الكامل - تعرض جميع الأقسام والمنتجات بطريقة احترافية
class BrowseAllScreen extends ConsumerStatefulWidget {
  const BrowseAllScreen({super.key});

  @override
  ConsumerState<BrowseAllScreen> createState() => _BrowseAllScreenState();
}

class _BrowseAllScreenState extends ConsumerState<BrowseAllScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedSort =
      'random'; // random, new, popular, price_low, price_high

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesConfigProvider);
    final allProductsAsync = ref.watch(allProductsStreamProvider);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A2647),
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false,
        title: CustomAppBarContent(
          isHome: false,
          centerWidget: Text(
            'تصفح المتجر',
            style: GoogleFonts.almarai(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          showSearch: true,
          iconColor: Colors.white,
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF0A2647),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  offset: const Offset(0, 2),
                  blurRadius: 4,
                ),
              ],
            ),
            child: TabBar(
              controller: _tabController,
              indicatorColor: const Color(0xFFD4AF37),
              indicatorWeight: 4,
              indicatorSize: TabBarIndicatorSize.tab,
              indicator: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: Color(0xFFD4AF37),
                    width: 4,
                  ),
                ),
              ),
              labelStyle: GoogleFonts.almarai(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
              unselectedLabelStyle: GoogleFonts.almarai(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              tabs: [
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.grid_view_rounded, size: 18),
                      const SizedBox(width: 8),
                      Text('الأقسام', style: GoogleFonts.almarai()),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.shopping_bag_outlined, size: 18),
                      const SizedBox(width: 8),
                      Text('جميع المنتجات', style: GoogleFonts.almarai()),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // =============== التاب الأول: الأقسام ===============
          _buildCategoriesTab(categoriesAsync),

          // =============== التاب الثاني: جميع المنتجات ===============
          _buildAllProductsTab(allProductsAsync),
        ],
      ),
    );
  }

  /// تاب الأقسام
  Widget _buildCategoriesTab(AsyncValue categoriesAsync) {
    return categoriesAsync.when(
      data: (categories) {
        if (categories.isEmpty) {
          return const Center(child: Text('لا توجد أقسام'));
        }

        return CustomScrollView(
          slivers: [
            // هيدر ترحيبي
            SliverToBoxAdapter(
              child: Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0A2647), Color(0xFF144272)],
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.category_outlined,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'اكتشف منتجاتنا',
                            style: GoogleFonts.almarai(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'تصفح ${categories.length} قسم متنوع',
                            style: GoogleFonts.almarai(
                              fontSize: 13,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // شبكة الأقسام
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverLayoutBuilder(
                builder: (context, constraints) {
                  final crossAxisCount = ResponsiveLayout.gridCountForWidth(
                    constraints.crossAxisExtent,
                    desiredItemWidth: 200,
                    minCount: 2,
                    maxCount: 5,
                  );

                  return SliverGrid(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      childAspectRatio: 1.1,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final category = categories[index];
                        return _buildCategoryCard(category);
                      },
                      childCount: categories.length,
                    ),
                  );
                },
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 20)),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, s) => Center(child: Text('خطأ: $e')),
    );
  }

  /// بطاقة قسم واحد
  Widget _buildCategoryCard(dynamic category) {
    final iconData = _getCategoryIcon(category.id);

    return InkWell(
      onTap: () => context.push(
        '/category/${category.id}',
        extra: {
          'name': category.name,
          'color': category.color,
        },
      ),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: category.color.withValues(alpha: 0.3)),
          boxShadow: [
            BoxShadow(
              color: category.color.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: category.color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                iconData,
                size: 32,
                color: category.color,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              category.name,
              textAlign: TextAlign.center,
              style: GoogleFonts.almarai(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF0A2647),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// تاب جميع المنتجات
  Widget _buildAllProductsTab(AsyncValue allProductsAsync) {
    return allProductsAsync.when(
      data: (products) {
        if (products.isEmpty) {
          return const Center(child: Text('لا توجد منتجات'));
        }

        // ترتيب المنتجات حسب الاختيار
        final sortedProducts = _sortProducts(products.toList());

        return CustomScrollView(
          slivers: [
            // شريط الفلترة والترتيب
            SliverToBoxAdapter(
              child: Container(
                margin: const EdgeInsets.all(16),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(Icons.sort, size: 20, color: Color(0xFF0A2647)),
                    const SizedBox(width: 8),
                    Text(
                      'الترتيب:',
                      style: GoogleFonts.almarai(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF0A2647),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildSortChip('عشوائي', 'random'),
                            _buildSortChip('الأحدث', 'new'),
                            _buildSortChip('الأكثر مبيعاً', 'popular'),
                            _buildSortChip('السعر (منخفض)', 'price_low'),
                            _buildSortChip('السعر (مرتفع)', 'price_high'),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // عداد المنتجات
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'عرض ${sortedProducts.length} منتج',
                  style: GoogleFonts.almarai(
                    fontSize: 13,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 12)),

            // قائمة المنتجات (عمودية - فوق بعض)
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _buildProductListCard(sortedProducts[index]),
                    );
                  },
                  childCount: sortedProducts.length,
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 80)),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, s) => Center(child: Text('خطأ: $e')),
    );
  }

  /// زر فلتر الترتيب
  Widget _buildSortChip(String label, String value) {
    final isSelected = _selectedSort == value;
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: FilterChip(
        label: Text(
          label,
          style: GoogleFonts.almarai(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
            color: isSelected ? Colors.white : const Color(0xFF0A2647),
          ),
        ),
        selected: isSelected,
        onSelected: (selected) {
          setState(() {
            _selectedSort = value;
          });
        },
        selectedColor: const Color(0xFF0A2647),
        backgroundColor: Colors.grey[100],
        checkmarkColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
    );
  }

  /// ترتيب المنتجات
  List _sortProducts(List products) {
    switch (_selectedSort) {
      case 'new':
        // ترتيب عشوائي لأن createdAt غير متوفر
        products.shuffle();
        break;
      case 'popular':
        products.sort((a, b) => b.ratingCount.compareTo(a.ratingCount));
        break;
      case 'price_low':
        products.sort((a, b) => a.price.compareTo(b.price));
        break;
      case 'price_high':
        products.sort((a, b) => b.price.compareTo(a.price));
        break;
      case 'random':
      default:
        products.shuffle();
        break;
    }
    return products;
  }

  /// بطاقة منتج واحد (عرض أفقي)
  Widget _buildProductListCard(dynamic product) {
    final hasDiscount =
        product.oldPrice != null && product.oldPrice! > product.price;
    final discountPercent = hasDiscount
        ? (((product.oldPrice! - product.price) / product.oldPrice!) * 100)
            .round()
        : 0;

    return InkWell(
      onTap: () => context.push(
        buildProductDetailsPath(product),
        extra: product,
      ),
      child: Container(
        height: 140,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // صورة المنتج
            Stack(
              children: [
                Container(
                  width: 130,
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.horizontal(
                        right: Radius.circular(16)),
                    color: Colors.grey[100],
                  ),
                  child: ClipRRect(
                    borderRadius: const BorderRadius.horizontal(
                        right: Radius.circular(16)),
                    child: product.imageUrl.isNotEmpty
                        ? Image.network(
                            product.thumbnailUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                const Icon(Icons.image, size: 40),
                          )
                        : const Icon(Icons.image, size: 40),
                  ),
                ),
                // شارة الخصم
                if (hasDiscount)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '-$discountPercent%',
                        style: GoogleFonts.almarai(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                // شارة فلاش
                if (product.isFlashDeal)
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD4AF37),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.flash_on,
                              size: 12, color: Colors.white),
                          const SizedBox(width: 2),
                          Text(
                            'فلاش',
                            style: GoogleFonts.almarai(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            // تفاصيل المنتج
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // اسم المنتج
                    Text(
                      product.title,
                      style: GoogleFonts.almarai(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF0A2647),
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    // التقييم
                    if (product.ratingCount > 0)
                      Row(
                        children: [
                          const Icon(Icons.star,
                              size: 14, color: Color(0xFFD4AF37)),
                          const SizedBox(width: 4),
                          Text(
                            product.ratingAverage.toStringAsFixed(1),
                            style: GoogleFonts.almarai(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[700],
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '(${product.ratingCount})',
                            style: GoogleFonts.almarai(
                              fontSize: 11,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                    const Spacer(),
                    // السعر
                    Row(
                      children: [
                        Text(
                          '${product.price.toStringAsFixed(0)} دينار',
                          style: GoogleFonts.almarai(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF0A2647),
                          ),
                        ),
                        if (hasDiscount) const SizedBox(width: 8),
                        if (hasDiscount)
                          Text(
                            '${product.oldPrice!.toStringAsFixed(0)} دينار',
                            style: GoogleFonts.almarai(
                              fontSize: 12,
                              color: Colors.grey,
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0A2647),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.arrow_back_ios_rounded,
                            size: 14,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// أيقونات الأقسام
  IconData _getCategoryIcon(String categoryId) {
    switch (categoryId) {
      case 'bedding':
        return FontAwesomeIcons.bed;
      case 'mattresses':
        return FontAwesomeIcons.layerGroup;
      case 'pillows':
        return FontAwesomeIcons.cloudMoon;
      case 'furniture':
        return FontAwesomeIcons.couch;
      case 'dining_table':
        return FontAwesomeIcons.utensils;
      case 'carpets':
        return FontAwesomeIcons.rug;
      case 'baby_supplies':
        return FontAwesomeIcons.baby;
      case 'home_decor':
        return FontAwesomeIcons.bahai;
      default:
        return Icons.category;
    }
  }
}
