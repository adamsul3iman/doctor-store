import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // للنسخ
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart' as intl;
import 'package:doctor_store/shared/utils/app_notifier.dart';

class AdminClientsView extends StatefulWidget {
  const AdminClientsView({super.key});

  @override
  State<AdminClientsView> createState() => _AdminClientsViewState();
}

class _AdminClientsViewState extends State<AdminClientsView> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _clients = [];

  @override
  void initState() {
    super.initState();
    _fetchClients();
  }

  Future<void> _fetchClients() async {
    try {
      final data = await Supabase.instance.client
          .from('profiles')
          .select('id, full_name, phone, avatar_url, updated_at')
          .order('updated_at', ascending: false);

      if (mounted) {
        setState(() {
          _clients = List<Map<String, dynamic>>.from(data);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteClient(String id) async {
    try {
      final deleted = await Supabase.instance.client
          .from('profiles')
          .delete()
          .eq('id', id)
          .select(); // نتحقق من عدد الصفوف المتأثرة للتأكد من أن RLS لم تمنع العملية

      if (deleted.isEmpty) {
        // لم يتم حذف أي صف: إما أن السجل غير موجود أو أن RLS منعت الحذف بدون إرجاع خطأ واضح
        if (!mounted) return;
        AppNotifier.showError(
          context,
          'لم يتم حذف العميل. تأكد أن حساب الأدمن مضاف في جدول admins وأن سياسات RLS تسمح بالحذف.',
        );
        return;
      }

      await _fetchClients();
      if (mounted) {
        AppNotifier.showSuccess(context, "تم حذف العميل من profiles");
      }
    } on PostgrestException catch (e) {
      // في الغالب المشكلة هنا ستكون من صلاحيات RLS على جدول profiles
      if (!mounted) return;
      final msg = e.message;
      AppNotifier.showError(context, msg);
    } catch (e) {
      if (!mounted) return;
      AppNotifier.showError(context, 'حدث خطأ أثناء الحذف: $e');
    }
  }

  Future<void> _confirmDeleteClient(Map<String, dynamic> client) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("تأكيد الحذف"),
        content: Text("هل أنت متأكد من حذف العميل ${client['full_name'] ?? client['id']}؟"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("إلغاء"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              "حذف",
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final id = client['id']?.toString();
      if (id != null) {
        _deleteClient(id);
      }
    }
  }

  Widget _buildClientAvatar(Map<String, dynamic> client, int index) {
    final avatarUrl = client['avatar_url'] as String?;
    final displayName = (client['full_name'] ?? '')
        .toString();

    final baseAvatar = CircleAvatar(
      backgroundColor: Colors.blue.withValues(alpha: 0.1),
      child: Text(
        displayName.isNotEmpty
            ? displayName.substring(0, 1).toUpperCase()
            : "${index + 1}",
        style: const TextStyle(color: Colors.blue),
      ),
    );

    if (avatarUrl == null || avatarUrl.isEmpty) {
      return baseAvatar;
    }

    return Stack(
      children: [
        CircleAvatar(
          backgroundColor: Colors.grey[200],
          backgroundImage: NetworkImage(avatarUrl),
        ),
        Positioned(
          bottom: -2,
          right: -2,
          child: CircleAvatar(
            radius: 10,
            backgroundColor: Colors.blue,
            child: Text(
              "${index + 1}",
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _editClient(Map<String, dynamic> client) async {
    final nameCtrl = TextEditingController(text: (client['full_name'] ?? '').toString());
    final phoneCtrl = TextEditingController(text: (client['phone'] ?? '').toString());
    final avatarCtrl = TextEditingController(text: (client['avatar_url'] ?? '').toString());

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("تعديل بيانات العميل"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'الاسم الكامل')),
              TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: 'رقم الجوال')),
              TextField(controller: avatarCtrl, decoration: const InputDecoration(labelText: 'رابط الصورة (avatar_url)')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("إلغاء")),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("حفظ")),
        ],
      ),
    );

    if (result != true) return;

    final id = client['id']?.toString();
    if (id == null) return;

    try {
      final updated = await Supabase.instance.client
          .from('profiles')
          .update({
            'full_name': nameCtrl.text.trim(),
            'phone': phoneCtrl.text.trim(),
            'avatar_url': avatarCtrl.text.trim(),
          })
          .eq('id', id)
          .select(); // نطلب الصف المحدث للتحقق أن RLS لم تمنع التعديل بصمت

      if (updated.isEmpty) {
        if (!mounted) return;
        AppNotifier.showError(
          context,
          'لم يتم تحديث بيانات العميل. تأكد أن حساب الأدمن مضاف في جدول admins وأن سياسات RLS تسمح بالتعديل.',
        );
        return;
      }

      await _fetchClients();

      if (mounted) {
        AppNotifier.showSuccess(context, "تم تحديث بيانات العميل");
      }
    } on PostgrestException catch (e) {
      if (!mounted) return;
      final msg = e.message;
      AppNotifier.showError(context, msg);
    } catch (e) {
      if (!mounted) return;
      AppNotifier.showError(context, 'حدث خطأ أثناء التحديث: $e');
    }
  }

  void _showClientDetails(Map<String, dynamic> client) {
    final updatedAtRaw = client['updated_at']?.toString();
    DateTime? updatedAt;
    if (updatedAtRaw != null) {
      try {
        updatedAt = DateTime.parse(updatedAtRaw).toLocal();
      } catch (_) {}
    }

    final name = (client['full_name'] ?? '').toString().trim();
    final phone = client['phone']?.toString();
    final userId = client['id']?.toString() ?? '';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("معلومات العميل"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (name.isNotEmpty)
              Text("الاسم: $name", style: const TextStyle(fontSize: 14)),
            if (userId.isNotEmpty)
              Text("المعرّف: $userId", style: const TextStyle(fontSize: 12, color: Colors.grey)),
            if (phone != null && phone.isNotEmpty)
              Text("الجوال: $phone", style: const TextStyle(fontSize: 14)),
            if (updatedAt != null)
              Text(
                "آخر تحديث: ${intl.DateFormat('yyyy/MM/dd - hh:mm a').format(updatedAt)}",
                style: const TextStyle(fontSize: 14),
              ),
            const SizedBox(height: 12),
            const Text(
              "معرّف العميل (ID) موجود في قاعدة البيانات ويُستخدم للربط مع الطلبات وغيرها.",
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("إغلاق"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_clients.isEmpty) return const Center(child: Text("لا يوجد عملاء مسجلين بعد"));

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        label: const Text("نسخ معرفات العملاء"),
        icon: const Icon(Icons.copy_all),
        backgroundColor: const Color(0xFF0A2647),
        foregroundColor: Colors.white,
        onPressed: () {
          final allIds = _clients
              .map((e) => (e['id'] ?? '').toString())
              .where((id) => id.isNotEmpty)
              .join('\n');
          Clipboard.setData(ClipboardData(text: allIds));
          AppNotifier.showInfo(context, "تم نسخ معرفات العملاء");
        },
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _clients.length,
        itemBuilder: (context, index) {
          final client = _clients[index];
          final dateRaw = client['updated_at']?.toString();
          DateTime? date;
          if (dateRaw != null) {
            try {
              date = DateTime.parse(dateRaw).toLocal();
            } catch (_) {}
          }
          
          final name = (client['full_name'] ?? '').toString().trim();
          final phone = client['phone']?.toString();
          final userId = client['id']?.toString() ?? '';

          return Card(
            child: ListTile(
              leading: _buildClientAvatar(client, index),
              title: Text(
                name.isNotEmpty ? name : 'عميل #${index + 1}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (userId.isNotEmpty)
                    Text(
                      "ID: ${userId.substring(0, 8)}...",
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  if (phone != null && phone.isNotEmpty)
                    Text(
                      "الجوال: $phone",
                      style:
                          const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  if (date != null)
                    Text(
                      intl.DateFormat('yyyy/MM/dd - hh:mm a').format(date),
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                ],
              ),
              isThreeLine: true,
              onTap: () => _showClientDetails(client),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit, size: 20, color: Colors.blue),
                    onPressed: () => _editClient(client),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy, size: 20, color: Colors.grey),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: userId));
                      AppNotifier.showInfo(context, "تم نسخ المعرّف");
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                    onPressed: () => _confirmDeleteClient(client),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}