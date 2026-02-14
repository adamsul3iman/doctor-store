import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:doctor_store/features/product/domain/models/product_model.dart';
import 'package:doctor_store/features/home/presentation/widgets/dining_section.dart';

/// قسم مخصص لطاولات السفرة مع إبراز حس الفخامة وشعار "توصيل مجاني".
///
/// يعيد استخدام منطق الفلترة والعرض في [DiningSection] حتى لا نكرر
/// منطق اختيار المنتجات أو نغيّر سلوك الجلب الحالي.
class DiningTableSection extends StatelessWidget {
  final List<Product> products;
  final String title;
  final String subtitle;

  const DiningTableSection({
    super.key,
    required this.products,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      padding: const EdgeInsets.symmetric(vertical: 24),
      // تمت إزالة الخلفية البج ليظهر القسم فوق خلفية الصفحة البيضاء فقط
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.brown.withValues(alpha: 0.15),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.table_restaurant_rounded,
                    color: Color(0xFF6D4C41),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.almarai(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF5D4037),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: GoogleFonts.almarai(
                          fontSize: 12,
                          color: Colors.brown.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // إعادة استخدام الودجت الأصلية حتى نحافظ على سلوك الفلترة والعرض
          DiningSection(products: products),
        ],
      ),
    );
  }
}
