import 'package:supabase_flutter/supabase_flutter.dart';

class OrderRepository {
  SupabaseClient? _getClientOrNull() {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  Stream<List<Map<String, dynamic>>> watchOrders() {
    final client = _getClientOrNull();
    if (client == null) return const Stream.empty();

    return client
        .from('orders')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false);
  }

  Future<void> deleteOrder(String orderId) async {
    final client = _getClientOrNull();
    if (client == null) return;

    await client.from('orders').delete().eq('id', orderId);
  }

  Future<List<Map<String, dynamic>>> getOrderItems(String orderId) async {
    final client = _getClientOrNull();
    if (client == null) return <Map<String, dynamic>>[];

    final data = await client.from('order_items').select().eq('order_id', orderId);
    return List<Map<String, dynamic>>.from(data as List);
  }

  Future<void> updateOrderStatus(String orderId, String status) async {
    final client = _getClientOrNull();
    if (client == null) return;

    await client.from('orders').update({'status': status}).eq('id', orderId);
  }
}
