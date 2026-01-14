import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
// تم حذف مكتبة FontAwesome لأنها غير مستخدمة هنا
import 'package:supabase_flutter/supabase_flutter.dart';

// تأكد من أن مسارات الاستيراد هذه صحيحة في مشروعك
import 'package:doctor_store/features/product/domain/models/product_model.dart';
import 'package:doctor_store/features/product/presentation/widgets/product_card.dart';
import 'package:doctor_store/features/product/presentation/widgets/product_card_skeleton.dart';
import 'package:doctor_store/shared/utils/categories_provider.dart';
import 'package:doctor_store/shared/utils/analytics_service.dart';

/// دالة لفتح البحث (Bottom Sheet)
Future<void> showProductSearchBottomSheet(BuildContext context) async {
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent, 
    builder: (ctx) => const _ProductSearchBottomSheet(),
  );
}

class _ProductSearchBottomSheet extends ConsumerStatefulWidget {
  const _ProductSearchBottomSheet();

  @override
  ConsumerState<_ProductSearchBottomSheet> createState() =>
      _ProductSearchBottomSheetState();
}

class _ProductSearchBottomSheetState
    extends ConsumerState<_ProductSearchBottomSheet> {
  final TextEditingController _controller = TextEditingController();

  // ذاكرة مؤقتة لعمليات البحث
  static final List<String> _recentSearches = [];

  String _query = '';
  String _sortBy = 'relevant';
  String? _categoryId;
  bool _onlyFeatured = false;
  bool _onlyOnOffer = false;
  double? _minPrice;
  double? _maxPrice;

  Future<List<Product>>? _future;
  Timer? _debounce;

  @override
  void dispose() {
    _controller.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    _query = value;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), _triggerSearch);
    setState(() {});
  }

  void _triggerSearch() {
    final trimmed = _query.trim();
    if (trimmed.isEmpty) {
      setState(() {
        _future = null;
      });
      return;
    }

    // حفظ في سجل البحث
    if (!_recentSearches.contains(trimmed)) {
      _recentSearches.insert(0, trimmed);
      if (_recentSearches.length > 8) _recentSearches.removeLast();
    }

    // Analytics Event
    AnalyticsService.instance.trackEvent('search_performed', props: {
      'query': trimmed,
      'sort_by': _sortBy,
      'category': _categoryId,
    });

    setState(() {
      _future = _searchProducts(trimmed, _categoryId);
    });
  }

  @override
  Widget build(BuildContext context) {
    // ارتفاع الشاشة بنسبة 92%
    final height = MediaQuery.of(context).size.height * 0.92;
    final catsAsync = ref.watch(categoriesConfigProvider);

    return Container(
      height: height,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // 1. مؤشر السحب
          const SizedBox(height: 8),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),

          // 2. الهيدر: شريط البحث
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                Expanded(
                  child: Material(
                    elevation: 0,
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                    child: TextField(
                      controller: _controller,
                      autofocus: true,
                      textInputAction: TextInputAction.search,
                      onChanged: _onQueryChanged,
                      onSubmitted: (_) => _triggerSearch(),
                      style: GoogleFonts.almarai(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                      decoration: InputDecoration(
                        hintText: 'عن ماذا تبحث؟',
                        hintStyle: GoogleFonts.almarai(
                          color: Colors.grey.shade500,
                          fontSize: 13,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 14),
                        prefixIcon: Icon(Icons.search,
                            color: Colors.grey.shade600, size: 22),
                        // زر "بحث" داخل الحقل
                        suffixIcon: Padding(
                          padding: const EdgeInsets.all(5.0),
                          child: _query.isNotEmpty
                              ? GestureDetector(
                                  onTap: _triggerSearch,
                                  child: Container(
                                    width: 60,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF0A2647),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      'بحث',
                                      style: GoogleFonts.almarai(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                )
                              : null,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: () => Navigator.pop(context),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.close, color: Colors.black, size: 22),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // 3. شريط الأدوات الموحد (فلاتر + أقسام)
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _buildToolChip(
                  icon: Icons.tune_rounded,
                  label: 'فلترة',
                  isActive: _minPrice != null ||
                      _maxPrice != null ||
                      _onlyFeatured ||
                      _onlyOnOffer,
                  onTap: _openFilterSheet,
                ),
                const SizedBox(width: 8),
                _buildToolChip(
                  icon: Icons.sort_rounded,
                  label: _getSortLabel(),
                  isActive: _sortBy != 'relevant',
                  onTap: _openSortSheet,
                ),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  width: 1,
                  color: Colors.grey.shade300,
                ),
                _buildCategoryChip(
                  label: 'الكل',
                  isSelected: _categoryId == null,
                  onTap: () => setState(() {
                    _categoryId = null;
                    _triggerSearch();
                  }),
                ),
                const SizedBox(width: 8),
                ..._buildDynamicCategoryChips(catsAsync),
              ],
            ),
          ),

          const Divider(height: 24, thickness: 1, color: Color(0xFFF0F0F0)),

          // 4. النتائج أو الاقتراحات
          Expanded(
            child: _future == null
                ? _buildSuggestionsView()
                : FutureBuilder<List<Product>>(
                    future: _future,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return _buildLoadingSkeleton();
                      }
                      if (snapshot.hasError) {
                        return _buildErrorState();
                      }

                      var results = snapshot.data ?? [];
                      results = _sortResults(results, _sortBy);

                      if (results.isEmpty) {
                        return _buildEmptyState();
                      }

                      return GridView.builder(
                        padding: const EdgeInsets.all(16),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 0.65,
                          crossAxisSpacing: 14,
                          mainAxisSpacing: 14,
                        ),
                        itemCount: results.length,
                        itemBuilder: (context, index) {
                          return ProductCard(
                            product: results[index],
                            isCompact: true,
                            heroTag: 'search_${results[index].id}',
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // --- Widgets ---

  Widget _buildToolChip({
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF0A2647) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? const Color(0xFF0A2647) : Colors.grey.shade300,
          ),
        ),
        child: Row(
          children: [
            Icon(icon,
                size: 16, color: isActive ? Colors.white : Colors.grey.shade700),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.almarai(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isActive ? Colors.white : Colors.grey.shade800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    Color? color,
  }) {
    final activeColor = color ?? const Color(0xFF0A2647);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? activeColor : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: GoogleFonts.almarai(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.white : Colors.grey.shade700,
          ),
        ),
      ),
    );
  }

  Widget _buildSuggestionsView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_recentSearches.isNotEmpty) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('أحدث عمليات البحث',
                    style: GoogleFonts.almarai(
                        fontSize: 14, fontWeight: FontWeight.bold)),
                TextButton(
                  onPressed: () => setState(() => _recentSearches.clear()),
                  child: Text('مسح',
                      style: GoogleFonts.almarai(
                          fontSize: 12, color: Colors.redAccent)),
                ),
              ],
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _recentSearches.map((text) {
                return InkWell(
                  onTap: () {
                    _controller.text = text;
                    _onQueryChanged(text);
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.history, size: 14, color: Colors.grey),
                        const SizedBox(width: 6),
                        Text(text,
                            style: GoogleFonts.almarai(
                                fontSize: 12, color: Colors.black87)),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
          ],
          Text('رائج الآن 🔥',
              style: GoogleFonts.almarai(
                  fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: const [
              {'label': 'عروض اليوم', 'icon': Icons.local_offer_rounded},
              {'label': 'فرشات طبية', 'icon': Icons.bed},
              {'label': 'مخدات فندقية', 'icon': Icons.cloud},
              {'label': 'أطقم كنب', 'icon': Icons.chair},
            ].map((tag) {
              return ActionChip(
                elevation: 0,
                backgroundColor: Colors.white,
                side: BorderSide(color: Colors.grey.shade200),
                avatar: Icon(tag['icon'] as IconData,
                    size: 16, color: const Color(0xFF0A2647)),
                label: Text(
                  tag['label'] as String,
                  style: GoogleFonts.almarai(
                      fontSize: 12, fontWeight: FontWeight.w600),
                ),
                onPressed: () {
                  final txt = tag['label'] as String;
                  _controller.text = txt;
                  _onQueryChanged(txt);
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off_rounded, size: 60, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            'لا توجد نتائج لـ "$_query"',
            style: GoogleFonts.almarai(
                fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black54),
          ),
          Text(
            'حاول البحث بكلمة أخرى أو تصفح الأقسام',
            style: GoogleFonts.almarai(fontSize: 13, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingSkeleton() {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.65,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
      ),
      itemCount: 4,
      itemBuilder: (_, __) => const ProductCardSkeleton(),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.wifi_off_rounded, size: 50, color: Colors.redAccent),
          const SizedBox(height: 10),
          Text('خطأ في الاتصال', style: GoogleFonts.almarai()),
        ],
      ),
    );
  }

  // --- Logic Helpers ---

  List<Widget> _buildDynamicCategoryChips(
      AsyncValue<List<AppCategoryConfig>> catsAsync) {
    final data = catsAsync.asData?.value;
    if (data == null || data.isEmpty) return [];

    return data.where((c) => c.isActive).map((c) {
      return Padding(
        padding: const EdgeInsetsDirectional.only(end: 8.0),
        child: _buildCategoryChip(
          label: c.name,
          isSelected: _categoryId == c.id,
          color: c.color,
          onTap: () => setState(() {
            _categoryId = c.id;
            _triggerSearch();
          }),
        ),
      );
    }).toList();
  }

  String _getSortLabel() {
    switch (_sortBy) {
      case 'price_low':
        return 'الأقل سعراً';
      case 'price_high':
        return 'الأعلى سعراً';
      case 'newest':
        return 'الأحدث';
      default:
        return 'ترتيب';
    }
  }

  List<Product> _sortResults(List<Product> list, String sortBy) {
    final results = List<Product>.from(list);
    if (sortBy == 'price_low') {
      results.sort((a, b) => a.price.compareTo(b.price));
    } else if (sortBy == 'price_high') {
      results.sort((a, b) => b.price.compareTo(a.price));
    }
    return results;
  }

  // --- (المكتملة) Filter & Sort Sheets ---

  void _openSortSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('ترتيب النتائج حسب',
                  style: GoogleFonts.almarai(
                      fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              _buildSortOption('relevant', 'الأكثر صلة'),
              _buildSortOption('newest', 'الأحدث'),
              _buildSortOption('price_low', 'الأقل سعراً'),
              _buildSortOption('price_high', 'الأعلى سعراً'),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSortOption(String key, String label) {
    return ListTile(
      title: Text(label, style: GoogleFonts.almarai()),
      trailing:
          _sortBy == key ? const Icon(Icons.check, color: Color(0xFF0A2647)) : null,
      onTap: () {
        setState(() => _sortBy = key);
        Navigator.pop(context);
        if (_query.isNotEmpty) _triggerSearch();
      },
    );
  }

  // ✅ الدالة الكاملة للفلترة المتقدمة (تم إصلاح التحذير)
  void _openFilterSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        String tempMin = _minPrice?.toString() ?? '';
        String tempMax = _maxPrice?.toString() ?? '';
        bool tempFeatured = _onlyFeatured;
        bool tempOffers = _onlyOnOffer;

        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                  bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
                  top: 20,
                  left: 20,
                  right: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('تصفية النتائج',
                          style: GoogleFonts.almarai(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      )
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // فلاتر الخصائص
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('عروض وتخفيضات فقط', style: GoogleFonts.almarai()),
                    value: tempOffers,
                    activeTrackColor: const Color(0xFF0A2647),
                    onChanged: (v) => setModalState(() => tempOffers = v),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('منتجات مميزة', style: GoogleFonts.almarai()),
                    value: tempFeatured,
                    activeTrackColor: const Color(0xFF0A2647),
                    onChanged: (v) => setModalState(() => tempFeatured = v),
                  ),
                  
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 8),
                  
                  // فلاتر السعر
                  Text('نطاق السعر (د.أ)',
                      style: GoogleFonts.almarai(
                          fontSize: 14, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'من',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            isDense: true,
                          ),
                          controller: TextEditingController(text: tempMin),
                          onChanged: (v) => tempMin = v,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'إلى',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            isDense: true,
                          ),
                          controller: TextEditingController(text: tempMax),
                          onChanged: (v) => tempMax = v,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  
                  // أزرار التحكم
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            // إعادة تعيين
                            setModalState(() {
                              tempMin = '';
                              tempMax = '';
                              tempFeatured = false;
                              tempOffers = false;
                            });
                          },
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          child: Text('مسح الكل',
                              style: GoogleFonts.almarai(color: Colors.red)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _onlyOnOffer = tempOffers;
                              _onlyFeatured = tempFeatured;
                              _minPrice = double.tryParse(tempMin);
                              _maxPrice = double.tryParse(tempMax);
                            });
                            Navigator.pop(context);
                            _triggerSearch();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0A2647),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          child: Text('تطبيق',
                              style: GoogleFonts.almarai(
                                  color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // --- Supabase Logic ---
  Future<List<Product>> _searchProducts(String term, String? catId) async {
    final supabase = Supabase.instance.client;
    final Map<String, Object> filters = {'is_active': true};
    if (catId != null) filters['category'] = catId;

    var query = supabase
        .from('products')
        .select()
        .match(filters)
        .or('title.ilike.%$term%,description.ilike.%$term%')
        .limit(50);

    final data = await query;
    var list = data.map<Product>((e) => Product.fromJson(e)).toList();

    // Client-side filtering logic
    if (_onlyFeatured) list = list.where((p) => p.isFeatured).toList();
    if (_onlyOnOffer) {
      list = list.where((p) => p.hasOffers || p.isFlashDeal).toList();
    }
    if (_minPrice != null) list = list.where((p) => p.price >= _minPrice!).toList();
    if (_maxPrice != null) list = list.where((p) => p.price <= _maxPrice!).toList();

    return list;
  }
}