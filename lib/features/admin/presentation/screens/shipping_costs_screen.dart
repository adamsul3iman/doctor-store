import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// صفحة إدارة أسعار الشحن حسب المحافظة والحجم
class ShippingCostsScreen extends StatefulWidget {
  const ShippingCostsScreen({super.key});

  @override
  State<ShippingCostsScreen> createState() => _ShippingCostsScreenState();
}

class _ShippingCostsScreenState extends State<ShippingCostsScreen> {
  final _supabase = Supabase.instance.client;
  
  bool _isLoading = true;
  List<Map<String, dynamic>> _shippingCosts = [];
  
  // خريطة لتخزين الأسعار حسب المحافظة والحجم
  final Map<String, Map<String, double>> _costsMap = {};
  
  // قائمة المحافظات
  final List<Map<String, String>> _zones = [
    {'id': 'amman', 'name': 'عمان'},
    {'id': 'irbid', 'name': 'إربد'},
    {'id': 'zarqa', 'name': 'الزرقاء'},
    {'id': 'ajloun', 'name': 'عجلون'},
    {'id': 'jerash', 'name': 'جرش'},
    {'id': 'salt', 'name': 'السلط'},
    {'id': 'madaba', 'name': 'مادبا'},
    {'id': 'karak', 'name': 'الكرك'},
    {'id': 'tafilah', 'name': 'الطفيلة'},
    {'id': 'maan', 'name': 'معان'},
    {'id': 'aqaba', 'name': 'العقبة'},
    {'id': 'mafraq', 'name': 'المفرق'},
  ];
  
  // أحجام الشحن
  final List<Map<String, String>> _sizes = [
    {'value': 'small', 'label': 'صغير', 'icon': 'S'},
    {'value': 'medium', 'label': 'متوسط', 'icon': 'M'},
    {'value': 'large', 'label': 'كبير', 'icon': 'L'},
    {'value': 'x_large', 'label': 'كبير جداً', 'icon': 'XL'},
  ];

  @override
  void initState() {
    super.initState();
    _loadShippingCosts();
  }

  Future<void> _loadShippingCosts() async {
    setState(() => _isLoading = true);
    
    try {
      final data = await _supabase
          .from('shipping_costs')
          .select()
          .order('zone_name');
      
      _shippingCosts = List<Map<String, dynamic>>.from(data as List);
      
      // بناء خريطة للوصول السريع
      _costsMap.clear();
      for (final item in _shippingCosts) {
        final zoneId = item['zone_id'] as String;
        final size = item['shipping_size'] as String;
        final cost = (item['cost'] as num).toDouble();
        
        if (!_costsMap.containsKey(zoneId)) {
          _costsMap[zoneId] = {};
        }
        _costsMap[zoneId]![size] = cost;
      }
      
      setState(() => _isLoading = false);
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في تحميل البيانات: $e')),
        );
      }
    }
  }

  Future<void> _updateCost(String zoneId, String zoneName, String size, double cost) async {
    try {
      await _supabase
          .from('shipping_costs')
          .upsert({
            'zone_id': zoneId,
            'zone_name': zoneName,
            'shipping_size': size,
            'cost': cost,
            'updated_at': DateTime.now().toIso8601String(),
          }, onConflict: 'zone_id,shipping_size');
      
      // تحديث الخريطة المحلية
      if (!_costsMap.containsKey(zoneId)) {
        _costsMap[zoneId] = {};
      }
      _costsMap[zoneId]![size] = cost;
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم حفظ السعر بنجاح'),
            duration: Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في الحفظ: $e')),
        );
      }
    }
  }

  void _showEditDialog(String zoneId, String zoneName, String size, String sizeLabel) {
    final currentCost = _costsMap[zoneId]?[size] ?? 0.0;
    final controller = TextEditingController(text: currentCost.toStringAsFixed(2));
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('تعديل سعر الشحن'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('المحافظة: $zoneName', style: const TextStyle(fontWeight: FontWeight.bold)),
            Text('الحجم: $sizeLabel', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'السعر (دينار أردني)',
                prefixIcon: Icon(Icons.attach_money),
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              final cost = double.tryParse(controller.text.trim());
              if (cost == null || cost < 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('يرجى إدخال سعر صحيح')),
                );
                return;
              }
              
              _updateCost(zoneId, zoneName, size, cost);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0A2647),
              foregroundColor: Colors.white,
            ),
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('إدارة أسعار الشحن'),
        backgroundColor: const Color(0xFF0A2647),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadShippingCosts,
            tooltip: 'تحديث',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // بطاقة تعريفية
                  Card(
                    color: Colors.blue[50],
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.info_outline, color: Colors.blue[700]),
                              const SizedBox(width: 8),
                              Text(
                                'نظام أسعار الشحن الذكي',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: Colors.blue[900],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'يتم احتساب تكلفة الشحن بناءً على:\n'
                            '• أكبر حجم منتج في السلة\n'
                            '• عنوان التوصيل (المحافظة)\n\n'
                            'اضغط على أي خلية لتعديل السعر',
                            style: TextStyle(fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // جدول الأسعار
                  Card(
                    elevation: 2,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        headingRowColor: WidgetStateProperty.all(
                          const Color(0xFF0A2647).withValues(alpha: 0.1),
                        ),
                        columns: [
                          const DataColumn(
                            label: Text(
                              'المحافظة',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          ..._sizes.map((size) => DataColumn(
                                label: Row(
                                  children: [
                                    Text(size['icon']!),
                                    const SizedBox(width: 4),
                                    Text(
                                      size['label']!,
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              )),
                        ],
                        rows: _zones.map((zone) {
                          final zoneId = zone['id']!;
                          final zoneName = zone['name']!;
                          
                          return DataRow(
                            cells: [
                              DataCell(
                                Text(
                                  zoneName,
                                  style: const TextStyle(fontWeight: FontWeight.w600),
                                ),
                              ),
                              ..._sizes.map((size) {
                                final sizeValue = size['value']!;
                                final sizeLabel = size['label']!;
                                final cost = _costsMap[zoneId]?[sizeValue] ?? 0.0;
                                
                                return DataCell(
                                  InkWell(
                                    onTap: () => _showEditDialog(
                                      zoneId,
                                      zoneName,
                                      sizeValue,
                                      sizeLabel,
                                    ),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.green[50],
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: Colors.green[200]!),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            '${cost.toStringAsFixed(2)} د.أ',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: Colors.green[900],
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          Icon(
                                            Icons.edit,
                                            size: 14,
                                            color: Colors.green[700],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              }),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // أمثلة توضيحية
                  Card(
                    color: Colors.orange[50],
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.lightbulb_outline, color: Colors.orange[700]),
                              const SizedBox(width: 8),
                              Text(
                                'أمثلة على الأحجام',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: Colors.orange[900],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _buildSizeExample('S', 'صغير', 'وسائد، مناشف، شراشف، مفارش صغيرة'),
                          _buildSizeExample('M', 'متوسط', 'لحاف، بطانية، ستائر صغيرة، مخدات كبيرة'),
                          _buildSizeExample('L', 'كبير', 'طاولة سفرة، مرتبة، ستائر كبيرة، سجاد متوسط'),
                          _buildSizeExample('XL', 'كبير جداً', 'غرفة نوم كاملة، طقم صالون، سجاد كبير'),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildSizeExample(String icon, String label, String examples) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(icon, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(fontSize: 13, color: Colors.black87),
                children: [
                  TextSpan(
                    text: '$label: ',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  TextSpan(text: examples),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
  }
}
