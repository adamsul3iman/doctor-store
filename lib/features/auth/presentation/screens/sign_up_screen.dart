// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
// import 'package:google_fonts/google_fonts.dart'; // ⚠️ REMOVED for smaller bundle // ⚠️ ADDED for styling
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:doctor_store/core/theme/app_theme.dart';
import 'package:doctor_store/features/auth/application/user_data_manager.dart';
import 'package:doctor_store/features/auth/presentation/widgets/email_otp_sheet.dart';
import 'package:doctor_store/features/cart/application/cart_manager.dart';
import 'package:doctor_store/shared/services/analytics_service.dart';
import 'package:doctor_store/shared/utils/app_notifier.dart';
import 'package:doctor_store/shared/utils/wishlist_manager.dart';

class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key});

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  AutovalidateMode _autovalidateMode = AutovalidateMode.disabled;

  bool _isLoading = false;
  bool _obscurePass = true;
  String? _formError;

  @override
  void initState() {
    super.initState();
    AnalyticsService.instance.trackEvent('signup_view');
  }

  void _setFormError(String? message) {
    if (!mounted) return;
    setState(() {
      _formError = message;
    });
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) {
      if (_autovalidateMode != AutovalidateMode.onUserInteraction) {
        setState(() => _autovalidateMode = AutovalidateMode.onUserInteraction);
      }
      return;
    }

    final pass = _passwordController.text.trim();
    final confirm = _confirmPasswordController.text.trim();
    if (pass != confirm) {
      _setFormError('كلمتا المرور غير متطابقتين، يرجى التأكد منهما.');
      return;
    }

    _setFormError(null);
    setState(() => _isLoading = true);

    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();
    final fullName = [firstName, lastName].where((e) => e.isNotEmpty).join(' ');
    final client = Supabase.instance.client;

    try {
      final res = await client.auth.signUp(
        email: email,
        password: password,
        data: {
          'first_name': firstName,
          'last_name': lastName,
          'full_name': fullName,
        },
      );

      // 1) جلسة جاهزة مباشرة
      if (res.session != null && res.user != null) {
        await ref.read(userProfileProvider.notifier).refreshProfile();
        await ref.read(wishlistProvider.notifier).refreshAfterLogin();
        await ref.read(cartProvider.notifier).syncAfterLogin();
        await AnalyticsService.instance.trackEvent('signup_success_instant');

        if (!mounted) return;
        final profile = ref.read(userProfileProvider);
        final target = profile.isAdmin ? '/admin/dashboard' : '/';
        context.go(target);
        AppNotifier.showSuccess(context, 'تم إنشاء الحساب وتسجيل الدخول بنجاح');
        return;
      }

      // 2) يتطلب OTP
      if (!mounted) return;
      final bool? verified = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => EmailOtpSheet(email: email),
      );

      if (verified == true) {
        await AnalyticsService.instance.trackEvent('signup_success');
        if (!mounted) return;
        final profile = ref.read(userProfileProvider);
        final target = profile.isAdmin ? '/admin/dashboard' : '/';
        context.go(target);
      } else {
        const msg =
            'لم يتم تفعيل الحساب بعد، تأكد من الكود أو رابط التفعيل في بريدك.';
        _setFormError(msg);
        AppNotifier.showInfo(context, msg);
      }
    } on AuthException catch (e) {
      if (!mounted) return;

      final lower = e.message.toLowerCase();
      final msg = (lower.contains('user already registered') ||
              lower.contains('already exists'))
          ? 'هذا البريد مسجّل بالفعل، جرّب تسجيل الدخول أو استعادة كلمة المرور.'
          : (e.message.isNotEmpty ? e.message : 'تعذّر إنشاء الحساب، حاول لاحقاً.');

      _setFormError(msg);
      AppNotifier.showError(context, msg);
    } catch (_) {
      if (!mounted) return;
      const msg = 'حدث خطأ غير متوقع أثناء إنشاء الحساب، حاول لاحقاً.';
      _setFormError(msg);
      AppNotifier.showError(context, msg);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets;
    final isKeyboardVisible = viewInsets.bottom > 0;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('إنشاء حساب'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 700;
            final maxWidth = isWide ? 420.0 : constraints.maxWidth;

            return Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  16,
                  isKeyboardVisible ? 12 : 24,
                  16,
                  24 + viewInsets.bottom,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxWidth),
                  child: _buildAuthCard(),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildAuthCard() {
    final theme = Theme.of(context);
    final orangeFocus = Colors.orange.shade800;

    InputDecoration withOrangeFocus(InputDecoration base) {
      return base.copyWith(
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: orangeFocus, width: 1.5),
        ),
      );
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            autovalidateMode: _autovalidateMode,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Hero(
                    tag: 'app_logo_auth',
                    child: Image.asset(
                      'assets/images/logo.png',
                      height: 54,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'أنشئ حسابك في ثوانٍ',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.displayMedium?.copyWith(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'سيساعدك الحساب على حفظ العناوين والمفضلة وتتبع الطلبات بسهولة.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
                ),
                const SizedBox(height: 18),

                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _firstNameController,
                        textInputAction: TextInputAction.next,
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'الاسم الأول مطلوب';
                          }
                          return null;
                        },
                        decoration: withOrangeFocus(
                          const InputDecoration(
                            labelText: 'الاسم الأول',
                            prefixIcon: Icon(Icons.person_outline),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _lastNameController,
                        textInputAction: TextInputAction.next,
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'اسم العائلة مطلوب';
                          }
                          return null;
                        },
                        decoration: withOrangeFocus(
                          const InputDecoration(
                            labelText: 'اسم العائلة',
                            prefixIcon: Icon(Icons.badge_outlined),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'البريد الإلكتروني مطلوب';
                    }
                    if (!val.contains('@')) {
                      return 'يرجى إدخال بريد إلكتروني صحيح';
                    }
                    return null;
                  },
                  decoration: withOrangeFocus(
                    const InputDecoration(
                      labelText: 'البريد الإلكتروني',
                      hintText: 'name@example.com',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePass,
                  autofillHints: const [AutofillHints.newPassword],
                  validator: (val) {
                    if (val == null || val.isEmpty) {
                      return 'كلمة المرور مطلوبة';
                    }
                    if (val.length < 6) {
                      return 'كلمة المرور قصيرة جداً';
                    }
                    return null;
                  },
                  decoration: withOrangeFocus(
                    InputDecoration(
                      labelText: 'كلمة المرور (على الأقل 6 أحرف)',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePass
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                        ),
                        onPressed: () =>
                            setState(() => _obscurePass = !_obscurePass),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: _obscurePass,
                  autofillHints: const [AutofillHints.newPassword],
                  validator: (val) {
                    if (val == null || val.isEmpty) {
                      return 'يرجى تأكيد كلمة المرور';
                    }
                    if (val != _passwordController.text) {
                      return 'كلمتا المرور غير متطابقتين';
                    }
                    return null;
                  },
                  decoration: withOrangeFocus(
                    const InputDecoration(
                      labelText: 'تأكيد كلمة المرور',
                      prefixIcon: Icon(Icons.lock_reset),
                    ),
                  ),
                ),

                if (_formError != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.error.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppTheme.error.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Text(
                      _formError!,
                      style: TextStyle(
                        color: AppTheme.error,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 14),

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
                        : const Text('إنشاء حساب'),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('لديك حساب؟ '),
                    TextButton(
                      onPressed: _isLoading ? null : () => context.go('/login'),
                      child: const Text('تسجيل الدخول'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
