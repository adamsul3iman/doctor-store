/// Pure pricing calculator for cart operations.
/// Stateless, no side effects, fully testable.
library;

import 'package:doctor_store/features/cart/application/cart_manager.dart'
    show CartItem, Coupon;

/// Result of pricing calculations
class CartPricing {
  final double subtotal;
  final double discountAmount;
  final double totalAfterDiscount;
  final double deliveryFee;
  final double grandTotal;

  const CartPricing({
    required this.subtotal,
    required this.discountAmount,
    required this.totalAfterDiscount,
    required this.deliveryFee,
    required this.grandTotal,
  });

  @override
  String toString() {
    return 'CartPricing(subtotal: $subtotal, discount: $discountAmount, '
        'afterDiscount: $totalAfterDiscount, delivery: $deliveryFee, total: $grandTotal)';
  }
}

/// Configuration for pricing calculations
class PricingConfig {
  final double? freeShippingThreshold;
  final bool freeShippingEnabled;

  const PricingConfig({
    this.freeShippingThreshold,
    this.freeShippingEnabled = false,
  });

  static const PricingConfig defaultConfig = PricingConfig();
}

/// Pure pricing calculator - no state, no side effects
class PricingCalculator {
  const PricingCalculator._();

  // ================== Subtotal Calculations ==================

  /// Calculate subtotal from list of cart items
  /// Formula: sum(item.activePrice * item.quantity)
  static double calculateSubtotal(List<CartItem> items) {
    return items.fold(
      0.0,
      (sum, item) => sum + (item.activePrice * item.quantity),
    );
  }

  /// Calculate subtotal for a single item
  static double calculateItemSubtotal(CartItem item) {
    return item.activePrice * item.quantity;
  }

  // ================== Discount Calculations ==================

  /// Calculate discount amount based on coupon type
  /// - Percent: subtotal * (value / 100)
  /// - Fixed: value (capped at subtotal)
  static double calculateDiscount({
    required double subtotal,
    required Coupon? coupon,
  }) {
    if (coupon == null) return 0.0;

    double discountAmount;
    if (coupon.type == 'percent') {
      discountAmount = subtotal * (coupon.value / 100);
    } else {
      // Fixed amount
      discountAmount = coupon.value;
    }

    // Cap discount at subtotal (can't have negative total)
    if (discountAmount > subtotal) {
      discountAmount = subtotal;
    }

    return discountAmount;
  }

  /// Calculate total after discount
  static double calculateTotalAfterDiscount({
    required double subtotal,
    required double discountAmount,
  }) {
    final result = subtotal - discountAmount;
    return result < 0 ? 0.0 : result;
  }

  // ================== Delivery Fee Calculations ==================

  /// Calculate delivery fee with dynamic and zone fallback
  static double calculateDeliveryFee({
    required double? dynamicFee,
    required double? zonePrice,
    required double subtotal,
    PricingConfig config = PricingConfig.defaultConfig,
  }) {
    // Check free shipping
    if (config.freeShippingEnabled &&
        config.freeShippingThreshold != null &&
        subtotal >= config.freeShippingThreshold!) {
      return 0.0;
    }

    // Use dynamic fee if available, otherwise zone price, default 0
    if (dynamicFee != null && dynamicFee > 0) {
      return dynamicFee;
    }

    return zonePrice ?? 0.0;
  }

  /// Check if order qualifies for free shipping
  static bool qualifiesForFreeShipping({
    required double subtotal,
    required PricingConfig config,
  }) {
    if (!config.freeShippingEnabled) return false;
    if (config.freeShippingThreshold == null) return false;
    return subtotal >= config.freeShippingThreshold!;
  }

  /// Calculate remaining amount to reach free shipping
  static double? remainingForFreeShipping({
    required double subtotal,
    required PricingConfig config,
  }) {
    if (!config.freeShippingEnabled) return null;
    if (config.freeShippingThreshold == null) return null;

    final remaining = config.freeShippingThreshold! - subtotal;
    return remaining > 0 ? remaining : 0.0;
  }

  // ================== Grand Total Calculations ==================

  /// Calculate grand total
  static double calculateGrandTotal({
    required double subtotal,
    required double discountAmount,
    required double deliveryFee,
  }) {
    return subtotal - discountAmount + deliveryFee;
  }

  // ================== Complete Cart Pricing ==================

  /// Calculate complete cart pricing in one call
  static CartPricing calculateCartPricing({
    required List<CartItem> items,
    Coupon? coupon,
    double? dynamicDeliveryFee,
    double? zonePrice,
    PricingConfig config = PricingConfig.defaultConfig,
  }) {
    final subtotal = calculateSubtotal(items);
    final discountAmount = calculateDiscount(
      subtotal: subtotal,
      coupon: coupon,
    );
    final totalAfterDiscount = calculateTotalAfterDiscount(
      subtotal: subtotal,
      discountAmount: discountAmount,
    );
    final deliveryFee = calculateDeliveryFee(
      dynamicFee: dynamicDeliveryFee,
      zonePrice: zonePrice,
      subtotal: subtotal,
      config: config,
    );
    final grandTotal = calculateGrandTotal(
      subtotal: subtotal,
      discountAmount: discountAmount,
      deliveryFee: deliveryFee,
    );

    return CartPricing(
      subtotal: subtotal,
      discountAmount: discountAmount,
      totalAfterDiscount: totalAfterDiscount,
      deliveryFee: deliveryFee,
      grandTotal: grandTotal,
    );
  }

  // ================== Provider Helpers (Backward Compatible) ==================

  /// Calculate cart total for provider (legacy behavior)
  /// Same as cartTotalProvider logic
  static double calculateCartTotalForProvider({
    required List<CartItem> items,
    Coupon? coupon,
  }) {
    final subtotal = calculateSubtotal(items);

    if (coupon == null) return subtotal;

    final discountAmount = calculateDiscount(
      subtotal: subtotal,
      coupon: coupon,
    );

    final finalTotal = subtotal - discountAmount;
    return finalTotal < 0 ? 0.0 : finalTotal;
  }
}
