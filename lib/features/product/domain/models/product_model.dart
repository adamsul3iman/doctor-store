import 'package:flutter/foundation.dart';

class Product {
  final String id;
  final String title;
  final String description;
  /// السعر الأساسي للمنتج (يُستخدم كباك أب في حال عدم وجود متغير محدد)
  final double price;
  final double? oldPrice;

  /// رابط الصورة الخام كما هو مخزَّن في قاعدة البيانات (image_url).
  /// يتم إخفاؤه خلف getter [imageUrl] الذي يضيف معاملات التحسين عند الحاجة.
  final String? _originalImageUrl;
 
  /// كود القسم الرئيسي للمنتج.
  ///
  /// مهم جداً:
  /// - هذا الحقل مرتبط مباشرةً بالـ enum `public.product_category` في قاعدة البيانات.
  /// - القيم المسموح بها حالياً في السكيمة هي:
  ///   bedding, mattresses, pillows, furniture, dining_table,
  ///   carpets, baby_supplies, home_decor, towels
  /// - أي قيمة جديدة (مثل curtains) يجب إضافتها أولاً للـ enum في Postgres عبر Migration
  ///   قبل استخدامها في التطبيق أو في لوحة التحكم.
  final String category;
  /// معرّف الفئة الفرعية الديناميكية (اختياري)
  final String? subCategoryId;
  /// حقل مرن لتخزين إعدادات إضافية مثل: الألوان، المقاسات، نوع التسعير، الخ.
  final Map<String, dynamic> options;
  final List<ProductImage> gallery;
  /// قائمة المتغيرات المتقدمة (لون + مقاس + وحدة + سعر + مخزون + SKU)
  final List<ProductVariant> variants;
  final double ratingAverage; 
  final int ratingCount;
  final bool isFeatured;
  
  /// هل المنتج مفعّل/ظاهر في المتجر أم مخفي (soft delete)
  final bool isActive;
  
  final String? slug;
  
  // وصف قصير مخصص للسيو والمشاركة
  final String? shortDescription;

  // قائمة وسوم المنتج (Tags) لاستخدامها في البحث والسيو
  final List<String> tags;
  
  // ✅ الحقل الجديد لعروض الفلاش
  final bool isFlashDeal; 

  Product({
    required this.id,
    required this.title,
    required this.description,
    required this.price,
    this.oldPrice,
    String? imageUrl,
    required this.category,
    this.subCategoryId,
    required this.options,
    required this.gallery,
    required this.variants,
    this.ratingAverage = 0.0, 
    this.ratingCount = 0,
    this.isFeatured = false,
    this.isActive = true,
    this.slug,
    this.shortDescription,
    this.tags = const [],
    this.isFlashDeal = false, // ✅ قيمة افتراضية
  }) : _originalImageUrl = imageUrl;

  /// Getter افتراضي متوسط الجودة/الحجم، مناسب لمعظم الاستخدامات العامة.
  /// يستخدم WebP بجودة 80 بدون تحديد عرض ثابت.
  String get imageUrl => _buildOptimizedUrl(quality: 80);

  /// رابط صورة مصغّرة (Thumbnail) لقوائم المنتجات، الـ home، الـ wishlist، إلخ.
  ///
  /// - عرض ثابت 300 بكسل تقريباً.
  /// - جودة 70 لتقليل الحجم قدر الإمكان.
  String get thumbnailUrl => _buildOptimizedUrl(width: 300, quality: 70);

  /// رابط صورة أكبر لصفحة تفاصيل المنتج، مناسب لشاشات الويب/الموبايل.
  ///
  /// - عرض مستهدف 1000 بكسل.
  /// - جودة 80 لموازنة الوضوح مع الحجم.
  String get detailImageUrl => _buildOptimizedUrl(width: 1000, quality: 80);

  /// رابط الصورة الخام كما هو مخزَّن في قاعدة البيانات بدون أي معاملات.
  /// مفيد عندما نريد ترك مهمة التحسين لـ [image_url_helper] فقط.
  String get originalImageUrl => _originalImageUrl ?? '';

