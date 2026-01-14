import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:doctor_store/shared/utils/wishlist_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    // كل اختبار يبدأ بمخزن تفضيلات فارغ
    SharedPreferences.setMockInitialValues({});
  });

  group('WishlistNotifier.toggleWishlist', () {
    test('adds product id when not present, then removes when called again',
        () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(wishlistProvider.notifier);

      expect(container.read(wishlistProvider), isEmpty);

      await notifier.toggleWishlist('p1');
      expect(container.read(wishlistProvider), ['p1']);

      await notifier.toggleWishlist('p1');
      expect(container.read(wishlistProvider), isEmpty);
    });

    test('persists wishlist locally in SharedPreferences', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(wishlistProvider.notifier);

      await notifier.toggleWishlist('p1');
      await notifier.toggleWishlist('p2');
      expect(container.read(wishlistProvider), containsAll(['p1', 'p2']));

      // تحقق مباشرة من أن القيم حُفظت في SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getStringList('user_wishlist') ?? [];
      expect(stored, containsAll(['p1', 'p2']));
    });
  });
}
