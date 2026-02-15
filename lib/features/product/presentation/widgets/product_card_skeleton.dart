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
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final h = constraints.maxHeight;
                  final pad = h < 60 ? 6.0 : 12.0;
                  final contentH = (h - (pad * 2)).clamp(0.0, double.infinity);
                  final titleH = (contentH * 0.26).clamp(6.0, 14.0);
                  final categoryH = (contentH * 0.18).clamp(5.0, 10.0);
                  final gap = (contentH * 0.08).clamp(1.0, 6.0);
                  final iconSize = (contentH * 0.34).clamp(10.0, 20.0);

                  return Padding(
                    padding: EdgeInsets.all(pad),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          height: titleH,
                          width: double.infinity,
                          color: baseColor,
                        ),
                        SizedBox(height: gap),
                        Container(
                          height: categoryH,
                          width: 70,
                          color: baseColor,
                        ),
                        Expanded(
                          child: Align(
                            alignment: Alignment.bottomLeft,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Flexible(
                                  child: Container(
                                    height: (contentH * 0.30).clamp(8.0, 18.0),
                                    width: 45,
                                    color: baseColor,
                                  ),
                                ),
                                Container(
                                  height: iconSize,
                                  width: iconSize,
                                  decoration: const BoxDecoration(
                                    color: baseColor,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}