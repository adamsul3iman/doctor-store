import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:doctor_store/shared/utils/categories_provider.dart';
import 'package:doctor_store/shared/utils/link_share_helper.dart';
import 'package:doctor_store/shared/utils/home_sections_provider.dart';

class ModernCategorySection extends ConsumerWidget {
  const ModernCategorySection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // قائمة الأقسام الافتراضية (تُستخدم في حال عدم توفر بيانات من Supabase)
    final defaultCategories = [
      {'id': 'bedding', 'name': 'بياضات ومفارش', 'subtitle': 'راحة وفخامة', 'icon': FontAwesomeIcons.bed, 'color': const Color(0xFF5C6BC0)},
      {'id': 'dining_table', 'name': 'طاولات سفرة', 'subtitle': 'تجمعات العائلة', 'icon': Icons.table_restaurant_rounded, 'color': const Color(0xFF8D6E63)},
      {'id': 'baby_supplies', 'name': 'عالم الأطفال', 'subtitle': 'أمان وراحة', 'icon': FontAwesomeIcons.baby, 'color': const Color(0xFFEC407A)},
      {'id': 'carpets', 'name': 'سجاد فاخر', 'subtitle': 'لمسة دافئة', 'icon': FontAwesomeIcons.rug, 'color': const Color(0xFF26A69A)},
      {'id': 'pillows', 'name': 'وسائد طبية', 'subtitle': 'نوم صحي', 'icon': FontAwesomeIcons.cloud, 'color': const Color(0xFF78909C)},
      {'id': 'furniture', 'name': 'أثاث منزلي', 'subtitle': 'تجديد شامل', 'icon': FontAwesomeIcons.couch, 'color': const Color(0xFFFFA726)},
      {'id': 'home_decor', 'name': 'ديكورات', 'subtitle': 'لمسات فنية', 'icon': FontAwesomeIcons.leaf, 'color': const Color(0xFF66BB6A)},
    ];

    final categoriesAsync = ref.watch(categoriesConfigProvider);
    final sectionsAsync = ref.watch(homeSectionsProvider);
    final sectionsConfig = sectionsAsync.asData?.value;

    String headerTitle = "تصفح الأقسام";
    String? headerSubtitle;
    if (sectionsConfig != null) {
      final cfg = sectionsConfig[HomeSectionKeys.categories];
      final t = cfg?.title;
      final s = cfg?.subtitle;
      if (t != null && t.trim().isNotEmpty) {
        headerTitle = t.trim();
      }
      if (s != null && s.trim().isNotEmpty) {
        headerSubtitle = s.trim();
      }
    }

