import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:doctor_store/features/product/domain/models/product_model.dart';
import 'package:doctor_store/features/auth/application/user_data_manager.dart';
import 'package:doctor_store/features/cart/domain/pricing_calculator.dart';
import 'package:doctor_store/features/cart/data/cart_repository.dart';
import 'package:doctor_store/shared/services/whatsapp_service.dart';

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

  // استخدام PricingCalculator لتجنب تكرار المنطق
  return PricingCalculator.calculateCartTotalForProvider(
    items: cart,
    coupon: coupon,
  );
});

class CartNotifier extends StateNotifier<List<CartItem>> {
  late final CartRepository _cartRepository;
  Timer? _cloudSyncDebounceTimer;
  static const _cloudSyncDebounceDelay = Duration(seconds: 2);

  CartNotifier({CartRepository? cartRepository}) : super([]) {
    _cartRepository = cartRepository ?? CartRepository.current();
    _loadCart();
  }

  @override
  void dispose() {
    // Flush any pending cloud sync before disposal
    _flushPendingCloudSync();
    _cloudSyncDebounceTimer?.cancel();
    super.dispose();
  }

  String? get _currentUserId {
    try {
      return Supabase.instance.client.auth.currentUser?.id;
    } catch (_) {
      return null;
    }
  }

  /// تحميل السلة من التخزين المحلي + السحابي
  ///
  /// [mergeLocalWithRemote]: يُستخدم فقط بعد تسجيل الدخول لدمج سلة الزائر
  /// مع سلة الحساب مرة واحدة. في الاستخدام العادي نفضّل السحابة كمصدر
  /// رئيسي لتجنّب تكرار جمع الكميات في كل مرة يفتح فيها المستخدم التطبيق.
  Future<void> _loadCart({bool mergeLocalWithRemote = false}) async {
    final userId = _currentUserId;

    try {
      final result = mergeLocalWithRemote && userId != null
          ? await _cartRepository.loadAndMergeCarts(userId)
          : await _cartRepository.loadCart(userId: userId);

      state = result.items;
    } catch (e) {
      debugPrint('Load cart error: $e');
      state = [];
    }
  }

  /// حفظ السلة: Local فوري + Cloud debounced
  Future<void> _saveCart() async {
    final userId = _currentUserId;

    // 1. Local save is always immediate
    try {
      await _cartRepository.saveLocalCart(state);
    } catch (e) {
      debugPrint('Local cart save error: $e');
    }

    // 2. Cloud sync is debounced (only for logged-in users)
    if (userId != null) {
      _debounceCloudSync(userId);
    }
  }

  /// Debounced cloud sync - cancels previous timer if new edit arrives
  void _debounceCloudSync(String userId) {
    _cloudSyncDebounceTimer?.cancel();
    _cloudSyncDebounceTimer = Timer(_cloudSyncDebounceDelay, () async {
      await _syncToCloud(userId);
    });
  }

  /// Immediate cloud sync (used for flush scenarios)
  Future<void> _syncToCloud(String userId) async {
    try {
      await _cartRepository.syncRemoteCart(userId, state);
    } catch (e) {
      debugPrint('Cloud sync error: $e');
      // Silent failure - local is already saved, will retry on next edit
    }
  }

  /// Flush any pending cloud sync immediately (for dispose/clear scenarios)
  Future<void> _flushPendingCloudSync() async {
    final userId = _currentUserId;
    if (_cloudSyncDebounceTimer != null && userId != null) {
      _cloudSyncDebounceTimer!.cancel();
      _cloudSyncDebounceTimer = null;
      await _syncToCloud(userId);
    }
  }

  /// استدعِ هذه الدالة بعد تسجيل الدخول لدمج سلة الزائر مع سلة الحساب
  Future<void> syncAfterLogin() async {
    await _loadCart(mergeLocalWithRemote: true);
  }

  /// ✅ Helper: Get available stock for a product variant
  int? _getAvailableStock(Product product, String? selectedColor, String? selectedSize) {
    final variant = product.findMatchingVariant(
      color: selectedColor,
      size: selectedSize,
      unit: null,
    );
    return variant?.stock;
  }

  /// ✅ Helper: Get total quantity of an item already in cart
  int _getCurrentCartQuantity(Product product, String? selectedColor, String? selectedSize) {
    final existingItem = state.firstWhere(
      (item) =>
          item.product.id == product.id &&
          item.selectedColor == selectedColor &&
          item.selectedSize == selectedSize,
      orElse: () => CartItem(product: product, quantity: 0),
    );
    return existingItem.quantity;
  }

  Future<bool> addItem(Product product, {int quantity = 1, String? selectedColor, String? selectedSize, double? variantPrice}) async {
    // ✅ Stock validation: Check if adding exceeds available stock
    final availableStock = _getAvailableStock(product, selectedColor, selectedSize);
    if (availableStock != null) {
      final currentQty = _getCurrentCartQuantity(product, selectedColor, selectedSize);
      final totalRequested = currentQty + quantity;
      
      if (totalRequested > availableStock) {
        debugPrint('❌ Stock limit exceeded: requested $totalRequested, available $availableStock');
        return false; // Cannot add more than available
      }
    }

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
    return true;
  }

