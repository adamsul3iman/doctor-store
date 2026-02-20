// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
// import 'package:google_fonts/TextStyle'; // ⚠️ REMOVED for smaller bundle // ⚠️ ADDED for TextStyle
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:doctor_store/shared/widgets/constrained_dialog.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:doctor_store/features/auth/application/user_data_manager.dart';
import 'package:doctor_store/shared/utils/wishlist_manager.dart';
import 'package:doctor_store/features/cart/application/cart_manager.dart';
import 'package:doctor_store/shared/services/analytics_service.dart';
import 'package:doctor_store/shared/utils/app_notifier.dart';
import 'package:doctor_store/core/theme/app_theme.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  AutovalidateMode _autovalidateMode = AutovalidateMode.disabled;

  bool _isLoading = false;
  bool _obscurePass = true;
  String? _formError;

  @override
  void initState() {
    super.initState();
    // تتبع زيارة شاشة تسجيل الدخول
    AnalyticsService.instance.trackEvent('login_view');
  }

  void _setFormError(String? message) {
    if (!mounted) return;
    setState(() {
      _formError = message;
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
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

    _setFormError(null);
    setState(() => _isLoading = true);

    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final client = Supabase.instance.client;

    try {
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
    } on AuthException catch (e) {
      if (!mounted) return;

      String msg;
      final raw = e.message.trim();
      if (raw.isEmpty) {
        msg = 'فشل تسجيل الدخول: تأكد من البريد الإلكتروني وكلمة المرور.';
      } else if (raw.toLowerCase().contains('invalid login credentials')) {
        msg = 'بيانات الدخول غير صحيحة. تأكد من البريد الإلكتروني وكلمة المرور.';
      } else {
        msg = raw;
      }
      _setFormError(msg);
      AppNotifier.showError(context, msg);
    } catch (_) {
      if (!mounted) return;
      const msg = 'حدث خطأ غير متوقع أثناء تسجيل الدخول، حاول لاحقاً.';
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
            return ConstrainedDialog(
              maxWidth: 550,
              child: AlertDialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                title: Text(
                  'استعادة كلمة المرور',
                  style: TextStyle(fontWeight: FontWeight.bold),
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
                              final origin = Uri.base
                                  .origin; // مثال: https://doctorstore.com
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
              ),
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
      resizeToAvoidBottomInset: true,
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('تسجيل الدخول'),
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
                  'مرحباً بعودتك',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.displayMedium?.copyWith(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'سجّل دخولك لمتابعة طلباتك وحفظ المفضلة بسهولة.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
                ),
                const SizedBox(height: 18),

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
                  decoration: const InputDecoration(
                    labelText: 'البريد الإلكتروني',
                    hintText: 'name@example.com',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                ),
                const SizedBox(height: 12),
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
                  decoration: InputDecoration(
                    labelText: 'كلمة المرور',
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
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _isLoading ? null : _showForgotPasswordDialog,
                    child: const Text('نسيت كلمة المرور؟'),
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
                        : const Text('تسجيل الدخول'),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 44,
                  child: OutlinedButton.icon(
                    onPressed: _isLoading ? null : _signInWithGoogle,
                    icon: Image.asset(
                      'assets/images/google_logo.png',
                      width: 18,
                      height: 18,
                      fit: BoxFit.contain,
                    ),
                    label: const Text('متابعة باستخدام Google'),
                  ),
                ),
                const SizedBox(height: 12),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('ليس لديك حساب؟ '),
                    TextButton(
                      onPressed: _isLoading ? null : () => context.go('/signup'),
                      child: const Text('إنشاء حساب'),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
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
                  child: const Text('المتابعة كضيف'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