  /// مُساعد داخلي لبناء رابط صورة محسَّن من Supabase.
  ///
  /// - لو `_originalImageUrl` فارغ → يرجع سلسلة فارغة (توافقاً مع الكود القديم).
  /// - لو الرابط لا يحتوي `supabase.co` → يرجع كما هو بدون تغيير.
  /// - لو الرابط من Supabase → يضيف معاملات WebP + quality + resize،
  ///   بالإضافة إلى `width` إن تم تمريرها.
  String _buildOptimizedUrl({int? width, int quality = 80}) {
    final url = _originalImageUrl;
    if (url == null || url.isEmpty) return '';

    // في حال كان الرابط خارجي أو من مصدر آخر، نرجعه كما هو بدون تغيير.
    if (!url.contains('supabase.co')) {
      return url;
    }

    final params = <String>[
      if (width != null) 'width=$width',
      'format=webp',
      'quality=$quality',
      'resize=contain',
    ];

    // لو كان هناك بارامترات مسبقاً نستخدم &، وإلا نستخدم ?
    final separator = url.contains('?') ? '&' : '?';
    return '$url$separator${params.join('&')}';
  }

  String get categoryArabic {
    // هذه الترجمة تعتمد على قيم enum product_category في قاعدة البيانات.
    // ملاحظة: قيمة 'curtains' غير موجودة حالياً في enum، فإذا أردت استخدامها
    // يجب أولاً تعديل enum في Postgres ثم إضافتها لقائمة الأقسام في لوحة التحكم.
    switch (category) {
      case 'bedding':
        return 'مفارش';
      case 'mattresses':
        return 'فرشات';
      case 'pillows':
        return 'وسائد';
      case 'furniture':
        return 'أثاث';
      case 'dining_table':
        return 'سفرة';
      case 'carpets':
        return 'سجاد';
      case 'baby_supplies':
        return 'أطفال';
      case 'home_decor':
        return 'ديكور';
      case 'towels':
        return 'مناشف';
      case 'curtains':
        return 'برادي';
      default:
        // fallback عام في حال كانت القيمة غير معروفة (مثلاً بيانات قديمة أو سكيمة مُعدَّلة).
        return 'عام';
    }
  }

  // ✅ هل هذا المنتج عبارة عن عرض خاص (بكج)؟
  bool get hasOffers {
    final rawIsOffer = options['is_offer'];
    final rawTiers = options['price_tiers'];
    final hasValidTiers = rawTiers is List && rawTiers.isNotEmpty;
    return rawIsOffer == true && hasValidTiers;
  }

  // ✅ استخراج جدول الأسعار (الكمية -> السعر) بشكل دفاعي ضد JSON التالف
  List<OfferTier> get offerTiers {
    if (!hasOffers) return [];

    final raw = options['price_tiers'];
    if (raw is! List) {
      return [];
    }

    final List<OfferTier> tiers = [];
    for (final item in raw) {
      if (item is Map<String, dynamic>) {
        try {
          tiers.add(OfferTier.fromJson(item));
        } catch (e) {
          // نتجاهل العناصر التالفة ولا نكسر الواجهة لكن نطبع الخطأ للتتبّع
          debugPrint('Handled Error (OfferTier.fromJson map<String,dynamic>): $e');
        }
      } else if (item is Map) {
        try {
          tiers.add(OfferTier.fromJson(Map<String, dynamic>.from(item)));
        } catch (e) {
          debugPrint('Handled Error (OfferTier.fromJson Map): $e');
        }
      }
    }
    return tiers;
  }

  /// نوع المنتج (قياسي، عرض، متغير بالمتغيرات، لكل متر/وحدة)
  /// يتم تخزينه في options['product_type'] للحفاظ على المرونة.
  String get productType {
    final type = options['product_type'];
    if (type is String && type.isNotEmpty) return type;
    // الحفاظ على التوافق للخلف: إذا كان هناك عروض نعتبره bundle افتراضياً.
    if (hasOffers) return 'bundle';
    return 'standard';
  }

