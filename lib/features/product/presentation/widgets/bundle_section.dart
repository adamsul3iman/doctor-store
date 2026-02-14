import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:doctor_store/features/product/domain/models/product_model.dart';
import 'package:doctor_store/shared/utils/product_nav_helper.dart';
import 'package:doctor_store/shared/utils/image_url_helper.dart';
import 'package:doctor_store/shared/widgets/app_network_image.dart';
import 'package:doctor_store/shared/widgets/image_shimmer_placeholder.dart';
import 'package:go_router/go_router.dart';

/// قسم "منتجات مقترحة" - يعرض منتجات قد تعجب العميل
class BundleSection extends ConsumerStatefulWidget {
  final Product mainProduct;
  final List<Product> suggestedProducts;

  const BundleSection({
    super.key,
    required this.mainProduct,
    required this.suggestedProducts,
  });

  @override
  ConsumerState<BundleSection> createState() => _BundleSectionState();
}

class _BundleSectionState extends ConsumerState<BundleSection> {
  final Set<String> _selectedProducts = {};
  bool _isAdding = false;

  double get _totalOriginalPrice {
    double total = widget.mainProduct.price;
    for (final product in widget.suggestedProducts) {
      if (_selectedProducts.contains(product.id)) {
        total += product.price;
      }
    }
    return total;
  }

  double get _bundlePrice {
    // خصم 10% عند شراء المجموعة
    return _totalOriginalPrice * 0.9;
  }

  double get _savings {
    return _totalOriginalPrice - _bundlePrice;
  }

