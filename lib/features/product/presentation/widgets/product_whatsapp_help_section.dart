import 'package:flutter/material.dart';
// import 'package:google_fonts/google_fonts.dart'; // ⚠️ REMOVED for smaller bundle
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:doctor_store/features/product/domain/models/product_model.dart';
import 'package:doctor_store/shared/utils/app_notifier.dart';
import 'package:doctor_store/shared/utils/link_share_helper.dart';

class ProductWhatsappHelpSection extends StatelessWidget {
  final String storePhone;
  final Product product;
  final int quantity;
  final String unitLabel;
  final bool hasColors;
  final bool hasSizes;
  final String? selectedColor;
  final String? selectedSize;
  final Color primaryDark;

  const ProductWhatsappHelpSection({
    super.key,
    required this.storePhone,
    required this.product,
    required this.quantity,
    required this.unitLabel,
    required this.hasColors,
    required this.hasSizes,
    required this.selectedColor,
    required this.selectedSize,
    required this.primaryDark,
  });

  @override
  Widget build(BuildContext context) {
    if (storePhone.trim().isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF81C784)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'تحتاج مساعدة قبل الشراء؟',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 14,
              color: primaryDark,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'فريق خدمة العملاء جاهز لمساعدتك في اختيار المقاس واللون الأنسب لك قبل تأكيد الطلب.',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade800,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _launchWhatsAppProductHelp(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF25D366),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const FaIcon(FontAwesomeIcons.whatsapp, size: 18),
              label: Text(
                'اسألنا عن هذا المنتج عبر واتساب',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _launchWhatsAppProductHelp(BuildContext context) async {
    final phone = storePhone.trim();
    if (phone.isEmpty) {
      AppNotifier.showError(context, 'خدمة الواتساب غير متاحة حالياً. حاول مرة أخرى لاحقاً.');
      return;
    }

    final colorText = hasColors
        ? (selectedColor ?? 'لم أحدد بعد')
        : 'غير متوفر';
    final sizeText = hasSizes
        ? (selectedSize ?? 'لم أحدد بعد')
        : 'غير متوفر';

    final productUrl = buildFullUrl('/p/${product.slug ?? product.id}');

    final buffer = StringBuffer();
    buffer.writeln('مرحباً، لدي استفسار قبل الشراء عن هذا المنتج من متجر الدكتور:');
    buffer.writeln('• الاسم: ${product.title}');
    buffer.writeln('• القسم: ${product.categoryArabic}');
    buffer.writeln('• رابط المنتج: $productUrl');
    if (hasColors) {
      buffer.writeln('• اللون المختار: $colorText');
    }
    if (hasSizes) {
      buffer.writeln('• المقاس المختار: $sizeText');
    }
    buffer.writeln('• الكمية: $quantity $unitLabel');
    buffer.writeln('');
    buffer.writeln('أرغب بمساعدتكم في اختيار الأنسب وتأكيد تفاصيل الطلب، وشكراً لكم.');

    final encoded = Uri.encodeComponent(buffer.toString());
    final url = Uri.parse('https://wa.me/$phone?text=$encoded');

    final messenger = ScaffoldMessenger.maybeOf(context);

    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      // في حال تعذر فتح الرابط نستخدم SnackBar بسيطة بدلاً من AppNotifier لتجنب استخدام السياق بعد الانتظار.
      messenger?.showSnackBar(
        const SnackBar(
          content: Text('تعذر فتح الواتساب على هذا الجهاز.'),
        ),
      );
    }
  }
}
