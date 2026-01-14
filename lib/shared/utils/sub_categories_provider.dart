import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AppSubCategory {
  final String id;
  final String name;
  final String parentCategoryId;
  final int sortOrder;
  final bool isActive;

  const AppSubCategory({
    required this.id,
    required this.name,
    required this.parentCategoryId,
    required this.sortOrder,
    required this.isActive,
  });

  factory AppSubCategory.fromMap(Map<String, dynamic> map) {
    return AppSubCategory(
      id: map['id'] as String,
      name: map['name'] as String? ?? '',
      parentCategoryId: map['parent_category_id'] as String,
      sortOrder: (map['sort_order'] as int?) ?? 0,
      isActive: (map['is_active'] as bool?) ?? true,
    );
  }
}

/// مزود لجلب الفئات الفرعية النشطة لفئة رئيسية معيّنة من جدول `sub_categories`.
final subCategoriesByParentProvider =
    FutureProvider.family<List<AppSubCategory>, String>((ref, parentId) async {
  final supabase = Supabase.instance.client;
  try {
    final data = await supabase
        .from('sub_categories')
        .select('id,name,parent_category_id,sort_order,is_active')
        .eq('parent_category_id', parentId)
        .eq('is_active', true)
        .order('sort_order', ascending: true);

    return data
        .whereType<Map<String, dynamic>>()
        .map(AppSubCategory.fromMap)
        .toList();
  } catch (e) {
    debugPrint('Error loading sub categories: $e');
    return [];
  }
});