  /// تسمية الوحدة (تظهر في صفحة المنتج والفاتورة)، مثل: "حبة"، "متر"، "علبة".
  String get pricingUnitLabel {
    final unit = options['pricing_unit'];
    if (unit is String && unit.isNotEmpty) return unit;
    return 'حبة';
  }

  /// أقل كمية يمكن شراؤها في المنتجات المعتمدة على الوحدة/المتر.
  double get unitMin {
    final raw = options['unit_min'];
    if (raw is num) return raw.toDouble();
    return 1.0;
  }

  /// مقدار الزيادة في الكمية (مثلاً 0.5 متر).
  double get unitStep {
    final raw = options['unit_step'];
    if (raw is num) return raw.toDouble();
    return 1.0;
  }

  /// هل المنتج يحتوي خيارات ألوان (ضمن options['colors']).
  bool get hasColorOptions {
    final colors = options['colors'];
    return colors is List && colors.isNotEmpty;
  }

  /// هل المنتج يحتوي خيارات مقاسات، بما فيها وضع الفرشات (mattress auto pricing).
  bool get hasSizeOptions {
    final sizes = options['sizes'];
    final hasStandard = sizes is List && sizes.isNotEmpty;
    return hasStandard || isMattressAuto;
  }

  /// ✅ هل هذا المنتج فرشة بنظام تسعير تلقائي حسب المقاس؟
  ///
  /// نعتبره Mattress Auto إذا:
  /// - القسم 'mattresses'
  /// - ويوجد options['mattress'] أو product_type == 'mattress'
  bool get isMattressAuto {
    if (category != 'mattresses') return false;
    final type = options['product_type'];
    if (type is String && type == 'mattress') return true;
    final raw = options['mattress'];
    return raw is Map;
  }

  Map<String, dynamic>? get mattressConfig {
    final raw = options['mattress'];
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return null;
  }

  int? get mattressWidthMinCm {
    final v = mattressConfig?['width_min'];
    return v is num ? v.toInt() : null;
  }

  int? get mattressWidthMaxCm {
    final v = mattressConfig?['width_max'];
    return v is num ? v.toInt() : null;
  }

  int? get mattressWidthStepCm {
    final v = mattressConfig?['width_step'];
    return v is num ? v.toInt() : null;
  }

  List<int> get mattressLengthsCm {
    final raw = mattressConfig?['lengths'];
    if (raw is! List) return const [];

    final values = <int>{};
    for (final e in raw) {
      final n = e is num ? e.toInt() : int.tryParse(e.toString());
      if (n != null && n > 0) values.add(n);
    }
    final list = values.toList()..sort();
    return list;
  }

  /// يولّد قائمة العروض المتاحة (بالسنتيمتر).
  ///
  /// الأولوية:
  /// 1) mattress.widths = قائمة مخصصة
  /// 2) width_min/width_max/width_step = توليد ضمن مدى
  List<int> get mattressWidthsCm {
    final rawCustom = mattressConfig?['widths'];
    if (rawCustom is List) {
      final values = <int>{};
      for (final e in rawCustom) {
        final n = e is num ? e.toInt() : int.tryParse(e.toString());
        if (n != null && n > 0) values.add(n);
      }
      final list = values.toList()..sort();
      if (list.isNotEmpty) return list;
    }

    final min = mattressWidthMinCm;
    final max = mattressWidthMaxCm;
    final step = mattressWidthStepCm;

    if (min == null || max == null || step == null) return const [];
    if (min <= 0 || max < min || step <= 0) return const [];

    // حماية من أي بيانات خاطئة قد تنتج عدد كبير جداً.
    final expectedCount = ((max - min) ~/ step) + 1;
    if (expectedCount <= 0 || expectedCount > 500) return const [];

    final list = <int>[];
    for (int w = min; w <= max; w += step) {
      list.add(w);
    }
    return list;
  }

  /// وضع تسعير الفرشات:
  /// - per_sqm: حسب المساحة
  /// - by_width: يدوي حسب العرض فقط
  String get mattressPricingMode {
    final pricing = mattressConfig?['pricing'];
    if (pricing is Map) {
      final p = Map<String, dynamic>.from(pricing);
      final mode = p['mode'];
      if (mode is String && mode.isNotEmpty) return mode;
    }
    return 'per_sqm';
  }

