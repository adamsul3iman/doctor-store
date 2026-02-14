import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

// تأكد من أن مسارات الاستيراد هذه صحيحة في مشروعك
import 'package:doctor_store/features/product/domain/models/product_model.dart';
import 'package:doctor_store/features/product/presentation/widgets/product_card.dart';
import 'package:doctor_store/features/product/presentation/widgets/product_card_skeleton.dart';
import 'package:doctor_store/shared/utils/categories_provider.dart';
import 'package:doctor_store/shared/services/smart_search_service.dart';
import 'package:doctor_store/shared/services/analytics_service.dart';
import 'package:doctor_store/shared/utils/responsive_layout.dart';

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
                                heroTag: 'search_${results[index].id}',
                              );
                            },
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
          itemCount: 6,
          itemBuilder: (_, __) => const ProductCardSkeleton(),
        );
      },
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

  // ✅ دالة الفلترة المتقدمة بتصميم احترافي محسّن
  void _openFilterSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        String tempMin = _minPrice?.toString() ?? '';
        String tempMax = _maxPrice?.toString() ?? '';
        bool tempFeatured = _onlyFeatured;
        bool tempOffers = _onlyOnOffer;

        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
                  top: 24,
                  left: 24,
                  right: 24,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header with drag handle
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 20),
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'تصفية النتائج',
                              style: GoogleFonts.almarai(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF0A2647),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'حدد المعايير المناسبة للبحث',
                              style: GoogleFonts.almarai(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.grey),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    
                    // Quick Filters Section
                    Text(
                      'خيارات سريعة',
                      style: GoogleFonts.almarai(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[800],
                      ),
                    ),
                    const SizedBox(height: 12),
                    
                    // Filter Chips
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _buildFilterChip(
                          icon: Icons.local_offer_rounded,
                          label: 'عروض وتخفيضات',
                          isSelected: tempOffers,
                          onTap: () => setModalState(() => tempOffers = !tempOffers),
                          color: Colors.orange,
                        ),
                        _buildFilterChip(
                          icon: Icons.star_rounded,
                          label: 'منتجات مميزة',
                          isSelected: tempFeatured,
                          onTap: () => setModalState(() => tempFeatured = !tempFeatured),
                          color: const Color(0xFF0A2647),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 24),
                    const Divider(height: 1),
                    const SizedBox(height: 24),
                    
                    // Price Range Section
                    Row(
                      children: [
                        Icon(Icons.payments_outlined, size: 18, color: Colors.grey[600]),
                        const SizedBox(width: 8),
                        Text(
                          'نطاق السعر',
                          style: GoogleFonts.almarai(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[800],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    Row(
                      children: [
                        Expanded(
                          child: _buildPriceField(
                            label: 'الحد الأدنى',
                            hint: '0',
                            value: tempMin,
                            onChanged: (v) => tempMin = v,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'د.أ',
                            style: GoogleFonts.almarai(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[700],
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildPriceField(
                            label: 'الحد الأقصى',
                            hint: '∞',
                            value: tempMax,
                            onChanged: (v) => tempMax = v,
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 32),
                    
                    // Quick Price Presets
                    Text(
                      'نطاقات سريعة',
                      style: GoogleFonts.almarai(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildPricePreset('أقل من 50', '0', '50', tempMin, tempMax, setModalState),
                        _buildPricePreset('50 - 100', '50', '100', tempMin, tempMax, setModalState),
                        _buildPricePreset('100 - 200', '100', '200', tempMin, tempMax, setModalState),
                        _buildPricePreset('200+', '200', '', tempMin, tempMax, setModalState),
                      ],
                    ),
                    
                    const SizedBox(height: 32),
                    
                    // Action Buttons
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: ElevatedButton.icon(
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
                            icon: const Icon(Icons.check, size: 20),
                            label: Text(
                              'تطبيق التصفية',
                              style: GoogleFonts.almarai(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0A2647),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              setModalState(() {
                                tempMin = '';
                                tempMax = '';
                                tempFeatured = false;
                                tempOffers = false;
                              });
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red[400],
                              side: BorderSide(color: Colors.red[200]!),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              'مسح',
                              style: GoogleFonts.almarai(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFilterChip({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required Color color,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.1) : Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? color : Colors.grey[600],
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.almarai(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? color : Colors.grey[700],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPriceField({
    required String label,
    required String hint,
    required String value,
    required Function(String) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.almarai(
            fontSize: 11,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          keyboardType: TextInputType.number,
          controller: TextEditingController(text: value),
          onChanged: onChanged,
          style: GoogleFonts.almarai(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF0A2647),
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.almarai(
              color: Colors.grey[400],
              fontSize: 14,
            ),
            filled: true,
            fillColor: Colors.grey[50],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[200]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF0A2647), width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ],
    );
  }

  Widget _buildPricePreset(
    String label,
    String min,
    String max,
    String currentMin,
    String currentMax,
    Function(void Function()) setModalState,
  ) {
    final isSelected = currentMin == min && (max.isEmpty ? currentMax.isEmpty : currentMax == max);
    
    return GestureDetector(
      onTap: () {
        setModalState(() {
          // Update temp values through parent callback
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0A2647) : Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: GoogleFonts.almarai(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: isSelected ? Colors.white : Colors.grey[700],
          ),
        ),
      ),
    );
  }

  // --- Supabase Logic with Smart Search ---
  Future<List<Product>> _searchProducts(String term, String? catId) async {
    // استخدام SmartSearchService للبحث الذكي مع المرادفات
    final smartSearch = SmartSearchService.instance;
    
    // الحصول على نتائج البحث الذكي
    var results = await smartSearch.smartSearch(term);
    
    // تطبيق الفلاتر الإضافية
    if (catId != null) {
      results = results.where((p) => p.category == catId).toList();
    }
    if (_onlyFeatured) {
      results = results.where((p) => p.isFeatured).toList();
    }
    if (_onlyOnOffer) {
      results = results.where((p) => p.hasOffers || p.isFlashDeal).toList();
    }
    if (_minPrice != null) {
      results = results.where((p) => p.price >= _minPrice!).toList();
    }
    if (_maxPrice != null) {
      results = results.where((p) => p.price <= _maxPrice!).toList();
    }

    return results;
  }
}