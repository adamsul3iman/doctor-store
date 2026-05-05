import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;
import 'package:doctor_store/shared/utils/image_url_helper.dart';
import 'package:doctor_store/shared/widgets/app_network_image.dart';
import 'package:doctor_store/features/admin/data/order_repository.dart';
import 'package:doctor_store/features/orders/domain/models/order_model.dart';

class AdminOrdersView extends StatefulWidget {
  const AdminOrdersView({super.key});

  @override
  State<AdminOrdersView> createState() => _AdminOrdersViewState();
}

class _AdminOrdersViewState extends State<AdminOrdersView> {
  final OrderRepository _repo = OrderRepository();
  final Set<String> _selectedOrderIds = {};
  String _searchQuery = '';

  // نحتفظ بآخر بيانات ناجحة من الستريم لعرضها في حال حدوث خطأ مؤقت في Realtime
  List<Order>? _lastOrdersData;

  // فلاتر متقدمة
  String _statusFilter = 'all'; // all, new, completed, cancelled
  String _dateFilter = 'all'; // all, today, 7d, 30d

  Stream<List<Order>> get _ordersStream => _repo.watchOrders();

  void _toggleSelect(String id, bool selected) {
    setState(() {
      if (selected) {
        _selectedOrderIds.add(id);
      } else {
        _selectedOrderIds.remove(id);
      }
    });
  }

  void _toggleSelectAll(List<Order> orders) {
    setState(() {
      // نطبق على القائمة بعد التصفية (بالاسم/الهاتف)
      final ids = orders
          .map((o) => o.id)
          .toList();
      final allSelected =
          ids.isNotEmpty && ids.every((id) => _selectedOrderIds.contains(id));
      if (allSelected) {
        _selectedOrderIds.removeWhere((id) => ids.contains(id));
      } else {
        _selectedOrderIds.addAll(ids);
      }
    });
  }

