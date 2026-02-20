import 'package:flutter/material.dart';
// import 'package:google_fonts/google_fonts.dart'; // ⚠️ REMOVED for smaller bundle
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import 'package:doctor_store/core/theme/app_theme.dart';

class ProductBottomBar extends StatelessWidget {
  final double price;
  final int quantity;
  final String unitLabel;
  final VoidCallback onAddToCart;
  final VoidCallback onBuyNow;
  final VoidCallback onShare;

  const ProductBottomBar({
    super.key,
    required this.price,
    required this.quantity,
    required this.unitLabel,
    required this.onAddToCart,
    required this.onBuyNow,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    const primaryColor = AppTheme.primary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // ملخص صغير للطلب يعطي إحساس بالنظام والوضوح
            Flexible(
              flex: 3,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "ملخص طلبك",
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    // مثال: "1 حبة • 160.0 د.أ"
                    "$quantity $unitLabel • ${price.toStringAsFixed(1)} د.أ",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: primaryColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    "إتمام الطلب عبر واتساب والدفع عند الاستلام",
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // زر مشاركة أنيق وصغير لا يفسد شكل الأيقونات
            Container(
              height: 44,
              width: 44,
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: IconButton(
                onPressed: onShare,
                tooltip: 'مشاركة المنتج',
                icon: const Icon(
                  Icons.ios_share,
                  size: 20,
                  color: primaryColor,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 4,
              child: Row(
                children: [
                  // زر الإضافة للسلة
                  Expanded(
                    child: ElevatedButton(
                      onPressed: onAddToCart,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: primaryColor,
                        side: const BorderSide(color: primaryColor),
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Icon(Icons.add_shopping_cart),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // زر الطلب السريع (شراء الآن عبر واتساب) بمظهر احترافي أوضح
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: onBuyNow,
                      style: ElevatedButton.styleFrom(
                        // نستخدم لون الواتساب الرسمي مع حواف دائرية ليبدو مثل CTA واضح
                        backgroundColor: const Color(0xFF25D366),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                        elevation: 3,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: const FaIcon(
                                FontAwesomeIcons.whatsapp,
                                size: 16,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              "اطلب عبر واتساب",
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
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
}
