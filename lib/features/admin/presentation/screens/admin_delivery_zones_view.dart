// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:doctor_store/shared/utils/app_notifier.dart';

class AdminDeliveryZonesView extends StatefulWidget {
  const AdminDeliveryZonesView({super.key});

  @override
  State<AdminDeliveryZonesView> createState() => _AdminDeliveryZonesViewState();
}

class _AdminDeliveryZonesViewState extends State<AdminDeliveryZonesView> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _zones = [];

  @override
  void initState() {
    super.initState();
    _loadZones();
  }

  Future<void> _loadZones() async {
    setState(() => _isLoading = true);
    try {
      final data = await _supabase
          .from('delivery_zones')
          .select()
          .order('sort_order', ascending: true);

      setState(() {
        _zones = List<Map<String, dynamic>>.from(data as List);
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        AppNotifier.showError(context, 'خطأ في تحميل مناطق التوصيل: $e');
      }
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveZone({Map<String, dynamic>? existing}) async {
    final isEditing = existing != null;
    final nameCtrl = TextEditingController(text: existing?['name'] ?? '');
    final priceCtrl = TextEditingController(
      text: existing?['price']?.toString() ?? '',
    );
    int sortOrder = (existing?['sort_order'] as int?) ?? 0;
    bool isActive = (existing?['is_active'] as bool?) ?? true;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        bool isSaving = false;
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title:
                  Text(isEditing ? 'تعديل منطقة توصيل' : 'إضافة منطقة توصيل'),
              content: SizedBox(
                width: 500,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: nameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'اسم المنطقة (مثال: عمان - تلاع العلي)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: priceCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'سعر التوصيل (د.أ)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Text('ترتيب الظهور'),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                              ),
                              controller: TextEditingController(
                                text: sortOrder.toString(),
                              ),
                              onChanged: (v) {
                                sortOrder = int.tryParse(v) ?? 0;
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SwitchListTile.adaptive(
                        title: const Text('مفعّل'),
                        value: isActive,
                        onChanged: (v) => setState(() => isActive = v),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.pop(ctx),
                  child: const Text('إلغاء'),
                ),
                ElevatedButton.icon(
                  onPressed: isSaving
                      ? null
                      : () async {
                          final rawName = nameCtrl.text.trim();
                          final rawPrice = priceCtrl.text.trim();

                          if (rawName.isEmpty || rawPrice.isEmpty) {
                            AppNotifier.showError(
                              ctx,
                              'يرجى إدخال اسم المنطقة وسعر التوصيل.',
                            );
                            return;
                          }

                          final price = double.tryParse(rawPrice);
                          if (price == null || price < 0) {
                            AppNotifier.showError(
                              ctx,
                              'يرجى إدخال سعر توصيل صحيح (رقم).',
                            );
                            return;
                          }

                          // إذا لم يتم إدخال ترتيب، نولّده تلقائياً بعد آخر منطقة
                          if (!isEditing && sortOrder == 0) {
                            final maxOrder = _zones
                                .map((z) => (z['sort_order'] as int?) ?? 0)
                                .fold<int>(0, (prev, v) => v > prev ? v : prev);
                            sortOrder = maxOrder + 1;
                          }

                          setState(() => isSaving = true);
                          try {
                            final payload = <String, dynamic>{
                              'name': rawName,
                              'price': price,
                              'sort_order': sortOrder,
                              'is_active': isActive,
                            };
                            if (isEditing) {
                              payload['id'] = existing['id'];
                            }

                            await _supabase
                                .from('delivery_zones')
                                .upsert(payload);

                            if (!mounted) return;
                            Navigator.pop(ctx);

                            // نحدّث القائمة بعد إغلاق الحوار
                            await _loadZones();
                            if (!mounted) return;

                            AppNotifier.showSuccess(
                              context,
                              'تم حفظ منطقة التوصيل بنجاح',
                            );
                          } catch (e) {
                            if (!mounted) return;
                            setState(() => isSaving = false);
                            final errorText = e.toString();
                            var message = 'خطأ في حفظ منطقة التوصيل: $e';
                            if (errorText.contains('delivery_zones_name_key') ||
                                errorText.contains('duplicate key value')) {
                              message =
                                  'هناك منطقة توصيل أخرى بنفس الاسم، يرجى اختيار اسم مختلف.';
                            }
                            AppNotifier.showError(
                              context,
                              message,
                            );
                          }
                        },
                  icon: isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.save),
                  label: const Text('حفظ'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _deleteZone(Map<String, dynamic> zone) async {
    final id = zone['id'];
    if (id == null) return;
    final name = (zone['name'] as String?) ?? '';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف منطقة توصيل'),
        content: Text('هل أنت متأكد من حذف "$name"؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'حذف',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _supabase.from('delivery_zones').delete().eq('id', id);
      if (!mounted) return;
      await _loadZones();
      if (!mounted) return;
      AppNotifier.showSuccess(context, 'تم حذف "$name" بنجاح');
    } catch (e) {
      if (!mounted) return;
      AppNotifier.showError(context, 'حدث خطأ أثناء الحذف: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('مناطق التوصيل'),
        backgroundColor: const Color(0xFF0A2647),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'تحديث',
            icon: const Icon(Icons.refresh),
            onPressed: _loadZones,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _saveZone(),
        backgroundColor: const Color(0xFF0A2647),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('منطقة جديدة', style: TextStyle(color: Colors.white)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _zones.isEmpty
              ? const Center(
                  child: Text('لا توجد مناطق توصيل بعد، أضف أول منطقة.'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _zones.length,
                  itemBuilder: (context, index) {
                    final zone = _zones[index];
                    final bool isActive = (zone['is_active'] as bool?) ?? true;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isActive
                              ? const Color(0xFF0A2647).withValues(alpha: 0.1)
                              : Colors.grey.withValues(alpha: 0.1),
                          child: Icon(
                            Icons.delivery_dining,
                            color: isActive
                                ? const Color(0xFF0A2647)
                                : Colors.grey,
                          ),
                        ),
                        title: Text(zone['name'] ?? ''),
                        subtitle: Text(
                          'السعر: ${zone['price']} د.أ • الترتيب: ${zone['sort_order'] ?? 0}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Switch(
                              value: isActive,
                              activeThumbColor: const Color(0xFF0A2647),
                              onChanged: (v) async {
                                try {
                                  await _supabase.from('delivery_zones').update(
                                      {'is_active': v}).eq('id', zone['id']);
                                  if (!mounted) return;
                                  setState(() {
                                    zone['is_active'] = v;
                                  });
                                } catch (e) {
                                  if (!mounted) return;
                                  AppNotifier.showError(
                                    context,
                                    'خطأ في تحديث الحالة: $e',
                                  );
                                }
                              },
                            ),
                            IconButton(
                              tooltip: 'تعديل',
                              icon: const Icon(Icons.edit_outlined),
                              onPressed: () => _saveZone(existing: zone),
                            ),
                            IconButton(
                              tooltip: 'حذف',
                              icon: const Icon(
                                Icons.delete_outline,
                                color: Colors.redAccent,
                              ),
                              onPressed: () => _deleteZone(zone),
                            ),
                          ],
                        ),
                        onTap: () => _saveZone(existing: zone),
                      ),
                    );
                  },
                ),
    );
  }
}
