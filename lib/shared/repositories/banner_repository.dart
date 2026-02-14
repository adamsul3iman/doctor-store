import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:doctor_store/shared/models/banner_model.dart';

class BannerRepository {
  SupabaseClient? _getClientOrNull() {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  Future<List<AppBanner>> fetchActiveBanners() async {
    final client = _getClientOrNull();
    if (client == null) return <AppBanner>[];

    try {
      final data = await client
          .from('banners')
          .select()
          .eq('is_active', true)
          .order('sort_order', ascending: true);

      return data.map((e) => AppBanner.fromJson(e)).toList();
    } catch (_) {
      return <AppBanner>[];
    }
  }

  Future<List<Map<String, dynamic>>> fetchActiveBannersByPosition({
    required String position,
  }) async {
    final client = _getClientOrNull();
    if (client == null) return <Map<String, dynamic>>[];

    try {
      final data = await client
          .from('banners')
          .select()
          .eq('is_active', true)
          .eq('position', position)
          .order('sort_order', ascending: true);

      return List<Map<String, dynamic>>.from(data);
    } catch (_) {
      return <Map<String, dynamic>>[];
    }
  }
}
