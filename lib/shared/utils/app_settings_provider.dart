import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// نموذج إعدادات التطبيق
class AppSettings {
  final bool freeShippingEnabled; // تفعيل/إخفاء بانر الشحن المجاني
  final double freeShippingThreshold; // حد الشحن المجاني
  final double bundleDiscountPercent; // نسبة خصم المجموعة
  final double firstTimeDiscountPercent; // نسبة خصم العملاء الجدد
  final String firstTimeDiscountCode; // كود خصم العملاء الجدد

  AppSettings({
    this.freeShippingEnabled = true,
    this.freeShippingThreshold = 100.0,
    this.bundleDiscountPercent = 10.0,
    this.firstTimeDiscountPercent = 15.0,
    this.firstTimeDiscountCode = 'WELCOME15',
  });

  static double _asDouble(dynamic v, double fallback) {
    if (v == null) return fallback;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? fallback;
    return fallback;
  }

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      freeShippingEnabled: (json['free_shipping_enabled'] as bool?) ?? true,
      freeShippingThreshold: _asDouble(json['free_shipping_threshold'], 100.0),
      bundleDiscountPercent: _asDouble(json['bundle_discount_percent'], 10.0),
      firstTimeDiscountPercent: _asDouble(json['first_time_discount_percent'], 15.0),
      firstTimeDiscountCode: json['first_time_discount_code']?.toString() ?? 'WELCOME15',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'free_shipping_enabled': freeShippingEnabled,
      'free_shipping_threshold': freeShippingThreshold,
      'bundle_discount_percent': bundleDiscountPercent,
      'first_time_discount_percent': firstTimeDiscountPercent,
      'first_time_discount_code': firstTimeDiscountCode,
    };
  }
}

/// مزود إعدادات التطبيق
final appSettingsProvider = FutureProvider<AppSettings>((ref) async {
  try {
    final supabase = Supabase.instance.client;
    
    // جلب الإعدادات من جدول app_settings
    final response = await supabase
        .from('app_settings')
        .select()
        .eq('id', 1) // نفترض أن ID الإعدادات هو 1
        .single();
    
    return AppSettings.fromJson(response);
  } catch (e) {
    // في حالة الخطأ أو عدم وجود الجدول، نرجع القيم الافتراضية
    return AppSettings();
  }
});

/// Stream للإعدادات للتحديث الفوري
final appSettingsStreamProvider = StreamProvider<AppSettings>((ref) {
  try {
    final supabase = Supabase.instance.client;
    
    return supabase
        .from('app_settings')
        .stream(primaryKey: ['id'])
        .eq('id', 1)
        .map((data) {
          if (data.isEmpty) return AppSettings();
          return AppSettings.fromJson(data.first);
        });
  } catch (e) {
    // في حالة الخطأ، نرجع stream بالقيم الافتراضية
    return Stream.value(AppSettings());
  }
});
