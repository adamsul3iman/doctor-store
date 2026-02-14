import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AppCategoryConfig {
  final String id;
  final String name;
  final String subtitle;
  final Color color;
  final String iconName;
  final bool isActive;
  final int sortOrder;

  AppCategoryConfig({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.color,
    required this.iconName,
    required this.isActive,
    required this.sortOrder,
  });

  /// يرجع الأيقونة المناسبة بناءً على اسم الأيقونة المخزن في قاعدة البيانات
  IconData get icon => _iconFromName(iconName);

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
      iconName: map['icon_name'] as String? ?? 'box',
      isActive: (map['is_active'] as bool?) ?? true,
      sortOrder: (map['sort_order'] as int?) ?? 0,
    );
  }
}

/// خريطة الأيقونات المتاحة - يمكن للأدمن اختيار اسم الأيقونة من هذه القائمة
const Map<String, IconData> availableCategoryIcons = {
  'bed': FontAwesomeIcons.bed,
  'table': Icons.table_restaurant_rounded,
  'baby': FontAwesomeIcons.baby,
  'carpet': FontAwesomeIcons.rug,
  'pillow': FontAwesomeIcons.cloud,
  'couch': FontAwesomeIcons.couch,
  'leaf': FontAwesomeIcons.leaf,
  'shower': FontAwesomeIcons.shower,
  'curtains': FontAwesomeIcons.windowMaximize,
  'mattress': FontAwesomeIcons.bedPulse,
  'box': FontAwesomeIcons.box,
  'star': FontAwesomeIcons.star,
  'heart': FontAwesomeIcons.heart,
  'home': FontAwesomeIcons.house,
  'gift': FontAwesomeIcons.gift,
  'percent': FontAwesomeIcons.percent,
  'fire': FontAwesomeIcons.fire,
  'tag': FontAwesomeIcons.tag,
};

IconData _iconFromName(String name) {
  return availableCategoryIcons[name] ?? FontAwesomeIcons.box;
}

/// مزود لجلب إعدادات الأقسام من جدول `categories`.
/// إذا لم يكن الجدول موجوداً أو حدث خطأ، يرجع قائمة فارغة ويتم استخدام القيم الافتراضية في الواجهة.
final categoriesConfigProvider =
    FutureProvider<List<AppCategoryConfig>>((ref) async {
  SupabaseClient? supabase;
  try {
    supabase = Supabase.instance.client;
  } catch (_) {
    return [];
  }

  try {
    final data = await supabase
        .from('categories')
        .select('id,name,subtitle,color_value,icon_name,is_active,sort_order')
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

/// خريطة سريعة لاسم القسم حسب الـ id (لتقليل العمل داخل كل كرت منتج).
final categoryLabelByIdProvider = Provider<Map<String, String>>((ref) {
  final cats = ref.watch(categoriesConfigProvider).asData?.value;
  if (cats == null || cats.isEmpty) return const <String, String>{};

  final map = <String, String>{};
  for (final c in cats) {
    final name = c.name.trim();
    if (name.isNotEmpty) map[c.id] = name;
  }
  return map;
});
