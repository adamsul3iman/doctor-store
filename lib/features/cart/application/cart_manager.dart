import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:doctor_store/features/product/domain/models/product_model.dart';
import 'package:doctor_store/features/auth/application/user_data_manager.dart';

// ================== الموديل (CartItem) ==================
class CartItem {
  final Product product;
  int quantity;
  final String? selectedColor;
  final String? selectedSize;
  final double? variantPrice;

  CartItem({
    required this.product, 
    this.quantity = 1,
    this.selectedColor,
    this.selectedSize,
    this.variantPrice,
  });

  double get activePrice => variantPrice ?? product.price;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CartItem &&
          runtimeType == other.runtimeType &&
          product.id == other.product.id &&
          selectedColor == other.selectedColor &&
          selectedSize == other.selectedSize;

  @override
  int get hashCode => Object.hash(product.id, selectedColor, selectedSize);

  Map<String, dynamic> toJson() {
    return {
      'productId': product.id,
      'quantity': quantity,
      'color': selectedColor,
      'size': selectedSize,
      'variantPrice': variantPrice,
      'productData': product.toJson(),
    };
  }

  factory CartItem.fromJson(Map<String, dynamic> json) {
    return CartItem(
      product: Product.fromJson(json['productData']),
      quantity: json['quantity'] ?? 1,
      selectedColor: json['color'],
      selectedSize: json['size'],
      variantPrice: (json['variantPrice'] as num?)?.toDouble(),
    );
  }
}

// ================== الموديل (Coupon) ==================
class Coupon {
  final String id;
  final String code;
  final String type; 
  final double value;

  Coupon({required this.id, required this.code, required this.type, required this.value});

  factory Coupon.fromRpc(Map<String, dynamic> json, String code) {
    final String id = json['id']?.toString() ?? '';
    final String type = (json['type'] as String?) ?? '';
    final double value = (json['value'] as num?)?.toDouble() ?? 0.0;

    return Coupon(
      id: id,
      code: code,
      type: type,
      value: value,
    );
  }
}

// ================== البروفايدر ==================

final cartProvider = StateNotifierProvider<CartNotifier, List<CartItem>>((ref) {
  return CartNotifier();
});

final couponProvider = StateProvider<Coupon?>((ref) => null);

final cartTotalAfterDiscountProvider = Provider<double>((ref) {
  return ref.watch(cartTotalProvider);
});

final cartTotalProvider = Provider<double>((ref) {
  final cart = ref.watch(cartProvider);
  final coupon = ref.watch(couponProvider);

  double originalTotal = cart.fold(0, (sum, item) => sum + item.activePrice * item.quantity);

  if (coupon == null) return originalTotal;

  double discountAmount = 0;
  if (coupon.type == 'percent') {
    discountAmount = originalTotal * (coupon.value / 100);
  } else {
    discountAmount = coupon.value;
  }
  
  double finalTotal = originalTotal - discountAmount;
  return finalTotal < 0 ? 0.0 : finalTotal;
});

class CartNotifier extends StateNotifier<List<CartItem>> {
  CartNotifier() : super([]) {
    // عند بدء التشغيل نحمّل السلة مرة واحدة بدون دمج محلي/سحابي متكرر
    _loadCart();
  }

  SupabaseClient? _getClientOrNull() {
    try {
      return Supabase.instance.client;
    } catch (_) {
      // في بيئات الاختبار أو قبل تهيئة Supabase نعمل بالسلة المحلية فقط
      return null;
    }
  }