  Map<int, double> get mattressWidthPrices {
    final pricing = mattressConfig?['pricing'];
    if (pricing is Map) {
      final p = Map<String, dynamic>.from(pricing);
      final raw = p['width_prices'];
      if (raw is Map) {
        final map = <int, double>{};
        for (final e in Map<String, dynamic>.from(raw).entries) {
          final w = int.tryParse(e.key);
          final price = e.value is num
              ? (e.value as num).toDouble()
              : double.tryParse(e.value.toString());
          if (w != null && price != null) {
            map[w] = price;
          }
        }
        return map;
      }
    }
    return const {};
  }

  double get mattressBaseFee {
    final pricing = mattressConfig?['pricing'];
    if (pricing is Map) {
      final p = Map<String, dynamic>.from(pricing);
      final v = p['base_fee'];
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString()) ?? 0;
    }
    return 0;
  }

  double get mattressPricePerSqm {
    final pricing = mattressConfig?['pricing'];
    if (pricing is Map) {
      final p = Map<String, dynamic>.from(pricing);
      final v = p['price_per_sqm'];
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString()) ?? 0;
    }
    return 0;
  }

  /// يحسب سعر الفرشة حسب وضع التسعير.
  /// - per_sqm: base_fee + (area_m2 * price_per_sqm)
  /// - by_width: سعر حسب العرض فقط (تجاهل الطول)
  double? computeMattressUnitPrice({required int widthCm, int? lengthCm}) {
    if (!isMattressAuto) return null;
    if (widthCm <= 0) return null;

    if (mattressPricingMode == 'by_width') {
      final map = mattressWidthPrices;
      final p = map[widthCm];
      return p;
    }

    final l = lengthCm;
    if (l == null || l <= 0) return null;

    final area = (widthCm / 100.0) * (l / 100.0);
    final price = mattressBaseFee + (area * mattressPricePerSqm);
    return price;
  }

  /// أقل سعر ممكن (Unit Price) للفرشات:
  /// - نحسبه من معادلة التسعير إن توفرت بيانات المقاسات
  /// - ونقارن مع أقل سعر متغيرات (إن وجدت)
  double? get mattressMinUnitPrice {
    if (!isMattressAuto) return null;

    double? minPrice;

    // 1) من التسعير اليدوي حسب العرض
    if (mattressPricingMode == 'by_width') {
      final map = mattressWidthPrices;
      if (map.isNotEmpty) {
        minPrice = map.values.reduce((a, b) => a < b ? a : b);
      }
    } else {
      // 2) من المعادلة (per_sqm)
      final widths = mattressWidthsCm;
      final lengths = mattressLengthsCm;
      if (widths.isNotEmpty && lengths.isNotEmpty) {
        for (final w in widths) {
          for (final l in lengths) {
            final p = computeMattressUnitPrice(widthCm: w, lengthCm: l);
            if (p == null) continue;
            if (minPrice == null || p < minPrice) minPrice = p;
          }
        }
      }
    }

    // 3) من المتغيرات (قد تحتوي استثناءات أسعار)
    if (variants.isNotEmpty) {
      for (final v in variants) {
        if (v.price <= 0) continue;
        if (minPrice == null || v.price < minPrice) minPrice = v.price;
      }
    }

    return minPrice;
  }

  /// إيجاد المتغير المطابق لاختيارات العميل (لون + مقاس + وحدة).
  ProductVariant? findMatchingVariant({
    String? color,
    String? size,
    String? unit,
  }) {
    if (variants.isEmpty) return null;

    return variants.firstWhere(
      (v) {
        final sameColor = color == null || (v.color ?? '') == color;
        final sameSize = size == null || (v.size ?? '') == size;
        final sameUnit = unit == null || (v.unit ?? '') == unit;
        return sameColor && sameSize && sameUnit;
      },
      orElse: () => variants.first,
    );
  }

  factory Product.fromJson(Map<String, dynamic> json) {
    // المعرض (gallery) - نتعامل معه بشكل دفاعي ضد أي JSON غير متوقع
    var galleryList = <ProductImage>[];
    final rawGallery = json['gallery'];
    if (rawGallery is List) {
      for (final item in rawGallery) {
        if (item is Map<String, dynamic>) {
          try {
            galleryList.add(ProductImage.fromJson(item));
          } catch (e) {
            debugPrint('Handled Error (ProductImage.fromJson map<String,dynamic>): $e');
          }
        } else if (item is Map) {
          try {
            galleryList.add(ProductImage.fromJson(Map<String, dynamic>.from(item)));
          } catch (e) {
            debugPrint('Handled Error (ProductImage.fromJson Map): $e');
          }
        }
      }
    }

    // المتغيرات (variants) - نفس الأسلوب الدفاعي
    var variantsList = <ProductVariant>[];
    final rawVariants = json['variants'];
    if (rawVariants is List) {
      for (final item in rawVariants) {
        if (item is Map<String, dynamic>) {
          try {
            variantsList.add(ProductVariant.fromJson(item));
          } catch (e) {
            debugPrint('Handled Error (ProductVariant.fromJson map<String,dynamic>): $e');
          }
        } else if (item is Map) {
          try {
            variantsList.add(ProductVariant.fromJson(Map<String, dynamic>.from(item)));
          } catch (e) {
            debugPrint('Handled Error (ProductVariant.fromJson Map): $e');
          }
        }
      }
    }

    // الوسوم (tags)
    final rawTags = json['tags'];
    final parsedTags = rawTags is List
        ? rawTags.map((e) => e.toString()).toList()
        : <String>[];

    // خيارات المنتج (options) - ضمان أن تكون Map<String, dynamic>
    final rawOptions = json['options'];
    Map<String, dynamic> safeOptions;
    if (rawOptions is Map<String, dynamic>) {
      safeOptions = rawOptions;
    } else if (rawOptions is Map) {
      safeOptions = Map<String, dynamic>.from(rawOptions);
    } else {
      safeOptions = <String, dynamic>{};
    }
    
    // ✅ إضافة shipping_size من الحقل المباشر إلم options لسهولة الوصول
    if (json['shipping_size'] != null) {
      safeOptions['shipping_size'] = json['shipping_size'];
    }

    return Product(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      oldPrice: (json['old_price'] as num?)?.toDouble(),
      imageUrl: (json['image_url'] as String?) ?? '',
      category: json['category']?.toString() ?? 'general',
      subCategoryId: json['sub_category_id']?.toString(),
      options: safeOptions,
      gallery: galleryList,
      variants: variantsList,
      ratingAverage: (json['rating_average'] as num?)?.toDouble() ?? 0.0,
      ratingCount: (json['rating_count'] as num?)?.toInt() ?? 0,
      isFeatured: (json['is_featured'] as bool?) ?? false,
      isActive: (json['is_active'] as bool?) ?? true,
      slug: json['slug']?.toString(),
      shortDescription: json['short_description']?.toString(),
      tags: parsedTags,
      // ✅ قراءة حالة الفلاش ديل من قاعدة البيانات بشكل آمن
      isFlashDeal: (json['is_flash_deal'] as bool?) ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'price': price,
      'old_price': oldPrice,
      // نرسل دائماً الرابط الخام كما هو مخزَّن في قاعدة البيانات بدون معاملات التحسين.
      'image_url': _originalImageUrl,
      'category': category,
      'sub_category_id': subCategoryId,
      'options': options,
      'rating_average': ratingAverage,
      'rating_count': ratingCount,
      'is_featured': isFeatured,
      'is_active': isActive,
      'variants': variants.map((v) => v.toJson()).toList(),
      'slug': slug,
      'short_description': shortDescription,
      'tags': tags,
      // ✅ إرسال حالة الفلاش ديل لقاعدة البيانات
      'is_flash_deal': isFlashDeal,
    };
  }
}

