import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:doctor_store/features/home/presentation/widgets/dining_section.dart';
import 'package:doctor_store/features/product/domain/models/product_model.dart';

void main() {
  group('DiningSection classification', () {
    Product buildProduct({
      required String id,
      required String title,
      required String description,
      required String category,
      List<String> tags = const [],
    }) {
      return Product(
        id: id,
        title: title,
        description: description,
        price: 100,
        category: category,
        options: const {},
        gallery: const [],
        variants: const [],
        tags: tags,
      );
    }

    testWidgets('splits products into wood and porcelain tables correctly',
        (tester) async {
      final woodDining = buildProduct(
        id: 'wood1',
        title: 'طاولة سفرة خشب راقية',
        description: 'طاولة سفرة من الخشب الصلب',
        category: 'dining_table',
      );

      final porcelainDining = buildProduct(
        id: 'porc1',
        title: 'طاولة سفرة بورسلان دائرية',
        description: 'تصميم حديث من البورسلان',
        category: 'dining_table',
      );

      final furnitureDining = buildProduct(
        id: 'wood2',
        title: 'طاولة طعام عائلية',
        description: 'طاولة طعام خشبية مميزة',
        category: 'furniture',
      );

      final nonDining = buildProduct(
        id: 'other',
        title: 'مفرش سرير فاخر',
        description: 'ليس طاولة سفرة',
        category: 'bedding',
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: DiningSection(
                products: [
                  woodDining,
                  porcelainDining,
                  furnitureDining,
                  nonDining,
                ],
              ),
            ),
          ),
        ),
      );

      // إطار إضافي للسماح بإكمال أي AnimatedSwitcher أو build ثانوي
      await tester.pump();

      // نتوقع أن يكون لدينا:
      // - 2 خشب (dining_table خشب + furniture طاولة طعام)
      // - 1 بورسلان
      final woodFinder = find.textContaining('خشب كلاسيك');
      final porcelainFinder = find.textContaining('بورسلان مودرن');

      expect(woodFinder, findsOneWidget);
      expect(porcelainFinder, findsOneWidget);

      final woodText = tester.widget<Text>(woodFinder);
      final porcelainText = tester.widget<Text>(porcelainFinder);

      expect(woodText.data, contains('(3)'));
      expect(porcelainText.data, contains('(1)'));
    });

    testWidgets('classification can rely on tags and description keywords',
        (tester) async {
      final taggedPorcelain = buildProduct(
        id: 'porc2',
        title: 'طاولة أنيقة',
        description: 'مناسبة لغرفة الطعام',
        category: 'home_decor',
        tags: const ['طاولة سفرة بورسلان'],
      );

      final plainTable = buildProduct(
        id: 'wood3',
        title: 'طاولة سفرة كلاسيكية',
        description: 'سفرة خشبية',
        category: 'furniture',
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: DiningSection(
                products: [taggedPorcelain, plainTable],
              ),
            ),
          ),
        ),
      );


      // المنتج الأول يجب أن يُعامل كطاولة بورسلان استناداً إلى الوسوم والنصوص
      // الثاني كخشب.
      expect(find.text('خشب كلاسيك (1)'), findsOneWidget);
      expect(find.text('بورسلان مودرن (1)'), findsOneWidget);
    });
  });
}