  /// تحميل السلة من التخزين المحلي + السحابي
  ///
  /// [mergeLocalWithRemote]: يُستخدم فقط بعد تسجيل الدخول لدمج سلة الزائر
  /// مع سلة الحساب مرة واحدة. في الاستخدام العادي نفضّل السحابة كمصدر
  /// رئيسي لتجنّب تكرار جمع الكميات في كل مرة يفتح فيها المستخدم التطبيق.
  Future<void> _loadCart({bool mergeLocalWithRemote = false}) async {
    final prefs = await SharedPreferences.getInstance();
    final String? cartString = prefs.getString('cart_items');
    List<CartItem> localItems = [];
    if (cartString != null) {
      final List<dynamic> decoded = jsonDecode(cartString);
      localItems = decoded.map((e) => CartItem.fromJson(e)).toList();
    }

    // محاولة مزامنة السلة مع Supabase للمستخدم المسجّل
    final client = _getClientOrNull();
    final user = client?.auth.currentUser;
    if (client != null && user != null) {
      try {
        final data = await client
            .from('user_carts')
            .select('items')
            .eq('user_id', user.id)
            .maybeSingle();

        List<CartItem> remoteItems = [];
        if (data != null && data['items'] is List) {
          remoteItems = (data['items'] as List)
              .map((e) => CartItem.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList();
        }

        if (mergeLocalWithRemote) {
          // يُستخدم عند تسجيل الدخول فقط لدمج سلة الزائر مع سلة الحساب
          state = _mergeCarts(localItems, remoteItems);
        } else {
          // في الاستخدام العادي نعتبر السحابة هي المصدر الرئيسي
          // إذا كانت السحابة فارغة نستخدم المحلي، وإلا نستخدم السحابة فقط
          if (remoteItems.isNotEmpty) {
            state = remoteItems;
          } else {
            state = localItems;
          }
        }
      } catch (e) {
        debugPrint('Load remote cart error: $e');
        state = localItems;
      }
    } else {
      // مستخدم زائر: نستخدم السلة المحلية فقط
      state = localItems;
    }

    await _saveCart();
    await _syncCartToCloud();
  }

  /// دمج سلتين مع جمع الكميات لنفس العنصر
  List<CartItem> _mergeCarts(List<CartItem> a, List<CartItem> b) {
    final Map<CartItem, int> map = {};
    for (final item in [...a, ...b]) {
      map[item] = (map[item] ?? 0) + item.quantity;
    }
    return map.entries
        .map((entry) => CartItem(
              product: entry.key.product,
              quantity: entry.value,
              selectedColor: entry.key.selectedColor,
              selectedSize: entry.key.selectedSize,
              variantPrice: entry.key.variantPrice,
            ))
        .toList();
  }

  Future<void> _saveCart() async {
    final prefs = await SharedPreferences.getInstance();
    final String encoded = jsonEncode(state.map((e) => e.toJson()).toList());
    await prefs.setString('cart_items', encoded);
  }

  Future<void> _syncCartToCloud() async {
    final client = _getClientOrNull();
    final user = client?.auth.currentUser;
    if (client == null || user == null) return; // زائر أو بيئة بدون Supabase

    try {
      await client.from('user_carts').upsert({
        'user_id': user.id,
        'items': state.map((e) => e.toJson()).toList(),
      }, onConflict: 'user_id');
    } catch (e) {
      debugPrint('Sync cart error: $e');
    }
  }

  /// استدعِ هذه الدالة بعد تسجيل الدخول لدمج سلة الزائر مع سلة الحساب
  Future<void> syncAfterLogin() async {
    await _loadCart(mergeLocalWithRemote: true);
  }

  Future<void> addItem(Product product, {int quantity = 1, String? selectedColor, String? selectedSize, double? variantPrice}) async {
    final newItem = CartItem(
      product: product,
      quantity: quantity,
      selectedColor: selectedColor,
      selectedSize: selectedSize,
      variantPrice: variantPrice,
    );

    if (state.contains(newItem)) {
      state = [
        for (final item in state)
          if (item == newItem)
            CartItem(
              product: item.product,
              quantity: item.quantity + quantity,
              selectedColor: item.selectedColor,
              selectedSize: item.selectedSize,
              variantPrice: item.variantPrice,
            )
          else
            item
      ];
    } else {
      state = [...state, newItem];
    }
    await _saveCart();
    await _syncCartToCloud();
  }

  void removeItem(CartItem item) {
    state = state.where((element) => element != item).toList();
    _saveCart();
    _syncCartToCloud();
  }

  void incrementQuantity(CartItem item) {
    updateQuantity(item, item.quantity + 1);
  }

  void decrementQuantity(CartItem item) {
    if (item.quantity > 1) {
      updateQuantity(item, item.quantity - 1);
    } else {
      removeItem(item); 
    }
  }

  void updateQuantity(CartItem item, int newQuantity) {
    if (newQuantity < 1) return;
    state = [
      for (final i in state)
        if (i == item)
          CartItem(
            product: i.product,
            quantity: newQuantity,
            selectedColor: i.selectedColor,
            selectedSize: i.selectedSize,
            variantPrice: i.variantPrice,
          )
        else
          i
    ];
    _saveCart();
    _syncCartToCloud();
  }

  void clearCart() {
    state = [];
    _saveCart();
    _syncCartToCloud();
  }

  // ✅ 1. دالة مساعدة لتحديد رابط الصورة المناسبة
  String _getCorrectImageUrl(Product product, String? selectedColor) {
    // الصورة الافتراضية
    String finalUrl = product.imageUrl;

    // إذا اختار العميل لوناً، نبحث في المعرض عن صورة مرتبطة بهذا اللون
    if (selectedColor != null && product.gallery.isNotEmpty) {
      try {
        final variantImage = product.gallery.firstWhere(
          (img) => img.colorName == selectedColor,
        );
        finalUrl = variantImage.url;
      } catch (e) {
        // إذا لم نجد صورة للون، نستخدم الصورة الرئيسية
      }
    }
    return finalUrl;
  }

  // ✅ 2. تحديث شكل الفاتورة لإظهار رابط الصورة + ملخص الأسعار (منتجات / خصم / توصيل)
  String _buildWhatsAppInvoice({
    required String orderId,
    required String name,
    required String address,
    required String phone,
    required List<Map<String, dynamic>> items,
    required double productsTotal,
    required double finalTotal,
    double? discountAmount,
    double? deliveryFee,
    String? deliveryZoneName,
    Coupon? coupon,
    String? notes,
  }) {
    final buffer = StringBuffer();

    buffer.writeln("🧾 *طلب جديد - متجر الدكتور*");
    buffer.writeln("🔹 رقم الطلب: #${orderId.substring(0, 5)}");
    buffer.writeln("================================");

    buffer.writeln("👤 *العميل:* $name");
    buffer.writeln("📍 *العنوان:* $address");
    buffer.writeln("📞 *الهاتف:* $phone");
    buffer.writeln("================================");

    buffer.writeln("📦 *تفاصيل الطلب:*");
    for (var item in items) {
      buffer.writeln("• *${item['title']}*");

      if (item['color'] != null) {
        buffer.writeln("   🎨 اللون: ${item['color']}");
      }
      if (item['size'] != null) {
        buffer.writeln("   📏 المقاس: ${item['size']}");
      }

      final unitLabel = item['unit'] != null ? ' ${item['unit']}' : '';
      final int quantity = (item['quantity'] as num?)?.toInt() ?? 0;
      final double unitPrice = (item['price'] as num?)?.toDouble() ?? 0.0;
      final double lineTotal = unitPrice * quantity;

      buffer.writeln("   🔢 الكمية: $quantity$unitLabel");
      buffer.writeln("   💵 سعر الوحدة: ${unitPrice.toStringAsFixed(2)} د.أ");
      buffer.writeln("   💰 إجمالي هذا المنتج: ${lineTotal.toStringAsFixed(2)} د.أ");

      buffer.writeln("   🖼️ رابط الصورة: ${item['image_url']}");
      buffer.writeln(""); // مسافة بين المنتجات
    }

    buffer.writeln("================================");
    buffer.writeln("💳 *ملخص الفاتورة:*");
    buffer.writeln("🧾 مجموع المنتجات: ${productsTotal.toStringAsFixed(2)} د.أ");

    if (discountAmount != null && discountAmount > 0) {
      buffer.writeln("🎟️ إجمالي الخصم: -${discountAmount.toStringAsFixed(2)} د.أ");
      if (coupon != null) {
        buffer.writeln("   (كوبون: ${coupon.code})");
      }
    } else if (coupon != null) {
      // في حال تم تمرير كوبون بدون تمرير قيمة الخصم
      buffer.writeln("🎟️ كوبون مفعّل: ${coupon.code}");
    }

    if (deliveryFee != null && deliveryFee > 0) {
      final zoneLabel = deliveryZoneName != null && deliveryZoneName.trim().isNotEmpty
          ? " (${deliveryZoneName.trim()})"
          : "";
      buffer.writeln(
        "🚚 رسوم التوصيل$zoneLabel: ${deliveryFee.toStringAsFixed(2)} د.أ",
      );
      buffer.writeln("⚖️ *ملاحظة:* رسوم التوصيل تقديرية وتختلف حسب حجم الطلب.");
    }

    buffer.writeln("================================");
    buffer.writeln("💰 *المجموع النهائي المستحق:* ${finalTotal.toStringAsFixed(2)} د.أ");

    if (notes != null && notes.trim().isNotEmpty) {
      buffer.writeln("================================");
      buffer.writeln("📝 *ملاحظات العميل:* ${notes.trim()}");
    }

    buffer.writeln("================================");
    buffer.writeln("📍 يرجى تأكيد الطلب وموعد التوصيل.");

    return buffer.toString();
  }

  // ✅ 3. تحديث دالة الشراء من السلة مع دعم رسوم التوصيل
  // ملاحظة مهمة على الويب: يجب فتح نافذة الواتساب مباشرة بعد تفاعل المستخدم
  // حتى لا يقوم Safari / Chrome بحظر النافذة المنبثقة. لذلك:
  // - نبني رسالة الواتساب محلياً أولاً.
  // - نفتح رابط الواتساب فوراً.
  // - بعد ذلك فقط نرسل الطلب إلى Supabase في الخلفية (خصوصاً على الويب).
  Future<void> checkoutViaWhatsApp({
    required String customerName,
    required String customerPhone,
    required double totalAmount,
    required double productsTotal,
    required double deliveryFee,
    required String deliveryZoneName,
    required String storePhone,
    double? discountAmount,
    Coupon? coupon,
    String? notes,
  }) async {
    final supabase = Supabase.instance.client;
    final user = Supabase.instance.client.auth.currentUser;

    // نأخذ نسخة ثابتة من السلة قبل تفريغها حتى نستخدمها في حفظ الطلب
    final itemsSnapshot = List<CartItem>.from(state);

    // نبني عناصر الفاتورة دائماً من حالة السلة الحالية (النسخة الثابتة)
    final List<Map<String, dynamic>> invoiceItems = [];
    for (final item in itemsSnapshot) {
      final specificImageUrl = _getCorrectImageUrl(item.product, item.selectedColor);

      final variant = item.product.findMatchingVariant(
        color: item.selectedColor,
        size: item.selectedSize,
        unit: null,
      );
      final unitLabel = (variant?.unit != null && variant!.unit!.isNotEmpty)
          ? variant.unit
          : item.product.options['pricing_unit'];

      invoiceItems.add({
        'title': item.product.title,
        'size': item.selectedSize,
        'color': item.selectedColor,
        'quantity': item.quantity,
        'price': item.activePrice,
        'unit': unitLabel,
        'image_url': specificImageUrl,
      });
    }

    // نستخدم معرفًا مبدئياً للطلب في رسالة الواتساب، وفي الخلفية نحاول
    // الحصول على رقم الطلب الحقيقي من Supabase (إن نجح الاتصال).
    String orderIdLabel = 'local';

    // 1) نرسل رسالة الواتساب أولاً (حتى لا يحظرها المتصفح على الويب)
    final msg = _buildWhatsAppInvoice(
      orderId: orderIdLabel,
      name: customerName,
      address: 'منطقة التوصيل: $deliveryZoneName',
      phone: customerPhone,
      items: invoiceItems,
      productsTotal: productsTotal,
      finalTotal: totalAmount,
      discountAmount: discountAmount,
      deliveryFee: deliveryFee,
      deliveryZoneName: deliveryZoneName,
      coupon: coupon,
      notes: notes,
    );

    final url = Uri.parse("https://wa.me/$storePhone?text=${Uri.encodeComponent(msg)}");
    LaunchMode mode = kIsWeb ? LaunchMode.platformDefault : LaunchMode.externalApplication;
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: mode);
      // عند نجاح الإطلاق يمكننا إفراغ السلة فوراً
      clearCart();
    } else {
      throw Exception('Cannot launch WhatsApp');
    }

