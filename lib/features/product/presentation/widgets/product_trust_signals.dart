import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:doctor_store/features/product/domain/models/product_model.dart';

class ProductTrustSignals extends StatelessWidget {
  final Color primaryDark;
  final Product product;

  const ProductTrustSignals({
    super.key,
    required this.primaryDark,
    required this.product,
  });

  @override
  Widget build(BuildContext context) {
    // حساب عدد المبيعات الوهمي بناءً على التقييمات
    final estimatedSales = product.ratingCount > 0
        ? (product.ratingCount * 2.5).round()
        : 50;

    return Column(
      children: [
        // شارات الثقة الكبيرة
        Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                primaryDark.withValues(alpha: 0.05),
                primaryDark.withValues(alpha: 0.02),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: primaryDark.withValues(alpha: 0.1),
              width: 2,
            ),
          ),
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.center,
            children: [
              _buildTrustBadge(
                icon: Icons.verified,
                label: 'تم بيع +$estimatedSales',
                color: const Color(0xFF4CAF50),
              ),
              if (product.ratingAverage > 0)
                _buildTrustBadge(
                  icon: Icons.star,
                  label: 'تقييم ${product.ratingAverage.toStringAsFixed(1)} ⭐',
                  color: const Color(0xFFFFA726),
                ),
              _buildTrustBadge(
                icon: Icons.refresh,
                label: 'إرجاع 30 يوم',
                color: const Color(0xFF5C6BC0),
              ),
              _buildTrustBadge(
                icon: Icons.security,
                label: 'ضمان سنة',
                color: const Color(0xFFFF6F00),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // القسم التقليدي
        _buildTraditionalSection(),
      ],
    );
  }

  Widget _buildTrustBadge({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: color,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.almarai(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: primaryDark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTraditionalSection() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 340;

        final items = [
          _TrustItem(
            icon: FontAwesomeIcons.shieldHalved,
            title: 'ضمان الجودة',
            subtitle: 'منتجات أصلية 100%'.trim(),
            primaryDark: primaryDark,
          ),
          _TrustItem(
            icon: FontAwesomeIcons.truckFast,
            title: 'شحن سريع',
            subtitle: 'توصيل آمن لباب بيتك',
            primaryDark: primaryDark,
          ),
          _TrustItem(
            icon: FontAwesomeIcons.headset,
            title: 'دعم متواصل',
            subtitle: 'خدمة عملاء على مدار الساعة',
            primaryDark: primaryDark,
          ),
        ];

        return Container(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 15),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'لماذا تختار متجر الدكتور؟',
                style: GoogleFonts.almarai(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  color: primaryDark,
                ),
              ),
              const SizedBox(height: 10),
              if (isNarrow)
                Wrap(
                  spacing: 16,
                  runSpacing: 12,
                  alignment: WrapAlignment.spaceAround,
                  children: items,
                )
              else
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: items,
                ),
            ],
          ),
        );
      },
    );
  }
}

class _TrustItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color primaryDark;

  const _TrustItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.primaryDark,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: primaryDark.withValues(alpha: 0.8), size: 24),
        const SizedBox(height: 8),
        Text(
          title,
          style: GoogleFonts.almarai(
            fontWeight: FontWeight.w800,
            fontSize: 12,
            color: primaryDark,
          ),
        ),
        const SizedBox(height: 4),
        SizedBox(
          width: 90,
          child: Text(
            subtitle,
            style: GoogleFonts.almarai(
              fontSize: 10,
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}