  Future<void> _deleteSelected(List<Order> visibleOrders) async {
    if (_selectedOrderIds.isEmpty) return;

    final count = _selectedOrderIds.length;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: Text('هل تريد حذف $count طلباً؟ لا يمكن التراجع عن هذه العملية.'),
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
      for (final id in _selectedOrderIds) {
        await _repo.deleteOrder(id);
      }
      if (!mounted) return;
      setState(() {
        _selectedOrderIds.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حذف الطلبات المحددة')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل حذف الطلبات: $e')),
      );
    }
  }

  // ✅ تحسين: تخزين مؤقت للطلبات المفلترة
  List<Order>? _cachedFilteredOrders;
  String _lastFilterKey = '';

  List<Order> _getFilteredOrders(List<Order> allOrders) {
    // إنشاء مفتاح فريد للفلاتر الحالية
    final filterKey = '$_statusFilter|$_dateFilter|$_searchQuery';
    
    // إذا لم تتغير الفلاتر، أعد النتائج المخزنة
    if (filterKey == _lastFilterKey && _cachedFilteredOrders != null) {
      return _cachedFilteredOrders!;
    }

    final now = DateTime.now();
    
    final filtered = allOrders.where((order) {
      // 1) فلتر الحالة
      final status = order.status.toDbString();
      if (_statusFilter != 'all' && status != _statusFilter) {
        return false;
      }

      // 2) فلتر التاريخ - تحسين: استخدام parse مرة واحدة
      if (_dateFilter != 'all') {
        final date = order.createdAt.toLocal();

        final diff = now.difference(date);
        switch (_dateFilter) {
          case 'today':
            if (now.year != date.year || now.month != date.month || now.day != date.day) {
              return false;
            }
            break;
          case '7d':
            if (diff.inDays >= 7) return false;
            break;
          case '30d':
            if (diff.inDays >= 30) return false;
            break;
        }
      }

      // 3) فلتر البحث - تحسين: toLowerCase مرة واحدة
      if (_searchQuery.trim().isNotEmpty) {
        final query = _searchQuery.trim().toLowerCase();
        final name = order.customerName.toLowerCase();
        final phone = order.customerPhone;
        if (!name.contains(query) && !phone.contains(query)) {
          return false;
        }
      }

      return true;
    }).toList();

    // تخزين النتائج
    _cachedFilteredOrders = filtered;
    _lastFilterKey = filterKey;
    
    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: StreamBuilder<List<Order>>(
        stream: _ordersStream,
        builder: (context, snapshot) {
          // لا نعرض الخطأ للمستخدم. نكتفي بالـ log (اختياري) لتتبع مشاكل Realtime.
          if (snapshot.hasError) {
            debugPrint('Orders stream error: ${snapshot.error}');
          }

          // استراتيجية صامتة: إذا كان هناك error لكن توجد بيانات (cached/previous)،
          // نتجاهل الخطأ ونعرض البيانات.
          List<Order>? effectiveOrders;

          if (snapshot.hasData) {
            effectiveOrders = snapshot.data;
            _lastOrdersData = snapshot.data;
          } else if (_lastOrdersData != null) {
            effectiveOrders = _lastOrdersData;
          }

          // إذا حصل خطأ ولا توجد بيانات إطلاقاً، نعرض تحميل بدل نص الاستثناء.
          if (snapshot.hasError && effectiveOrders == null) {
            return const Center(child: Text('جاري التحميل...'));
          }

          // في أول تحميل، لو لا توجد بيانات بعد، نعرض مؤشر الانتظار
          if (snapshot.connectionState == ConnectionState.waiting &&
              (effectiveOrders == null || effectiveOrders.isEmpty)) {
            return const Center(child: CircularProgressIndicator());
          }

          // لو لم نحصل على أي بيانات حتى بعد الانتظار، نعرض رسالة عدم وجود طلبات
          if (effectiveOrders == null || effectiveOrders.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inbox, size: 60, color: Colors.grey),
                  SizedBox(height: 10),
                  Text("لا توجد طلبات حتى الآن"),
                ],
              ),
            );
          }

          final allOrders = effectiveOrders;

          // ✅ استخدام الدالة المُحسّنة للفلترة مع التخزين المؤقت
          final filteredOrders = _getFilteredOrders(allOrders);

          if (filteredOrders.isEmpty) {
            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _OrdersToolbar(
                    totalSelected: _selectedOrderIds.length,
                    allVisibleSelected: false,
                    onSearchChanged: (value) => setState(() {
                      _searchQuery = value;
                    }),
                    onDeleteSelected: filteredOrders.isEmpty
                        ? null
                        : () => _deleteSelected(filteredOrders),
                    onToggleSelectAll: filteredOrders.isEmpty
                        ? null
                        : () => _toggleSelectAll(filteredOrders),
                    statusFilter: _statusFilter,
                    dateFilter: _dateFilter,
                    onStatusFilterChanged: (value) => setState(() {
                      _statusFilter = value;
                    }),
                    onDateFilterChanged: (value) => setState(() {
                      _dateFilter = value;
                    }),
                    onResetFilters: () => setState(() {
                      _statusFilter = 'all';
                      _dateFilter = 'all';
                    }),
                  ),
                  const SizedBox(height: 32),
                  const Center(child: Text('لا توجد نتائج مطابقة لبحثك.')),
                ],
              ),
            );
          }

          final visibleIds = filteredOrders
              .map((o) => o.id)
              .toList();
          final allVisibleSelected =
              visibleIds.isNotEmpty &&
                  visibleIds.every((id) => _selectedOrderIds.contains(id));

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: _OrdersToolbar(
                  totalSelected: _selectedOrderIds.length,
                  allVisibleSelected: allVisibleSelected,
                  onSearchChanged: (value) => setState(() {
                    _searchQuery = value;
                  }),
                  onDeleteSelected: _selectedOrderIds.isEmpty
                      ? null
                      : () => _deleteSelected(filteredOrders),
                  onToggleSelectAll: () => _toggleSelectAll(filteredOrders),
                  statusFilter: _statusFilter,
                  dateFilter: _dateFilter,
                  onStatusFilterChanged: (value) => setState(() {
                    _statusFilter = value;
                  }),
                  onDateFilterChanged: (value) => setState(() {
                    _dateFilter = value;
                  }),
                  onResetFilters: () => setState(() {
                    _statusFilter = 'all';
                    _dateFilter = 'all';
                  }),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: filteredOrders.length,
                  itemBuilder: (context, index) {
                    final order = filteredOrders[index];
                    final isSelected =
                        _selectedOrderIds.contains(order.id);
                    return _OrderCard(
                      order: order,
                      isSelected: isSelected,
                      onSelectedChanged: (value) => _toggleSelect(order.id, value ?? false),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _OrderCard extends StatefulWidget {
  final Order order;
  final bool isSelected;
  final ValueChanged<bool?>? onSelectedChanged;

  const _OrderCard({
    required this.order,
    this.isSelected = false,
    this.onSelectedChanged,
  });

  @override
  State<_OrderCard> createState() => _OrderCardState();
}

class _OrderCardState extends State<_OrderCard> {
  bool _expanded = false;
  List<OrderItem> _items = [];
  bool _loadingItems = false;
  final OrderRepository _repo = OrderRepository();
  // Track which statuses are being updated to show loading state
  final Set<OrderStatus> _updatingStatuses = {};

  // جلب تفاصيل المنتجات فقط عند فتح الكارد (لتحسين الأداء)
  Future<void> _fetchItems() async {
    if (_items.isNotEmpty) return;
    setState(() => _loadingItems = true);
    
    try {
      final data = await _repo.getOrderItems(widget.order.id);

      if (!mounted) return;

      setState(() {
        _items = data;
        _loadingItems = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingItems = false);
    }
  }

  Future<void> _updateStatus(OrderStatus status) async {
    debugPrint('UI: Updating order ${widget.order.id} to status: ${status.toDbString()}');
    
    setState(() => _updatingStatuses.add(status));
    
    try {
      await _repo.updateOrderStatus(widget.order.id, status);
      debugPrint('UI: Order status updated successfully');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم تحديث حالة الطلب إلى: ${status.displayName}'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e, stackTrace) {
      debugPrint('UI: Error updating order status: $e');
      debugPrint('Stack trace: $stackTrace');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('فشل تحديث حالة الطلب: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _updatingStatuses.remove(status));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = widget.order.status.toDbString();
    final date = widget.order.createdAt.toLocal();
    
    // تنسيق الألوان حسب الحالة
    Color statusColor = Color(widget.order.status.colorValue);
    String statusText = widget.order.status.displayName;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: status == 'new' ? const BorderSide(color: Colors.blue, width: 1.5) : BorderSide.none,
      ),
      child: Column(
        children: [
          ListTile(
            onTap: () {
              setState(() => _expanded = !_expanded);
              if (_expanded) _fetchItems();
            },
            leading: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Checkbox(
                  value: widget.isSelected,
                  onChanged: widget.onSelectedChanged,
                ),
                CircleAvatar(
                  backgroundColor: statusColor.withValues(alpha: 0.1),
                  child: Icon(Icons.shopping_bag, color: statusColor),
                ),
              ],
            ),
            title: Row(
              children: [
                Text(widget.order.customerName, style: const TextStyle(fontWeight: FontWeight.bold)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                  child: Text(statusText, style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            subtitle: Text(
              "${intl.DateFormat('yyyy/MM/dd HH:mm').format(date)} • ${widget.order.totalAmount.toStringAsFixed(0)} د.أ",
              style: TextStyle(color: Colors.grey[600]),
            ),
            trailing: Icon(_expanded ? Icons.expand_less : Icons.expand_more),
          ),
          
          if (_expanded) ...[
            const Divider(height: 1),
            // تفاصيل الاتصال
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              color: Colors.grey[50],
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _InfoRow(Icons.phone, widget.order.customerPhone),
                  const SizedBox(height: 5),
                  _InfoRow(Icons.location_on, widget.order.customerAddress),
                ],
              ),
            ),
            
            // المنتجات
            if (_loadingItems)
              const Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator()))
            else
              ..._items.map((item) {
                final details = [
                  if (item.selectedSize?.trim().isNotEmpty ?? false)
                    'المقاس: ${item.selectedSize}',
                  if (item.selectedColor?.trim().isNotEmpty ?? false)
                    'اللون: ${item.selectedColor}',
                ];
                return ListTile(
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: SizedBox(
                    width: 40,
                    height: 40,
                    child: AppNetworkImage(
                      url: item.imageUrl ?? '',
                      variant: ImageVariant.thumbnail,
                      fit: BoxFit.cover,
                      placeholder: Container(color: Colors.grey[200]),
                      errorWidget: const Icon(Icons.image),
                    ),
                  ),
                ),
                title: Text(item.productTitle),
                subtitle: Text([
                  "${item.quantity}x",
                  if (details.isNotEmpty) details.join(' | '),
                ].join('  |  ')),
                trailing: Text("${item.price.toStringAsFixed(0)} د.أ"),
              );
              }),

            // أزرار التحكم
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (status != 'completed')
                    Builder(builder: (context) {
                      final orderId = widget.order.id;
                      final isUpdating = _updatingStatuses.contains(OrderStatus.completed);
                      return ElevatedButton.icon(
                        onPressed: isUpdating ? null : () {
                          debugPrint('COMPLETE BUTTON CLICKED: order=$orderId, currentStatus=$status');
                          _updateStatus(OrderStatus.completed);
                        },
                        icon: isUpdating 
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.check, size: 18),
                        label: Text(isUpdating ? "جاري التحديث..." : "إتمام الطلب"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green, 
                          foregroundColor: Colors.white,
                          elevation: 2,
                        ),
                      );
                    }),
                  const SizedBox(width: 8),
                  if (status != 'cancelled')
                    Builder(builder: (context) {
                      final orderId = widget.order.id;
                      final isUpdating = _updatingStatuses.contains(OrderStatus.cancelled);
                      return TextButton(
                        onPressed: isUpdating ? null : () {
                          debugPrint('CANCEL BUTTON CLICKED: order=$orderId, currentStatus=$status');
                          _updateStatus(OrderStatus.cancelled);
                        },
                        style: TextButton.styleFrom(
                          foregroundColor: isUpdating ? Colors.grey : Colors.red,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                        ),
                        child: Text(isUpdating ? "جاري الإلغاء..." : "إلغاء الطلب"),
                      );
                    }),
                ],
              ),
            ),
          ]
        ],
      ),
    );
  }
}

