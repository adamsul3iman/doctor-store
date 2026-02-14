import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminDashboardService {
  final SupabaseClient _client = Supabase.instance.client;

  /// جلب إحصائيات Dashboard الرئيسية
  Future<DashboardStats> getDashboardStats() async {
    try {
      // 1. إجمالي المبيعات (هذا الشهر)
      final now = DateTime.now();
      final startOfMonth = DateTime(now.year, now.month, 1);
      
      final salesResult = await _client
          .from('orders')
          .select('total_amount')
          .gte('created_at', startOfMonth.toIso8601String())
          .not('status', 'eq', 'cancelled');
      
      final totalSales = (salesResult as List)
          .fold<double>(0, (sum, order) => sum + ((order['total_amount'] as num?)?.toDouble() ?? 0));

      // 2. عدد الطلبات الجديدة (pending/new)
      final ordersResult = await _client
          .from('orders')
          .select('id')
          .eq('status', 'new');
      
      final newOrdersCount = (ordersResult as List).length;

      // 3. عدد المنتجات النشطة
      final productsResult = await _client
          .from('products')
          .select('id')
          .eq('is_active', true);
      
      final activeProductsCount = (productsResult as List).length;

      // 4. عدد العملاء المسجلين (من جدول profiles)
      final clientsResult = await _client
          .from('profiles')
          .select('id')
          .count();
      
      final clientsCount = clientsResult.count;

      // حساب نسبة التغيير (مقارنة بالشهر السابق)
      final lastMonth = DateTime(now.year, now.month - 1, 1);
      final endOfLastMonth = DateTime(now.year, now.month, 0, 23, 59, 59);
      
      final lastMonthSales = await _client
          .from('orders')
          .select('total_amount')
          .gte('created_at', lastMonth.toIso8601String())
          .lte('created_at', endOfLastMonth.toIso8601String())
          .not('status', 'eq', 'cancelled');
      
      final lastMonthTotal = (lastMonthSales as List)
          .fold<double>(0, (sum, order) => sum + ((order['total_amount'] as num?)?.toDouble() ?? 0));

      final salesTrend = lastMonthTotal > 0 
          ? ((totalSales - lastMonthTotal) / lastMonthTotal * 100).toStringAsFixed(1)
          : '0.0';

      return DashboardStats(
        totalSales: totalSales,
        salesTrend: salesTrend,
        newOrdersCount: newOrdersCount,
        activeProductsCount: activeProductsCount,
        clientsCount: clientsCount,
      );
    } catch (e) {
      debugPrint('Error fetching dashboard stats: $e');
      return DashboardStats.empty();
    }
  }

  /// جلب بيانات المبيعات لآخر 7 أيام
  Future<List<SalesData>> getWeeklySales() async {
    try {
      final now = DateTime.now();
      final List<SalesData> salesData = [];

      for (int i = 6; i >= 0; i--) {
        final date = now.subtract(Duration(days: i));
        final startOfDay = DateTime(date.year, date.month, date.day);
        final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);

        final result = await _client
            .from('orders')
            .select('total_amount')
            .gte('created_at', startOfDay.toIso8601String())
            .lte('created_at', endOfDay.toIso8601String())
            .not('status', 'eq', 'cancelled');

        final dayTotal = (result as List)
            .fold<double>(0, (sum, order) => sum + ((order['total_amount'] as num?)?.toDouble() ?? 0));

        salesData.add(SalesData(date: startOfDay, amount: dayTotal));
      }

      return salesData;
    } catch (e) {
      debugPrint('Error fetching weekly sales: $e');
      return [];
    }
  }

  /// جلب آخر النشاطات (طلبات + تقييمات + تنبيهات مخزون)
  Future<List<RecentActivity>> getRecentActivities() async {
    try {
      final List<RecentActivity> activities = [];

      // 1. آخر 3 طلبات
      final ordersResult = await _client
          .from('orders')
          .select('id, customer_name, total_amount, status, created_at')
          .order('created_at', ascending: false)
          .limit(3);

      for (final order in ordersResult as List) {
        activities.add(RecentActivity(
          type: ActivityType.order,
          title: 'طلب جديد #${order['id']}',
          subtitle: '${order['customer_name']} - ${(order['total_amount'] as num).toStringAsFixed(2)} د.أ',
          time: DateTime.parse(order['created_at']),
        ));
      }

      // 2. آخر 2 تقييم
      final reviewsResult = await _client
          .from('reviews')
          .select('id, rating, product_id, created_at')
          .order('created_at', ascending: false)
          .limit(2);

      for (final review in reviewsResult as List) {
        final stars = '⭐' * (review['rating'] as int);
        activities.add(RecentActivity(
          type: ActivityType.review,
          title: 'تقييم جديد $stars',
          subtitle: 'مراجعة على منتج',
          time: DateTime.parse(review['created_at']),
        ));
      }

      // ترتيب حسب الوقت
      activities.sort((a, b) => b.time.compareTo(a.time));

      return activities.take(5).toList();
    } catch (e) {
      debugPrint('Error fetching recent activities: $e');
      return [];
    }
  }

  /// Stream للتحديثات الفورية للطلبات الجديدة
  Stream<int> getNewOrdersCountStream() {
    return _client
        .from('orders')
        .stream(primaryKey: ['id'])
        .eq('status', 'new')
        .map((data) => data.length);
  }

  /// جلب المنتجات الأكثر مبيعاً
  Future<List<TopProduct>> getTopProducts({int limit = 3}) async {
    try {
      // جلب المنتجات الأكثر مبيعاً من order_items
      final result = await _client
          .from('order_items')
          .select('product_id, quantity, products(id, title, price)')
          .order('quantity', ascending: false);

      // تجميع البيانات حسب product_id
      final Map<String, TopProductData> productsMap = {};
      
      for (final item in result as List) {
        final productId = item['product_id'] as String?;
        if (productId == null) continue;
        
        final quantity = (item['quantity'] as num?)?.toInt() ?? 0;
        final productData = item['products'] as Map<String, dynamic>?;
        
        if (productData != null) {
          final price = (productData['price'] as num?)?.toDouble() ?? 0;
          final name = productData['title'] as String? ?? 'منتج غير معروف';
          
          if (productsMap.containsKey(productId)) {
            productsMap[productId]!.totalQuantity += quantity;
            productsMap[productId]!.totalRevenue += (quantity * price);
          } else {
            productsMap[productId] = TopProductData(
              productId: productId,
              name: name,
              totalQuantity: quantity,
              totalRevenue: quantity * price,
            );
          }
        }
      }

      // ترتيب وإرجاع أفضل المنتجات
      final topProducts = productsMap.values.toList()
        ..sort((a, b) => b.totalQuantity.compareTo(a.totalQuantity));

      return topProducts
          .take(limit)
          .map((data) => TopProduct(
                name: data.name,
                sales: '${data.totalQuantity} طلب',
                revenue: '${data.totalRevenue.toStringAsFixed(0)} د.أ',
              ))
          .toList();
    } catch (e) {
      debugPrint('Error fetching top products: $e');
      return [];
    }
  }

  /// جلب التحليلات السريعة
  Future<QuickAnalytics> getQuickAnalytics() async {
    try {
      final now = DateTime.now();
      final startOfMonth = DateTime(now.year, now.month, 1);
      
      // 1. جلب جميع الطلبات النشطة هذا الشهر
      final ordersResult = await _client
          .from('orders')
          .select('id, total_amount, customer_phone, created_at')
          .gte('created_at', startOfMonth.toIso8601String())
          .not('status', 'eq', 'cancelled');
      
      final orders = ordersResult as List;
      final totalSales = orders.fold<double>(
        0, 
        (sum, order) => sum + ((order['total_amount'] as num?)?.toDouble() ?? 0)
      );
      
      // 2. متوسط قيمة الطلب
      final avgOrderValue = orders.isNotEmpty ? totalSales / orders.length : 0.0;
      
      // 3. عدد العملاء الجدد (عملاء لديهم طلب واحد فقط)
      final uniquePhones = orders
          .map((order) => order['customer_phone'])
          .where((phone) => phone != null)
          .toSet();
      
      int newCustomersCount = 0;
      for (final phone in uniquePhones) {
        final customerOrders = await _client
            .from('orders')
            .select('id')
            .eq('customer_phone', phone)
            .count();
        
        if (customerOrders.count == 1) {
          newCustomersCount++;
        }
      }
      
      // 4. عدد المنتجات النشطة
      final productsResult = await _client
          .from('products')
          .select('id')
          .eq('is_active', true)
          .count();
      
      final activeProductsCount = productsResult.count;
      
      // 5. معدل التحويل (الطلبات / المنتجات النشطة)
      final conversionRate = activeProductsCount > 0
          ? (orders.length / activeProductsCount) * 100
          : 0.0;
      
      // 6. معدل الإشغال (نسبة المنتجات النشطة)
      // ملاحظة: نعتبر جميع المنتجات النشطة متوفرة
      // لأن المخزون مخزن في variants (JSONB) ويحتاج معالجة معقدة
      final occupancyRate = activeProductsCount > 0 ? 100.0 : 0.0;
      
      return QuickAnalytics(
        avgOrderValue: avgOrderValue,
        conversionRate: conversionRate,
        newCustomersCount: newCustomersCount,
        occupancyRate: occupancyRate,
      );
    } catch (e) {
      debugPrint('Error fetching quick analytics: $e');
      return QuickAnalytics.empty();
    }
  }
}