  void removeItem(CartItem item) {
    state = state.where((element) => element != item).toList();
    _saveCart();
  }

  void incrementQuantity(CartItem item) {
    // ✅ Stock validation before incrementing
    final availableStock = _getAvailableStock(item.product, item.selectedColor, item.selectedSize);
    if (availableStock != null && item.quantity >= availableStock) {
      debugPrint('❌ Cannot increment: stock limit reached ($availableStock)');
      return; // Already at max stock
    }
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
    
    // ✅ Stock validation: Cannot exceed available stock
    final availableStock = _getAvailableStock(item.product, item.selectedColor, item.selectedSize);
    if (availableStock != null && newQuantity > availableStock) {
      debugPrint('❌ Cannot update: requested $newQuantity, available $availableStock');
      newQuantity = availableStock; // Cap at available stock
    }
    
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
  }

  void clearCart() {
    state = [];
    _saveCart();
  }

  // ✅ استخدام WhatsAppService لبناء رسائل الواتساب وفتحها
  // تم نقل المنطق إلى lib/shared/services/whatsapp_service.dart

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
      final specificImageUrl = WhatsAppService.getCorrectImageUrl(item.product, item.selectedColor);

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
    final url = WhatsAppService.buildWhatsAppUrl(
      storePhone,
      WhatsAppService.buildInvoiceMessage(
        orderId: orderIdLabel,
        customerName: customerName,
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
      ),
    );
    final result = await WhatsAppService.launchWhatsApp(url);
    if (result.success) {
      clearCart();
    } else {
      throw Exception(result.error ?? 'تعذر فتح واتساب لإتمام الطلب.');
    }

    // 2) بعد فتح الواتساب نحاول حفظ الطلب في Supabase في الخلفية.
    () async {
      // نحفظ طلبات السلة للضيوف أيضًا حتى تظهر في لوحة التحكم.
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

        // Fix: Only clear cart after at least one order item is saved
        // بعد الحصول على رقم الطلب، نحاول حفظ عناصر السلة (من النسخة الثابتة)
        var savedItemsCount = 0;
        for (final item in itemsSnapshot) {
          final specificImageUrl = WhatsAppService.getCorrectImageUrl(item.product, item.selectedColor);
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
            savedItemsCount++;
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

  // تحديث دالة الشراء السريع لدعم رسوم التوصيل
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
    final specificImageUrl = WhatsAppService.getCorrectImageUrl(product, color);

    final variant = product.findMatchingVariant(
      color: color,
      size: size,
      unit: null,
    );
    final unitLabel = (variant?.unit != null && variant!.unit!.isNotEmpty)
        ? variant.unit
        : product.options['pricing_unit'];

    // 1) نبني رسالة الواتساب ونفتحها فوراً
    final url = WhatsAppService.buildWhatsAppUrl(
      storePhone,
      WhatsAppService.buildInvoiceMessage(
        orderId: orderIdLabel,
        customerName: customerName,
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
      ),
    );
    final result = await WhatsAppService.launchWhatsApp(url);
    if (!result.success) {
      throw Exception(result.error ?? 'Cannot launch WhatsApp');
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
      final specificImageUrl = WhatsAppService.getCorrectImageUrl(item.product, item.selectedColor);

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

    final url = WhatsAppService.buildWhatsAppUrl(
      storePhone,
      WhatsAppService.buildInvoiceMessage(
        orderId: orderIdLabel,
        customerName: customerName,
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
      ),
    );
    final result = await WhatsAppService.launchWhatsApp(url);
    if (!result.success) {
      throw Exception(result.error ?? 'Cannot launch WhatsApp');
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
          final specificImageUrl = WhatsAppService.getCorrectImageUrl(item.product, item.selectedColor);
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
Future<String?> validateCoupon(WidgetRef ref, String code, {String? phone}) async {
  try {
    final userProfile = ref.read(userProfileProvider);
    final customerPhone =
        (phone != null && phone.trim().isNotEmpty) ? phone.trim() : userProfile.phone;
    final response = await Supabase.instance.client.rpc('verify_and_apply_coupon', params: {
      'p_code': code,
      'p_phone': customerPhone,
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
    await Supabase.instance.client.rpc('register_coupon_usage', params: {
      'p_coupon_id': couponId,
      'p_order_id': orderId,
      'p_customer_phone': phone,
    });
  } catch (rpcError) {
    debugPrint("RPC coupon usage error: $rpcError");
    try {
      await Supabase.instance.client.from('coupon_usage').insert({
        'coupon_id': couponId,
        'order_id': orderId,
        'customer_phone': phone,
      });
      await Supabase.instance.client.rpc(
        'increment_coupon_usage',
        params: {'coupon_id': couponId},
      );
    } catch (e) {
      debugPrint("Error registering coupon: $e");
    }
  }
}

Future<void> incrementCouponUsage(String couponId) async {
  await Supabase.instance.client.rpc(
    'increment_coupon_usage',
    params: {'coupon_id': couponId},
  );
}
