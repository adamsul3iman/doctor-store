import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class FreeShippingProgressBar extends StatelessWidget {
  final double currentTotal;
  final double freeShippingThreshold;

  const FreeShippingProgressBar({
    super.key,
    required this.currentTotal,
    this.freeShippingThreshold = 100.0, // 100 دينار افتراضياً
  });

  @override
  Widget build(BuildContext context) {
    final remaining = freeShippingThreshold - currentTotal;
    final progress = (currentTotal / freeShippingThreshold).clamp(0.0, 1.0);
    final hasAchieved = remaining <= 0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: hasAchieved
              ? [
                  const Color(0xFF4CAF50),
                  const Color(0xFF66BB6A),
                ]
              : [
                  const Color(0xFF0A2647).withValues(alpha: 0.05),
                  const Color(0xFF144272).withValues(alpha: 0.05),
                ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasAchieved
              ? const Color(0xFF4CAF50)
              : const Color(0xFF0A2647).withValues(alpha: 0.1),
          width: 2,
        ),
      ),
      child: Column(
        children: [
          // النص العلوي
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                hasAchieved ? Icons.check_circle : Icons.local_shipping,
                color: hasAchieved
                    ? Colors.white
                    : const Color(0xFF0A2647),
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  hasAchieved
                      ? 'مبروك! حصلت على شحن مجاني'
                      : 'باقي ${remaining.toStringAsFixed(0)} دينار للحصول على شحن مجاني',
                  style: GoogleFonts.almarai(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: hasAchieved
                        ? Colors.white
                        : const Color(0xFF0A2647),
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // شريط التقدم
          Stack(
            children: [
              // الخلفية
              Container(
                height: 12,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              // التقدم
              AnimatedContainer(
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeInOut,
                height: 12,
                width: MediaQuery.of(context).size.width * progress * 0.85,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: hasAchieved
                        ? [
                            const Color(0xFF4CAF50),
                            const Color(0xFF66BB6A),
                          ]
                        : [
                            const Color(0xFFFF6F00),
                            const Color(0xFFFFA726),
                          ],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: [
                    BoxShadow(
                      color: (hasAchieved
                              ? const Color(0xFF4CAF50)
                              : const Color(0xFFFF6F00))
                          .withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
              // النسبة المئوية
              if (progress > 0.15)
                Positioned.fill(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: EdgeInsets.only(
                          left: MediaQuery.of(context).size.width *
                              progress *
                              0.85 -
                              30),
                      child: Text(
                        '${(progress * 100).toInt()}%',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          if (!hasAchieved) ...[
            const SizedBox(height: 8),
            Text(
              'أضف منتجات بقيمة ${remaining.toStringAsFixed(0)} دينار لتوفير تكلفة الشحن',
              style: GoogleFonts.almarai(
                fontSize: 11,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}