    // 2) بعد فتح الواتساب نحاول حفظ الطلب في Supabase في الخلفية.
    () async {
      try {
        final orderRes = await supabase.from('orders').insert({
          'customer_name': customerName,
          'customer_phone': customerPhone,
          'customer_address':
              'منطقة التوصيل: $deliveryZoneName (رسوم: ${deliveryFee.toStringAsFixed(2)} د.أ)',
          'total_amount': totalAmount,
          'platform': 'whatsapp',
          'status': 'new',
          'user_id': user?.id,
        }).select().single();

        final dynamic orderIdRaw = orderRes['id'];
        orderIdLabel = orderIdRaw.toString();

        // بعد الحصول على رقم الطلب، نحاول حفظ عناصر السلة (من النسخة الثابتة)
        for (final item in itemsSnapshot) {
          final specificImageUrl = _getCorrectImageUrl(item.product, item.selectedColor);
          try {
            await supabase.from('order_items').insert({
              'order_id': orderIdRaw,
              'product_id': item.product.id,
              'product_title': item.product.title,
              'quantity': item.quantity,
              'price': item.activePrice,
              'selected_size': item.selectedSize,
              'selected_color': item.selectedColor,
              'image_url': specificImageUrl,
            });
          } catch (e) {
            debugPrint('Order item insert error: $e');
          }
        }

        if (coupon != null) {
          try {
            await registerCouponUsage(coupon.id, orderIdLabel, customerPhone);
          } catch (e) {
            debugPrint('Coupon usage error: $e');
          }
        }
      } catch (e) {
        debugPrint('Checkout Error (Supabase): $e');
        // لا نمنع الطلب من الوصول للواتساب حتى لو فشل الحفظ في قاعدة البيانات
      }
    }();
  }

  // ✅ 4. تحديث دالة الشراء السريع لدعم رسوم التوصيل
  // على الويب أيضاً نفتح الواتساب أولاً ثم نحفظ الطلب في الخلفية.
  Future<void> checkoutSingleProductViaWhatsApp({
    required Product product,
    required int quantity,
    required String? size,
    required String? color,
    required double price,
    required String customerName,
    required String customerPhone,
    required String storePhone,
    required double productsTotal,
    required double deliveryFee,
    required String deliveryZoneName,
    double? discountAmount,
    Coupon? coupon,
    String? notes,
  }) async {
    final supabase = Supabase.instance.client;
    // تنظيف رقم الهاتف من أي رموز أو مسافات لضمان عمل رابط الواتساب بشكل صحيح
    final String cleanPhone =
        storePhone.replaceAll(RegExp(r'[^0-9]'), '');
    // احتساب المجموع والخصم محلياً لحماية إضافية
    double effectiveProductsTotal = productsTotal;
    if (effectiveProductsTotal <= 0) {
      effectiveProductsTotal = price * quantity;
    }

    double appliedDiscount = discountAmount ?? 0;
    if (coupon != null && discountAmount == null) {
      if (coupon.type == 'percent') {
        appliedDiscount = effectiveProductsTotal * (coupon.value / 100);
      } else {
        appliedDiscount = coupon.value;
      }
    }
    if (appliedDiscount > effectiveProductsTotal) {
      appliedDiscount = effectiveProductsTotal;
    }

    double total = effectiveProductsTotal - appliedDiscount;
    if (total < 0) total = 0;
    total += deliveryFee;

    final user = Supabase.instance.client.auth.currentUser;
    String orderIdLabel = 'local';
    final specificImageUrl = _getCorrectImageUrl(product, color);

    final variant = product.findMatchingVariant(
      color: color,
      size: size,
      unit: null,
    );
    final unitLabel = (variant?.unit != null && variant!.unit!.isNotEmpty)
        ? variant.unit
        : product.options['pricing_unit'];

    // 1) نبني رسالة الواتساب ونفتحها فوراً
    final msg = _buildWhatsAppInvoice(
      orderId: orderIdLabel,
      name: customerName,
      address: 'منطقة التوصيل: $deliveryZoneName',
      phone: customerPhone,
      items: [
        {
          'title': product.title,
          'size': size,
          'color': color,
          'quantity': quantity,
          'price': price,
          'unit': unitLabel,
          'image_url': specificImageUrl,
        }
      ],
      productsTotal: effectiveProductsTotal,
      finalTotal: total,
      discountAmount: appliedDiscount,
      deliveryFee: deliveryFee,
      deliveryZoneName: deliveryZoneName,
      coupon: coupon,
      notes: notes,
    );

    final url = Uri.parse(
      "https://wa.me/$cleanPhone?text=${Uri.encodeComponent(msg)}",
    );
    
    // For web, use platform-specific launch mode
    LaunchMode mode = kIsWeb ? LaunchMode.platformDefault : LaunchMode.externalApplication;
    
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: mode);
    } else {
      throw Exception('Cannot launch WhatsApp');
    }

    // 2) بعد فتح الواتساب نحفظ الطلب في Supabase في الخلفية
    () async {
      try {
        final orderRes = await supabase.from('orders').insert({
          'customer_name': customerName,
          'customer_phone': customerPhone,
          'customer_address':
              'منطقة التوصيل: $deliveryZoneName (رسوم: ${deliveryFee.toStringAsFixed(2)} د.أ)',
          'total_amount': total,
          'status': 'new',
          'platform': 'whatsapp',
          'user_id': user?.id,
        }).select().single();

        final dynamic orderIdRaw = orderRes['id'];
        orderIdLabel = orderIdRaw.toString();

        try {
          await supabase.from('order_items').insert({
            'order_id': orderIdRaw,
            'product_id': product.id,
            'product_title': product.title,
            'quantity': quantity,
            'price': price,
            'selected_size': size,
            'selected_color': color,
            'image_url': specificImageUrl,
          });
        } catch (e) {
          debugPrint('Quick checkout order item error: $e');
        }

        if (coupon != null) {
          try {
            await registerCouponUsage(coupon.id, orderIdLabel, customerPhone);
          } catch (e) {
            debugPrint('Quick checkout coupon usage error: $e');
          }
        }
      } catch (e) {
        debugPrint('Quick Checkout Error (Supabase): $e');
      }
    }();
  }

  /// طلب واتساب مخصص لعدة اختيارات (نفس المنتج أو عدة منتجات) بدون الاعتماد على حالة السلة
  Future<void> checkoutCustomItemsViaWhatsApp({
    required List<CustomCheckoutItem> items,
    required String customerName,
    required String customerPhone,
    required String storePhone,
    required double productsTotal,
    required double deliveryFee,
    required String deliveryZoneName,
    double? discountAmount,
    Coupon? coupon,
    String? notes,
  }) async {
    final supabase = Supabase.instance.client;
    final user = Supabase.instance.client.auth.currentUser;

    // تنظيف رقم الهاتف من أي رموز أو مسافات لضمان عمل رابط الواتساب بشكل صحيح
    final String cleanPhone = storePhone.replaceAll(RegExp(r'[^0-9]'), '');

    double effectiveProductsTotal = productsTotal;
    if (effectiveProductsTotal <= 0) {
      effectiveProductsTotal = items.fold(
        0,
        (sum, item) => sum + (item.unitPrice * item.quantity),
      );
    }

    double appliedDiscount = discountAmount ?? 0;
    if (coupon != null && discountAmount == null) {
      if (coupon.type == 'percent') {
        appliedDiscount = effectiveProductsTotal * (coupon.value / 100);
      } else {
        appliedDiscount = coupon.value;
      }
    }
    if (appliedDiscount > effectiveProductsTotal) {
      appliedDiscount = effectiveProductsTotal;
    }

    double total = effectiveProductsTotal - appliedDiscount;
    if (total < 0) total = 0;
    total += deliveryFee;

    String orderIdLabel = 'local';

    // بناء عناصر الفاتورة لاستخدامها في رسالة الواتساب
    final List<Map<String, dynamic>> invoiceItems = [];
    for (final item in items) {
      final specificImageUrl = _getCorrectImageUrl(item.product, item.selectedColor);

      final variant = item.product.findMatchingVariant(
        color: item.selectedColor,
        size: item.selectedSize,
        unit: null,
      );
      final unitLabel = (variant?.unit != null && variant!.unit!.isNotEmpty)
          ? variant.unit
          : item.product.options['pricing_unit'];

      invoiceItems.add({
        'title': item.product.title,
        'size': item.selectedSize,
        'color': item.selectedColor,
        'quantity': item.quantity,
        'price': item.unitPrice,
        'unit': unitLabel,
        'image_url': specificImageUrl,
      });
    }

    final msg = _buildWhatsAppInvoice(
      orderId: orderIdLabel,
      name: customerName,
      address: 'منطقة التوصيل: $deliveryZoneName',
      phone: customerPhone,
      items: invoiceItems,
      productsTotal: effectiveProductsTotal,
      finalTotal: total,
      discountAmount: appliedDiscount,
      deliveryFee: deliveryFee,
      deliveryZoneName: deliveryZoneName,
      coupon: coupon,
      notes: notes,
    );

    final url = Uri.parse(
      "https://wa.me/$cleanPhone?text=${Uri.encodeComponent(msg)}",
    );
    LaunchMode mode = kIsWeb ? LaunchMode.platformDefault : LaunchMode.externalApplication;
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: mode);
    } else {
      throw Exception('Cannot launch WhatsApp');
    }

    // 2) بعد فتح الواتساب نحفظ الطلب في Supabase في الخلفية
    () async {
      try {
        final orderRes = await supabase.from('orders').insert({
          'customer_name': customerName,
          'customer_phone': customerPhone,
          'customer_address':
              'منطقة التوصيل: $deliveryZoneName (رسوم: ${deliveryFee.toStringAsFixed(2)} د.أ)',
          'total_amount': total,
          'status': 'new',
          'platform': 'whatsapp',
          'user_id': user?.id,
        }).select().single();

        final dynamic orderIdRaw = orderRes['id'];
        orderIdLabel = orderIdRaw.toString();

        for (final item in items) {
          final specificImageUrl = _getCorrectImageUrl(item.product, item.selectedColor);
          try {
            await supabase.from('order_items').insert({
              'order_id': orderIdRaw,
              'product_id': item.product.id,
              'product_title': item.product.title,
              'quantity': item.quantity,
              'price': item.unitPrice,
              'selected_size': item.selectedSize,
              'selected_color': item.selectedColor,
              'image_url': specificImageUrl,
            });
          } catch (e) {
            debugPrint('Custom quick checkout order item error: $e');
          }
        }

        if (coupon != null) {
          try {
            await registerCouponUsage(coupon.id, orderIdLabel, customerPhone);
          } catch (e) {
            debugPrint('Custom quick checkout coupon usage error: $e');
          }
        }
      } catch (e) {
        debugPrint('Custom Quick Checkout Error (Supabase): $e');
      }
    }();
  }
}

