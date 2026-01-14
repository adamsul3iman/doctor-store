import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:doctor_store/features/auth/application/user_data_manager.dart';
import 'package:doctor_store/features/cart/application/cart_manager.dart';
import 'package:doctor_store/shared/utils/wishlist_manager.dart';
import 'package:doctor_store/shared/utils/analytics_service.dart';

/// Widget يغلف الشجرة كاملة ليستمع لتغيرات حالة تسجيل الدخول في Supabase
/// ويقوم تلقائياً بمزامنة بيانات المستخدم بعد نجاح تسجيل الدخول عبر Google
/// أو أي طريقة أخرى تعتمد على onAuthStateChange (مثل OAuth بشكل عام).
class SupabaseAuthListener extends ConsumerStatefulWidget {
  final Widget child;

  const SupabaseAuthListener({super.key, required this.child});

  @override
  ConsumerState<SupabaseAuthListener> createState() => _SupabaseAuthListenerState();
}

class _SupabaseAuthListenerState extends ConsumerState<SupabaseAuthListener> {
  StreamSubscription<AuthState>? _sub;

  @override
  void initState() {
    super.initState();

    SupabaseClient? client;
    try {
      client = Supabase.instance.client;
    } catch (_) {
      // في بيئات الاختبار أو قبل تهيئة Supabase نتجاهل المستمع بهدوء
      return;
    }

    _sub = client.auth.onAuthStateChange.listen((authState) async {
      final event = authState.event;

      if (event == AuthChangeEvent.signedIn) {
        if (!mounted) return;
        final router = GoRouter.of(context);
        final location = router.routerDelegate.currentConfiguration.uri.toString();
        await handleSupabaseSignedIn(
          ref: ref,
          router: router,
          currentLocation: location,
        );
      }

      // يمكن مستقبلاً التعامل مع signedOut هنا إذا احتجنا.
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

/// دالة مساعدة عامة (ومعلَّمة للاختبارات) تنفِّذ منطق ما بعد تسجيل الدخول بنجاح.
///
/// - تزامن ملف المستخدم، المفضلة، والسلة.
/// - تتبع حدث نجاح تسجيل الدخول عبر OAuth.
/// - إذا كان المستخدم على `/login` تنقله إما للوحة التحكم أو الصفحة الرئيسية.
@visibleForTesting
Future<void> handleSupabaseSignedIn({
  required WidgetRef ref,
  required GoRouter router,
  required String currentLocation,
}) async {
  try {
    await ref.read(userProfileProvider.notifier).refreshProfile();
    await ref.read(wishlistProvider.notifier).refreshAfterLogin();
    await ref.read(cartProvider.notifier).syncAfterLogin();
    await AnalyticsService.instance.trackEvent('login_success_oauth');
  } catch (_) {
    // لا نكسر التطبيق بسبب خطأ في المزامنة أو التتبع
  }

  if (currentLocation == '/login') {
    final profile = ref.read(userProfileProvider);
    final target = profile.isAdmin ? '/admin/dashboard' : '/';
    router.go(target);
  }
}
