import 'package:flutter_test/flutter_test.dart';

import 'package:doctor_store/features/product/domain/models/product_model.dart';

void main() {
  group('Product.fromJson', () {
    test('parses full valid JSON correctly', () {
      final json = <String, dynamic>{
        'id': '123',
        'title': 'مفرش فاخر',
        'description': 'وصف المنتج',
        'price': 99.5,
        'old_price': 120,
        'image_url': 'https://example.supabase.co/storage/v1/object/public/products/main.jpg',
        'category': 'bedding',
        'sub_category_id': 'sub-1',
        'options': {
          'product_type': 'bundle',
          'pricing_unit': 'حبة',
          'unit_min': 1,
          'unit_step': 1,
          'is_offer': true,
          'price_tiers': [
            {'qty': 2, 'price': 150},
            {'qty': 4, 'price': 260},
          ],
        },
        'gallery': [
          {
            'url': 'https://example.supabase.co/storage/v1/object/public/products/g1.jpg',
            'color_name': 'أبيض',
            'color_value': 0xFFFFFFFF,
          },
        ],
        'variants': [
          {
            'id': 'v1',
            'sku': 'SKU-1',
            'color': 'أبيض',
            'size': '200x200',
            'unit': 'حبة',
            'price': 99.5,
            'stock': 10,
          },
        ],
        'rating_average': 4.5,
        'rating_count': 12,
        'is_featured': true,
        'is_active': true,
        'slug': 'premium-bedding',
        'short_description': 'وصف قصير',
        'tags': ['مفرش', 'بيدنج'],
        'is_flash_deal': true,
      };

      final product = Product.fromJson(json);

      expect(product.id, '123');
      expect(product.title, 'مفرش فاخر');
      expect(product.description, 'وصف المنتج');
      expect(product.price, 99.5);
      expect(product.oldPrice, 120);
      expect(product.originalImageUrl, isNotEmpty);
      expect(product.category, 'bedding');
      expect(product.subCategoryId, 'sub-1');

      expect(product.options['product_type'], 'bundle');
      expect(product.options['pricing_unit'], 'حبة');
      expect(product.unitMin, 1.0);
      expect(product.unitStep, 1.0);

      expect(product.gallery.length, 1);
      expect(product.gallery.first.url, contains('g1.jpg'));

      expect(product.variants.length, 1);
      final v = product.variants.first;
      expect(v.id, isNotEmpty);
      expect(v.sku, 'SKU-1');
      expect(v.price, 99.5);
      expect(v.stock, 10);

      expect(product.ratingAverage, 4.5);
      expect(product.ratingCount, 12);
      expect(product.isFeatured, isTrue);
      expect(product.isActive, isTrue);
      expect(product.slug, 'premium-bedding');
      expect(product.shortDescription, 'وصف قصير');
      expect(product.tags, contains('مفرش'));
      expect(product.isFlashDeal, isTrue);
    });

    test('handles missing/invalid gallery and variants defensively', () {
      final json = <String, dynamic>{
        'id': 456, // رقم سيُحوَّل إلى نص
        'title': 'منتج بدون معرض',
        'description': null,
        'price': 50,
        'image_url': null,
        'category': 'furniture',
        // gallery فيها عناصر غير صالحة
        'gallery': [
          123,
          'invalid',
        ],
        // variants فيها عنصر غير Map
        'variants': [
          42,
          {'size': 'XL', 'price': 60},
        ],
        'options': 'not a map',
      };

      final product = Product.fromJson(json);

      expect(product.id, '456');
      expect(product.description, ''); // null تتحول إلى نص فارغ في fromJson
      expect(product.gallery, isEmpty);
      expect(product.variants.length, 1);
      expect(product.options, isA<Map<String, dynamic>>());
    });

    test('offer helpers work when is_offer and price_tiers are set', () {
      final json = <String, dynamic>{
        'id': '789',
        'title': 'عرض مخدات',
        'description': '',
        'price': 20,
        'image_url': '',
        'category': 'pillows',
        'options': {
          'is_offer': true,
          'price_tiers': [
            {'qty': 2, 'price': 35},
            {'qty': 4, 'price': 60},
          ],
        },
      };

      final product = Product.fromJson(json);

      expect(product.hasOffers, isTrue);
      expect(product.offerTiers.length, 2);
      expect(product.offerTiers.first.quantity, 2);
      expect(product.offerTiers.first.price, 35);
    });
  });

  group('Product helpers', () {
    test('pricingUnitLabel, unitMin, and unitStep fallback correctly', () {
      final product = Product(
        id: '1',
        title: 'منتج بدون إعدادات وحدة واضحة',
        description: '',
        price: 10,
        category: 'bedding',
        options: const {},
        gallery: const [],
        variants: const [],
      );

      // لا يوجد pricing_unit في options → حبة افتراضياً
      expect(product.pricingUnitLabel, 'حبة');
      // لا يوجد unit_min / unit_step → 1.0 افتراضياً
      expect(product.unitMin, 1.0);
      expect(product.unitStep, 1.0);
    });

    test('pricingUnitLabel and unit helpers respect valid options', () {
      final product = Product(
        id: '2',
        title: 'قماش بالمتر',
        description: '',
        price: 25,
        category: 'home_decor',
        options: const {
          'pricing_unit': 'متر',
          'unit_min': 2,
          'unit_step': 0.5,
        },
        gallery: const [],
        variants: const [],
      );

      expect(product.pricingUnitLabel, 'متر');
      expect(product.unitMin, 2.0);
      expect(product.unitStep, 0.5);
    });

    test('productType uses options["product_type"] when present and non-empty', () {
      final product = Product(
        id: '3',
        title: 'باقة عروض',
        description: '',
        price: 100,
        category: 'pillows',
        options: const {
          'product_type': 'bundle',
        },
        gallery: const [],
        variants: const [],
      );

      expect(product.productType, 'bundle');
    });

    test('productType falls back to bundle when hasOffers is true', () {
      final product = Product(
        id: '4',
        title: 'عرض خاص',
        description: '',
        price: 50,
        category: 'pillows',
        options: const {
          'is_offer': true,
          'price_tiers': [
            {'qty': 2, 'price': 80},
          ],
        },
        gallery: const [],
        variants: const [],
      );

      expect(product.hasOffers, isTrue);
      expect(product.productType, 'bundle');
    });

    test('productType defaults to standard otherwise', () {
      final product = Product(
        id: '5',
        title: 'منتج عادي',
        description: '',
        price: 30,
        category: 'bedding',
        options: const {},
        gallery: const [],
        variants: const [],
      );

      expect(product.hasOffers, isFalse);
      expect(product.productType, 'standard');
    });

    test('findMatchingVariant returns correct variant by color and size', () {
      final variants = [
        ProductVariant(
          id: 'v1',
          color: 'أبيض',
          size: '200x200',
          unit: 'حبة',
          price: 100,
        ),
        ProductVariant(
          id: 'v2',
          color: 'رمادي',
          size: '180x200',
          unit: 'حبة',
          price: 90,
        ),
      ];

      final product = Product(
        id: '6',
        title: 'مفرش ألوان متعددة',
        description: '',
        price: 80,
        category: 'bedding',
        options: const {},
        gallery: const [],
        variants: variants,
      );

      final match1 = product.findMatchingVariant(
        color: 'أبيض',
        size: '200x200',
        unit: 'حبة',
      );
      expect(match1, isNotNull);
      expect(match1!.id, 'v1');

      final match2 = product.findMatchingVariant(
        color: 'رمادي',
        size: '180x200',
        unit: null,
      );
      expect(match2, isNotNull);
      expect(match2!.id, 'v2');
    });

    test('findMatchingVariant falls back gracefully when nothing matches', () {
      final variants = [
        ProductVariant(
          id: 'v1',
          color: 'أبيض',
          size: '200x200',
          unit: 'حبة',
          price: 100,
        ),
      ];

      final product = Product(
        id: '7',
        title: 'مفرش بلون واحد',
        description: '',
        price: 80,
        category: 'bedding',
        options: const {},
        gallery: const [],
        variants: variants,
      );

      // طلب متغير غير موجود → يرجع أول متغير في القائمة حفاظاً على التوافق للخلف.
      final match = product.findMatchingVariant(
        color: 'أزرق',
        size: '210x210',
        unit: 'حبة',
      );

      expect(match, isNotNull);
      expect(match!.id, 'v1');
    });

    test('findMatchingVariant returns null when there are no variants', () {
      final product = Product(
        id: '8',
        title: 'منتج بدون متغيرات',
        description: '',
        price: 50,
        category: 'bedding',
        options: const {},
        gallery: const [],
        variants: const [],
      );

      final match = product.findMatchingVariant(
        color: 'أبيض',
        size: '200x200',
        unit: 'حبة',
      );

      expect(match, isNull);
    });
  });
}
