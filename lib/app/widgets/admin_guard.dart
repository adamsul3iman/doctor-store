import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:doctor_store/features/auth/application/user_data_manager.dart';

/// يحمي صفحات الإدارة:
/// - إذا لم يكن المستخدم مسجلاً: ينقله إلى /login
/// - إذا كان مسجلاً لكن ليس أدمن: يعرض رسالة منع وصول
class AdminGuard extends ConsumerWidget {
  final Widget child;

  const AdminGuard({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;

    if (user == null) {
      // نستخدم post-frame لتجنّب مشاكل navigation أثناء build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) context.go('/login');
      });

      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final profile = ref.watch(userProfileProvider);

    // قد تكون البيانات لم تتزامن بعد (مثلاً أول تسجيل دخول)
    if (profile.id == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (!profile.isAdmin) {
      return Scaffold(
        appBar: AppBar(title: const Text('غير مصرح')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'ليس لديك صلاحية للوصول إلى لوحة الإدارة.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () => context.go('/'),
                  child: const Text('العودة للرئيسية'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return child;
  }
}
