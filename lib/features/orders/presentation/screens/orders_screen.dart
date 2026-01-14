import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart'; // لتنسيق التاريخ
import 'package:doctor_store/core/theme/app_theme.dart';
import 'package:doctor_store/shared/widgets/quick_nav_bar.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  late Future<List<Map<String, dynamic>>> _ordersFuture;

  @override
  void initState() {
    super.initState();
    _ordersFuture = _fetchMyOrders();
  }

  Future<List<Map<String, dynamic>>> _fetchMyOrders() async {
    SupabaseClient? client;
    try {
      client = Supabase.instance.client;
    } catch (e) {
      // في حال لم يتم تهيئة Supabase أو في بيئات الاختبار نرجع قائمة فارغة بدلاً من كسر التطبيق
      debugPrint('Supabase not initialized when fetching orders: $e');
      return [];
    }

    final user = client.auth.currentUser;
    if (user == null) return []; // حماية: إذا لم يكن مسجلاً

    try {
      final raw = await client
          .from('orders')
          .select('id,created_at,status,total_amount')
          .eq('user_id', user.id)
          .order('created_at', ascending: false);

      final data = raw;

      final List<Map<String, dynamic>> orders = [];
      for (final item in data) {
        orders.add(item);
            }
      return orders;
    } catch (e) {
      debugPrint('Error fetching orders: $e');
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("طلباتي السابقة"),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.menu_rounded),
            tooltip: 'القائمة السريعة',
            onPressed: () => showQuickNavBar(context),
          ),
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _ordersFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.shopping_bag_outlined, size: 80, color: Colors.grey[300]),
                  const SizedBox(height: 20),
                  Text("لا توجد طلبات سابقة", style: GoogleFonts.almarai(fontSize: 18, color: Colors.grey)),
                ],
              ),
            );
          }

          final orders = snapshot.data!;

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: orders.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final order = orders[index];
              return OrderCard(order: order);
            },
          );
        },
      ),
    );
  }

}

/// كرت واحد لعرض تفاصيل طلب معيّن (يُستخدم في الشاشة وفي الاختبارات).
class OrderCard extends StatelessWidget {
  final Map<String, dynamic> order;

  const OrderCard({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    DateTime date;
    final rawDate = order['created_at'];
    if (rawDate is String) {
      try {
        date = DateTime.parse(rawDate);
      } catch (_) {
        date = DateTime.fromMillisecondsSinceEpoch(0);
      }
    } else {
      date = DateTime.fromMillisecondsSinceEpoch(0);
    }
    final formattedDate = DateFormat('yyyy/MM/dd - hh:mm a').format(date);

    // الحالة القادمة من قاعدة البيانات (new, processing, completed, cancelled)
    final dbStatus = order['status']?.toString() ?? 'new';

    // استخدام الحقل الصحيح من جدول orders (total_amount)
    final total = (order['total_amount'] as num?)?.toDouble() ?? 0;

    final rawId = order['id'];
    final idString = rawId?.toString() ?? '';
    final shortId = idString.length > 8 ? idString.substring(0, 8) : idString;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 5,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "#$shortId",
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
              buildOrderStatusBadge(dbStatus),
            ],
          ),
          const Divider(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "تاريخ الطلب:",
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
              Text(
                formattedDate,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "الإجمالي:",
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
              Text(
                "$total د.أ",
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  color: AppTheme.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// دالة عامة يمكن إعادة استخدامها في الاختبارات لعرض بادج حالة الطلب.
@visibleForTesting
Widget buildOrderStatusBadge(String dbStatus) {
  late final Color color;
  late final String label;

  switch (dbStatus) {
    case 'completed':
      color = Colors.green;
      label = 'مكتمل';
      break;
    case 'cancelled':
      color = Colors.red;
      label = 'ملغي';
      break;
    case 'processing':
      color = const Color(0xFFD4AF37);
      label = 'قيد التنفيذ';
      break;
    case 'new':
    default:
      color = const Color(0xFFD4AF37);
      label = 'قيد المراجعة';
      break;
  }

  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: color.withValues(alpha: 0.5)),
    ),
    child: Text(
      label,
      style: TextStyle(
        color: color,
        fontSize: 11,
        fontWeight: FontWeight.bold,
      ),
    ),
  );
}
