import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:doctor_store/features/auth/presentation/screens/login_screen.dart';

// نهيئ الـ binding مرة واحدة (مطلوب من flutter_test)
final TestWidgetsFlutterBinding binding =
    TestWidgetsFlutterBinding.ensureInitialized();

void main() {
  group('LoginScreen validation', () {
    Future<void> configureTestSurface(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      await tester.pump();
    }

    Widget buildApp() {
      return const ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 700, // ارتفاع كافٍ لتجنّب overflow في الاختبارات
              child: LoginScreen(),
            ),
          ),
        ),
      );
    }

    testWidgets('shows error when signup passwords do not match',
        (tester) async {
      await configureTestSurface(tester);
      await tester.pumpWidget(buildApp());

      // انتقل إلى وضع إنشاء حساب عبر الـ toggle
      await tester.tap(find.text('إنشاء حساب'));
      await tester.pumpAndSettle();

      // أدخل بريد إلكتروني صالح
      await tester.enterText(
        find.widgetWithText(TextFormField, 'البريد الإلكتروني'),
        'user@example.com',
      );

      // أدخل كلمتي مرور غير متطابقتين (تتجاوزان حد الطول الدنيا)
      await tester.enterText(
        find.widgetWithText(TextFormField, 'كلمة المرور (على الأقل 6 أحرف)'),
        'password1',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'تأكيد كلمة المرور'),
        'password2',
      );

      // اضغط زر إنشاء الحساب
      await tester.ensureVisible(find.text('إنشاء حساب جديد'));
      await tester.tap(find.text('إنشاء حساب جديد'));
      await tester.pumpAndSettle();

      // يجب إظهار رسالة الخطأ الخاصة بعدم تطابق كلمتي المرور (رسالة حقل التأكيد)
      expect(
        find.text('كلمتا المرور غير متطابقتين'),
        findsOneWidget,
      );
    });

    testWidgets('shows field-level validation error for invalid email',
        (tester) async {
      await configureTestSurface(tester);
      await tester.pumpWidget(buildApp());

      // نبقى في وضع تسجيل الدخول الافتراضي
      await tester.enterText(
        find.widgetWithText(TextFormField, 'البريد الإلكتروني'),
        'not-an-email',
      );

      // أدخل كلمة مرور صحيحة الطول
      await tester.enterText(
        find.widgetWithText(TextFormField, 'كلمة المرور'),
        '123456',
      );

      // اضغط زر تسجيل الدخول
      await tester.ensureVisible(find.text('تسجيل الدخول'));
      await tester.tap(find.text('تسجيل الدخول'));
      await tester.pumpAndSettle();

      // يجب أن يظهر خطأ حقل البريد الإلكتروني
      expect(
        find.text('يرجى إدخال بريد إلكتروني صحيح'),
        findsOneWidget,
      );
    });
  });
}