class ProductImage {
  final String url;
  final String colorName;
  final int colorValue;

  ProductImage({required this.url, required this.colorName, this.colorValue = 0xFFFFFFFF});

  factory ProductImage.fromJson(Map<String, dynamic> json) {
    final dynamic rawColor = json['color_value'];
    final int resolvedColor =
        rawColor is num ? rawColor.toInt() : 0xFFFFFFFF;

    return ProductImage(
      url: (json['url'] as String?) ?? '', 
      colorName: (json['color_name'] as String?) ?? '',
      colorValue: resolvedColor,
    );
  }
}

class ProductVariant {
  /// معرف داخلي للمتغير (يمكن استخدامه في الفوترة أو التكاملات الأخرى)
  final String id;
  /// كود SKU فريد (اختياري)
  final String? sku;
  /// لون المتغير (نصي، مثل "أزرق ملكي")
  final String? color;
  /// المقاس (مثل "200x200")
  final String? size;
  /// تسمية الوحدة ("حبة"، "متر"، ...)
  final String? unit;
  final String? imageUrl;
  final Map<String, String> attributes;
  /// سعر الوحدة لهذا المتغير
  final double price;
  /// مخزون هذا المتغير (اختياري)
  final int? stock;

  ProductVariant({
    required this.id,
    this.sku,
    this.color,
    this.size,
    this.unit,
    this.imageUrl,
    this.attributes = const <String, String>{},
    required this.price,
    this.stock,
  });