class _OrdersToolbar extends StatelessWidget {
  final int totalSelected;
  final bool allVisibleSelected;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback? onDeleteSelected;
  final VoidCallback? onToggleSelectAll;
  final String statusFilter;
  final String dateFilter;
  final ValueChanged<String> onStatusFilterChanged;
  final ValueChanged<String> onDateFilterChanged;
  final VoidCallback onResetFilters;

  const _OrdersToolbar({
    required this.totalSelected,
    required this.allVisibleSelected,
    required this.onSearchChanged,
    required this.onDeleteSelected,
    required this.onToggleSelectAll,
    required this.statusFilter,
    required this.dateFilter,
    required this.onStatusFilterChanged,
    required this.onDateFilterChanged,
    required this.onResetFilters,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search),
            hintText: 'بحث بالاسم أو رقم الهاتف...',
            border: OutlineInputBorder(),
          ),
          onChanged: onSearchChanged,
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              Checkbox(
                value: allVisibleSelected,
                onChanged: onToggleSelectAll == null
                    ? null
                    : (_) => onToggleSelectAll!(),
              ),
              const Text('تحديد الكل (في النتائج الحالية)'),
              const SizedBox(width: 16),

              // فلتر الحالة
              DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: statusFilter,
                  items: const [
                    DropdownMenuItem(
                      value: 'all',
                      child: Text('كل الحالات'),
                    ),
                    DropdownMenuItem(
                      value: 'new',
                      child: Text('جديدة فقط'),
                    ),
                    DropdownMenuItem(
                      value: 'completed',
                      child: Text('مكتملة فقط'),
                    ),
                    DropdownMenuItem(
                      value: 'cancelled',
                      child: Text('ملغاة فقط'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    onStatusFilterChanged(value);
                  },
                ),
              ),

              const SizedBox(width: 8),

              // فلتر الفترة الزمنية
              DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: dateFilter,
                  items: const [
                    DropdownMenuItem(
                      value: 'all',
                      child: Text('كل الفترات'),
                    ),
                    DropdownMenuItem(
                      value: 'today',
                      child: Text('اليوم فقط'),
                    ),
                    DropdownMenuItem(
                      value: '7d',
                      child: Text('آخر 7 أيام'),
                    ),
                    DropdownMenuItem(
                      value: '30d',
                      child: Text('آخر 30 يوماً'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    onDateFilterChanged(value);
                  },
                ),
              ),

              const SizedBox(width: 8),

              TextButton.icon(
                onPressed: onResetFilters,
                icon: const Icon(Icons.clear, size: 16),
                label: const Text('تصفير الفلاتر'),
              ),

              const SizedBox(width: 16),
              if (totalSelected > 0) Text('المحدد: $totalSelected'),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: onDeleteSelected,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.delete_forever, size: 18),
                label: const Text('حذف المحدد'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoRow(this.icon, this.text);
  @override
  Widget build(BuildContext context) {
    return Row(children: [Icon(icon, size: 16, color: Colors.grey), const SizedBox(width: 8), SelectableText(text)]);
  }
}