/// موديل لإحصائيات Dashboard
class DashboardStats {
  final double totalSales;
  final String salesTrend;
  final int newOrdersCount;
  final int activeProductsCount;
  final int clientsCount;

  DashboardStats({
    required this.totalSales,
    required this.salesTrend,
    required this.newOrdersCount,
    required this.activeProductsCount,
    required this.clientsCount,
  });

  factory DashboardStats.empty() {
    return DashboardStats(
      totalSales: 0,
      salesTrend: '0.0',
      newOrdersCount: 0,
      activeProductsCount: 0,
      clientsCount: 0,
    );
  }
}

/// موديل لبيانات المبيعات اليومية
class SalesData {
  final DateTime date;
  final double amount;

  SalesData({
    required this.date,
    required this.amount,
  });
}

/// موديل للنشاطات الأخيرة
class RecentActivity {
  final ActivityType type;
  final String title;
  final String subtitle;
  final DateTime time;

  RecentActivity({
    required this.type,
    required this.title,
    required this.subtitle,
    required this.time,
  });
}

enum ActivityType { order, review, product }

/// موديل للمنتجات الأكثر مبيعاً
class TopProduct {
  final String name;
  final String sales;
  final String revenue;

  TopProduct({
    required this.name,
    required this.sales,
    required this.revenue,
  });
}

/// موديل مساعد لتجميع بيانات المنتجات
class TopProductData {
  final String productId;
  final String name;
  int totalQuantity;
  double totalRevenue;

  TopProductData({
    required this.productId,
    required this.name,
    required this.totalQuantity,
    required this.totalRevenue,
  });
}

/// موديل للتحليلات السريعة
class QuickAnalytics {
  final double avgOrderValue;
  final double conversionRate;
  final int newCustomersCount;
  final double occupancyRate;

  QuickAnalytics({
    required this.avgOrderValue,
    required this.conversionRate,
    required this.newCustomersCount,
    required this.occupancyRate,
  });

  factory QuickAnalytics.empty() {
    return QuickAnalytics(
      avgOrderValue: 0,
      conversionRate: 0,
      newCustomersCount: 0,
      occupancyRate: 0,
    );
  }
}
