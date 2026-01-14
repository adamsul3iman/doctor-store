import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:doctor_store/features/cart/application/cart_manager.dart';
import 'package:doctor_store/features/product/domain/models/product_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    // نبدأ كل اختبار بمخزن تفضيلات فارغ
    SharedPreferences.setMockInitialValues({});
  });

  Product buildProduct(String id, double price) {
    return Product(
      id: id,
      title: 'منتج $id',
      description: '',
      price: price,
      category: 'bedding',
      options: const {},
      gallery: const [],
      variants: const [],
    );
  }

  group('CartNotifier basic operations', () {
    test('addItem merges quantities for same product/color/size', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(cartProvider.notifier);

      final p = buildProduct('p1', 10.0);
      await notifier.addItem(p, quantity: 1, selectedColor: 'أحمر', selectedSize: 'M');
      await notifier.addItem(p, quantity: 2, selectedColor: 'أحمر', selectedSize: 'M');

      final items = container.read(cartProvider);
      expect(items.length, 1);
      expect(items.first.quantity, 3);
      expect(items.first.product.id, 'p1');
    });

    test('decrementQuantity removes item when quantity goes below 1', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(cartProvider.notifier);
      final p = buildProduct('p2', 15.0);

      await notifier.addItem(p, quantity: 1);
      var items = container.read(cartProvider);
      expect(items.length, 1);
      expect(items.first.quantity, 1);

      notifier.decrementQuantity(items.first);
      items = container.read(cartProvider);
      expect(items, isEmpty);
    });

    test('clearCart removes all items', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(cartProvider.notifier);
      await notifier.addItem(buildProduct('p3', 5.0), quantity: 2);
      await notifier.addItem(buildProduct('p4', 7.5), quantity: 1);

      expect(container.read(cartProvider).length, 2);

      notifier.clearCart();
      expect(container.read(cartProvider), isEmpty);
    });
  });

  group('cartTotalProvider with coupons', () {
    test('returns sum of item prices without coupon', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(cartProvider.notifier);
      await notifier.addItem(buildProduct('p1', 10.0), quantity: 1);
      await notifier.addItem(buildProduct('p2', 5.0), quantity: 2);

      final total = container.read(cartTotalProvider);
      expect(total, 20.0); // 10 + 5*2
    });

    test('applies percent coupon correctly', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(cartProvider.notifier);
      await notifier.addItem(buildProduct('p1', 100.0), quantity: 1);

      // كوبون بنسبة 20%
      container.read(couponProvider.notifier).state =
          Coupon(id: 'c1', code: 'DISC20', type: 'percent', value: 20);

      final total = container.read(cartTotalAfterDiscountProvider);
      // 100 - 20% = 80
      expect(total, 80.0);
    });

    test('applies fixed coupon and does not go below zero', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(cartProvider.notifier);
      await notifier.addItem(buildProduct('p1', 30.0), quantity: 1);

      // كوبون خصم ثابت 50
      container.read(couponProvider.notifier).state =
          Coupon(id: 'c2', code: 'FIX50', type: 'fixed', value: 50);

      final total = container.read(cartTotalAfterDiscountProvider);
      // 30 - 50 = -20 → يجب أن تكون النتيجة 0 (لا تقل عن الصفر)
      expect(total, 0.0);
    });
  });
}
