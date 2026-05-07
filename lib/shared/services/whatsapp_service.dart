/// WhatsApp service for building and sending order messages.
/// Focused only on WhatsApp responsibilities - no state, no Supabase, no cart logic.
library;

import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:doctor_store/features/product/domain/models/product_model.dart';
import 'package:doctor_store/features/cart/application/cart_manager.dart'
    show Coupon;

/// Data class for invoice items
class InvoiceItem {
  final String title;
  final String? size;
  final String? color;
  final int quantity;
  final double price;
  final String? unit;
  final String? imageUrl;

  const InvoiceItem({
    required this.title,
    this.size,
    this.color,
    required this.quantity,
    required this.price,
    this.unit,
    this.imageUrl,
  });

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'size': size,
      'color': color,
      'quantity': quantity,
      'price': price,
      'unit': unit,
      'image_url': imageUrl,
    };
  }
}

/// Result of launching WhatsApp
class WhatsAppLaunchResult {
  final bool success;
  final String? error;

  const WhatsAppLaunchResult({required this.success, this.error});
}

/// Pure WhatsApp service - builds messages and launches WhatsApp.
/// No side effects except launching the URL (which is the core responsibility).
class WhatsAppService {
  const WhatsAppService._();

  // ================== Message Building ==================

  /// Build WhatsApp invoice message with all order details.
  /// This is the core formatting logic - pure function with no side effects.
  static String buildInvoiceMessage({
    required String orderId,
    required String customerName,
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
    buffer.writeln("🔹 رقم الطلب: #${orderId.substring(0, orderId.length < 5 ? orderId.length : 5)}");
    buffer.writeln("================================");

    buffer.writeln("👤 *العميل:* $customerName");
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

  // ================== URL & Launching ==================

  /// Normalize phone numbers before building WhatsApp URLs.
  /// Supports raw digits, local Jordan numbers, and mistakenly stored wa.me links.
  static String normalizePhoneNumber(String phoneNumber) {
    final raw = phoneNumber.trim();
    if (raw.isEmpty) return '';

    String extracted = raw;
    final uri = Uri.tryParse(raw);
    if (uri != null) {
      if (uri.host.contains('wa.me') && uri.pathSegments.isNotEmpty) {
        extracted = uri.pathSegments.first;
      } else {
        final qpPhone = uri.queryParameters['phone'];
        if (qpPhone != null && qpPhone.trim().isNotEmpty) {
          extracted = qpPhone;
        }
      }
    }

    String digits = extracted.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return '';

    if (digits.startsWith('00962')) {
      digits = digits.substring(2);
    }

    if (digits.startsWith('0') && digits.length == 10) {
      digits = '962${digits.substring(1)}';
    } else if (digits.startsWith('79') && digits.length == 9) {
      digits = '962$digits';
    }

    return digits;
  }

  /// Build WhatsApp URL for a given phone number and message.
  static Uri buildWhatsAppUrl(String phoneNumber, String message) {
    final String cleanPhone = normalizePhoneNumber(phoneNumber);
    return Uri.parse(
      "https://wa.me/$cleanPhone?text=${Uri.encodeComponent(message)}",
    );
  }

  /// Launch WhatsApp with the given URL.
  /// Returns success/failure result.
  static Future<WhatsAppLaunchResult> launchWhatsApp(Uri url) async {
    try {
      // For web, use platform-specific launch mode
      final LaunchMode mode = kIsWeb
          ? LaunchMode.platformDefault
          : LaunchMode.externalApplication;

      if (await canLaunchUrl(url)) {
        final success = await launchUrl(url, mode: mode);
        return WhatsAppLaunchResult(success: success);
      } else {
        return const WhatsAppLaunchResult(
          success: false,
          error: 'Cannot launch WhatsApp',
        );
      }
    } catch (e) {
      return WhatsAppLaunchResult(
        success: false,
        error: e.toString(),
      );
    }
  }

  /// Convenience method: build message and launch in one call.
  static Future<WhatsAppLaunchResult> sendOrderMessage({
    required String storePhone,
    required String orderId,
    required String customerName,
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
  }) async {
    final message = buildInvoiceMessage(
      orderId: orderId,
      customerName: customerName,
      address: address,
      phone: phone,
      items: items,
      productsTotal: productsTotal,
      finalTotal: finalTotal,
      discountAmount: discountAmount,
      deliveryFee: deliveryFee,
      deliveryZoneName: deliveryZoneName,
      coupon: coupon,
      notes: notes,
    );

    final url = buildWhatsAppUrl(storePhone, message);
    return launchWhatsApp(url);
  }

  // ================== Helper Methods ==================

  /// Get the correct image URL for a product based on selected color.
  /// If a color is selected, tries to find a matching image from the gallery.
  static String getCorrectImageUrl(Product product, String? selectedColor) {
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

  /// Build invoice items from a list of objects that have product data.
  /// Helper to convert domain objects to the Map format expected by buildInvoiceMessage.
  static List<Map<String, dynamic>> buildInvoiceItems({
    required List<InvoiceItem> items,
  }) {
    return items.map((item) => item.toMap()).toList();
  }
}