/// نموذج عنصر مخصص للاستخدام في الطلبات السريعة المتعددة من صفحة المنتج
class CustomCheckoutItem {
  final Product product;
  final int quantity;
  final String? selectedSize;
  final String? selectedColor;
  final double unitPrice;

  const CustomCheckoutItem({
    required this.product,
    required this.quantity,
    required this.selectedSize,
    required this.selectedColor,
    required this.unitPrice,
  });
}

// الدوال المساعدة العامة
Future<String?> validateCoupon(WidgetRef ref, String code) async {
  try {
    final userProfile = ref.read(userProfileProvider);
    final response = await Supabase.instance.client.rpc('verify_and_apply_coupon', params: {
      'p_code': code,
      'p_phone': userProfile.phone, 
    });
    
    final data = response as Map<String, dynamic>;

    if (data['valid'] == true) {
      final coupon = Coupon.fromRpc(data, code);
      ref.read(couponProvider.notifier).state = coupon;
      return null; 
    } else {
      return data['message'] ?? "الكوبون غير صالح";
    }

  } catch (e) {
    return "خطأ في الاتصال";
  }
}

Future<void> registerCouponUsage(String couponId, String orderId, String phone) async {
  try {
    await Supabase.instance.client.from('coupon_usage').insert({
      'coupon_id': couponId,
      'order_id': orderId,
      'customer_phone': phone,
    });
    await Supabase.instance.client.rpc('increment_coupon_usage', params: {'coupon_id': couponId});
  } catch (e) {
    debugPrint("Error registering coupon: $e");
  }
}

Future<void> incrementCouponUsage(String couponId) async {
   await Supabase.instance.client.rpc('increment_coupon_usage', params: {'coupon_id': couponId});
}