import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:doctor_store/features/auth/application/user_data_manager.dart';
import 'package:doctor_store/shared/utils/wishlist_manager.dart';
import 'package:doctor_store/features/cart/application/cart_manager.dart';
import 'package:doctor_store/shared/utils/analytics_service.dart';
import 'package:doctor_store/shared/utils/app_notifier.dart';

/// شاشة / نافذة إدخال كود التحقق المرسل إلى البريد الإلكتروني.
///
/// - يفترض أن الكود تم إرساله مسبقاً بعد signUp.
/// - هنا نقوم فقط بـ verifyOTP وعرض رسائل الخطأ / النجاح.
class EmailOtpSheet extends ConsumerStatefulWidget {
  final String email;

  const EmailOtpSheet({super.key, required this.email});

  @override
  ConsumerState<EmailOtpSheet> createState() => _EmailOtpSheetState();
}

class _EmailOtpSheetState extends ConsumerState<EmailOtpSheet> {
  final _codeCtrl = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _confirmCode() async {
    final code = _codeCtrl.text.trim();
    if (code.length != 6) {
      setState(() => _errorMessage = 'الرجاء إدخال الكود المكوَّن من 6 أرقام كاملاً');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final supabase = Supabase.instance.client;

      final AuthResponse res = await supabase.auth.verifyOTP(
        type: OtpType.signup,
        token: code,
        email: widget.email,
      );

      if (res.session != null && res.user != null) {
        // تحديث حالة المستخدم في التطبيق بعد نجاح التفعيل
        await ref.read(userProfileProvider.notifier).refreshProfile();
        await ref.read(wishlistProvider.notifier).refreshAfterLogin();
        await ref.read(cartProvider.notifier).syncAfterLogin();
        await AnalyticsService.instance
            .trackEvent('email_signup_otp_success');

        if (!mounted) return;
        Navigator.of(context).pop(true); // نُرجع true لمنادينا كإشارة نجاح

        AppNotifier.showSuccess(
          context,
          'تم إنشاء الحساب وتفعيله بنجاح. أهلاً بك في متجر الدكتور!',
        );
      } else {
        setState(() =>
            _errorMessage = 'تعذَّر تأكيد الكود، حاول مرة أخرى أو أعد الإرسال.');
      }
    } on AuthException catch (e) {
      setState(() => _errorMessage = e.message);
    } catch (_) {
      setState(() => _errorMessage =
          'حدث خطأ غير متوقَّع أثناء التحقق، حاول لاحقاً.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resendCode() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final supabase = Supabase.instance.client;
      await supabase.auth.resend(type: OtpType.signup, email: widget.email);

      if (!mounted) return;
      AppNotifier.showInfo(
        context,
        'تم إرسال كود جديد إلى ${widget.email}',
      );
    } on AuthException catch (e) {
      setState(() => _errorMessage = e.message);
    } catch (_) {
      setState(() =>
          _errorMessage = 'تعذَّر إعادة إرسال الكود حالياً، حاول لاحقاً.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(20, 24, 20, bottomPadding + 20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'تحقق من بريدك الإلكتروني',
            style: GoogleFonts.almarai(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF0A2647),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'أرسلنا رمز تحقق مكوَّن من 6 أرقام إلى: ${widget.email}\nالرجاء إدخاله أدناه لإكمال إنشاء الحساب.',
            style:
                GoogleFonts.almarai(fontSize: 13, color: Colors.grey[700]),
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _codeCtrl,
            keyboardType: TextInputType.number,
            maxLength: 6,
            decoration: InputDecoration(
              counterText: '',
              hintText: '••••••',
              hintStyle: GoogleFonts.chakraPetch(
                  letterSpacing: 8,
                  fontSize: 22,
                  color: Colors.grey[400]),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14)),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide:
                    const BorderSide(color: Color(0xFF0A2647), width: 1.5),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            ),
            textAlign: TextAlign.center,
            style: GoogleFonts.chakraPetch(
                fontSize: 24, letterSpacing: 10, fontWeight: FontWeight.bold),
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 8),
            Text(
              _errorMessage!,
              style: GoogleFonts.almarai(
                  color: Colors.red.shade700,
                  fontSize: 12,
                  fontWeight: FontWeight.w600),
            ),
          ],
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _confirmCode,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0A2647),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2),
                    )
                  : Text('تأكيد الكود',
                      style: GoogleFonts.almarai(
                          fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ),
          const SizedBox(height: 10),
          Center(
            child: TextButton(
              onPressed: _isLoading ? null : _resendCode,
              child: Text('لم يصلك الكود؟ أعد الإرسال',
                  style: GoogleFonts.almarai(
                      color: const Color(0xFF0A2647),
                      fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}