  Future<void> _viewBundleProducts() async {
    if (_selectedProducts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'اختر منتجاً واحداً على الأقل',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Almarai',
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          backgroundColor: const Color(0xFFFF6F00),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    setState(() => _isAdding = true);

    // عرض رسالة توضيحية
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          '🛍️ سيتم فتح المنتجات',
          textAlign: TextAlign.right,
          style: TextStyle(
            fontFamily: 'Almarai',
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'سيتم فتح ${_selectedProducts.length} منتج لتختار المقاس واللون إن وجد، ثم أضفها للسلة.\n\nلا تنسى خصم 10% عند شراء المجموعة!',
          textAlign: TextAlign.right,
          style: const TextStyle(
            fontFamily: 'Almarai',
            fontSize: 14,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'إلغاء',
              style: TextStyle(fontFamily: 'Almarai'),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _navigateToProducts();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0A2647),
            ),
            child: const Text(
              'متابعة',
              style: TextStyle(
                fontFamily: 'Almarai',
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );

    if (!mounted) return;
    setState(() => _isAdding = false);
  }

  void _navigateToProducts() {
    // الانتقال لصفحة كل منتج لاختيار المقاس/اللون
    for (final product in widget.suggestedProducts) {
      if (_selectedProducts.contains(product.id)) {
        context.push(
          buildProductDetailsPath(product),
          extra: product,
        );
        break; // فتح أول منتج فقط
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.suggestedProducts.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [
            const Color(0xFFFF6F00).withValues(alpha: 0.05),
            const Color(0xFF0A2647).withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFFF6F00).withValues(alpha: 0.2),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // العنوان والتوفير
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
                colors: [
                  Color(0xFF0A2647),
                  Color(0xFF144272),
                ],
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(14),
                topRight: Radius.circular(14),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text(
                        'قد يعجبك أيضاً',
                        style: TextStyle(
                          fontFamily: 'Almarai',
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'منتجات مختارة لك',
                        style: TextStyle(
                          fontFamily: 'Almarai',
                          fontSize: 13,
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF6F00),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.local_offer_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
              ],
            ),
          ),

          // المنتج الأساسي (دائماً محدد)
          Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFF0A2647).withValues(alpha: 0.2),
                width: 2,
              ),
            ),
            child: Row(
              children: [
                // صورة المنتج
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    width: 60,
                    height: 60,
                    child: AppNetworkImage(
                      url: widget.mainProduct.imageUrl,
                      variant: ImageVariant.thumbnail,
                      fit: BoxFit.cover,
                      placeholder: const ShimmerImagePlaceholder(),
                      errorWidget: Container(
                        color: Colors.grey[300],
                        child:
                            const Icon(Icons.image_not_supported, size: 30),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // معلومات المنتج
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        widget.mainProduct.title,
                        style: const TextStyle(
                          fontFamily: 'Almarai',
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0A2647),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${widget.mainProduct.price.toStringAsFixed(2)} د.أ',
                        style: const TextStyle(
                          fontFamily: 'Almarai',
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0A2647),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // أيقونة الاختيار
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0A2647),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.check,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),

          // أيقونة الجمع
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFFF6F00).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                '+',
                style: TextStyle(
                  fontFamily: 'Almarai',
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFFF6F00),
                ),
              ),
            ),
          ),

          // المنتجات المقترحة
          ...widget.suggestedProducts.map((product) {
            final isSelected = _selectedProducts.contains(product.id);
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    setState(() {
                      if (isSelected) {
                        _selectedProducts.remove(product.id);
                      } else {
                        _selectedProducts.add(product.id);
                      }
                    });
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFFFF6F00)
                            : Colors.grey.withValues(alpha: 0.3),
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        // صورة المنتج
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: SizedBox(
                            width: 60,
                            height: 60,
                            child: AppNetworkImage(
                              url: product.imageUrl,
                              variant: ImageVariant.thumbnail,
                              fit: BoxFit.cover,
                              placeholder: const ShimmerImagePlaceholder(),
                              errorWidget: Container(
                                color: Colors.grey[300],
                                child: const Icon(Icons.image_not_supported,
                                    size: 30),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // معلومات المنتج
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                product.title,
                                style: const TextStyle(
                                  fontFamily: 'Almarai',
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF0A2647),
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${product.price.toStringAsFixed(2)} د.أ',
                                style: const TextStyle(
                                  fontFamily: 'Almarai',
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFFF6F00),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Checkbox
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFFFF6F00)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: isSelected
                                  ? const Color(0xFFFF6F00)
                                  : Colors.grey.withValues(alpha: 0.4),
                              width: 2,
                            ),
                          ),
                          child: isSelected
                              ? const Icon(
                                  Icons.check,
                                  color: Colors.white,
                                  size: 18,
                                )
                              : null,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),

          // ملخص السعر والزر
          if (_selectedProducts.isNotEmpty)
            Container(
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                  colors: [
                    const Color(0xFFFF6F00).withValues(alpha: 0.1),
                    const Color(0xFFFF6F00).withValues(alpha: 0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  // السعر الأصلي
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${_totalOriginalPrice.toStringAsFixed(2)} د.أ',
                        style: TextStyle(
                          fontFamily: 'Almarai',
                          fontSize: 16,
                          decoration: TextDecoration.lineThrough,
                          color: Colors.grey.withValues(alpha: 0.6),
                        ),
                      ),
                      const Text(
                        'السعر الأصلي:',
                        style: TextStyle(
                          fontFamily: 'Almarai',
                          fontSize: 14,
                          color: Color(0xFF0A2647),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // سعر المجموعة
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${_bundlePrice.toStringAsFixed(2)} د.أ',
                        style: const TextStyle(
                          fontFamily: 'Almarai',
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0A2647),
                        ),
                      ),
                      const Text(
                        'سعر المجموعة:',
                        style: TextStyle(
                          fontFamily: 'Almarai',
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0A2647),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // التوفير
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4CAF50),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'توفر ${_savings.toStringAsFixed(2)} د.أ',
                      style: const TextStyle(
                        fontFamily: 'Almarai',
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // زر الشراء
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                              onPressed: _isAdding ? null : _viewBundleProducts,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF6F00),
                        foregroundColor: Colors.white,
                        elevation: 3,
                        shadowColor: const Color(0xFFFF6F00).withValues(alpha: 0.4),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                                child: _isAdding
                                    ? const SizedBox(
                                        height: 24,
                                        width: 24,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2.5,
                                        ),
                                      )
                                    : Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            'عرض المنتجات (${_selectedProducts.length})',
                                            style: const TextStyle(
                                              fontFamily: 'Almarai',
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          const Icon(Icons.arrow_back, size: 20),
                                        ],
                                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
