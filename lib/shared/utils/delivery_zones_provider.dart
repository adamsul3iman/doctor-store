import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DeliveryZone {
  final String id;
  final String name;
  final double price;
  final bool isActive;
  final int sortOrder;

  DeliveryZone({
    required this.id,
    required this.name,
    required this.price,
    required this.isActive,
    required this.sortOrder,
  });

  factory DeliveryZone.fromMap(Map<String, dynamic> map) {
    return DeliveryZone(
      id: map['id']?.toString() ?? '',
      name: (map['name'] as String?) ?? '',
      price: (map['price'] as num?)?.toDouble() ?? 0.0,
      isActive: (map['is_active'] as bool?) ?? true,
      sortOrder: (map['sort_order'] as num?)?.toInt() ?? 0,
    );
  }
}

/// FutureProvider يقوم بجلب جميع مناطق التوصيل المفعّلة من Supabase
final deliveryZonesProvider = FutureProvider<List<DeliveryZone>>((ref) async {
  try {
    final supabase = Supabase.instance.client;

    final rawData = await supabase
        .from('delivery_zones')
        .select('id, name, price, is_active, sort_order')
        .eq('is_active', true)
        .order('sort_order', ascending: true);

    final List<DeliveryZone> zones = [];
    for (final row in rawData) {
      zones.add(DeliveryZone.fromMap(row));
        }
    return zones;
  } catch (_) {
    // في حال أي خطأ في الشبكة أو عدم تهيئة Supabase نرجع قائمة فارغة
    return <DeliveryZone>[];
  }
});
