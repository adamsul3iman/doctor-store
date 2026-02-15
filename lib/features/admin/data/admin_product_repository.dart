import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminProductRepository {
  SupabaseClient? _getClientOrNull() {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> fetchProductsPage({
    required int limit,
    required int offset,
    String? searchQuery,
    String? categoryId,
    bool? isActive,
    bool? isFlashDeal,
    String sortMode = 'created_desc',
  }) async {
    final client = _getClientOrNull();
    if (client == null) return <Map<String, dynamic>>[];

    dynamic q = client.from('products').select();

    final sq = (searchQuery ?? '').trim();
    if (sq.isNotEmpty) {
      final escaped = sq.replaceAll(',', r'\\,');
      // ✅ إصلاح: البحث فقط في title لأن id من نوع UUID لا يمكن البحث فيه بـ ilike
      q = q.ilike('title', '%$escaped%');
    }

    final cat = (categoryId ?? '').trim();
    if (cat.isNotEmpty) {
      q = q.eq('category', cat);
    }

    if (isActive != null) {
      q = q.eq('is_active', isActive);
    }

    if (isFlashDeal != null) {
      q = q.eq('is_flash_deal', isFlashDeal);
    }

    switch (sortMode) {
      case 'price_asc':
        q = q.order('price', ascending: true);
        break;
      case 'price_desc':
        q = q.order('price', ascending: false);
        break;
      case 'created_desc':
      default:
        q = q.order('created_at', ascending: false);
        break;
    }

    final data = await q.range(offset, offset + limit - 1);
    return List<Map<String, dynamic>>.from(data as List);
  }

  Future<void> upsertProduct({required Map<String, dynamic> productData, String? productId}) async {
    final client = _getClientOrNull();
    if (client == null) return;

    if (productId != null && productId.isNotEmpty) {
      await client.from('products').update(productData).eq('id', productId);
      return;
    }

    await client.from('products').insert(productData);
  }

  Future<String> uploadProductImage({required String path, required Uint8List bytes}) async {
    final client = _getClientOrNull();
    if (client == null) return '';

    await client.storage.from('products').uploadBinary(path, bytes);
    return client.storage.from('products').getPublicUrl(path);
  }

  Future<void> setFlashDeal({required String productId, required bool isFlashDeal}) async {
    final client = _getClientOrNull();
    if (client == null) return;

    await client
        .from('products')
        .update({'is_flash_deal': isFlashDeal})
        .eq('id', productId);
  }

  Future<void> setActive({required String productId, required bool isActive}) async {
    final client = _getClientOrNull();
    if (client == null) return;

    await client
        .from('products')
        .update({'is_active': isActive})
        .eq('id', productId);
  }

  Future<List<Map<String, dynamic>>> deleteProduct(String productId) async {
    final client = _getClientOrNull();
    if (client == null) return <Map<String, dynamic>>[];

    final deleted = await client
        .from('products')
        .delete()
        .eq('id', productId)
        .select();
    return List<Map<String, dynamic>>.from(deleted as List);
  }

  Stream<List<Map<String, dynamic>>> watchProducts() {
    final client = _getClientOrNull();
    if (client == null) return const Stream.empty();

    return client
        .from('products')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false);
  }
}
