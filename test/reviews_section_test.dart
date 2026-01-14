import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:doctor_store/features/product/presentation/widgets/reviews_section.dart';

void main() {
  // تأكد من تهيئة GoogleFonts في الاختبارات البسيطة
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ReviewsSection admin reply rendering', () {
    Widget wrapWithMaterial(Widget child) {
      return MaterialApp(
        theme: ThemeData(
          textTheme: GoogleFonts.almaraiTextTheme(),
        ),
        home: Scaffold(body: child),
      );
    }

    testWidgets('shows admin reply block when admin_reply is non-empty',
        (tester) async {
      final reviews = [
        <String, dynamic>{
          'user_name': 'عميل 1',
          'rating': 5,
          'comment': 'منتج ممتاز جداً',
          'created_at': DateTime.now().toIso8601String(),
          'admin_reply': 'شكراً لثقتك بنا، يسعدنا خدمتك دائماً.',
        },
      ];

      await tester.pumpWidget(
        wrapWithMaterial(
          SingleChildScrollView(
            child: ReviewsSection(
              productId: 'p1',
              averageRating: 5,
              ratingCount: reviews.length,
              initialReviews: reviews,
            ),
          ),
        ),
      );

      await tester.pump();

      // نص تعليق العميل موجود
      expect(find.text('منتج ممتاز جداً'), findsOneWidget);

      // بلوك "رد الإدارة" يظهر مع الأيقونة الزرقاء
      expect(find.text('رد الإدارة'), findsOneWidget);
      expect(find.text('شكراً لثقتك بنا، يسعدنا خدمتك دائماً.'), findsOneWidget);
      expect(
        find.byIcon(Icons.verified),
        findsWidgets,
      );
    });

    testWidgets('does not show admin reply block when admin_reply is null or empty',
        (tester) async {
      final reviews = [
        <String, dynamic>{
          'user_name': 'عميل 2',
          'rating': 4,
          'comment': 'جيد بشكل عام',
          'created_at': DateTime.now().toIso8601String(),
          'admin_reply': null,
        },
        <String, dynamic>{
          'user_name': 'عميل 3',
          'rating': 3,
          'comment': 'لا بأس به',
          'created_at': DateTime.now().toIso8601String(),
          'admin_reply': '   ', // فراغات فقط
        },
      ];

      await tester.pumpWidget(
        wrapWithMaterial(
          SingleChildScrollView(
            child: ReviewsSection(
              productId: 'p2',
              averageRating: 3.5,
              ratingCount: reviews.length,
              initialReviews: reviews,
            ),
          ),
        ),
      );

      await tester.pump();

      // تعليقات العملاء تظهر
      expect(find.text('جيد بشكل عام'), findsOneWidget);
      expect(find.text('لا بأس به'), findsOneWidget);

      // لا يوجد أي بلوك "رد الإدارة" لأن admin_reply فارغ/null
      expect(find.text('رد الإدارة'), findsNothing);
      expect(find.byIcon(Icons.verified), findsNothing);
    });
  });

  group('ReviewsSection sorting', () {
    testWidgets('sorts reviews by highest rating when اختيار "الأعلى تقييمًا"',
        (tester) async {
      final reviews = [
        <String, dynamic>{
          'user_name': 'A',
          'rating': 3,
          'comment': '3 stars',
          'created_at': DateTime(2024, 1, 1).toIso8601String(),
        },
        <String, dynamic>{
          'user_name': 'B',
          'rating': 5,
          'comment': '5 stars',
          'created_at': DateTime(2024, 1, 2).toIso8601String(),
        },
        <String, dynamic>{
          'user_name': 'C',
          'rating': 4,
          'comment': '4 stars',
          'created_at': DateTime(2023, 12, 31).toIso8601String(),
        },
      ];

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            textTheme: GoogleFonts.almaraiTextTheme(),
          ),
          home: Scaffold(
            body: SingleChildScrollView(
              child: ReviewsSection(
                productId: 'p3',
                averageRating: 4,
                ratingCount: reviews.length,
                initialReviews: reviews,
              ),
            ),
          ),
        ),
      );

      await tester.pump();

      // نتأكد أولاً أن جميع التعليقات الثلاثة ظاهرة في الوضع الافتراضي
      expect(find.textContaining('5 stars'), findsOneWidget);
      expect(find.textContaining('4 stars'), findsOneWidget);
      expect(find.textContaining('3 stars'), findsOneWidget);

      // اضغط على Chip "الأعلى تقييمًا"
      await tester.tap(find.text('الأعلى تقييمًا'));
      await tester.pump();

      // بعد الترتيب حسب الأعلى، ما زالت كل التعليقات موجودة (الاختبار هنا يضمن أن
      // التبديل لا يخفي أي مراجعة، وأن منطق sort لا يكسر الشجرة)
      expect(find.textContaining('5 stars'), findsOneWidget);
      expect(find.textContaining('4 stars'), findsOneWidget);
      expect(find.textContaining('3 stars'), findsOneWidget);
    });
  });
}
