import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class ProductCardSkeleton extends StatelessWidget {
  const ProductCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    // الألوان المستخدمة في تأثير الوميض (رمادي فاتح جداً)
    const baseColor = Color(0xFFE0E0E0);
    const highlightColor = Color(0xFFF5F5F5);

    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white, // لون الخلفية الأساسي للشكل
          borderRadius: BorderRadius.circular(15),
          // لا نضع إطاراً (border) في السكيلتون ليكون الشكل أنظف
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. مربع مكان الصورة
            Expanded(
              flex: 3,
              child: Container(
                decoration: const BoxDecoration(
                  color: baseColor, // يملأ باللون الرمادي
                  borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
                ),
              ),
            ),
            
            // 2. مربعات مكان النصوص
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // سطر طويل مكان العنوان
                    Container(
                      height: 14,
                      width: double.infinity,
                      color: baseColor,
                    ),
                    const SizedBox(height: 6),
                    // سطر قصير مكان الفئة
                    Container(
                      height: 10,
                      width: 70,
                      color: baseColor,
                    ),
                    // سطر مكان السعر ودائرة مكان زر السلة
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(height: 18, width: 56, color: baseColor),
                        Container(
                          height: 26,
                          width: 26,
                          decoration: const BoxDecoration(
                            color: baseColor,
                            shape: BoxShape.circle,
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
}