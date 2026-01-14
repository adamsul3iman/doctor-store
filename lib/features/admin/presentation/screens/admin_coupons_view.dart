import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminCouponsView extends StatefulWidget {
  const AdminCouponsView({super.key});

  @override
  State<AdminCouponsView> createState() => _AdminCouponsViewState();
}

class _AdminCouponsViewState extends State<AdminCouponsView> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _coupons = [];
  bool _isLoading = true;
  final Set<String> _selectedCouponIds = {};
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _fetchCoupons();
  }

  Future<void> _fetchCoupons() async {
    try {
      final data = await _supabase
          .from('coupons')
          .select()
          .order('created_at', ascending: false);
      if (mounted) {
        setState(() {
          _coupons = List<Map<String, dynamic>>.from(data);
          _isLoading = false;
          _selectedCouponIds.removeWhere(
            (id) => !_coupons.any((c) => c['id']?.toString() == id),
          );
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleStatus(String id, bool currentStatus) async {
    await _supabase
        .from('coupons')
        .update({'is_active': !currentStatus}).eq('id', id);
    _fetchCoupons();
  }

  Future<void> _deleteCoupon(String id) async {
    await _supabase.from('coupons').delete().eq('id', id);
    _selectedCouponIds.remove(id);
    _fetchCoupons();
  }

  Future<void> _deleteSelectedCoupons() async {
    if (_selectedCouponIds.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: Text(
          'هل تريد حذف ${_selectedCouponIds.length} كوبون/كوبونات دفعة واحدة؟',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'حذف',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      for (final id in _selectedCouponIds) {
        await _supabase.from('coupons').delete().eq('id', id);
      }
      if (!mounted) return;
      setState(() {
        _selectedCouponIds.clear();
      });
      await _fetchCoupons();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حذف الكوبونات المحددة')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل حذف الكوبونات: $e')),
      );
    }
  }

  // ✅ دالة إظهار نافذة الإضافة (تم تحديثها لدعم التاريخ)
  void _showAddDialog() {
    final codeCtrl = TextEditingController();
    final valueCtrl = TextEditingController();
    String type = 'percent';
    final limitCtrl = TextEditingController(text: '100');
    
    // متغير لحفظ التاريخ المختار
    DateTime? selectedDate;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder( // ✅ نستخدم StatefulBuilder لتحديث الواجهة داخل النافذة
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: const Text("إضافة كوبون جديد"),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 1. حقل الكود
                  TextField(
                    controller: codeCtrl, 
                    decoration: const InputDecoration(
                      labelText: "الكود (مثال: SALE2025)", 
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.qr_code)
                    )
                  ),
                  const SizedBox(height: 10),
                  
                  // 2. نوع الخصم
                  DropdownButtonFormField<String>(
                    initialValue: type,
                    items: const [
                      DropdownMenuItem(value: 'percent', child: Text("نسبة مئوية (%)")),
                      DropdownMenuItem(value: 'fixed', child: Text("مبلغ ثابت (د.أ)")),
                    ],
                    onChanged: (val) => setStateDialog(() => type = val!),
                    decoration: const InputDecoration(border: OutlineInputBorder(), labelText: "نوع الخصم"),
                  ),
                  const SizedBox(height: 10),
                  
                  // 3. القيمة والحد الأقصى
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: valueCtrl, 
                          keyboardType: TextInputType.number, 
                          decoration: const InputDecoration(labelText: "القيمة", border: OutlineInputBorder())
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: limitCtrl, 
                          keyboardType: TextInputType.number, 
                          decoration: const InputDecoration(labelText: "العدد المسموح", border: OutlineInputBorder())
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),

                  // ✅ 4. منتقي التاريخ (الميزة الجديدة)
                  ListTile(
                    title: Text(
                      selectedDate == null 
                          ? "اختر تاريخ الانتهاء (اختياري)" 
                          : "ينتهي في: ${selectedDate!.year}/${selectedDate!.month}/${selectedDate!.day}",
                      style: TextStyle(
                        color: selectedDate == null ? Colors.grey : const Color(0xFF0A2647),
                        fontWeight: FontWeight.bold
                      ),
                    ),
                    leading: const Icon(Icons.calendar_today, color: Color(0xFF0A2647)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8), 
                      side: const BorderSide(color: Colors.grey)
                    ),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now().add(const Duration(days: 1)),
                        firstDate: DateTime.now(),
                        lastDate: DateTime(2030),
                      );
                      if (picked != null) {
                        setStateDialog(() => selectedDate = picked);
                      }
                    },
                    trailing: selectedDate != null 
                      ? IconButton(
                          icon: const Icon(Icons.clear, color: Colors.red),
                          onPressed: () => setStateDialog(() => selectedDate = null),
                        ) 
                      : null,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text("إلغاء")),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0A2647), foregroundColor: Colors.white),
                onPressed: () async {
                  final rawCode = codeCtrl.text.trim();
                  final rawValue = valueCtrl.text.trim();
                  final rawLimit = limitCtrl.text.trim();

                  if (rawCode.isEmpty || rawValue.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('يرجى إدخال الكود وقيمة الخصم.')),
                    );
                    return;
                  }

                  // يفضَّل أن يكون الكود إنجليزياً بدون مسافات (slug بسيط)
                  final slugRegex = RegExp(r'^[A-Za-z0-9_-]+$');
                  if (!slugRegex.hasMatch(rawCode)) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('الكود يجب أن يكون بالإنجليزية (A-Z, 0-9, - , _) بدون مسافات.'),
                      ),
                    );
                    return;
                  }

                  final value = double.tryParse(rawValue);
                  if (value == null || value <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('يرجى إدخال قيمة خصم صحيحة (رقماً أكبر من صفر).')),
                    );
                    return;
                  }

                  final usageLimit = int.tryParse(rawLimit.isEmpty ? '0' : rawLimit);
                  if (usageLimit == null || usageLimit <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('يرجى إدخال عدد استخدامات صحيح (رقماً أكبر من صفر).')),
                    );
                    return;
                  }

                  try {
                    await _supabase.from('coupons').insert({
                      'code': rawCode.toUpperCase(),
                      'discount_type': type,
                      'value': value,
                      'usage_limit': usageLimit,
                      'expiration_date': selectedDate?.toIso8601String(), // ✅ إرسال التاريخ
                      'is_active': true,
                    });

                    if (!context.mounted) return;
                    Navigator.pop(context);
                    await _fetchCoupons();
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('تم إضافة الكوبون بنجاح')),
                    );
                  } catch (e) {
                    if (!context.mounted) return;
                    final errorText = e.toString();
                    var message = 'فشل حفظ الكوبون: $e';
                    if (errorText.contains('coupons_code_key') ||
                        errorText.contains('duplicate key value')) {
                      message =
                          'هناك كوبون آخر بنفس الكود، يرجى اختيار كود مختلف.';
                    }
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(message)),
                    );
                  }
                },
                child: const Text("حفظ الكوبون"),
              ),
            ],
          );
        }
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredCoupons = _coupons.where((coupon) {
      if (_searchQuery.trim().isEmpty) return true;
      final q = _searchQuery.trim().toLowerCase();
      final code = (coupon['code'] ?? '').toString().toLowerCase();
      return code.contains(q);
    }).toList();

    final visibleIds = filteredCoupons
        .map((c) => c['id']?.toString())
        .whereType<String>()
        .toList();
    final allVisibleSelected = visibleIds.isNotEmpty &&
        visibleIds.every((id) => _selectedCouponIds.contains(id));

    return Scaffold(
      backgroundColor: Colors.white,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _coupons.isEmpty
              ? const Center(child: Text("لا توجد كوبونات، أضف أول كوبون!"))
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextField(
                            decoration: const InputDecoration(
                              prefixIcon: Icon(Icons.search),
                              hintText: 'بحث برمز الكوبون...',
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (value) => setState(() {
                              _searchQuery = value;
                            }),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Checkbox(
                                value: allVisibleSelected,
                                onChanged: filteredCoupons.isEmpty
                                    ? null
                                    : (_) {
                                        setState(() {
                                          if (allVisibleSelected) {
                                            _selectedCouponIds.removeWhere(
                                              (id) => visibleIds.contains(id),
                                            );
                                          } else {
                                            _selectedCouponIds.addAll(visibleIds);
                                          }
                                        });
                                      },
                              ),
                              const Text('تحديد الكل (في النتائج الحالية)'),
                              const Spacer(),
                              if (_selectedCouponIds.isNotEmpty)
                                Text('المحدد: ${_selectedCouponIds.length}'),
                              const SizedBox(width: 8),
                              ElevatedButton.icon(
                                onPressed: _selectedCouponIds.isEmpty
                                    ? null
                                    : _deleteSelectedCoupons,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                  foregroundColor: Colors.white,
                                ),
                                icon: const Icon(Icons.delete_forever, size: 18),
                                label: const Text('حذف المحدد'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: filteredCoupons.isEmpty
                          ? const Center(child: Text('لا توجد نتائج مطابقة'))
                          : ListView.builder(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              itemCount: filteredCoupons.length,
                              itemBuilder: (context, index) {
                                final coupon = filteredCoupons[index];
                                final expiry = coupon['expiration_date'];
                                final isExpired = expiry != null &&
                                    DateTime.parse(expiry).isBefore(
                                      DateTime.now(),
                                    );
                                final id = coupon['id']?.toString();
                                final isSelected = id != null &&
                                    _selectedCouponIds.contains(id);

                                return Card(
                                  elevation: 2,
                                  margin:
                                      const EdgeInsets.only(bottom: 12),
                                  color: (coupon['is_active'] && !isExpired)
                                      ? Colors.white
                                      : Colors.grey[100],
                                  child: ListTile(
                                    leading: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Checkbox(
                                          value: isSelected,
                                          onChanged: id == null
                                              ? null
                                              : (value) {
                                                  setState(() {
                                                    if (value == true) {
                                                      _selectedCouponIds
                                                          .add(id);
                                                    } else {
                                                      _selectedCouponIds
                                                          .remove(id);
                                                    }
                                                  });
                                                },
                                        ),
                                        CircleAvatar(
                                          backgroundColor: (coupon[
                                                      'is_active'] &&
                                                  !isExpired)
                                              ? (coupon['discount_type'] ==
                                                      'percent'
                                                  ? Colors.orange
                                                  : Colors.green)
                                              : Colors.grey,
                                          child: Text(
                                              coupon['discount_type'] ==
                                                      'percent'
                                                  ? '%'
                                                  : '\$',
                                              style: const TextStyle(
                                                  color: Colors.white,
                                                  fontWeight:
                                                      FontWeight.bold)),
                                        ),
                                      ],
                                    ),
                                    title: Row(
                                      children: [
                                        Text(coupon['code'],
                                            style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16)),
                                        if (isExpired)
                                          Container(
                                            margin: const EdgeInsets.only(
                                                right: 8),
                                            padding: const EdgeInsets
                                                .symmetric(
                                                horizontal: 6,
                                                vertical: 2),
                                            decoration: BoxDecoration(
                                                color: Colors.red[100],
                                                borderRadius:
                                                    BorderRadius.circular(
                                                        4)),
                                            child: const Text("منتهي",
                                                style: TextStyle(
                                                    color: Colors.red,
                                                    fontSize: 10)),
                                          )
                                      ],
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                            "القيمة: ${coupon['value']} | الاستخدام: ${coupon['used_count']}/${coupon['usage_limit']}"),
                                        if (expiry != null)
                                          Text(
                                            "ينتهي في: ${expiry.toString().split('T')[0]}",
                                            style: TextStyle(
                                                fontSize: 11,
                                                color: isExpired
                                                    ? Colors.red
                                                    : Colors
                                                        .grey[600]),
                                          ),
                                      ],
                                    ),
                                    trailing: Switch(
                                        value: coupon['is_active'],
                                        activeThumbColor:
                                            const Color(0xFF0A2647),
                                        onChanged: (val) => _toggleStatus(
                                            coupon['id'],
                                            coupon[
                                                'is_active'])),
                                    onLongPress: () =>
                                        _deleteCoupon(coupon['id']),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddDialog,
        backgroundColor: const Color(0xFF0A2647),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text("كوبون جديد",
            style: TextStyle(color: Colors.white)),
      ),
    );
  }
}