    return Column(
      children: [
        // 1. العنوان مع زر "عرض الكل" النصي
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 4,
                    height: 20,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0A2647),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 240),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AutoSizeText(
                          headerTitle,
                          maxLines: 1,
                          minFontSize: 14,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.almarai(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF0A2647),
                          ),
                        ),
                        if (headerSubtitle != null) ...[
                          const SizedBox(height: 2),
                          AutoSizeText(
                            headerSubtitle,
                            maxLines: 1,
                            minFontSize: 9,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.almarai(
                              fontSize: 11,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              
              // زر نصي أنيق وصغير
              InkWell(
                onTap: () => context.push('/all_products'),
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(
                    children: [
                      Text("الكل", style: GoogleFonts.almarai(fontSize: 14, color: Colors.grey[600], fontWeight: FontWeight.bold)),
                      const Icon(Icons.arrow_forward_ios, size: 12, color: Colors.grey),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        
        // 2. القائمة الأفقية
        SizedBox(
          height: 150,
          child: categoriesAsync.when(
            data: (data) {
              // إذا لم يكن هناك أقسام فعّالة في الداتابيز، نستخدم الافتراضية
              if (data.isEmpty) {
                return _buildDefaultCategoriesList(context, defaultCategories);
              }

              final mapped = data.map((c) {
                return {
                  'id': c.id,
                  'name': c.name,
                  'subtitle': c.subtitle,
                  'icon': _iconForCategory(c.id),
                  'color': c.color,
                };
              }).toList();

              return _buildCategoriesList(context, mapped);
            },
            loading: () => _buildDefaultCategoriesList(context, defaultCategories),
            error: (_, __) => _buildDefaultCategoriesList(context, defaultCategories),
          ),
        ),
      ],
    );
  }

  // قائمة افتراضية مبنية على الهاردكود
  Widget _buildDefaultCategoriesList(
      BuildContext context, List<Map<String, dynamic>> categories) {
    return _buildCategoriesList(context, categories);
  }

  // قائمة عامة تُستخدم لكل من البيانات القادمة من Supabase أو الافتراضية
  Widget _buildCategoriesList(
      BuildContext context, List<Map<String, dynamic>> categories) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      scrollDirection: Axis.horizontal,
      cacheExtent: 800.0,
      itemCount: categories.length + 1,
      itemBuilder: (context, index) {
        // نجعل بطاقة "عرض الكل" هي الأولى دائماً، ثم تليها الأقسام
        if (index == 0) {
          return _buildSeeAllCard(context);
        }
        final cat = categories[index - 1];
        return _buildCategoryCard(context, cat);
      },
    );
  }

  IconData _iconForCategory(String id) {
    switch (id) {
      case 'bedding':
        return FontAwesomeIcons.bed;
      case 'dining_table':
        return Icons.table_restaurant_rounded;
      case 'baby_supplies':
        return FontAwesomeIcons.baby;
      case 'carpets':
        return FontAwesomeIcons.rug;
      case 'pillows':
        return FontAwesomeIcons.cloud;
      case 'furniture':
        return FontAwesomeIcons.couch;
      case 'home_decor':
        return FontAwesomeIcons.leaf;
      default:
        return Icons.category_outlined;
    }
  }

  // بطاقة القسم العادية
  Widget _buildCategoryCard(BuildContext context, Map<String, dynamic> cat) {
    return GestureDetector(
      onTap: () {
        context.push('/category/${cat['id']}', extra: {'name': cat['name'], 'color': cat['color']});
      },
      child: Container(
        width: 120,
        margin: const EdgeInsets.only(right: 12, bottom: 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [(cat['color'] as Color).withValues(alpha: 0.8), (cat['color'] as Color)],
            begin: Alignment.topLeft, end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: (cat['color'] as Color).withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 4))],
        ),
        child: Stack(
          children: [
            Positioned(
              right: -15, bottom: -15,
              child: Transform.rotate(
                angle: -0.2,
                child: Icon(cat['icon'] as IconData, size: 80, color: Colors.white.withValues(alpha: 0.15)),
              ),
            ),
            Positioned(
              top: 8,
              left: 8,
              child: InkWell(
                onTap: () {
                  shareAppPage(
                    path: '/category/${cat['id']}',
                    title: 'تصفح قسم ${cat['name']} في متجر الدكتور',
                  );
                },
                borderRadius: BorderRadius.circular(999),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.ios_share,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), shape: BoxShape.circle),
                    child: Icon(cat['icon'] as IconData, color: Colors.white, size: 16),
                  ),
                  const Spacer(),
                  AutoSizeText(
                    cat['name'] as String,
                    maxLines: 2,
                    minFontSize: 10,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.almarai(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  AutoSizeText(
                    cat['subtitle'] as String,
                    maxLines: 1,
                    minFontSize: 8,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.almarai(
                      color: Colors.white70,
                      fontSize: 9,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ✅ البطاقة المميزة "عرض كل المنتجات" في نهاية القائمة
  Widget _buildSeeAllCard(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/all_products'),
      child: Container(
        width: 120,
        margin: const EdgeInsets.only(right: 12, bottom: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF0A2647).withValues(alpha: 0.1), width: 1),
          boxShadow: [BoxShadow(color: Colors.grey.withValues(alpha: 0.05), blurRadius: 5)],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF0A2647).withValues(alpha: 0.05),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.grid_view_rounded, color: Color(0xFF0A2647)),
            ),
            const SizedBox(height: 12),
            Text("عرض الكل", style: GoogleFonts.almarai(color: const Color(0xFF0A2647), fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 4),
            Text("تصفح الجميع", style: GoogleFonts.almarai(color: Colors.grey, fontSize: 10)),
          ],
        ),
      ),
    );
  }
}