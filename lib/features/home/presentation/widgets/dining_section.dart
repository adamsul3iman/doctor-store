import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:doctor_store/features/product/domain/models/product_model.dart';
import 'package:doctor_store/features/product/presentation/widgets/product_card.dart';

/// قسم طاولات السفرة في الصفحة الرئيسية.
/// يسمح للعميل بالاختيار بين طاولات خشب كلاسيكية وطاولات بورسلان عصرية.
class DiningSection extends StatefulWidget {
  final List<Product> products;

  const DiningSection({super.key, required this.products});

  @override
  State<DiningSection> createState() => _DiningSectionState();
}

class _DiningSectionState extends State<DiningSection> {
  // false = خشب كلاسيك (افتراضي)، true = بورسلان مودرن
  bool _isPorcelain = false;

  // نحفظ القوائم مصنّفة حتى لا نعيد حسابها في كل build
  final List<Product> _porcelainProducts = [];
  final List<Product> _woodProducts = [];

  @override
  void initState() {
    super.initState();
    _classifyProducts();
  }

  @override
  void didUpdateWidget(covariant DiningSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.products != widget.products) {
      _classifyProducts();
    }
  }

  void _classifyProducts() {
    _porcelainProducts.clear();
    _woodProducts.clear();

    for (final p in widget.products) {
      // نجمع أكبر قدر من المعلومات النصية لمساعدة الفلترة بالكلمات المفتاحية
      final fullText = (
        '${p.title} ${p.description} ${p.category} ${p.tags.join(' ')}'
      ).toLowerCase();

      // تحديد أن المنتج فعلاً "طاولة سفرة" حتى لا ندخل منتجات أخرى
      final isTable =
          p.category == 'dining_table' ||
          p.category == 'furniture' ||
          fullText.contains('طاولة سفرة') ||
          fullText.contains('طاولة سفره') ||
          fullText.contains('طاولة طعام') ||
          fullText.contains('طاولة اكل') ||
          fullText.contains('سفرة') ||
          fullText.contains('سفره') ||
          fullText.contains('dining table') ||
          fullText.contains('dining');
      if (!isTable) continue;

      // فلترة صارمة للبورسلان: يجب أن يحتوي على كلمة "بورسلان" بالعربية
      final isPorcelain = fullText.contains('بورسلان');

      // فلترة صارمة للخشب: يجب أن يحتوي على كلمة "خشب" بالعربية
      final isWood = fullText.contains('خشب');

      if (isPorcelain) {
        _porcelainProducts.add(p);
      } else if (isWood) {
        _woodProducts.add(p);
      }
      // إذا لم يحتوي على أي من الكلمتين، لا يتم عرضه في أي من الفئتين
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredProducts =
        _isPorcelain ? _porcelainProducts : _woodProducts;

    // نستخدم لون خلفية التطبيق حتى يندمج القسم مع باقي الصفحة
    final backgroundColor = Theme.of(context).scaffoldBackgroundColor;
    const chipBackgroundColor = Color(0xFF7A5C4A); // بني هادئ موحد

    const Color activeTextColor = Colors.white; // على الخلفية البنية
    const Color inactiveTextColor = Color(0xFF4B5563); // رمادي غامق

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 20),
      padding: const EdgeInsets.symmetric(vertical: 16),
      color: backgroundColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'اختر جو منزلك',
                      style: GoogleFonts.almarai(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.brown.shade900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'طاولات سفرة خشبية أو بورسلان لتناسب أسلوب بيتك.',
                      style: GoogleFonts.almarai(
                        fontSize: 12,
                        color: const Color(0xFF374151),
                      ),
                    ),
                  ],
                ),
                const Icon(
                  Icons.table_restaurant,
                  color: Colors.brown,
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // شريط الاختيار بين الخشب والبورسلان (زرين واضحين بالكامل)
          Center(
            child: Container(
              width: 320,
              height: 52,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        if (_isPorcelain) {
                          setState(() => _isPorcelain = false);
                        }
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: _isPorcelain
                              ? Colors.transparent
                              : chipBackgroundColor,
                          borderRadius: BorderRadius.circular(30),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'خشب كلاسيك (${_woodProducts.length})',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.almarai(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: _isPorcelain
                                ? inactiveTextColor
                                : activeTextColor,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        if (!_isPorcelain) {
                          setState(() => _isPorcelain = true);
                        }
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: _isPorcelain
                              ? chipBackgroundColor
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(30),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'بورسلان مودرن (${_porcelainProducts.length})',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.almarai(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: _isPorcelain
                                ? activeTextColor
                                : inactiveTextColor,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // وصف نصي بسيط بدون رموز خاصة
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 160),
              child: Text(
                _isPorcelain
                    ? 'اختر من طاولات السفرة البورسلان بتصاميم حديثة وجودة عالية.'
                    : 'اختر من طاولات السفرة الخشبية الكلاسيكية بأجواء دافئة.',
                key: ValueKey(_isPorcelain),
                style: GoogleFonts.almarai(
                  fontSize: 12,
                  color: const Color(0xFF374151),
                ),
              ),
            ),
          ),

          const SizedBox(height: 18),

          SizedBox(
            height: 260,
            child: filteredProducts.isEmpty
                ? Center(
                    child: Text(
                      'لا توجد طاولات متاحة في هذا التصنيف حالياً.',
                      style: GoogleFonts.almarai(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  )
                : ListView.builder(
                    key: ValueKey(_isPorcelain),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    scrollDirection: Axis.horizontal,
                    itemCount: filteredProducts.length,
                    itemBuilder: (context, index) {
                      final product = filteredProducts[index];
                      return Container(
                        width: 220,
                        margin: const EdgeInsets.only(left: 12),
                        child: ProductCard(product: product),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
