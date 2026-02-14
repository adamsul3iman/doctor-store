import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flex_color_picker/flex_color_picker.dart';
import 'package:doctor_store/shared/utils/app_notifier.dart';
import 'package:doctor_store/shared/utils/categories_provider.dart';

class AdminCategoriesView extends StatefulWidget {
  const AdminCategoriesView({super.key});

  @override
  State<AdminCategoriesView> createState() => _AdminCategoriesViewState();
}

class _AdminCategoriesViewState extends State<AdminCategoriesView> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _categories = [];

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    setState(() => _isLoading = true);
    try {
      final data = await _supabase
          .from('categories')
          .select()
          .order('sort_order', ascending: true);
      setState(() {
        _categories = List<Map<String, dynamic>>.from(data as List);
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        AppNotifier.showError(context, 'خطأ في تحميل الأقسام: $e');
      }
      setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleActive(Map<String, dynamic> cat, bool value) async {
    final id = cat['id'];
    setState(() {
      cat['is_active'] = value;
    });
    try {
      await _supabase
          .from('categories')
          .update({'is_active': value}).eq('id', id);
    } catch (e) {
      if (mounted) {
        AppNotifier.showError(context, 'خطأ في تحديث حالة القسم: $e');
      }
    }
  }

  /// استيراد أقسام افتراضية مبنية على الأقسام المستخدمة حالياً في المتجر.
  ///
  /// يتم حفظها في جدول `categories` باستخدام upsert حتى لا تتكرر.
  Future<void> _seedDefaultCategories() async {
    setState(() => _isLoading = true);

    final defaults = [
      {
        'id': 'bedding',
        'name': 'مفارش',
        'subtitle': 'مفارش سرير فاخرة لغرفة النوم',
        'sort_order': 1,
        'is_active': true,
        'color_value': 0xFF0A2647,
        'icon_name': 'bed',
      },
      {
        'id': 'mattresses',
        'name': 'فرشات',
        'subtitle': 'مراتب وفرشات طبية للراحة والدعم',
        'sort_order': 2,
        'is_active': true,
        'color_value': 0xFF1B4F72,
        'icon_name': 'mattress',
      },
      {
        'id': 'pillows',
        'name': 'وسائد',
        'subtitle': 'وسائد مريحة لمختلف أنماط النوم',
        'sort_order': 3,
        'is_active': true,
        'color_value': 0xFF7D6608,
        'icon_name': 'pillow',
      },
      {
        'id': 'furniture',
        'name': 'أثاث',
        'subtitle': 'أثاث غرف نوم وديكور متكامل',
        'sort_order': 4,
        'is_active': true,
        'color_value': 0xFF784212,
        'icon_name': 'couch',
      },
      {
        'id': 'dining_table',
        'name': 'سفرة',
        'subtitle': 'طاولات سفرة وكراسي بتصاميم عصرية',
        'sort_order': 5,
        'is_active': true,
        'color_value': 0xFF6C3483,
        'icon_name': 'table',
      },
      {
        'id': 'carpets',
        'name': 'سجاد',
        'subtitle': 'سجاد بسماكات وألوان متنوعة',
        'sort_order': 6,
        'is_active': true,
        'color_value': 0xFF145A32,
        'icon_name': 'carpet',
      },
      {
        'id': 'baby_supplies',
        'name': 'أطفال',
        'subtitle': 'مستلزمات نوم وغرف أطفال مريحة',
        'sort_order': 7,
        'is_active': true,
        'color_value': 0xFF2471A3,
        'icon_name': 'baby',
      },
      {
        'id': 'home_decor',
        'name': 'ديكور',
        'subtitle': 'إكسسوارات وديكورات لتكملة أناقة المنزل',
        'sort_order': 8,
        'is_active': true,
        'color_value': 0xFF922B21,
        'icon_name': 'leaf',
      },
    ];

    try {
      await _supabase.from('categories').upsert(defaults);

      if (!mounted) return;
      await _loadCategories();
      if (!mounted) return;

      AppNotifier.showSuccess(context, 'تم استيراد الأقسام الافتراضية بنجاح');
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      AppNotifier.showError(context, 'حدث خطأ أثناء استيراد الأقسام: $e');
    }
  }

  /// حذف قسم بعد تأكيد من المستخدم.
  Future<void> _confirmDeleteCategory(Map<String, dynamic> cat) async {
    final id = cat['id'] as String?;
    if (id == null) return;

    final name = (cat['name'] as String?) ?? id;

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('حذف القسم'),
          content: Text('هل أنت متأكد من حذف القسم "$name"؟\n'
              'تأكد من تحديث المنتجات المرتبطة به إذا لزم الأمر.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('إلغاء'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text(
                'حذف',
                style: TextStyle(color: Colors.redAccent),
              ),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true) return;

    setState(() => _isLoading = true);

    try {
      await _supabase.from('categories').delete().eq('id', id);
      if (!mounted) return;
      await _loadCategories();
      if (!mounted) return;

      AppNotifier.showSuccess(context, 'تم حذف القسم "$name" بنجاح');
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      AppNotifier.showError(context, 'حدث خطأ أثناء حذف القسم: $e');
    }
  }

  /// إعادة ترتيب الأقسام في الواجهة وحفظ "sort_order" في Supabase.
  Future<void> _onReorder(int oldIndex, int newIndex) async {
    if (oldIndex == newIndex) return;

    if (newIndex > oldIndex) {
      newIndex -= 1;
    }

    setState(() {
      final item = _categories.removeAt(oldIndex);
      _categories.insert(newIndex, item);
    });

    try {
      // نحدّث sort_order لكل قسم بتحديث منفصل لتجنّب مشاكل الأعمدة not-null أو المفاتيح
      final futures = <Future<void>>[];

      for (var i = 0; i < _categories.length; i++) {
        final cat = _categories[i];
        final id = cat['id'];
        if (id == null) continue;

        final newOrder = i + 1;
        cat['sort_order'] = newOrder; // تحديث القيمة محلياً أيضاً

        futures.add(
          _supabase
              .from('categories')
              .update({'sort_order': newOrder}).eq('id', id),
        );
      }

      if (futures.isEmpty) return;

      await Future.wait(futures);

      if (!mounted) return;
      AppNotifier.showSuccess(context, 'تم تحديث ترتيب الأقسام بنجاح');
    } catch (e) {
      if (!mounted) return;
      AppNotifier.showError(context, 'حدث خطأ أثناء حفظ الترتيب: $e');
      // في حالة الخطأ، نعيد التحميل من المصدر حتى لا يبقى الترتيب غير متسق
      await _loadCategories();
    }
  }

  Future<void> _openCategoryEditor({Map<String, dynamic>? existing}) async {
    final isEditing = existing != null;
    final idController = TextEditingController(text: existing?['id'] ?? '');
    final nameController = TextEditingController(text: existing?['name'] ?? '');
    final subtitleController =
        TextEditingController(text: existing?['subtitle'] ?? '');
    int sortOrder = (existing?['sort_order'] as int?) ?? 0;
    String selectedIconName = (existing?['icon_name'] as String?) ?? 'box';

    Color color;
    final rawColor = existing?['color_value'];
    if (rawColor is int) {
      color = Color(rawColor);
    } else {
      color = const Color(0xFF0A2647);
    }

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        bool isSaving = false;
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(isEditing ? 'تعديل القسم' : 'إضافة قسم جديد'),
              content: SizedBox(
                width: 500,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: idController,
                        enabled: !isEditing,
                        decoration: const InputDecoration(
                          labelText:
                              'معرّف القسم (Code) - بالإنجليزية، مثال: bedding',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: nameController,
                        decoration: const InputDecoration(
                          labelText: 'الاسم الظاهر بالعربية',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: subtitleController,
                        decoration: const InputDecoration(
                          labelText: 'وصف قصير (يظهر تحت الاسم)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Text('ترتيب الظهور:'),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                              ),
                              controller: TextEditingController(
                                  text: sortOrder.toString()),
                              onChanged: (v) {
                                final parsed = int.tryParse(v) ?? 0;
                                sortOrder = parsed;
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // اختيار الأيقونة
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('أيقونة القسم'),
                        trailing: DropdownButton<String>(
                          value: selectedIconName,
                          items: availableCategoryIcons.entries.map((entry) {
                            return DropdownMenuItem(
                              value: entry.key,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(entry.value, size: 18),
                                  const SizedBox(width: 8),
                                  Text(entry.key),
                                ],
                              ),
                            );
                          }).toList(),
                          onChanged: (value) {
                            if (value != null) {
                              setState(() => selectedIconName = value);
                            }
                          },
                        ),
                      ),
                      const SizedBox(height: 12),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('لون الهوية في الواجهة'),
                        trailing: ColorIndicator(
                          width: 30,
                          height: 30,
                          borderRadius: 999,
                          color: color,
                          onSelect: () async {
                            final picked = await showColorPickerDialog(
                              context,
                              color,
                              title: const Text('اختر لوناً للقسم'),
                              enableOpacity: false,
                              showColorCode: true,
                              colorCodeHasColor: true,
                            );
                            setState(() => color = picked);
                          },
                        ),
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
                          final rawId = idController.text.trim();
                          final rawName = nameController.text.trim();

                          // تحقق أساسي من الحقول المطلوبة
                          if (rawId.isEmpty || rawName.isEmpty) {
                            AppNotifier.showError(
                              ctx,
                              'يرجى إدخال كود القسم بالإنجليزية واسم عربي ظاهر.',
                            );
                            return;
                          }

                          // يفضَّل أن يكون الكود إنجليزيًا بدون مسافات (slug)
                          final slugRegex = RegExp(r'^[a-z0-9_-]+$');
                          if (!slugRegex.hasMatch(rawId)) {
                            AppNotifier.showError(
                              ctx,
                              'كود القسم يجب أن يكون بالإنجليزية (a-z, 0-9, - , _) بدون مسافات.',
                            );
                            return;
                          }

                          // منع تكرار نفس الكود عند إضافة قسم جديد
                          if (!isEditing &&
                              _categories.any((c) =>
                                  (c['id'] as String?)?.toLowerCase() ==
                                  rawId.toLowerCase())) {
                            AppNotifier.showError(
                              ctx,
                              'يوجد قسم آخر يستخدم نفس الكود، يرجى اختيار كود مختلف.',
                            );
                            return;
                          }

                          // إذا لم يتم إدخال ترتيب ظهور، نولّده تلقائياً بعد آخر قسم
                          if (!isEditing && sortOrder == 0) {
                            final maxOrder = _categories
                                .map((c) => (c['sort_order'] as int?) ?? 0)
                                .fold<int>(0, (prev, v) => v > prev ? v : prev);
                            sortOrder = maxOrder + 1;
                          }

                          setState(() => isSaving = true);
                          try {
                            final payload = {
                              'id': rawId,
                              'name': rawName,
                              'subtitle': subtitleController.text.trim(),
                              'sort_order': sortOrder,
                              'color_value': color.toARGB32(),
                              'icon_name': selectedIconName,
                            };
                            await _supabase
                                .from('categories')
                                .upsert(payload);

                            if (!context.mounted) return;

                            Navigator.pop(ctx);
                            await _loadCategories();
                            if (!context.mounted) return;

                            AppNotifier.showSuccess(context, 'تم حفظ القسم بنجاح');
                          } catch (e) {
                            if (!context.mounted) return;

                            setState(() => isSaving = false);
                            final errorText = e.toString();
                            String message = 'خطأ في حفظ القسم: $e';
                            if (errorText.contains('duplicate key value') ||
                                errorText.contains('categories_pkey') ||
                                errorText.contains('categories_id_key')) {
                              message =
                                  'يوجد قسم آخر بنفس الكود، يرجى اختيار كود مختلف.';
                            }
                            AppNotifier.showError(context, message);
                          }
                        },
                  icon: isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('إدارة الأقسام'),
        backgroundColor: const Color(0xFF0A2647),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'تحديث القائمة',
            icon: const Icon(Icons.refresh),
            onPressed: _loadCategories,
          ),
          IconButton(
            tooltip: 'استيراد الأقسام الافتراضية',
            icon: const Icon(Icons.auto_fix_high_outlined),
            onPressed: _seedDefaultCategories,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openCategoryEditor(),
        backgroundColor: const Color(0xFF0A2647),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('قسم جديد', style: TextStyle(color: Colors.white)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      'قم من هنا بإدارة أقسام المتجر: إضافة، تعديل، تفعيل/تعطيل، وحذف الأقسام.',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: Colors.grey[700]),
                      textAlign: TextAlign.right,
                    ),
                  ),
                ),
                Expanded(
                  child: _categories.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('لا توجد أقسام بعد'),
                              const SizedBox(height: 8),
                              ElevatedButton.icon(
                                onPressed: _seedDefaultCategories,
                                icon: const Icon(Icons.auto_fix_high_outlined),
                                label:
                                    const Text('استيراد الأقسام الافتراضية'),
                              ),
                            ],
                          ),
                        )
                      : ReorderableListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _categories.length,
                          onReorder: (oldIndex, newIndex) {
                            _onReorder(oldIndex, newIndex);
                          },
                          buildDefaultDragHandles: false,
                          itemBuilder: (context, index) {
                            final cat = _categories[index];
                            final color = (cat['color_value'] is int)
                                ? Color(cat['color_value'] as int)
                                : const Color(0xFF0A2647);
                            final isActive =
                                (cat['is_active'] as bool?) ?? true;

                            return Card(
                              key: ValueKey(cat['id'] ?? index),
                              margin: const EdgeInsets.only(bottom: 12),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor:
                                      color.withValues(alpha: 0.15),
                                  child: Icon(Icons.category, color: color),
                                ),
                                title: Text(cat['name'] ?? ''),
                                subtitle: Text(
                                  'الكود: ${cat['id']}  •  الترتيب: ${cat['sort_order'] ?? 0}',
                                  style: const TextStyle(fontSize: 12),
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    ReorderableDragStartListener(
                                      index: index,
                                      child: const Padding(
                                        padding: EdgeInsetsDirectional.only(end: 4.0),
                                        child: Icon(
                                          Icons.drag_indicator,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ),
                                    Switch(
                                      value: isActive,
                                      onChanged: (v) =>
                                          _toggleActive(cat, v),
                                      activeThumbColor: const Color(0xFF0A2647),
                                    ),
                                    IconButton(
                                      tooltip: 'تعديل',
                                      icon:
                                          const Icon(Icons.edit_outlined),
                                      onPressed: () =>
                                          _openCategoryEditor(existing: cat),
                                    ),
                                    IconButton(
                                      tooltip: 'حذف',
                                      icon: const Icon(
                                        Icons.delete_outline,
                                        color: Colors.redAccent,
                                      ),
                                      onPressed: () =>
                                          _confirmDeleteCategory(cat),
                                    ),
                                  ],
                                ),
                                onTap: () =>
                                    _openCategoryEditor(existing: cat),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}