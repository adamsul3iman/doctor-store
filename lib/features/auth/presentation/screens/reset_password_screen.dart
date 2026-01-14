import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// شاشة إعادة تعيين كلمة المرور بعد الضغط على رابط "نسيت كلمة المرور" من البريد.
///
/// ملاحظة مهمة:
/// - يجب ضبط redirect URL في Supabase ليشير إلى هذا المسار على الويب، مثلاً:
///   https://YOUR_DOMAIN/reset-password
class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final newPassword = _passwordController.text.trim();

    try {
      final client = Supabase.instance.client;
      await client.auth.updateUser(UserAttributes(password: newPassword));

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم تحديث كلمة المرور بنجاح، يمكنك تسجيل الدخول الآن'),
        ),
      );

      // توجيه المستخدم إلى صفحة تسجيل الدخول بعد النجاح
      context.go('/login');
    } on AuthException catch (e) {
      setState(() {
        _errorMessage = e.message.isNotEmpty
            ? e.message
            : 'تعذر تحديث كلمة المرور، تأكد من أن الرابط صالح وحاول مرة أخرى.';
      });
    } catch (_) {
      setState(() {
        _errorMessage =
            'حدث خطأ غير متوقَّع أثناء تحديث كلمة المرور، حاول لاحقاً.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'إعادة تعيين كلمة المرور',
          style: GoogleFonts.almarai(fontWeight: FontWeight.bold),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'أدخل كلمة مرور جديدة لحسابك ثم اضغط حفظ.',
                  style: GoogleFonts.almarai(fontSize: 14),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'كلمة المرور الجديدة',
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                  validator: (val) {
                    if (val == null || val.isEmpty) {
                      return 'كلمة المرور مطلوبة';
                    }
                    if (val.length < 6) {
                      return 'كلمة المرور قصيرة جداً (الحد الأدنى 6 أحرف)';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _confirmController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'تأكيد كلمة المرور',
                    prefixIcon: Icon(Icons.lock_reset),
                  ),
                  validator: (val) {
                    if (val == null || val.isEmpty) {
                      return 'يرجى تأكيد كلمة المرور';
                    }
                    if (val != _passwordController.text) {
                      return 'كلمتا المرور غير متطابقتين';
                    }
                    return null;
                  },
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _errorMessage!,
                    style: GoogleFonts.almarai(
                      color: Colors.red,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _submit,
                    child: _isLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            'حفظ كلمة المرور',
                            style: GoogleFonts.almarai(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