  factory ProductVariant.fromJson(Map<String, dynamic> json) {
    // دعم البيانات القديمة: قد تحتوي فقط على size و price.
    final size = json['size']?.toString();
    final color = json['color']?.toString();
    final unit = json['unit']?.toString();
    final rawId = json['id']?.toString();

    Map<String, String> attrs = const <String, String>{};
    final rawAttrs = json['attributes'];
    if (rawAttrs is Map<String, dynamic>) {
      attrs = rawAttrs.map((k, v) => MapEntry(k.toString(), v?.toString() ?? ''))
        ..removeWhere((k, v) => k.trim().isEmpty || v.trim().isEmpty);
    } else if (rawAttrs is Map) {
      attrs = Map<String, dynamic>.from(rawAttrs)
          .map((k, v) => MapEntry(k.toString(), v?.toString() ?? ''))
        ..removeWhere((k, v) => k.trim().isEmpty || v.trim().isEmpty);
    }

    // إذا لم يكن هناك id محفوظ، نكوّن واحداً بسيطاً من الأبعاد المتاحة.
    final generatedId = rawId == null || rawId.isEmpty
        ? [color, size, unit].where((e) => e != null && e.isNotEmpty).join('-')
        : rawId;

    return ProductVariant(
      id: generatedId.isEmpty ? DateTime.now().millisecondsSinceEpoch.toString() : generatedId,
      sku: json['sku']?.toString(),
      color: color,
      size: size,
      unit: unit,
      imageUrl: json['image_url']?.toString(),
      attributes: attrs,
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      stock: json['stock'] is num ? (json['stock'] as num).toInt() : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      if (sku != null && sku!.isNotEmpty) 'sku': sku,
      if (color != null && color!.isNotEmpty) 'color': color,
      if (size != null && size!.isNotEmpty) 'size': size,
      if (unit != null && unit!.isNotEmpty) 'unit': unit,
      if (imageUrl != null && imageUrl!.isNotEmpty) 'image_url': imageUrl,
      if (attributes.isNotEmpty) 'attributes': attributes,
      'price': price,
      if (stock != null) 'stock': stock,
    };
  }
}

// ✅ كلاس لتمثيل العرض (الكمية والسعر)
class OfferTier {
  final int quantity;
  final double price;

  OfferTier({required this.quantity, required this.price});

  factory OfferTier.fromJson(Map<String, dynamic> json) {
    final int quantity = (json['qty'] as num?)?.toInt() ?? 1;
    final num? rawPrice = json['price'] as num?;
    final double price = rawPrice?.toDouble() ?? 0.0;

    return OfferTier(
      quantity: quantity,
      price: price,
    );
  }
}