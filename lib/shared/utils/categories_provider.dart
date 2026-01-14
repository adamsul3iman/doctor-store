import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AppCategoryConfig {
  final String id;
  final String name;
  final String subtitle;
  final Color color;
  final bool isActive;
  final int sortOrder;

  AppCategoryConfig({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.color,
    required this.isActive,
    required this.sortOrder,
  });

  factory AppCategoryConfig.fromMap(Map<String, dynamic> map) {
    final rawColor = map['color_value'];
    Color color;
    if (rawColor is int) {
      color = Color(rawColor);
    } else {
      color = const Color(0xFF0A2647);
    }

    return AppCategoryConfig(
      id: map['id'] as String,
      name: map['name'] as String? ?? '',
      subtitle: map['subtitle'] as String? ?? '',
      color: color,
      isActive: (map['is_active'] as bool?) ?? true,
      sortOrder: (map['sort_order'] as int?) ?? 0,
    );
  }
}

/// مزود لجلب إعدادات الأقسام من جدول `categories`.
/// إذا لم يكن الجدول موجوداً أو حدث خطأ، يرجع قائمة فارغة ويتم استخدام القيم الافتراضية في الواجهة.
final categoriesConfigProvider =
    FutureProvider<List<AppCategoryConfig>>((ref) async {
  final supabase = Supabase.instance.client;
  try {
    final data = await supabase
        .from('categories')
        .select('id,name,subtitle,color_value,is_active,sort_order')
        .eq('is_active', true)
        .order('sort_order', ascending: true);

    return data
        .whereType<Map<String, dynamic>>()
        .map(AppCategoryConfig.fromMap)
        .toList();
  } catch (_) {
    return [];
  }
});