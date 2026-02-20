import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
// import 'package:google_fonts/google_fonts.dart'; // ⚠️ REMOVED for smaller bundle

import 'package:doctor_store/features/orders/presentation/screens/orders_screen.dart';

/// نسخة مبسطة من OrdersScreen لا تعتمد على Supabase، لحقن بيانات ثابتة للاختبار.
class TestOrdersScreen extends StatelessWidget {
  final List<Map<String, dynamic>> orders;

  const TestOrdersScreen({super.key, required this.orders});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        textTheme: ThemeData.light().textTheme,
      ),
      home: Scaffold(
        body: _OrdersList(orders: orders),
      ),
    );
  }
}

class _OrdersList extends StatelessWidget {
  final List<Map<String, dynamic>> orders;

  const _OrdersList({required this.orders});

  @override
  Widget build(BuildContext context) {
    if (orders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.shopping_bag_outlined, size: 80, color: Colors.grey[300]),
            const SizedBox(height: 20),
            Text(
              'لا توجد طلبات سابقة',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: orders.length,
      itemBuilder: (context, index) {
        final order = orders[index];
        final dbStatus = (order['status'] ?? 'new').toString();
        return buildOrderStatusBadge(dbStatus);
      },
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Orders status badge mapping', () {
    testWidgets('maps dbStatus values to correct Arabic labels and colors',
        (tester) async {
      final testOrders = [
        {'id': '1', 'status': 'new'},
        {'id': '2', 'status': 'processing'},
        {'id': '3', 'status': 'completed'},
        {'id': '4', 'status': 'cancelled'},
        {'id': '5', 'status': 'unknown'},
      ];

      await tester.pumpWidget(TestOrdersScreen(orders: testOrders));
      await tester.pump();

      // Helper to get the Container badge for a given Arabic label
      Container findBadgeWithLabel(String label) {
        return tester.widget<Container>(
          find.byWidgetPredicate((widget) {
            if (widget is Container && widget.child is Text) {
              final text = (widget.child as Text).data;
              return text == label;
            }
            return false;
          }),
        );
      }

      // new و unknown → "قيد المراجعة" بلون ذهبي
      final reviewBadges = tester.widgetList<Container>(
        find.byWidgetPredicate((widget) {
          if (widget is Container && widget.child is Text) {
            final text = (widget.child as Text).data;
            return text == 'قيد المراجعة';
          }
          return false;
        }),
      );
      expect(reviewBadges.length, 2);
      for (final badge in reviewBadges) {
        final textWidget = badge.child as Text;
        final style = textWidget.style!;
        expect(style.color, const Color(0xFFD4AF37));

        final decoration = badge.decoration as BoxDecoration?;
        expect(decoration, isNotNull);
        expect(decoration!.color, const Color(0xFFD4AF37).withValues(alpha: 0.1));
        final border = decoration.border as Border?;
        expect(border?.top.color, const Color(0xFFD4AF37).withValues(alpha: 0.5));
      }

      // processing → "قيد التنفيذ" بلون ذهبي
      final processingBadge = findBadgeWithLabel('قيد التنفيذ');
      final processingText = processingBadge.child as Text;
      expect(processingText.style!.color, const Color(0xFFD4AF37));

      // completed → "مكتمل" بلون أخضر
      final completedBadge = findBadgeWithLabel('مكتمل');
      final completedText = completedBadge.child as Text;
      expect(completedText.style!.color, Colors.green);

      // cancelled → "ملغي" بلون أحمر
      final cancelledBadge = findBadgeWithLabel('ملغي');
      final cancelledText = cancelledBadge.child as Text;
      expect(cancelledText.style!.color, Colors.red);
    });
  });

  group('OrdersScreen empty state', () {
    testWidgets('shows empty state when there are no orders', (tester) async {
      await tester.pumpWidget(const TestOrdersScreen(orders: []));
      await tester.pump();

      expect(find.text('لا توجد طلبات سابقة'), findsOneWidget);
      expect(find.byIcon(Icons.shopping_bag_outlined), findsOneWidget);
    });
  });

  group('OrderCard UI', () {
    testWidgets('displays short id, formatted date and total amount', (tester) async {
      final order = {
        'id': '1234567890ABCDEF',
        'created_at': '2024-01-02T15:30:00',
        'status': 'completed',
        'total_amount': 42.5,
      };

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OrderCard(order: order),
          ),
        ),
      );
      await tester.pump();

      // يجب عرض أول 8 خانات فقط من رقم الطلب
      expect(find.text('#12345678'), findsOneWidget);

      // نتأكد من وجود جزء التاريخ على الأقل، بغض النظر عن الساعة الدقيقة حسب المنطقة الزمنية
      final dateTextWidget = tester.widget<Text>(
        find.byWidgetPredicate(
          (w) => w is Text && w.data != null && w.data!.startsWith('2024/01/02'),
        ),
      );
      expect(dateTextWidget.data, startsWith('2024/01/02'));

      // الإجمالي مع العملة
      expect(find.text('42.5 د.أ'), findsOneWidget);

      // شارة الحالة مكتمل
      expect(find.text('مكتمل'), findsOneWidget);
    });

    testWidgets('falls back to epoch date when created_at is invalid', (tester) async {
      final order = {
        'id': '1',
        'created_at': 'not-a-date',
        'status': 'new',
        'total_amount': 10,
      };

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OrderCard(order: order),
          ),
        ),
      );
      await tester.pump();

      // يتم استخدام 1970/01/01 عند فشل التحويل
      final dateTextWidget = tester.widget<Text>(
        find.byWidgetPredicate(
          (w) => w is Text && w.data != null && w.data!.startsWith('1970/01/01'),
        ),
      );
      expect(dateTextWidget.data, startsWith('1970/01/01'));
    });
  });
}
