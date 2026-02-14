// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:doctor_store/app/app.dart';

void main() {
  testWidgets('App renders home screen without crashing', (WidgetTester tester) async {
    // Build our app wrapped with ProviderScope (for Riverpod).
    await tester.pumpWidget(const ProviderScope(child: DoctorStoreApp()));

    // Pump a single frame to render the first screen.
    await tester.pump(const Duration(milliseconds: 100));

    // Basic sanity check: fallback hero slogan of the home screen appears
    // when Supabase is not initialized in tests.
    expect(find.text('مرحباً بك في عالم الراحة'), findsOneWidget);
  });
}
