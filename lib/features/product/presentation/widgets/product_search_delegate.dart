import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import 'package:doctor_store/features/product/domain/models/product_model.dart';
import 'package:doctor_store/features/product/presentation/widgets/product_card.dart';
import 'package:doctor_store/features/product/presentation/widgets/product_card_skeleton.dart';
import 'package:doctor_store/shared/services/smart_search_service.dart';
import 'package:doctor_store/shared/utils/responsive_layout.dart';

class ProductSearchDelegate extends SearchDelegate {
  
  // قائمة بسيطة للاحتفاظ بآخر عمليات البحث خلال جلسة الاستخدام الحالية فقط
  static final List<String> _recentQueries = [];
  
  // تخصيص مظهر شريط البحث (كما في تصميمك)
  @override
  ThemeData appBarTheme(BuildContext context) {
    return Theme.of(context).copyWith(
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF0A2647), // لون الهوية
        foregroundColor: Colors.white,
        elevation: 0,
        toolbarHeight: 70,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.1),
        hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      ),
      textTheme: TextTheme(
        titleLarge: GoogleFonts.almarai(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.normal,
        ),
      ),
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: Colors.white,
        selectionColor: Colors.blueAccent,
      ),
    );
  }

  @override
  String? get searchFieldLabel => 'عن ماذا تبحث اليوم؟...';

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(
          icon: const Icon(Icons.clear, color: Colors.white),
          onPressed: () {
            query = '';
            showSuggestions(context);
          },
        ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: Colors.white),
      onPressed: () => close(context, null),
    );
  }

  // ✅ النتائج النهائية
  @override
  Widget buildResults(BuildContext context) {
    return _buildSearchResults(context);
  }

  // ✅ الاقتراحات
  @override
  Widget buildSuggestions(BuildContext context) {
    if (query.isEmpty) {
      return _buildQuickSuggestions(context);
    }
    // تفعيل البحث الفوري أثناء الكتابة
    return _buildSearchResults(context);
  }

  // 1. الاقتراحات السريعة + الذكية (أكثر بحثاً + آخر ما بحثت عنه)
  Widget _buildQuickSuggestions(BuildContext context) {
    final popularTags = [
      {'label': 'أطفال', 'icon': FontAwesomeIcons.baby},
      {'label': 'مخدات', 'icon': FontAwesomeIcons.cloud},
      {'label': 'طاولات', 'icon': Icons.table_restaurant_rounded},
      {'label': 'سجاد', 'icon': FontAwesomeIcons.rug},
      {'label': 'مفارش', 'icon': FontAwesomeIcons.bed},
      {'label': 'ديكور', 'icon': FontAwesomeIcons.leaf},
    ];

    return Container(
      color: Colors.grey[50],
      padding: const EdgeInsets.all(20),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // هيدر ترحيبي للبحث
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                gradient: const LinearGradient(
                  colors: [Color(0xFF0A2647), Color(0xFF144272)],
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.search,
                        color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ابحث عن منتجك المفضل',
                          style: GoogleFonts.almarai(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'اكتب اسم المنتج، النوع، أو استخدم كلمات مثل: فرشات، طاولات، مخدات...',
                          style: GoogleFonts.almarai(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // قسم "الأكثر بحثاً"
            Row(
              children: [
                const Icon(Icons.local_fire_department,
                    color: Colors.orange, size: 20),
                const SizedBox(width: 8),
                Text(
                  "الأكثر بحثاً",
                  style: GoogleFonts.almarai(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF0A2647)),
                ),
              ],
            ),
            const SizedBox(height: 15),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: popularTags.map((tag) {
                return ActionChip(
                  elevation: 0,
                backgroundColor: Colors.white,
                side: BorderSide(color: Colors.grey.shade200),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                avatar: Icon(tag['icon'] as IconData, size: 16, color: const Color(0xFF0A2647)),
                label: Text(
                  tag['label'] as String,
                  style: GoogleFonts.almarai(color: const Color(0xFF0A2647), fontWeight: FontWeight.w600),
                ),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                onPressed: () {
                  query = tag['label'] as String;
                  showResults(context);
                },
              );
              }).toList(),
            ),
            const SizedBox(height: 24),

            // قسم "آخر ما بحثت عنه"
            if (_recentQueries.isNotEmpty) ...[
              Row(
                children: [
                  const Icon(Icons.history, color: Colors.grey, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    "آخر ما بحثت عنه",
                    style: GoogleFonts.almarai(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _recentQueries.map((q) {
                  return InputChip(
                  label: Text(
                    q,
                    style: GoogleFonts.almarai(fontSize: 13),
                  ),
                  backgroundColor: Colors.white,
                  onPressed: () {
                    query = q;
                    showResults(context);
                  },
                );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // 2. منطق البحث الحقيقي
  Widget _buildSearchResults(BuildContext context) {
    final cleanedQuery = query.trim();
    if (cleanedQuery.isEmpty) {
      return const Center(child: Text("أدخل كلمة للبحث"));
    }

    // حفظ آخر عمليات البحث (بدون تكرار) لعرضها كاقتراحات ذكية لاحقاً
    if (!_recentQueries.contains(cleanedQuery)) {
      _recentQueries.insert(0, cleanedQuery);
      if (_recentQueries.length > 8) {
        _recentQueries.removeLast();
      }
    }

    return Container(
      color: Colors.grey[50], // خلفية فاتحة
      child: FutureBuilder<List<Product>>(
        // ✅ البحث الذكي مع تصحيح الأخطاء والمرادفات
        future: SmartSearchService.instance.smartSearch(cleanedQuery),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _buildLoadingSkeleton();
          }

          if (snapshot.hasError) {
            // نطبع الخطأ في الكونسول للتحليل، لكن نبقي الرسالة للمستخدم بسيطة
            debugPrint('Product search error: ${snapshot.error}');
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.wifi_off, size: 60, color: Colors.redAccent),
                  const SizedBox(height: 10),
                  Text("تعذر تحميل نتائج البحث، تأكد من اتصالك بالإنترنت", style: GoogleFonts.almarai()),
                ],
              ),
            );
          }

          final results = snapshot.data ?? [];

          // ✨ لا نظهر "غير متوفر" - بدلاً من ذلك نقترح منتجات عشوائية
          if (results.isEmpty) {
            return _buildSuggestionsInsteadOfEmpty(cleanedQuery);
          }

          // عرض النتائج كشبكة
          return _buildResultsGrid(results);
        },
      ),
    );
  }

  /// عرض منتجات مقترحة بدلاً من "غير متوفر"
  Widget _buildSuggestionsInsteadOfEmpty(String cleanedQuery) {
    return FutureBuilder<List<Product>>(
      // نجلب منتجات عشوائية لعرضها
      future: _getRandomProducts(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingSkeleton();
        }
        
        final suggestions = snapshot.data ?? [];
        
        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // رسالة لطيفة
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.lightbulb_outline, color: Colors.blue.shade700, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'لم نجد نتائج مطابقة تماماً، لكن قد تعجبك هذه المنتجات:',
                        style: GoogleFonts.almarai(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.blue.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              
              // عرض المنتجات المقترحة
              if (suggestions.isNotEmpty)
                LayoutBuilder(
                  builder: (context, constraints) {
                    final crossAxisCount = ResponsiveLayout.gridCountForWidth(
                      constraints.maxWidth,
                      desiredItemWidth: 120,
                      minCount: 3,
                      maxCount: 5,
                    );
                    final isCompact = crossAxisCount >= 3;
                    const spacing = 12.0;
                    final mainAxisExtent = ResponsiveLayout.productCardMainAxisExtent(
                      constraints.maxWidth,
                      crossAxisCount: crossAxisCount,
                      crossAxisSpacing: spacing,
                      isCompact: isCompact,
                    );

                    return GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        mainAxisExtent: mainAxisExtent,
                        crossAxisSpacing: spacing,
                        mainAxisSpacing: spacing,
                      ),
                      itemCount: suggestions.length,
                      itemBuilder: (context, index) {
                        return ProductCard(
                          product: suggestions[index],
                          isCompact: isCompact,
                          heroTag: 'suggestion_${suggestions[index].id}',
                        );
                      },
                    );
                  },
                )
              else
                Center(
                  child: Text(
                    'تصفح الأقسام لاكتشاف منتجاتنا',
                    style: GoogleFonts.almarai(color: Colors.grey),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildResultsGrid(List<Product> results) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = ResponsiveLayout.gridCountForWidth(
          constraints.maxWidth,
          desiredItemWidth: 120,
          minCount: 3,
          maxCount: 5,
        );
        final isCompact = crossAxisCount >= 3;
        const spacing = 12.0;
        final mainAxisExtent = ResponsiveLayout.productCardMainAxisExtent(
          constraints.maxWidth,
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: spacing,
          isCompact: isCompact,
        );

        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisExtent: mainAxisExtent,
            crossAxisSpacing: spacing,
            mainAxisSpacing: spacing,
          ),
          itemCount: results.length,
          itemBuilder: (context, index) {
            return ProductCard(
              product: results[index],
              isCompact: isCompact,
              // ✅ إضافة Hero Tag فريد لمنع التعارض مع الصفحة الرئيسية
              heroTag: 'search_${results[index].id}',
            );
          },
        );
      },
    );
  }

  Widget _buildLoadingSkeleton() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = ResponsiveLayout.gridCountForWidth(
          constraints.maxWidth,
          desiredItemWidth: 120,
          minCount: 3,
          maxCount: 5,
        );
        final isCompact = crossAxisCount >= 3;
        const spacing = 12.0;
        final mainAxisExtent = ResponsiveLayout.productCardMainAxisExtent(
          constraints.maxWidth,
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: spacing,
          isCompact: isCompact,
        );

        return Padding(
          padding: const EdgeInsets.all(16),
          child: GridView.builder(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              mainAxisExtent: mainAxisExtent,
              crossAxisSpacing: spacing,
              mainAxisSpacing: spacing,
            ),
            itemCount: 6,
            itemBuilder: (_, __) => const ProductCardSkeleton(),
          ),
        );
      },
    );
  }

  /// جلب منتجات عشوائية للاقتراحات
  Future<List<Product>> _getRandomProducts() async {
    try {
      final supabase = Supabase.instance.client;
      
      // نجلب منتجات عشوائية (أول 12 منتج)
      final data = await supabase
          .from('products')
          .select()
          .eq('is_active', true)
          .limit(12);

      return data.map((e) => Product.fromJson(e)).toList();
    } catch (e) {
      debugPrint('Random products error: $e');
      return [];
    }
  }
}