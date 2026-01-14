// ignore_for_file: use_build_context_synchronously

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:doctor_store/features/auth/application/user_data_manager.dart';
import 'package:doctor_store/shared/utils/wishlist_manager.dart';
import 'package:doctor_store/features/cart/application/cart_manager.dart';
import 'package:doctor_store/shared/utils/analytics_service.dart';
import 'package:doctor_store/shared/utils/app_notifier.dart';
import 'package:doctor_store/features/auth/presentation/widgets/email_otp_sheet.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _isLoading = false;
  bool _isLoginMode = true; // true = Login, false = Sign Up
  bool _obscurePass = true;
  String? _formError;

  late final AnimationController _bgAnimationController;
  late final Animation<double> _bgScaleAnimation;

  @override
  void initState() {
    super.initState();
    // تتبع زيارة شاشة تسجيل الدخول / إنشاء الحساب
    AnalyticsService.instance.trackEvent('login_view');

    _bgAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    );

    _bgScaleAnimation = CurvedAnimation(
      parent: _bgAnimationController,
      curve: Curves.easeOutCubic,
    );

    _bgAnimationController.forward();
  }

  void _setFormError(String? message) {
    if (!mounted) return;
    setState(() {
      _formError = message;
    });
  }

  @override
  void dispose() {
    _bgAnimationController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    // تحقق إضافي عند إنشاء حساب: تطابق كلمتي المرور
    if (!_isLoginMode) {
      final pass = _passwordController.text.trim();
      final confirm = _confirmPasswordController.text.trim();
      if (pass != confirm) {
        _setFormError('كلمتا المرور غير متطابقتين، يرجى التأكد منهما.');
        return;
      }
    }

    _setFormError(null);
    setState(() => _isLoading = true);

    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final client = Supabase.instance.client;

    try {
      if (_isLoginMode) {
        // تسجيل دخول تقليدي
        await client.auth.signInWithPassword(email: email, password: password);

        // مزامنة حالة المستخدم بعد النجاح
        await ref.read(userProfileProvider.notifier).refreshProfile();
        await ref.read(wishlistProvider.notifier).refreshAfterLogin();
        await ref.read(cartProvider.notifier).syncAfterLogin();
        await AnalyticsService.instance.trackEvent('login_success');

        if (!mounted) return;
        final profile = ref.read(userProfileProvider);
        final target = profile.isAdmin ? '/admin/dashboard' : '/';
        context.go(target);
        AppNotifier.showSuccess(context, 'تم تسجيل الدخول بنجاح');
      } else {
        // إنشاء حساب جديد ببريد + كلمة مرور
        final res = await client.auth.signUp(email: email, password: password);

        // 1) حالة: الجلسة جاهزة مباشرة (بدون كود OTP)
        if (res.session != null && res.user != null) {
          await ref.read(userProfileProvider.notifier).refreshProfile();
          await ref.read(wishlistProvider.notifier).refreshAfterLogin();
          await ref.read(cartProvider.notifier).syncAfterLogin();
          await AnalyticsService.instance
              .trackEvent('signup_success_instant');

          if (!mounted) return;
          final profile = ref.read(userProfileProvider);
          final target = profile.isAdmin ? '/admin/dashboard' : '/';
          context.go(target);
          AppNotifier.showSuccess(
              context, 'تم إنشاء الحساب وتسجيل الدخول بنجاح');
          return;
        }

        // 2) حالة: يتطلّب تفعيل عبر كود مكوّن من 6 أرقام في البريد
        if (!mounted) return;

        final bool? verified = await showModalBottomSheet<bool>(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => EmailOtpSheet(email: email),
        );

        if (verified == true) {
          // بعد نجاح التفعيل عبر OTP، يكون المستخدم مسجَّلاً دخولاً
          await AnalyticsService.instance.trackEvent('signup_success');

          if (!mounted) return;
          final profile = ref.read(userProfileProvider);
          final target = profile.isAdmin ? '/admin/dashboard' : '/';
          context.go(target);
        } else {
          const msg =
              'لم يتم تفعيل الحساب بعد، تأكد من الكود أو رابط التفعيل في بريدك.';
          _setFormError(msg);
          if (mounted) {
            AppNotifier.showInfo(context, msg);
          }
        }
      }
    } on AuthException catch (e) {
      if (!mounted) return;

      String msg;
      if (_isLoginMode) {
        msg = e.message.isNotEmpty
            ? e.message
            : 'فشل تسجيل الدخول: تأكد من البريد الإلكتروني وكلمة المرور.';
      } else {
        final lower = e.message.toLowerCase();
        if (lower.contains('user already registered') || lower.contains('already exists')) {
          msg = 'هذا البريد مسجّل بالفعل، جرّب تسجيل الدخول أو استعادة كلمة المرور.';
        } else {
          msg = e.message.isNotEmpty ? e.message : 'تعذّر إنشاء الحساب، حاول لاحقاً.';
        }
      }

      _setFormError(msg);
      AppNotifier.showError(context, msg);
    } catch (_) {
      if (!mounted) return;
      final msg = _isLoginMode
          ? 'حدث خطأ غير متوقع أثناء تسجيل الدخول، حاول لاحقاً.'
          : 'حدث خطأ غير متوقع أثناء إنشاء الحساب، حاول لاحقاً.';
      _setFormError(msg);
      AppNotifier.showError(context, msg);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _showForgotPasswordDialog() async {
    final emailController =
        TextEditingController(text: _emailController.text.trim());
    String? errorMessage;
    bool isLoading = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Text(
                'استعادة كلمة المرور',
                style: GoogleFonts.almarai(fontWeight: FontWeight.bold),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'البريد الإلكتروني',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'سنرسل رابط إعادة تعيين كلمة المرور إلى هذا البريد في حال كان مسجلاً لدينا.',
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                  if (errorMessage != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      errorMessage!,
                      style: TextStyle(
                        color: Colors.red.shade700,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isLoading
                      ? null
                      : () => Navigator.of(dialogContext).pop(),
                  child: const Text('إلغاء'),
                ),
                ElevatedButton(
                  onPressed: isLoading
                      ? null
                      : () async {
                          final email = emailController.text.trim();
                          if (email.isEmpty || !email.contains('@')) {
                            setState(() {
                              errorMessage = 'يرجى إدخال بريد إلكتروني صالح';
                            });
                            return;
                          }

                          setState(() {
                            isLoading = true;
                            errorMessage = null;
                          });

                          try {
                            final client = Supabase.instance.client;
                            final origin = Uri.base.origin; // مثال: https://doctorstore.com
                            await client.auth.resetPasswordForEmail(
                              email,
                              redirectTo: '$origin/reset-password',
                            );

                            ScaffoldMessenger.of(dialogContext).showSnackBar(
                              SnackBar(
                                content: Text(
                                    'تم إرسال رابط إعادة تعيين كلمة المرور إلى $email'),
                              ),
                            );

                            if (Navigator.of(dialogContext).canPop()) {
                              Navigator.of(dialogContext).pop();
                            }
                          } on AuthException catch (e) {
                            setState(() {
                              errorMessage = e.message;
                            });
                          } catch (_) {
                            setState(() {
                              errorMessage =
                                  'تعذَّر إرسال رابط إعادة التعيين حالياً، حاول لاحقاً.';
                            });
                          } finally {
                            setState(() {
                              isLoading = false;
                            });
                          }
                        },
                  child: isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('إرسال الرابط'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _signInWithGoogle() async {
    _setFormError(null);
    setState(() => _isLoading = true);
    try {
      // على الويب، نترك Supabase يتعامل مع إعادة التوجيه الافتراضية (https)
      // وعلى الموبايل نستخدم deep link doctorstore:// للعودة إلى التطبيق.
      debugPrint('[_signInWithGoogle] kIsWeb=$kIsWeb');
      if (kIsWeb) {
        debugPrint('[_signInWithGoogle] Using web OAuth (no redirectTo)');
        await Supabase.instance.client.auth.signInWithOAuth(
          OAuthProvider.google,
        );
      } else {
        debugPrint('[_signInWithGoogle] Using mobile OAuth with redirectTo doctorstore://login-callback');
        await Supabase.instance.client.auth.signInWithOAuth(
          OAuthProvider.google,
          redirectTo: 'doctorstore://login-callback',
        );
      }
    } on AuthException catch (e) {
      if (!mounted) return;
      final msg = e.message.isNotEmpty
          ? e.message
          : 'تعذر تسجيل الدخول عبر Google حالياً، حاول مرة أخرى لاحقاً.';
      _setFormError(msg);
      AppNotifier.showError(context, msg);
    } catch (_) {
      if (!mounted) return;
      const msg = 'حدث خطأ غير متوقع أثناء محاولة تسجيل الدخول عبر Google، حاول لاحقاً.';
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
      // ضروري جداً لمنع الكيبورد من تغطية الحقول أو عمل Overflow
      resizeToAvoidBottomInset: true,
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          _buildBrandSide(),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 700;
                final maxWidth = isWide ? 520.0 : constraints.maxWidth;

                return Center(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      20,
                      isKeyboardVisible ? 16 : (isWide ? 32 : 24),
                      20,
                      isKeyboardVisible
                          ? 16 + viewInsets.bottom
                          : 32 + viewInsets.bottom,
                    ),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: maxWidth),
                      child: _buildAuthCard(isWide: isWide),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  bool get _isInTestEnvironment {
    final binding = WidgetsBinding.instance;
    // نتجنب الاعتماد المباشر على flutter_test، نتحقق من نوع الـ Binding نصياً
    return binding.runtimeType.toString().contains('TestWidgetsFlutterBinding');
  }

  Widget _buildBrandSide() {
    // في بيئة الاختبار، نستخدم خلفية بسيطة بدون طلب شبكة لتجنّب NetworkImageLoadException
    final ImageProvider backgroundImage = _isInTestEnvironment
        ? const AssetImage('assets/images/Doctor_Store_login_logo.png')
        : const NetworkImage(
            'https://images.unsplash.com/photo-1505691723518-36a5ac3be353?auto=format&fit=crop&w=1600&q=80',
          );

    return Stack(
      fit: StackFit.expand,
      children: [
        ScaleTransition(
          scale: Tween<double>(begin: 1.0, end: 1.06).animate(_bgScaleAnimation),
          child: DecoratedBox(
            decoration: BoxDecoration(
              image: DecorationImage(
                image: backgroundImage,
                fit: BoxFit.cover,
              ),
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.05),
                Colors.black.withValues(alpha: 0.35),
                Colors.black.withValues(alpha: 0.78),
              ],
            ),
          ),
        ),
        Align(
          alignment: Alignment.topCenter,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(top: 24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    'assets/images/Doctor_Store_login_logo.png',
                    height: 80,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Doctor Store',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.almarai(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.6,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Sleep Better, Live Better',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.almarai(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
            child: Text(
              'تجربة نوم فاخرة مصممة خصيصاً لك، من المراتب إلى أدق تفاصيل غرفة النوم.',
              textAlign: TextAlign.center,
              style: GoogleFonts.almarai(
                color: Colors.white.withValues(alpha: 0.85),
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAuthCard({required bool isWide}) {
    final theme = Theme.of(context);
    const primaryColor = Color(0xFF0A2647); // Navy blue

    final title = _isLoginMode ? 'مرحباً بعودتك!' : 'أنشئ حسابك في ثوانٍ';
    final subtitle = _isLoginMode
        ? 'سجّل دخولك لمتابعة طلباتك وحفظ عناوينك بسهولة.'
        : 'أنشئ حساباً لحفظ المفضلة والعناوين وتتبع حالة طلباتك.';

    InputDecoration baseDecoration({
      required String label,
      String? hint,
      Widget? prefixIcon,
      Widget? suffixIcon,
    }) {
      return InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: prefixIcon,
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.08),
        floatingLabelBehavior: FloatingLabelBehavior.auto,
        floatingLabelStyle: const TextStyle(
          color: primaryColor,
          fontWeight: FontWeight.w600,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(
            color: Colors.white.withValues(alpha: 0.45),
            width: 1,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(
            color: Colors.white.withValues(alpha: 0.35),
            width: 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(
            color: primaryColor,
            width: 1.6,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(
            color: Colors.red.shade400,
            width: 1.2,
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(
            color: Colors.red.shade600,
            width: 1.4,
          ),
        ),
      );
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha: isWide ? 0.16 : 0.20),
                  Colors.white.withValues(alpha: isWide ? 0.08 : 0.12),
                ],
              ),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.40),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.38),
                  blurRadius: 32,
                  offset: const Offset(0, 18),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(28, 32, 28, 24),
              child: Form(
                key: _formKey,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(
                      alignment: Alignment.centerRight,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                          color: primaryColor.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: primaryColor.withValues(alpha: 0.45),
                            width: 0.8,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.verified_user_outlined,
                              size: 18,
                              color: primaryColor,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'تسجيل دخول آمن لحسابك',
                              style: theme.textTheme.labelSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: primaryColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      title,
                      style: theme.textTheme.displayMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        fontSize: 24,
                        color: primaryColor,
                      ),
                      textAlign: TextAlign.start,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.92),
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    // Text(
                    //   'يمكنك تسجيل الدخول بحسابك الحالي، إنشاء حساب جديد، أو إكمال الطلب كضيف بدون إنشاء حساب.',
                    //   style: theme.textTheme.bodySmall?.copyWith(
                    //     color: Colors.grey[200]?.withOpacity(0.9),
                    //     fontSize: 11,
                    //     height: 1.5,
                    //   ),
                    // ),
                    const SizedBox(height: 22),

                    // Sliding Toggle: Login / Sign Up
                    _buildModeToggle(),
                    const SizedBox(height: 22),

                    // Social Login - premium Google button
                    Container(
                      height: 44,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.20),
                            blurRadius: 18,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: OutlinedButton(
                        onPressed: _isLoading ? null : _signInWithGoogle,
                        style: OutlinedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF1F1F1F),
                          side: BorderSide(
                            color: Colors.black.withValues(alpha: 0.04),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          padding: EdgeInsets.zero,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.max,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              alignment: Alignment.center,
                              child: ClipOval(
                                child: Image.asset(
                                  'assets/images/google_logo.png',
                                  width: 24,
                                  height: 24,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'تسجيل الدخول باستخدام Google',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.almarai(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF1F1F1F),
                                  letterSpacing: 0.2,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    

                    const SizedBox(height: 22),

                    Row(
                      children: [
                        Expanded(
                          child: Divider(color: Colors.white.withValues(alpha: 0.22)),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Text(
                            'أو بالبريد الإلكتروني',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.white.withValues(alpha: 0.85),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Divider(color: Colors.white.withValues(alpha: 0.22)),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // Email
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
                      style: const TextStyle(color: Colors.white),
                      cursorColor: primaryColor,
                      decoration: baseDecoration(
                        label: 'البريد الإلكتروني',
                        hint: 'name@example.com',
                        prefixIcon: const Icon(Icons.email_outlined),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Password
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePass,
                      autofillHints: const [AutofillHints.password],
                      validator: (val) {
                        if (val == null || val.isEmpty) {
                          return 'كلمة المرور مطلوبة';
                        }
                        if (val.length < 6) {
                          return 'كلمة المرور قصيرة جداً';
                        }
                        return null;
                      },
                      style: const TextStyle(color: Colors.white),
                      cursorColor: primaryColor,
                      decoration: baseDecoration(
                        label: _isLoginMode
                            ? 'كلمة المرور'
                            : 'كلمة المرور (على الأقل 6 أحرف)',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePass
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                          ),
                          onPressed: () => setState(() => _obscurePass = !_obscurePass),
                        ),
                      ),
                    ),

                    if (_isLoginMode)
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed:
                              _isLoading ? null : _showForgotPasswordDialog,
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.white,
                            padding:
                                const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                          ),
                          child: const Text('نسيت كلمة المرور؟'),
                        ),
                      ),

                    if (!_isLoginMode) ...[
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _confirmPasswordController,
                        obscureText: _obscurePass,
                        autofillHints: const [AutofillHints.password],
                        validator: (val) {
                          if (_isLoginMode) return null;
                          if (val == null || val.isEmpty) {
                            return 'يرجى تأكيد كلمة المرور';
                          }
                          if (val != _passwordController.text) {
                            return 'كلمتا المرور غير متطابقتين';
                          }
                          return null;
                        },
                        style: const TextStyle(color: Colors.white),
                        cursorColor: primaryColor,
                        decoration: baseDecoration(
                          label: 'تأكيد كلمة المرور',
                          prefixIcon: const Icon(Icons.lock_reset),
                        ),
                      ),
                    ],

                    if (_formError != null) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.red.withValues(alpha: 0.4),
                            width: 0.8,
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline,
                                color: Colors.red, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _formError!,
                                style: GoogleFonts.almarai(
                                  color: Colors.red.shade100,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 22),

                    // Primary CTA
                    SizedBox(
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: Colors.white,
                          elevation: 8,
                          shadowColor: primaryColor.withValues(alpha: 0.55),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.4,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                _isLoginMode
                                    ? 'تسجيل الدخول'
                                    : 'إنشاء حساب جديد',
                                style: GoogleFonts.almarai(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                      ),
                    ),

                    const SizedBox(height: 10),
                    Text(
                      'بتسجيل الدخول أو إنشاء حساب، أنت توافق على شروط الاستخدام وسياسة الخصوصية.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: 11,
                        color: Colors.white.withValues(alpha: 0.80),
                        height: 1.4,
                      ),
                    ),

                    const SizedBox(height: 10),
                    Text(
                      'لا تريد إنشاء حساب الآن؟ لا مشكلة، يمكنك إكمال الطلب كضيف بخطوة واحدة فقط.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: 11,
                        color: Colors.white.withValues(alpha: 0.85),
                        height: 1.4,
                      ),
                    ),

                    const SizedBox(height: 10),

                    // Guest checkout option
                    TextButton(
                      onPressed: _isLoading
                          ? null
                          : () {
                              AnalyticsService.instance
                                  .trackEvent('login_continue_as_guest');
                              final cartItems = ref.read(cartProvider);
                              if (cartItems.isNotEmpty) {
                                context.go('/cart');
                              } else {
                                context.go('/');
                              }
                            },
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white,
                      ),
                      child: Text(
                        'إكمال الطلب كضيف (بدون إنشاء حساب)',
                        style: GoogleFonts.almarai(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),

                    const SizedBox(height: 4),

                    TextButton(
                      onPressed: _isLoading ? null : () => context.go('/'),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white.withValues(alpha: 0.9),
                      ),
                      child: Text(
                        'العودة لتصفح المتجر',
                        style: GoogleFonts.almarai(
                          fontWeight: FontWeight.w600,
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
    );
  }

  Widget _buildModeToggle() {
    const primaryColor = Color(0xFF0A2647);

    return Container(
      height: 46,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Stack(
        children: [
          AnimatedAlign(
            alignment:
                _isLoginMode ? Alignment.centerRight : Alignment.centerLeft,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            child: FractionallySizedBox(
              widthFactor: 0.5,
              child: Container(
                margin: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white,
                      Color(0xFFF4F4F4),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(999),
                    boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.20),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    if (!_isLoginMode) {
                      setState(() => _isLoginMode = true);
                    }
                  },
                  behavior: HitTestBehavior.opaque,
                  child: Center(
                    child: Text(
                      'تسجيل دخول',
                      style: GoogleFonts.almarai(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: _isLoginMode
                            ? primaryColor
                            : Colors.white.withValues(alpha: 0.82),
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    if (_isLoginMode) {
                      setState(() => _isLoginMode = false);
                    }
                  },
                  behavior: HitTestBehavior.opaque,
                  child: Center(
                    child: Text(
                      'إنشاء حساب',
                      style: GoogleFonts.almarai(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: !_isLoginMode
                            ? primaryColor
                            : Colors.white.withValues(alpha: 0.82),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
