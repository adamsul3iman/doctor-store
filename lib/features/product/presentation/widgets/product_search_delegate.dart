import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import 'package:doctor_store/features/product/domain/models/product_model.dart';
import 'package:doctor_store/features/product/presentation/widgets/product_card.dart';
import 'package:doctor_store/features/product/presentation/widgets/product_card_skeleton.dart';

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
        // ✅ البحث الشامل (عنوان، وصف، قسم)
        future: _searchProducts(cleanedQuery),
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

          var results = snapshot.data ?? [];

          // إذا لم يتم إيجاد نتائج، نحاول البحث باستخدام أول كلمة فقط كتحسين بسيط للذكاء
          if (results.isEmpty && cleanedQuery.contains(' ')) {
            final firstWord = cleanedQuery.split(' ').first;
            return FutureBuilder<List<Product>>(
              future: _searchProducts(firstWord),
              builder: (context, secondSnapshot) {
                if (secondSnapshot.connectionState == ConnectionState.waiting) {
                  return _buildLoadingSkeleton();
                }

                results = secondSnapshot.data ?? [];

                if (results.isEmpty) {
                  return _buildEmptyState(cleanedQuery);
                }

                return _buildResultsGrid(results);
              },
            );
          }

          if (results.isEmpty) {
            return _buildEmptyState(cleanedQuery);
          }

          // عرض النتائج كشبكة
          return _buildResultsGrid(results);
        },
      ),
    );
  }

  Widget _buildEmptyState(String cleanedQuery) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off_rounded, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 20),
          Text(
            "لم نجد نتائج لـ \"$cleanedQuery\"",
            style: GoogleFonts.almarai(fontSize: 18, color: Colors.grey[600], fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Text(
            "حاول كتابة كلمة مختلفة أو تصفح الأقسام",
            style: GoogleFonts.almarai(fontSize: 14, color: Colors.grey[400]),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsGrid(List<Product> results) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 220,
        childAspectRatio: 0.62,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: results.length,
      itemBuilder: (context, index) {
        return ProductCard(
          product: results[index],
          // ✅ إضافة Hero Tag فريد لمنع التعارض مع الصفحة الرئيسية
          heroTag: 'search_${results[index].id}',
        );
      },
    );
  }

  Widget _buildLoadingSkeleton() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 220,
          childAspectRatio: 0.62,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        itemCount: 6,
        itemBuilder: (_, __) => const ProductCardSkeleton(),
      ),
    );
  }

  // خريطة ثابتة قديمة (للتوافق فقط) لتحويل بعض الأسماء العربية إلى IDs
  String? _mapArabicCategoryToIdLegacy(String term) {
    switch (term.trim()) {
      case 'أطفال':
        return 'baby_supplies';
      case 'مخدات':
        return 'pillows';
      case 'طاولات':
        return 'dining_table';
      case 'سجاد':
        return 'carpets';
      case 'مفارش':
        return 'bedding';
      case 'ديكور':
        return 'home_decor';
      default:
        return null;
    }
  }

  /// محاولة ذكية لربط كلمة البحث العربية بأحد الأقسام الديناميكية
  Future<String?> _mapArabicCategoryToIdDynamic(String term) async {
    final cleaned = term.trim();
    if (cleaned.isEmpty) return null;

    // أولاً نحاول مطابقة الاسم مع جدول الأقسام مباشرة في Supabase
    try {
      final supabase = Supabase.instance.client;
      final List<dynamic> data = await supabase
          .from('categories')
          .select('id,name')
          .ilike('name', '%$cleaned%')
          .limit(1);

      if (data.isNotEmpty) {
        final row = data.first as Map<String, dynamic>;
        final id = row['id'] as String?;
        if (id != null && id.isNotEmpty) {
          return id;
        }
      }
    } catch (_) {
      // في حال فشل الاتصال بجدول الأقسام نستمر بدون كسر البحث
    }

    // كـ fallback أخير نستخدم الخريطة الثابتة القديمة
    return _mapArabicCategoryToIdLegacy(term);
  }

  // دالة البحث الفعلية
  Future<List<Product>> _searchProducts(String queryTerm) async {
    final supabase = Supabase.instance.client;
    final trimmed = queryTerm.trim();

    // 1) في حال كان النص يطابق إحدى الفئات في جدول الأقسام أو الخريطة القديمة
    final categoryId = await _mapArabicCategoryToIdDynamic(trimmed);
    if (categoryId != null) {
      final data = await supabase
          .from('products')
          .select()
          .eq('is_active', true)
          .eq('category', categoryId)
          .limit(30);

      return data.map((e) => Product.fromJson(e)).toList();
    }
    
    // 2) بحث عام بالعنوان + الوصف لأي نص آخر
    final data = await supabase
        .from('products')
        .select()
        .eq('is_active', true)
        .or('title.ilike.%$trimmed%,description.ilike.%$trimmed%')
        .limit(30);

    return data.map((e) => Product.fromJson(e)).toList();
  }
}