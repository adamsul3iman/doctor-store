import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:doctor_store/shared/widgets/constrained_dialog.dart';

/// Pop-up ذكي يظهر للعملاء الجدد مع عرض خصم 15%
/// يظهر مرة واحدة فقط بعد 10 ثوان من الدخول
class FirstTimeDiscountPopup extends StatefulWidget {
  const FirstTimeDiscountPopup({super.key});

  @override
  State<FirstTimeDiscountPopup> createState() => _FirstTimeDiscountPopupState();
}

class _FirstTimeDiscountPopupState extends State<FirstTimeDiscountPopup>
    with SingleTickerProviderStateMixin {
  final TextEditingController _emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _scaleAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutBack,
    );
    _opacityAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    // محاكاة إرسال البيانات
    await Future.delayed(const Duration(milliseconds: 1500));

    // حفظ البريد الإلكتروني والكوبون
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('customer_email', _emailController.text);
    await prefs.setString('first_time_coupon', 'WELCOME15');
    await prefs.setBool('first_time_popup_shown', true);

    if (!mounted) return;

    // إظهار رسالة النجاح
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          'تم! استخدم كود WELCOME15 للحصول على خصم 15%',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Almarai',
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFF4CAF50),
        duration: const Duration(seconds: 5),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _handleClose() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('first_time_popup_shown', true);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacityAnimation,
      child: Container(
        color: Colors.black.withValues(alpha: 0.7),
        child: Center(
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: Dialog(
              backgroundColor: Colors.transparent,
              child: ConstrainedDialog(
                maxWidth: 550,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF0A2647),
                        Color(0xFF144272),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                    // زر الإغلاق
                    Positioned(
                      left: 8,
                      top: 8,
                      child: IconButton(
                        icon: const Icon(Icons.close, color: Colors.white70),
                        onPressed: _handleClose,
                      ),
                    ),
                    // المحتوى
                    Padding(
                      padding: const EdgeInsets.all(32),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // أيقونة الهدية
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFF6F00).withValues(alpha: 0.2),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.card_giftcard_rounded,
                                size: 48,
                                color: Color(0xFFFF6F00),
                              ),
                            ),
                            const SizedBox(height: 20),
                            // العنوان
                            const Text(
                              'مرحباً بك!',
                              style: TextStyle(
                                fontFamily: 'Almarai',
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 12),
                            // النص الوصفي
                            const Text(
                              'احصل على خصم 15% على أول طلب',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontFamily: 'Almarai',
                                fontSize: 18,
                                color: Colors.white70,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFF6F00),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Text(
                                'كود: WELCOME15',
                                style: TextStyle(
                                  fontFamily: 'Almarai',
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  letterSpacing: 2,
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
                            // حقل البريد الإلكتروني
                            TextFormField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              textAlign: TextAlign.right,
                              style: const TextStyle(
                                fontFamily: 'Almarai',
                                color: Colors.white,
                              ),
                              decoration: InputDecoration(
                                hintText: 'أدخل بريدك الإلكتروني',
                                hintStyle: const TextStyle(
                                  fontFamily: 'Almarai',
                                  color: Colors.white54,
                                ),
                                prefixIcon: const Icon(
                                  Icons.email_outlined,
                                  color: Colors.white70,
                                ),
                                filled: true,
                                fillColor: Colors.white.withValues(alpha: 0.1),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: Colors.white.withValues(alpha: 0.2),
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: Color(0xFFFF6F00),
                                    width: 2,
                                  ),
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'الرجاء إدخال البريد الإلكتروني';
                                }
                                if (!value.contains('@') || !value.contains('.')) {
                                  return 'الرجاء إدخال بريد إلكتروني صحيح';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 20),
                            // زر الحصول على الخصم
                            SizedBox(
                              width: double.infinity,
                              height: 56,
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _handleSubmit,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFFF6F00),
                                  foregroundColor: Colors.white,
                                  elevation: 4,
                                  shadowColor: const Color(0xFFFF6F00).withValues(alpha: 0.5),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: _isLoading
                                    ? const SizedBox(
                                        height: 24,
                                        width: 24,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2.5,
                                        ),
                                      )
                                    : const Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            'احصل على الخصم',
                                            style: TextStyle(
                                              fontFamily: 'Almarai',
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          SizedBox(width: 8),
                                          Icon(Icons.arrow_back, size: 20),
                                        ],
                                      ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            // ملاحظة صغيرة
                            Text(
                              'لن نرسل لك رسائل مزعجة، وعد! 💙',
                              style: TextStyle(
                                fontFamily: 'Almarai',
                                fontSize: 12,
                                color: Colors.white.withValues(alpha: 0.6),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// دالة ثابتة لعرض الـ Pop-up إذا كان العميل جديد
  // ignore: unused_element
  static Future<void> showIfNeeded(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final hasShown = prefs.getBool('first_time_popup_shown') ?? false;

    if (!hasShown && context.mounted) {
      // انتظر 10 ثوان قبل العرض
      await Future.delayed(const Duration(seconds: 10));
      
      if (context.mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const FirstTimeDiscountPopup(),
        );
      }
    }
  }
}
