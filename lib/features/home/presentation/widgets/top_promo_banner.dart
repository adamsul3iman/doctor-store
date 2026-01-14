import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:doctor_store/features/auth/presentation/widgets/welcome_dialog.dart';

class TopPromoBanner extends StatefulWidget {
  const TopPromoBanner({super.key});

  @override
  State<TopPromoBanner> createState() => _TopPromoBannerState();
}

class _TopPromoBannerState extends State<TopPromoBanner> {
  bool _isVisible = false;

  @override
  void initState() {
    super.initState();
    _checkVisibility();
  }

  Future<void> _checkVisibility() async {
    final prefs = await SharedPreferences.getInstance();
    // نتحقق هل العميل أغلق الإعلان سابقاً؟ أو هل هو مسجل بالفعل؟
    final isHidden = prefs.getBool('hide_promo_banner') ?? false;
    final isRegistered = prefs.getBool('is_registered_client') ?? false;

    // نظهر الشريط فقط إذا لم يغلقه سابقاً ولم يسجل بعد
    if (!isHidden && !isRegistered) {
      setState(() => _isVisible = true);
    }
  }

  Future<void> _hideBanner() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hide_promo_banner', true); // حفظ الخيار للأبد
    setState(() => _isVisible = false);
  }

  @override
  Widget build(BuildContext context) {
    if (!_isVisible) return const SizedBox.shrink(); // لا ترسم شيئاً إذا كان مخفياً

    return Container(
      width: double.infinity,
      color: const Color(0xFF0A2647), // لون كحلي مميز
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SafeArea( // لضمان عدم تغطية النوتش في الموبايل
        bottom: false,
        child: Row(
          children: [
            // أيقونة هدية أو تنبيه
            const Icon(Icons.card_giftcard, color: Color(0xFFD4AF37), size: 20),
            const SizedBox(width: 10),
            
            // النص
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "انضم لعائلة الدكتور واحصل على الميزات!",
                    style: GoogleFonts.almarai(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    "سجل بريدك لحفظ المفضلة ومتابعة الطلبات",
                    style: GoogleFonts.almarai(color: Colors.white70, fontSize: 10),
                  ),
                ],
              ),
            ),

            // زر التسجيل
            TextButton(
              onPressed: () {
                // فتح النافذة فقط عند طلب العميل
                showDialog(context: context, builder: (_) => const WelcomeDialog());
              },
              style: TextButton.styleFrom(
                backgroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text("سجل الآن", style: GoogleFonts.almarai(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF0A2647))),
            ),

            const SizedBox(width: 8),

            // زر الإغلاق (X)
            InkWell(
              onTap: _hideBanner,
              child: const Icon(Icons.close, color: Colors.white54, size: 18),
            ),
          ],
        ),
      ),
    );
  }
}
