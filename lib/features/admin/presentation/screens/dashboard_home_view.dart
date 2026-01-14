import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart' as intl;
// ✅ نستورد ملف الودجت من نفس المجلد
import 'dashboard_chart.dart'; 
import 'admin_orders_view.dart';

class DashboardHomeView extends StatefulWidget {
  const DashboardHomeView({super.key});

  @override
  State<DashboardHomeView> createState() => _DashboardHomeViewState();
}

class _DashboardHomeViewState extends State<DashboardHomeView> {
  bool _isLoading = true;
  Map<String, dynamic> _stats = {
    'revenue': 0,
    'new_orders': 0,
    'clients': 0,
    'products': 0,
    'visits': 0,
  };
  List<Map<String, dynamic>> _salesData = [];

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        Supabase.instance.client.rpc('get_dashboard_stats'),
        Supabase.instance.client.rpc('get_weekly_sales'),
      ]);
      
      if (mounted) {
        setState(() {
          _stats = results[0] as Map<String, dynamic>;
          _salesData = List<Map<String, dynamic>>.from(results[1] as List);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching dashboard data: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    return RefreshIndicator(
      onRefresh: _fetchData,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("مرحباً بك دكتور، إليك ملخص الأداء 🚀", style: GoogleFonts.almarai(fontSize: 18, color: Colors.grey[700])),
            const SizedBox(height: 20),
            
            LayoutBuilder(
              builder: (context, constraints) {
                int crossAxisCount = constraints.maxWidth > 900 ? 4 : (constraints.maxWidth > 600 ? 2 : 1);
                return GridView.count(
                  crossAxisCount: crossAxisCount,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 15,
                  mainAxisSpacing: 15,
                  childAspectRatio: 1.5,
                  children: [
                    _StatCard(title: "المبيعات", value: "${_stats['revenue']} د.أ", icon: Icons.monetization_on, color: Colors.green),
                    _StatCard(title: "طلبات جديدة", value: "${_stats['new_orders']}", icon: FontAwesomeIcons.boxOpen, color: Colors.orange),
                    _StatCard(title: "العملاء", value: "${_stats['clients']}", icon: Icons.people, color: Colors.blue),
                    _StatCard(title: "المنتجات", value: "${_stats['products']}", icon: Icons.inventory_2, color: Colors.purple),
                    _StatCard(title: "زيارات الموقع", value: "${_stats['visits'] ?? 0}", icon: Icons.visibility, color: Colors.teal),
                  ],
                );
              },
            ),

            const SizedBox(height: 30),
            
            // ✅ هنا نستدعي الكلاس من الملف المنفصل
            SalesChart(salesData: _salesData),

            const SizedBox(height: 30),
            const _LatestOrdersPreview(),
            
            const SizedBox(height: 50),
          ],
        ),
      ),
    );
  }
}

class _LatestOrdersPreview extends StatefulWidget {
  const _LatestOrdersPreview();

  @override
  State<_LatestOrdersPreview> createState() => _LatestOrdersPreviewState();
}

class _LatestOrdersPreviewState extends State<_LatestOrdersPreview> {
  // نحتفظ بآخر قائمة طلبات ناجحة لعرضها عند حدوث أخطاء مؤقتة
  List<Map<String, dynamic>>? _lastOrders;

  @override
  Widget build(BuildContext context) {
    final client = Supabase.instance.client;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'أحدث الطلبات',
              style: GoogleFonts.almarai(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF0A2647),
              ),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const AdminOrdersView(),
                  ),
                );
              },
              icon: const Icon(Icons.open_in_new, size: 18),
              label: const Text('عرض كل الطلبات'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: StreamBuilder<List<Map<String, dynamic>>>(
            stream: client
                .from('orders')
                .stream(primaryKey: ['id'])
                .order('created_at', ascending: false)
                .limit(5),
            builder: (context, snapshot) {
              // لا نعرض الخطأ للمستخدم، فقط نطبعه في الكونسول
              if (snapshot.hasError) {
                debugPrint('LatestOrdersPreview stream error: ${snapshot.error}');
              }

              List<Map<String, dynamic>>? effectiveOrders;

              if (snapshot.hasData && !snapshot.hasError) {
                effectiveOrders = snapshot.data;
                _lastOrders = snapshot.data;
              } else if (_lastOrders != null) {
                // في حال انقطاع مؤقت أو خطأ في Realtime نستخدم آخر بيانات ناجحة
                effectiveOrders = _lastOrders;
              }

              if (snapshot.connectionState == ConnectionState.waiting &&
                  (effectiveOrders == null || effectiveOrders.isEmpty)) {
                return const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: SizedBox(
                    height: 80,
                    child: Center(child: CircularProgressIndicator()),
                  ),
                );
              }

              if (effectiveOrders == null || effectiveOrders.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: SizedBox(
                    height: 60,
                    child: Center(
                      child: Text(
                        'لا توجد طلبات حديثة',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  ),
                );
              }

              final orders = effectiveOrders;

              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: orders.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final order = orders[index];
                  final status = (order['status'] ?? 'new').toString();
                  final total = (order['total_amount'] as num?)?.toDouble() ?? 0.0;

                  DateTime date;
                  final rawDate = order['created_at'];
                  if (rawDate is String) {
                    try {
                      date = DateTime.parse(rawDate).toLocal();
                    } catch (_) {
                      date = DateTime.fromMillisecondsSinceEpoch(0);
                    }
                  } else {
                    date = DateTime.fromMillisecondsSinceEpoch(0);
                  }

                  Color statusColor = Colors.blue;
                  String statusText = 'جديد';
                  if (status == 'completed') {
                    statusColor = Colors.green;
                    statusText = 'مكتمل';
                  } else if (status == 'cancelled') {
                    statusColor = Colors.red;
                    statusText = 'ملغي';
                  }

                  return ListTile(
                    dense: true,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    leading: CircleAvatar(
                      backgroundColor: statusColor.withValues(alpha: 0.1),
                      child: Icon(Icons.shopping_bag, color: statusColor, size: 18),
                    ),
                    title: Text(
                      order['customer_name']?.toString() ?? 'عميل بدون اسم',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      '${intl.DateFormat('yyyy/MM/dd HH:mm').format(date)} • ${total.toStringAsFixed(2)} د.أ',
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        statusText,
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({required this.title, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: color.withValues(alpha: 0.1), blurRadius: 10, offset: const Offset(0, 4))],
        border: Border.all(color: color.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 10),
              Text(title, style: GoogleFonts.almarai(color: Colors.grey[600], fontWeight: FontWeight.bold)),
            ],
          ),
          const Spacer(),
          Text(
            value,
            style: GoogleFonts.almarai(fontSize: 24, fontWeight: FontWeight.bold, color: const Color(0xFF0A2647)),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}