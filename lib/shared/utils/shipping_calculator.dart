import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:doctor_store/features/cart/application/cart_manager.dart';

/// Helper class لحساب تكلفة الشحن بناءً على أكبر حجم في السلة
class ShippingCalculator {
  static final _supabase = Supabase.instance.client;
  
  /// تحديد أكبر حجم شحن في قائمة المنتجات
  /// الترتيب: small < medium < large < x_large
  static String getLargestShippingSize(List<CartItem> items) {
    if (items.isEmpty) return 'small';
    
    const sizeOrder = {
      'small': 1,
      'medium': 2,
      'large': 3,
      'x_large': 4,
    };
    
    String largestSize = 'small';
    int largestWeight = 1;
    
    for (final item in items) {
      // الحصول على حجم الشحن من options المنتج
      final shippingSize = item.product.options['shipping_size'] as String? ?? 'small';
      final weight = sizeOrder[shippingSize] ?? 1;
      
      if (weight > largestWeight) {
        largestWeight = weight;
        largestSize = shippingSize;
      }
    }
    
    return largestSize;
  }
  
  /// حساب تكلفة الشحن من قاعدة البيانات
  /// يأخذ zone_id (مثل: 'amman') وحجم الشحن
  static Future<double> calculateShippingCost({
    required String zoneId,
    required List<CartItem> items,
  }) async {
    if (items.isEmpty) return 0.0;
    
    // تحديد أكبر حجم في السلة
    final largestSize = getLargestShippingSize(items);
    
    try {
      // جلب السعر من قاعدة البيانات
      final result = await _supabase
          .from('shipping_costs')
          .select('cost')
          .eq('zone_id', zoneId)
          .eq('shipping_size', largestSize)
          .maybeSingle();
      
      if (result != null && result['cost'] != null) {
        return (result['cost'] as num).toDouble();
      }
      
      // إذا لم يوجد سعر محدد، نرجع السعر الافتراضي للحجم الصغير
      final fallback = await _supabase
          .from('shipping_costs')
          .select('cost')
          .eq('zone_id', zoneId)
          .eq('shipping_size', 'small')
          .maybeSingle();
      
      if (fallback != null && fallback['cost'] != null) {
        return (fallback['cost'] as num).toDouble();
      }
      
      // إذا لم يوجد أي سعر، نرجع 3 دينار كافتراضي
      return 3.0;
    } catch (e) {
      // في حالة الخطأ، نرجع سعر افتراضي
      return 3.0;
    }
  }
  
  /// نسخة بسيطة تستقبل zone_id مباشرة
  static Future<double> getShippingCostForZone({
    required String zoneId,
    required String shippingSize,
  }) async {
    try {
      final result = await _supabase
          .from('shipping_costs')
          .select('cost')
          .eq('zone_id', zoneId)
          .eq('shipping_size', shippingSize)
          .maybeSingle();
      
      if (result != null && result['cost'] != null) {
        return (result['cost'] as num).toDouble();
      }
      
      return 3.0;
    } catch (e) {
      return 3.0;
    }
  }
  
  /// تحويل اسم المحافظة إلى zone_id
  static String zoneNameToId(String zoneName) {
    const mapping = {
      'عمان': 'amman',
      'إربد': 'irbid',
      'الزرقاء': 'zarqa',
      'عجلون': 'ajloun',
      'جرش': 'jerash',
      'السلط': 'salt',
      'مادبا': 'madaba',
      'الكرك': 'karak',
      'الطفيلة': 'tafilah',
      'معان': 'maan',
      'العقبة': 'aqaba',
      'المفرق': 'mafraq',
    };
    
    return mapping[zoneName] ?? 'amman';
  }
  
  /// الحصول على اسم الحجم بالعربية
  static String getSizeLabel(String size) {
    switch (size) {
      case 'small':
        return 'صغير';
      case 'medium':
        return 'متوسط';
      case 'large':
        return 'كبير';
      case 'x_large':
        return 'كبير جداً';
      default:
        return 'صغير';
    }
  }
}
