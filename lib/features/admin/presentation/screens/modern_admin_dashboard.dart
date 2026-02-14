import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';

import '../widgets/dashboard/stats_card.dart';
import '../widgets/dashboard/quick_actions_grid.dart';
import '../widgets/dashboard/sales_chart.dart';
import '../widgets/dashboard/recent_activities.dart';
import '../../data/services/admin_dashboard_service.dart';

class ModernAdminDashboard extends ConsumerStatefulWidget {
  final Function(int)? onNavigateToTab;
  
  const ModernAdminDashboard({super.key, this.onNavigateToTab});

  @override
  ConsumerState<ModernAdminDashboard> createState() => _ModernAdminDashboardState();
}

class _ModernAdminDashboardState extends ConsumerState<ModernAdminDashboard> {
  final AdminDashboardService _dashboardService = AdminDashboardService();

  bool _isLoading = true;
  
  DashboardStats? _stats;
  List<SalesData>? _salesData;
  List<RecentActivity>? _activities;
  int? _realtimeOrdersCount;
  List<TopProduct>? _topProducts;
  QuickAnalytics? _quickAnalytics;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
    _setupRealtimeUpdates();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);
    
    try {
      final results = await Future.wait([
        _dashboardService.getDashboardStats(),
        _dashboardService.getWeeklySales(),
        _dashboardService.getRecentActivities(),
        _dashboardService.getTopProducts(limit: 3),
        _dashboardService.getQuickAnalytics(),
      ]);
      
      if (mounted) {
        setState(() {
          _stats = results[0] as DashboardStats;
          _salesData = results[1] as List<SalesData>;
          _activities = results[2] as List<RecentActivity>;
          _topProducts = results[3] as List<TopProduct>;
          _quickAnalytics = results[4] as QuickAnalytics;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('خطأ في تحميل بيانات Dashboard: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _setupRealtimeUpdates() {
    // تحديث فوري لعدد الطلبات الجديدة
    _dashboardService.getNewOrdersCountStream().listen((count) {
      if (mounted && count != _realtimeOrdersCount) {
        setState(() {
          _realtimeOrdersCount = count;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return _isLoading
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: _loadDashboardData,
            child: _buildBody(),
          );
  }

  Widget _buildBody() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildWelcomeSection(),
          const SizedBox(height: 24),
          _buildStatsCards(),
          const SizedBox(height: 24),
          QuickActionsGrid(onActionTap: _handleQuickAction),
          const SizedBox(height: 24),
          _buildAnalyticsSection(),
          const SizedBox(height: 24),
          SalesChart(salesData: _salesData, trend: _stats?.salesTrend),
          const SizedBox(height: 24),
          _buildTopProductsSection(),
          const SizedBox(height: 24),
          RecentActivitiesList(activities: _activities),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildWelcomeSection() {
    final stats = _stats ?? DashboardStats.empty();
    final now = DateTime.now();
    final greeting = now.hour < 12
        ? 'صباح الخير'
        : now.hour < 18
            ? 'مساء الخير'
            : 'مساء الخير';
    
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0A2647), Color(0xFF144272), Color(0xFF205295)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0A2647).withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '$greeting 👋',
                      style: GoogleFonts.almarai(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'إليك نظرة سريعة على أداء متجرك اليوم',
                      style: GoogleFonts.almarai(
                        fontSize: 14,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.3),
                    width: 2,
                  ),
                ),
                child: const Icon(
                  Icons.dashboard_customize,
                  color: Color(0xFFD4AF37),
                  size: 36,
                ),
              ),
            ],
          ),
          if (stats.newOrdersCount > 0) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFF6F00).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFFFF6F00).withValues(alpha: 0.5),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.notifications_active,
                    color: Color(0xFFFFD700),
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'لديك ${stats.newOrdersCount} طلب جديد يحتاج إلى معالجة!',
                      style: GoogleFonts.almarai(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatsCards() {
    final stats = _stats ?? DashboardStats.empty();
    final salesTrend = double.tryParse(stats.salesTrend) ?? 0.0;
    final trendSign = salesTrend >= 0 ? '+' : '';

    const navy = Color(0xFF0A2647);
    const navy2 = Color(0xFF144272);
    const orange = Color(0xFFFF6F00);
    const orange2 = Color(0xFFE65100);
    
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: StatsCard(
                title: 'إجمالي المبيعات',
                value: '${stats.totalSales.toStringAsFixed(0)} د.أ',
                subtitle: 'هذا الشهر',
                trend: '$trendSign${stats.salesTrend}%',
                icon: Icons.attach_money,
                gradientColors: const [navy, navy2],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: StatsCard(
                title: 'الطلبات الجديدة',
                value: '${_realtimeOrdersCount ?? stats.newOrdersCount}',
                subtitle: 'طلب قيد المعالجة',
                trend: null,
                icon: Icons.shopping_bag,
                gradientColors: const [orange, orange2],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: StatsCard(
                title: 'المنتجات',
                value: '${stats.activeProductsCount}',
                subtitle: 'منتج نشط',
                trend: null,
                icon: Icons.inventory,
                gradientColors: const [navy2, navy],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: StatsCard(
                title: 'العملاء',
                value: '${stats.clientsCount}',
                subtitle: 'عميل مسجل',
                trend: null,
                icon: Icons.people,
                gradientColors: const [orange2, orange],
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _handleQuickAction(String action) {
    // فهرس الصفحات في AdminDashboard:
    // 0: الرئيسية, 1: الطلبات, 2: المنتجات, 3: الأقسام, 4: الفئات الفرعية,
    // 5: الكوبونات, 6: مناطق التوصيل, 7: أسعار الشحن, 8: البانرات,
    // 9: العملاء, 10: التقييمات, 11: الإعدادات
    
    switch (action) {
      case 'add_product':
        // إضافة منتج جديد - الانتقال لصفحة منفصلة
        context.push('/admin/add');
        break;
      case 'add_coupon':
        // الانتقال لصفحة الكوبونات (فهرس 5)
        widget.onNavigateToTab?.call(5);
        break;
      case 'add_banner':
        // الانتقال لصفحة البانرات (فهرس 8)
        widget.onNavigateToTab?.call(8);
        break;
      case 'view_orders':
        // الانتقال لصفحة الطلبات (فهرس 1)
        widget.onNavigateToTab?.call(1);
        break;
      case 'view_clients':
        // الانتقال لصفحة العملاء (فهرس 9)
        widget.onNavigateToTab?.call(9);
        break;
      case 'settings':
        // الانتقال لصفحة الإعدادات (فهرس 11)
        widget.onNavigateToTab?.call(11);
        break;
    }
  }

  /// قسم التحليلات السريعة
  Widget _buildAnalyticsSection() {
    final analytics = _quickAnalytics ?? QuickAnalytics.empty();
    
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.analytics, color: const Color(0xFFFF6F00), size: 24),
                const SizedBox(width: 8),
                Text(
                  'تحليلات سريعة',
                  style: GoogleFonts.almarai(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF0A2647),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _buildAnalyticItem(
                    'متوسط قيمة الطلب',
                    '${analytics.avgOrderValue.toStringAsFixed(0)} د.أ',
                    Icons.shopping_cart,
                    const Color(0xFF4CAF50),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildAnalyticItem(
                    'معدل التحويل',
                    '${analytics.conversionRate.toStringAsFixed(1)}%',
                    Icons.trending_up,
                    const Color(0xFFFF6F00),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildAnalyticItem(
                    'عملاء جدد',
                    '${analytics.newCustomersCount}',
                    Icons.person_add,
                    const Color(0xFF9C27B0),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildAnalyticItem(
                    'معدل الإشغال',
                    '${analytics.occupancyRate.toStringAsFixed(0)}%',
                    Icons.inventory_2,
                    const Color(0xFF2196F3),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalyticItem(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: GoogleFonts.almarai(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF0A2647),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  title,
                  style: GoogleFonts.almarai(
                    fontSize: 11,
                    color: Colors.grey[600],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// قسم المنتجات الأكثر مبيعاً
  Widget _buildTopProductsSection() {
    final products = _topProducts ?? [];
    final medalColors = [
      const Color(0xFFFFD700), // ذهبي
      const Color(0xFFC0C0C0), // فضي
      const Color(0xFFCD7F32), // برونزي
    ];
    
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.emoji_events, color: const Color(0xFFFFD700), size: 24),
                    const SizedBox(width: 8),
                    Text(
                      'المنتجات الأكثر مبيعاً',
                      style: GoogleFonts.almarai(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF0A2647),
                      ),
                    ),
                  ],
                ),
                TextButton(
                  onPressed: () => context.push('/all_products'),
                  child: Text(
                    'عرض الكل',
                    style: GoogleFonts.almarai(
                      fontSize: 12,
                      color: const Color(0xFF0A2647),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (products.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'لا توجد بيانات مبيعات بعد',
                    style: GoogleFonts.almarai(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ),
              )
            else
              ...products.asMap().entries.map((entry) {
                final index = entry.key;
                final product = entry.value;
                final isLast = index == products.length - 1;
                
                return Column(
                  children: [
                    _buildTopProductItem(
                      rank: index + 1,
                      name: product.name,
                      sales: product.sales,
                      revenue: product.revenue,
                      color: index < medalColors.length 
                          ? medalColors[index] 
                          : Colors.grey,
                    ),
                    if (!isLast) const Divider(height: 24),
                  ],
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildTopProductItem({
    required int rank,
    required String name,
    required String sales,
    required String revenue,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [color, color.withValues(alpha: 0.7)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Center(
            child: Text(
              '#$rank',
              style: GoogleFonts.almarai(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: GoogleFonts.almarai(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF0A2647),
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.shopping_bag_outlined, size: 14, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    sales,
                    style: GoogleFonts.almarai(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              revenue,
              style: GoogleFonts.almarai(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF4CAF50),
              ),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'أفضل $rank',
                style: GoogleFonts.almarai(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
