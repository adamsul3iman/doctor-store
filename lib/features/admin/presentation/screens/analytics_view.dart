import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../shared/services/analytics_service.dart';
import '../widgets/live_users_widget.dart';

/// صفحة الإحصائيات في لوحة التحكم
class AnalyticsView extends StatefulWidget {
  const AnalyticsView({super.key});

  @override
  State<AnalyticsView> createState() => _AnalyticsViewState();
}

class _AnalyticsViewState extends State<AnalyticsView> {
  Map<String, dynamic>? _dashboardStats;
  List<Map<String, dynamic>> _topProducts = [];
  List<Map<String, dynamic>> _weeklyStats = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAnalyticsData();
  }

  Future<void> _loadAnalyticsData() async {
    setState(() => _isLoading = true);
    
    try {
      final results = await Future.wait([
        AnalyticsService.instance.getDashboardStats(),
        AnalyticsService.instance.getTopProducts(limit: 10),
        AnalyticsService.instance.getAnalyticsForDays(7),
      ]);
      
      if (mounted) {
        setState(() {
          _dashboardStats = results[0] as Map<String, dynamic>?;
          _topProducts = (results[1] as List).cast<Map<String, dynamic>>();
          _weeklyStats = (results[2] as List).cast<Map<String, dynamic>>();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text(
          'الإحصائيات والتحليلات',
          style: GoogleFonts.almarai(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF0A2647),
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _loadAnalyticsData,
            icon: const Icon(Icons.refresh),
            tooltip: 'تحديث',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadAnalyticsData,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Live Users Widget
                    const LiveUsersWidget(),
                    const SizedBox(height: 24),
                    
                    // Dashboard Stats Cards
                    _buildStatsGrid(),
                    const SizedBox(height: 32),
                    
                    // Top Products Section
                    _buildSection(
                      title: 'المنتجات الأكثر مشاهدة',
                      child: _buildTopProductsList(),
                    ),
                    const SizedBox(height: 32),
                    
                    // Weekly Analytics Chart
                    _buildSection(
                      title: 'إحصائيات آخر 7 أيام',
                      child: _buildWeeklyStatsChart(),
                    ),
                    const SizedBox(height: 32),
                    
                    // Detailed Stats Table
                    _buildSection(
                      title: 'تفاصيل الإحصائيات',
                      child: _buildDetailedStatsTable(),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildStatsGrid() {
    if (_dashboardStats == null) return const SizedBox();

    final stats = [
      {
        'title': 'زيارات اليوم',
        'value': _dashboardStats!['today_visits']?.toString() ?? '0',
        'icon': Icons.visibility,
        'color': const Color(0xFF4CAF50),
      },
      {
        'title': 'مشاهدات المنتجات',
        'value': _dashboardStats!['today_product_views']?.toString() ?? '0',
        'icon': Icons.shopping_bag,
        'color': const Color(0xFF2196F3),
      },
      {
        'title': 'طلبات اليوم',
        'value': _dashboardStats!['today_orders']?.toString() ?? '0',
        'icon': Icons.receipt,
        'color': const Color(0xFFFF9800),
      },
      {
        'title': 'إيرادات اليوم',
        'value': '${_dashboardStats!['today_revenue'] ?? 0} دينار',
        'icon': Icons.attach_money,
        'color': const Color(0xFF9C27B0),
      },
      {
        'title': 'إجمالي المنتجات',
        'value': _dashboardStats!['total_products']?.toString() ?? '0',
        'icon': Icons.inventory,
        'color': const Color(0xFF00BCD4),
      },
      {
        'title': 'إجمالي المستخدمين',
        'value': _dashboardStats!['total_users']?.toString() ?? '0',
        'icon': Icons.people,
        'color': const Color(0xFF795548),
      },
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.85,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: stats.length,
      itemBuilder: (context, index) {
        final stat = stats[index];
        return Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                stat['icon'] as IconData,
                color: stat['color'] as Color,
                size: 20,
              ),
              const SizedBox(height: 6),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  stat['value'] as String,
                  style: GoogleFonts.almarai(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF0A2647),
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                stat['title'] as String,
                style: GoogleFonts.almarai(
                  fontSize: 10,
                  color: Colors.grey[600],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSection({required String title, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.almarai(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF0A2647),
            ),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _buildTopProductsList() {
    if (_topProducts.isEmpty) {
      return Center(
        child: Text(
          'لا توجد بيانات متاحة',
          style: GoogleFonts.almarai(color: Colors.grey),
        ),
      );
    }

    return Column(
      children: _topProducts.take(5).map((product) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              // Product Image
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.grey[200],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: product['image_url'] != null
                      ? Image.network(
                          product['image_url'],
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return const Icon(Icons.image, color: Colors.grey);
                          },
                        )
                      : const Icon(Icons.image, color: Colors.grey),
                ),
              ),
              const SizedBox(width: 12),
              
              // Product Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product['title'] ?? 'منتج بدون اسم',
                      style: GoogleFonts.almarai(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF0A2647),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      product['category_name'] ?? 'بدون تصنيف',
                      style: GoogleFonts.almarai(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              
              // Views Count
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF0A2647).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${product['views'] ?? 0} مشاهدة',
                  style: GoogleFonts.almarai(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF0A2647),
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildWeeklyStatsChart() {
    if (_weeklyStats.isEmpty) {
      return Center(
        child: Text(
          'لا توجد بيانات متاحة',
          style: GoogleFonts.almarai(color: Colors.grey),
        ),
      );
    }

    return Column(
      children: _weeklyStats.map((day) {
        final date = DateTime.parse(day['stats_date']);
        final formattedDate = '${date.day}/${date.month}';
        
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              // Date
              SizedBox(
                width: 60,
                child: Text(
                  formattedDate,
                  style: GoogleFonts.almarai(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF0A2647),
                  ),
                ),
              ),
              
              // Visits Bar
              Expanded(
                child: SizedBox(
                  height: 30,
                  child: Stack(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      FractionallySizedBox(
                        alignment: Alignment.centerRight,
                        widthFactor: (day['visits'] ?? 0) / 100.0, // Max 100 for demo
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF4CAF50),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                      Center(
                        child: Text(
                          '${day['visits'] ?? 0}',
                          style: GoogleFonts.almarai(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              // Other Stats
              const SizedBox(width: 8),
              Text(
                '${day['orders'] ?? 0} طلب',
                style: GoogleFonts.almarai(fontSize: 11, color: Colors.grey[600]),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDetailedStatsTable() {
    if (_dashboardStats == null) return const SizedBox();

    return Table(
      columnWidths: const {
        0: FlexColumnWidth(2),
        1: FlexColumnWidth(1),
      },
      children: [
        _buildTableRow('المستخدمون المتصلون الآن', '${_dashboardStats!['online_users_now'] ?? 0}'),
        _buildTableRow('زيارات اليوم', '${_dashboardStats!['today_visits'] ?? 0}'),
        _buildTableRow('مشاهدات المنتجات اليوم', '${_dashboardStats!['today_product_views'] ?? 0}'),
        _buildTableRow('طلبات اليوم', '${_dashboardStats!['today_orders'] ?? 0}'),
        _buildTableRow('إيرادات اليوم', '${_dashboardStats!['today_revenue'] ?? 0} دينار'),
        _buildTableRow('إجمالي المنتجات', '${_dashboardStats!['total_products'] ?? 0}'),
        _buildTableRow('إجمالي المستخدمين', '${_dashboardStats!['total_users'] ?? 0}'),
      ],
    );
  }

  TableRow _buildTableRow(String label, String value) {
    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            label,
            style: GoogleFonts.almarai(
              fontSize: 14,
              color: Colors.grey[700],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            value,
            style: GoogleFonts.almarai(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF0A2647),
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}
