import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:doctor_store/features/orders/domain/models/order_model.dart';

class OrderRepository {
  SupabaseClient? _getClientOrNull() {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  /// Stream orders with type-safe Order model
  Stream<List<Order>> watchOrders() {
    final client = _getClientOrNull();
    if (client == null) return const Stream.empty();

    return client
        .from('orders')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .map((data) => data.map((json) => Order.fromJson(json)).toList());
  }

  Future<void> deleteOrder(String orderId) async {
    final client = _getClientOrNull();
    if (client == null) return;

    await client.from('orders').delete().eq('id', orderId);
  }

  /// Get order items with type-safe OrderItem model
  Future<List<OrderItem>> getOrderItems(String orderId) async {
    final client = _getClientOrNull();
    if (client == null) return [];

    final data =
        await client.from('order_items').select().eq('order_id', orderId);
    return (data as List).map((json) => OrderItem.fromJson(json)).toList();
  }

  /// Update order status with type-safe enum
  /// Throws exception on failure so UI can handle error feedback
  Future<void> updateOrderStatus(String orderId, OrderStatus status) async {
    final client = _getClientOrNull();
    if (client == null) {
      throw Exception('Supabase client not available');
    }

    // Convert enum to DB string value
    final statusString = status.toDbString();
    debugPrint('Updating order $orderId status to: $statusString');

    try {
      await client
          .from('orders')
          .update({'status': statusString}).eq('id', orderId);
      debugPrint('Order status updated successfully');
    } catch (e) {
      debugPrint('Error updating order status in repository: $e');
      rethrow;
    }
  }
}
