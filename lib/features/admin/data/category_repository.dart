import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:doctor_store/shared/utils/categories_provider.dart';

class CategoryRepository {
  SupabaseClient? _getClientOrNull() {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  Future<List<AppCategoryConfig>> getCategories() async {
    final client = _getClientOrNull();
    if (client == null) return <AppCategoryConfig>[];

    final data = await client
        .from('categories')
        .select('id,name,is_active,sort_order')
        .order('sort_order', ascending: true);
    
    return data
        .whereType<Map<String, dynamic>>()
        .map(AppCategoryConfig.fromMap)
        .toList();
  }
}
