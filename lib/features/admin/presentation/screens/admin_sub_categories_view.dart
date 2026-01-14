import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:doctor_store/shared/utils/app_notifier.dart';

class AdminSubCategoriesView extends StatefulWidget {
  const AdminSubCategoriesView({super.key});

  @override
  State<AdminSubCategoriesView> createState() => _AdminSubCategoriesViewState();
}

class _AdminSubCategoriesViewState extends State<AdminSubCategoriesView> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;

  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _subCategories = [];

  // خريطة بسيطة لتحويل الحروف العربية إلى أحرف لاتينية للـ slug (نفس منطق المنتجات)
  static const Map<String, String> _arabicToLatin = {
    'ا': 'a',
    'أ': 'a',
    'إ': 'a',
    'آ': 'a',
    'ب': 'b',
    'ت': 't',
    'ث': 'th',
    'ج': 'j',
    'ح': 'h',
    'خ': 'kh',
    'د': 'd',
    'ذ': 'dh',
    'ر': 'r',
    'ز': 'z',
    'س': 's',
    'ش': 'sh',
    'ص': 's',
    'ض': 'd',
    'ط': 't',
    'ظ': 'z',
    'ع': 'a',
    'غ': 'gh',
    'ف': 'f',
    'ق': 'q',
    'ك': 'k',
    'ل': 'l',
    'م': 'm',
    'ن': 'n',
    'ه': 'h',
    'و': 'w',
    'ي': 'y',
    'ى': 'a',
    'ة': 'h',
    'ؤ': 'o',
    'ئ': 'e',
  };

  /// يبني slug لاتيني قصير من نص عربي/إنجليزي
  String _buildSlug(String source) {
    String lower = source.trim().toLowerCase();

    final buffer = StringBuffer();
    for (final codeUnit in lower.runes) {
      final ch = String.fromCharCode(codeUnit);
      final mapped = _arabicToLatin[ch];
      if (mapped != null) {
        buffer.write(mapped);
      } else if (RegExp(r'[a-z0-9]').hasMatch(ch)) {
        buffer.write(ch);
      } else if (RegExp(r'[\\s_-]').hasMatch(ch)) {
        // المسافات أو الشرطات → مسافة واحدة، نحولها لاحقاً إلى "-"
        buffer.write(' ');
      } else {
        // نتجاهل أي رموز أخرى (إيموجي، علامات خاصة...)
        buffer.write(' ');
      }
    }

    String slug = buffer.toString();

    // استبدال الفراغات المتتالية بـ "-" وتوحيد الشرطات
    slug = slug.replaceAll(RegExp(r'\\s+'), '-');
    slug = slug.replaceAll(RegExp(r'-+'), '-');

    // إزالة الشرطات من البداية والنهاية إن وُجدت
    slug = slug.replaceAll(RegExp(r'^-+|-+$'), '');

    return slug;
  }

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final cats = await _supabase
          .from('categories')
          .select('id,name,is_active,sort_order')
          .eq('is_active', true)
          .order('sort_order');

      final subs = await _supabase
          .from('sub_categories')
          .select(
              'id,name,code,parent_category_id,sort_order,is_active,created_at')
          .order('parent_category_id')
          .order('sort_order');

      if (!mounted) return;
      setState(() {
        _categories = List<Map<String, dynamic>>.from(cats as List);
        _subCategories = List<Map<String, dynamic>>.from(subs as List);
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      AppNotifier.showError(context, 'خطأ في تحميل الفئات الفرعية: $e');
    }
  }

  Future<void> _openEditor({Map<String, dynamic>? existing}) async {
    final isEditing = existing != null;
    String? selectedParentId = existing?['parent_category_id'] as String?;
    final nameCtrl = TextEditingController(text: existing?['name'] ?? '');
    final codeCtrl = TextEditingController(text: existing?['code'] ?? '');
    int sortOrder = (existing?['sort_order'] as int?) ?? 0;
    final sortOrderCtrl = TextEditingController(
      text: sortOrder > 0 ? sortOrder.toString() : '',
    );
    bool sortOrderEdited = false;
    bool codeManuallyEdited =
        existing != null && (existing['code'] as String?)?.isNotEmpty == true;

    void updateSlugPreview() {
      if (codeManuallyEdited) return;
      final name = nameCtrl.text.trim();
      if (name.isEmpty) return;
      final slug = _buildSlug(name);
      if (slug.isEmpty) return;
      // لا نحدّث الحقل إذا كتب المستخدم شيئاً مختلفاً يدوياً
      codeCtrl.value = codeCtrl.value.copyWith(
        text: slug,
        selection: TextSelection.collapsed(offset: slug.length),
      );
    }

    nameCtrl.addListener(updateSlugPreview);

    bool isActive = (existing?['is_active'] as bool?) ?? true;

    final bool? saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        bool saving = false;
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title:
                  Text(isEditing ? 'تعديل فئة فرعية' : 'إضافة فئة فرعية جديدة'),
              content: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: selectedParentId,
                      decoration: const InputDecoration(
                        labelText: 'الفئة الرئيسية',
                        border: OutlineInputBorder(),
                      ),
                      items: _categories
                          .map(
                            (c) => DropdownMenuItem<String>(
                              value: c['id'] as String,
                              child: Text(
                                  c['name'] as String? ?? c['id'] as String),
                            ),
                          )
                          .toList(),
                      onChanged: (v) =>
                          setStateDialog(() => selectedParentId = v),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'اسم الفئة الفرعية (بالعربية)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: codeCtrl,
                      decoration: const InputDecoration(
                        labelText: 'الكود (Slug) بالإنجليزية - اختياري',
                        helperText:
                            'إذا تركته فارغاً سننشئه تلقائياً من الاسم (مثال: comforters, mattress-toppers)',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (v) {
                        codeManuallyEdited = v.trim().isNotEmpty;
                      },
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: sortOrderCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'ترتيب الظهور (اتركه فارغاً لتوليد تلقائي)',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (v) {
                        sortOrderEdited = v.trim().isNotEmpty;
                        final parsed = int.tryParse(v.trim());
                        if (parsed != null) {
                          sortOrder = parsed;
                        }
                      },
                    ),
                    const SizedBox(height: 4),
                    SwitchListTile(
                      title: const Text('مفعّل'),
                      value: isActive,
                      onChanged: (v) => setStateDialog(() => isActive = v),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving ? null : () => Navigator.pop(ctx),
                  child: const Text('إلغاء'),
                ),
                ElevatedButton.icon(
                  icon: saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save),
                  label: const Text('حفظ'),
                  onPressed: saving
                      ? null
                      : () async {
                          final rawName = nameCtrl.text.trim();

                          if (rawName.isEmpty || selectedParentId == null) {
                            AppNotifier.showError(
                              ctx,
                              'يرجى اختيار فئة رئيسية وكتابة اسم الفئة الفرعية.',
                            );
                            return;
                          }

                          // تحقق من أن الكود (لو تمت كتابته) بصيغة slug إنجليزية
                          final rawCode = codeCtrl.text.trim();
                          final slugRegex = RegExp(r'^[a-z0-9_-]+$');
                          if (rawCode.isNotEmpty && !slugRegex.hasMatch(rawCode)) {
                            AppNotifier.showError(
                              ctx,
                              'الكود (Slug) يجب أن يكون بالإنجليزية (a-z, 0-9, - , _) بدون مسافات.',
                            );
                            return;
                          }

                          // نحدّث حالة الزر داخل الـ dialog فقط قبل بدء العملية
                          setStateDialog(() => saving = true);
                          try {
                            // 1) توليد الكود (slug) تلقائياً إذا تُرك فارغاً
                            String code = rawCode;
                            if (code.isEmpty) {
                              code = _buildSlug(rawName);
                            }
                            if (code.isEmpty) {
                              // إذا لم نستطع توليد كود نتركه null في الـ payload
                              code = '';
                            }

                            // 2) توليد sort_order تلقائياً للفئة الجديدة إذا لم يحدده المستخدم
                            int finalSortOrder = sortOrder;
                            if (!isEditing && !sortOrderEdited) {
                              try {
                                final rows = await _supabase
                                    .from('sub_categories')
                                    .select('sort_order')
                                    .eq('parent_category_id',
                                        selectedParentId as Object)
                                    .order('sort_order', ascending: false)
                                    .limit(1);
                                final list = List<Map<String, dynamic>>.from(
                                    rows as List<dynamic>);
                                if (list.isNotEmpty) {
                                  final last =
                                      (list.first['sort_order'] as int?) ?? 0;
                                  finalSortOrder = last + 1;
                                } else {
                                  finalSortOrder = 1;
                                }
                              } catch (_) {
                                // في حال فشل الجلب، نستخدم 1 كقيمة افتراضية للمستجدين
                                finalSortOrder = sortOrder == 0 ? 1 : sortOrder;
                              }
                            }

                            final payload = {
                              'name': nameCtrl.text.trim(),
                              'code': code.isEmpty ? null : code,
                              'parent_category_id': selectedParentId,
                              'sort_order': finalSortOrder,
                              'is_active': isActive,
                            };
                            if (isEditing) {
                              await _supabase
                                  .from('sub_categories')
                                  .update(payload)
                                  .eq('id', existing['id']);
                            } else {
                              await _supabase
                                  .from('sub_categories')
                                  .insert(payload);
                            }
                            if (!ctx.mounted) return;
                            Navigator.pop(ctx, true);
                          } catch (e) {
                            if (!ctx.mounted) return;
                            setStateDialog(() => saving = false);
                            final errorText = e.toString();
                            String message = 'خطأ في حفظ الفئة الفرعية: $e';
                            if (errorText.contains('sub_categories_code_key') ||
                                errorText.contains('duplicate key value')) {
                              message =
                                  'هناك فئة فرعية أخرى تستخدم نفس الكود (Slug)، يرجى تعديل الحقل أو الاسم.';
                            }
                            AppNotifier.showError(ctx, message);
                          }
                        },
                ),
              ],
            );
          },
        );
      },
    );

    // بعد إغلاق الحوار، نحدّث القائمة في الـ State الرئيسي فقط إذا تم الحفظ
    if (saved == true) {
      await _loadAll();
      if (!mounted) return;
      AppNotifier.showSuccess(context, 'تم حفظ الفئة الفرعية بنجاح');
    }
  }

  Future<void> _deleteSubCategory(Map<String, dynamic> sub) async {
    final name = sub['name'] as String? ?? '';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف فئة فرعية'),
        content: Text(
          'هل أنت متأكد من حذف الفئة الفرعية "$name"؟\n'
          'تأكد من تحديث المنتجات المرتبطة بها إذا لزم الأمر.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('حذف', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (ok != true) return;

    try {
      await _supabase.from('sub_categories').delete().eq('id', sub['id']);
      await _loadAll();
      if (!mounted) return;
      AppNotifier.showSuccess(context, 'تم حذف الفئة الفرعية بنجاح');
    } catch (e) {
      if (!mounted) return;
      AppNotifier.showError(context, 'خطأ في حذف الفئة الفرعية: $e');
    }
  }

  /// إعادة ترتيب الفئات الفرعية داخل نفس القسم وحفظ sort_order في Supabase.
  Future<void> _onReorderForParent(
      String parentCategoryId, int oldIndex, int newIndex) async {
    if (oldIndex == newIndex) return;

    if (newIndex > oldIndex) {
      newIndex -= 1;
    }

    // نأخذ نسخة من الفئات الفرعية لهذا القسم مرتبة حسب sort_order الحالي
    final groupSubs = _subCategories
        .where((s) => s['parent_category_id'] == parentCategoryId)
        .toList()
      ..sort((a, b) {
        final aOrder = (a['sort_order'] as int?) ?? 0;
        final bOrder = (b['sort_order'] as int?) ?? 0;
        return aOrder.compareTo(bOrder);
      });

    if (oldIndex < 0 || oldIndex >= groupSubs.length) return;
    if (newIndex < 0 || newIndex >= groupSubs.length) return;

    setState(() {
      final item = groupSubs.removeAt(oldIndex);
      groupSubs.insert(newIndex, item);

      // نكتب ترتيب جديد في القائمة الأصلية _subCategories حتى ينعكس فوراً في الواجهة
      for (var i = 0; i < groupSubs.length; i++) {
        final id = groupSubs[i]['id'];
        final newOrder = i + 1;
        for (final sub in _subCategories) {
          if (sub['id'] == id) {
            sub['sort_order'] = newOrder;
            break;
          }
        }
      }
    });

    try {
      // نحفظ sort_order الجديد لكل فئة فرعية في هذا القسم
      final futures = <Future<void>>[];
      for (final sub in _subCategories) {
        if (sub['parent_category_id'] != parentCategoryId) continue;
        final id = sub['id'];
        final order = (sub['sort_order'] as int?) ?? 0;
        if (id == null || order == 0) continue;
        futures.add(
          _supabase
              .from('sub_categories')
              .update({'sort_order': order}).eq('id', id),
        );
      }
      if (futures.isEmpty) return;
      await Future.wait(futures);
      if (!mounted) return;
      AppNotifier.showSuccess(context, 'تم تحديث ترتيب الفئات الفرعية بنجاح');
    } catch (e) {
      if (!mounted) return;
      AppNotifier.showError(context, 'حدث خطأ أثناء حفظ الترتيب: $e');
      await _loadAll();
    }
  }

  List<Widget> _buildGroupedSubCategoryWidgets() {
    final List<Widget> items = [];

    for (final cat in _categories) {
      final String? catId = cat['id'] as String?;
      if (catId == null) continue;

      final groupSubs = _subCategories
          .where((s) => s['parent_category_id'] == catId)
          .toList();

      if (groupSubs.isEmpty) continue;

      groupSubs.sort((a, b) {
        final aOrder = (a['sort_order'] as int?) ?? 0;
        final bOrder = (b['sort_order'] as int?) ?? 0;
        return aOrder.compareTo(bOrder);
      });

      items.add(
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 4),
          child: Row(
            children: [
              const Icon(Icons.category, size: 18, color: Color(0xFF0A2647)),
              const SizedBox(width: 6),
              Text(
                cat['name'] as String? ?? catId,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      );

      // قائمة قابلة للسحب والإفلات داخل هذا القسم فقط
      items.add(
        ReorderableListView.builder(
          key: ValueKey('sub_list_$catId'),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: groupSubs.length,
          buildDefaultDragHandles: false,
          onReorder: (oldIndex, newIndex) =>
              _onReorderForParent(catId, oldIndex, newIndex),
          itemBuilder: (context, index) {
            final sub = groupSubs[index];
            final isActive = (sub['is_active'] as bool?) ?? true;
            return Card(
              key: ValueKey(sub['id'] ?? '$catId-$index'),
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.blueGrey.withValues(alpha: 0.1),
                  child:
                      const Icon(Icons.label_outline, color: Color(0xFF0A2647)),
                ),
                title: Text(sub['name'] as String? ?? ''),
                subtitle: Text(
                  'الكود: ${sub['code'] ?? '-'} • الترتيب: ${sub['sort_order'] ?? 0}',
                  style: const TextStyle(fontSize: 11),
                ),
                trailing: FittedBox(
                  child: Row(
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
                      Icon(
                        isActive
                            ? Icons.check_circle_outline
                            : Icons.pause_circle_outline,
                        color: isActive ? Colors.green : Colors.orangeAccent,
                        size: 18,
                      ),
                      IconButton(
                        tooltip: 'تعديل',
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: () => _openEditor(existing: sub),
                      ),
                      IconButton(
                        tooltip: 'حذف',
                        icon: const Icon(
                          Icons.delete_outline,
                          color: Colors.redAccent,
                        ),
                        onPressed: () => _deleteSubCategory(sub),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      );
    }

    final orphanSubs = _subCategories.where((sub) {
      final parentId = sub['parent_category_id'];
      return !_categories.any((c) => c['id'] == parentId);
    }).toList();

    if (orphanSubs.isNotEmpty) {
      items.add(const Divider(height: 32));
      items.add(
        const Padding(
          padding: EdgeInsets.only(bottom: 4),
          child: Text(
            'فئات فرعية بدون قسم رئيسي',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
        ),
      );

      for (final sub in orphanSubs) {
        final isActive = (sub['is_active'] as bool?) ?? true;
        items.add(
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.red.withValues(alpha: 0.08),
                child:
                    const Icon(Icons.warning_amber_outlined, color: Colors.red),
              ),
              title: Text(sub['name'] as String? ?? ''),
              subtitle: Text(
                'القسم غير متوفر • الكود: ${sub['code'] ?? '-'}',
                style: const TextStyle(fontSize: 11),
              ),
              trailing: FittedBox(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isActive
                          ? Icons.check_circle_outline
                          : Icons.pause_circle_outline,
                      color: isActive ? Colors.green : Colors.orangeAccent,
                      size: 18,
                    ),
                    IconButton(
                      tooltip: 'تعديل',
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: () => _openEditor(existing: sub),
                    ),
                    IconButton(
                      tooltip: 'حذف',
                      icon: const Icon(
                        Icons.delete_outline,
                        color: Colors.redAccent,
                      ),
                      onPressed: () => _deleteSubCategory(sub),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }
    }

    return items;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('إدارة الفئات الفرعية'),
        backgroundColor: const Color(0xFF0A2647),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'تحديث',
            icon: const Icon(Icons.refresh),
            onPressed: _loadAll,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(),
        backgroundColor: const Color(0xFF0A2647),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('فئة فرعية جديدة',
            style: TextStyle(color: Colors.white)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _subCategories.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('لا توجد فئات فرعية بعد'),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        onPressed: () => _openEditor(),
                        icon: const Icon(Icons.add),
                        label: const Text('إضافة أول فئة فرعية'),
                      ),
                    ],
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: _buildGroupedSubCategoryWidgets(),
                ),
    );
  }
}
