import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:doctor_store/shared/utils/supabase_auth_listener.dart';
import 'package:doctor_store/features/auth/application/user_data_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('SupabaseAuthListener builds child even when Supabase is not initialized',
      (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: SupabaseAuthListener(
          child: MaterialApp(
            home: Scaffold(
              body: Text('Home inside listener'),
            ),
          ),
        ),
      ),
    );

    await tester.pump();

    expect(find.text('Home inside listener'), findsOneWidget);
  });

  group('handleSupabaseSignedIn navigation', () {
    testWidgets('navigates non-admin user from /login to /', (tester) async {
      late WidgetRef capturedRef;

      final router = GoRouter(
        initialLocation: '/login',
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const Scaffold(body: Text('Home Page')), 
          ),
          GoRoute(
            path: '/login',
            builder: (context, state) => Consumer(
              builder: (context, ref, _) {
                capturedRef = ref;
                return const Scaffold(body: Text('Login Page'));
              },
            ),
          ),
          GoRoute(
            path: '/admin/dashboard',
            builder: (context, state) => const Scaffold(body: Text('Admin Dashboard')), 
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp.router(
            routerConfig: router,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // تأكد أننا على صفحة تسجيل الدخول وأن لدينا ref صالحاً
      expect(find.text('Login Page'), findsOneWidget);

      // اجعل المستخدم غير أدمن
      final notifier = capturedRef.read(userProfileProvider.notifier);
      notifier.state = notifier.state.copyWith(role: 'customer');

      await handleSupabaseSignedIn(
        ref: capturedRef,
        router: router,
        currentLocation: '/login',
      );

      await tester.pumpAndSettle();

      // يجب تحويله إلى الصفحة الرئيسية
      expect(find.text('Home Page'), findsOneWidget);
    });

    testWidgets('navigates admin user from /login to /admin/dashboard', (tester) async {
      // إعداد قيم SharedPreferences الوهمية بحيث يكون دور المستخدم أدمن منذ البداية
      SharedPreferences.setMockInitialValues({'user_role': 'admin'});

      late WidgetRef capturedRef;

      final router = GoRouter(
        initialLocation: '/login',
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const Scaffold(body: Text('Home Page')), 
          ),
          GoRoute(
            path: '/login',
            builder: (context, state) => Consumer(
              builder: (context, ref, _) {
                capturedRef = ref;
                return const Scaffold(body: Text('Login Page'));
              },
            ),
          ),
          GoRoute(
            path: '/admin/dashboard',
            builder: (context, state) => const Scaffold(body: Text('Admin Dashboard')), 
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp.router(
            routerConfig: router,
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Login Page'), findsOneWidget);

      await handleSupabaseSignedIn(
        ref: capturedRef,
        router: router,
        currentLocation: '/login',
      );

      await tester.pumpAndSettle();

      // يجب تحويله إلى لوحة التحكم للأدمن (التحقق من مسار GoRouter الفعلي)
      final currentLocation =
          router.routerDelegate.currentConfiguration.uri.toString();
      expect(currentLocation, '/admin/dashboard');
    });

    testWidgets('does not navigate when currentLocation is not /login', (tester) async {
      late WidgetRef capturedRef;

      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => Consumer(
              builder: (context, ref, _) {
                capturedRef = ref;
                return const Scaffold(body: Text('Home Page'));
              },
            ),
          ),
          GoRoute(
            path: '/login',
            builder: (context, state) => const Scaffold(body: Text('Login Page')), 
          ),
          GoRoute(
            path: '/admin/dashboard',
            builder: (context, state) => const Scaffold(body: Text('Admin Dashboard')), 
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp.router(
            routerConfig: router,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // حالياً على الصفحة الرئيسية
      expect(find.text('Home Page'), findsOneWidget);

      final notifier = capturedRef.read(userProfileProvider.notifier);
      notifier.state = notifier.state.copyWith(role: 'admin');

      await handleSupabaseSignedIn(
        ref: capturedRef,
        router: router,
        currentLocation: '/',
      );

      await tester.pumpAndSettle();

      // يجب أن يبقى على الصفحة الرئيسية (لا تنقل لأن الموقع الحالي ليس /login)
      expect(find.text('Home Page'), findsOneWidget);
    });
  });
}
