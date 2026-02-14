// ignore_for_file: use_build_context_synchronously

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:doctor_store/shared/utils/image_compressor.dart';
import 'package:doctor_store/shared/utils/image_url_helper.dart';
import 'package:doctor_store/shared/widgets/app_network_image.dart';

class AdminSettingsView extends StatefulWidget {
  const AdminSettingsView({super.key});

  @override
  State<AdminSettingsView> createState() => _AdminSettingsViewState();
}

class _HomeSectionToggle extends StatelessWidget {
  final String sectionKey;
  final String title;
  final String subtitle;

  const _HomeSectionToggle({
    required this.sectionKey,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final state = context.findAncestorStateOfType<_AdminSettingsViewState>();
    final enabled = state?._homeSectionsEnabled[sectionKey] ?? true;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SwitchListTile(
          value: enabled,
          onChanged: (val) => state?._updateHomeSection(sectionKey, val),
          title: Text(title),
          subtitle: Text(
            subtitle,
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
          activeThumbColor: const Color(0xFF0A2647),
        ),
        Padding(
          padding: const EdgeInsetsDirectional.only(start: 16, end: 16, bottom: 8),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              onPressed: state == null
                  ? null
                  : () => state._openHomeSectionTextsEditor(sectionKey, title),
              icon: const Icon(Icons.text_fields, size: 18),
              label: const Text('تعديل النص الظاهر في الصفحة الرئيسية'),
            ),
          ),
        ),
        const Divider(height: 1),
      ],
    );
  }
}

class _AdminSettingsViewState extends State<AdminSettingsView> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = false;
  bool _isHomeSectionsLoading = false;

  // Track unsaved changes
  bool _hasUnsavedChanges = false;
  bool _isAutoSaving = false;
  String? _lastSaveStatus;

  // Debounce timer for auto-save
  Timer? _autoSaveTimer;
  final Map<String, bool> _homeSectionsEnabled = {};
  final Map<String, String> _homeSectionsTitle = {};
  final Map<String, String> _homeSectionsSubtitle = {};
  final Map<String, int> _homeSectionsSortOrder = {};
  final List<String> _homeSectionsOrder = [
    'hero',
    'categories',
    'flash_sale',
    'latest',
    'middle_banner',
    'dining',
    'owner_section',
    'baby_section',
  ];

  // Controllers
  final _whatsappController = TextEditingController();
  final _facebookController = TextEditingController();
  final _instagramController = TextEditingController();
  final _tiktokController = TextEditingController();
  final _ownerNameController = TextEditingController();
  final _ownerBioController = TextEditingController();
  String _ownerImageUrl = '';

  bool _freeShippingEnabled = true;
  final _freeShippingThresholdController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _whatsappController.dispose();
    _facebookController.dispose();
    _instagramController.dispose();
    _tiktokController.dispose();
    _ownerNameController.dispose();
    _ownerBioController.dispose();
    _freeShippingThresholdController.dispose();
    _autoSaveTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    try {
      final data = await _supabase
          .from('app_settings')
          .select()
          .eq('id', 1)
          .single();
      _whatsappController.text = data['whatsapp_number'] ?? '';
      _facebookController.text = data['facebook_url'] ?? '';
      _instagramController.text = data['instagram_url'] ?? '';
      _tiktokController.text = data['tiktok_url'] ?? '';
      _ownerNameController.text = data['owner_name'] ?? '';
      _ownerBioController.text = data['owner_bio'] ?? '';
      _ownerImageUrl = (data['owner_image_url'] as String?) ?? '';

      _freeShippingEnabled = (data['free_shipping_enabled'] as bool?) ?? true;
      _freeShippingThresholdController.text =
          (data['free_shipping_threshold'] as num?)?.toDouble().toString() ?? '';

      // Add change listeners for auto-save
      _setupAutoSaveListeners();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ في تحميل إعدادات الموقع: $e')),
      );
    } finally {
      // في كل الأحوال نحاول تحميل إعدادات أقسام الصفحة الرئيسية
      if (mounted) {
        await _loadHomeSections();
      }
    }
  }

  void _setupAutoSaveListeners() {
    // Auto-save for simple text fields (with debounce)
    void onFieldChanged() {
      setState(() => _hasUnsavedChanges = true);
      _debouncedAutoSave();
    }

    _whatsappController.addListener(onFieldChanged);
    _facebookController.addListener(onFieldChanged);
    _instagramController.addListener(onFieldChanged);
    _tiktokController.addListener(onFieldChanged);
    _ownerNameController.addListener(onFieldChanged);
    _ownerBioController.addListener(onFieldChanged);
    _freeShippingThresholdController.addListener(onFieldChanged);
  }

  void _debouncedAutoSave() {
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer(const Duration(seconds: 2), () {
      if (_hasUnsavedChanges && mounted) {
        _autoSaveSettings();
      }
    });
  }

  Future<void> _autoSaveSettings() async {
    if (_isAutoSaving) return;
    setState(() => _isAutoSaving = true);

    try {
      final thresholdText = _freeShippingThresholdController.text.trim();
      final threshold = double.tryParse(thresholdText);

      await _supabase.from('app_settings').update({
        'whatsapp_number': _whatsappController.text,
        'facebook_url': _facebookController.text,
        'instagram_url': _instagramController.text,
        'tiktok_url': _tiktokController.text,
        'owner_name': _ownerNameController.text,
        'owner_bio': _ownerBioController.text,
        'owner_image_url': _ownerImageUrl,
        'free_shipping_enabled': _freeShippingEnabled,
        if (threshold != null) 'free_shipping_threshold': threshold,
      }).eq('id', 1);

      if (mounted) {
        setState(() {
          _hasUnsavedChanges = false;
          _isAutoSaving = false;
          _lastSaveStatus = 'تم الحفظ تلقائياً';
        });
        // Clear status after 3 seconds
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) {
            setState(() => _lastSaveStatus = null);
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isAutoSaving = false);
      }
    }
  }

  Future<void> _loadHomeSections() async {
    setState(() => _isHomeSectionsLoading = true);
    try {
      final data = await _supabase
          .from('home_sections')
          .select('key, enabled, title, subtitle, sort_order');

      if (!mounted) return;

      final Map<String, bool> enabledMap = {};
      final Map<String, String> titleMap = {};
      final Map<String, String> subtitleMap = {};
      final Map<String, int> sortMap = {};
      for (final row in data) {
        final key = row['key'] as String?;
        if (key != null) {
          enabledMap[key] = (row['enabled'] as bool?) ?? true;
          titleMap[key] = (row['title'] as String?) ?? '';
          subtitleMap[key] = (row['subtitle'] as String?) ?? '';
          sortMap[key] = (row['sort_order'] as int?) ?? 0;
        }
      }

      // ترتيب القائمة الافتراضية حسب sort_order إذا وُجد، وإلا حسب الترتيب الثابت
      final defaultOrder = List<String>.from(_homeSectionsOrder);
      defaultOrder.sort((a, b) {
        final sa = sortMap[a] ?? _homeSectionsOrder.indexOf(a);
        final sb = sortMap[b] ?? _homeSectionsOrder.indexOf(b);
        return sa.compareTo(sb);
      });

      setState(() {
        _homeSectionsEnabled
          ..clear()
          ..addAll(enabledMap);
        _homeSectionsTitle
          ..clear()
          ..addAll(titleMap);
        _homeSectionsSubtitle
          ..clear()
          ..addAll(subtitleMap);
        _homeSectionsSortOrder
          ..clear()
          ..addAll(sortMap);
        _homeSectionsOrder
          ..clear()
          ..addAll(defaultOrder);
        _isHomeSectionsLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isHomeSectionsLoading = false);
    }
  }

  Future<void> _updateHomeSection(String key, bool enabled) async {
    setState(() {
      _homeSectionsEnabled[key] = enabled;
    });

    try {
      await _supabase.from('home_sections').upsert({
        'key': key,
        'enabled': enabled,
        // نحافظ على النصوص الحالية إن وُجدت
        'title': _homeSectionsTitle[key],
        'subtitle': _homeSectionsSubtitle[key],
        'sort_order': _homeSectionsSortOrder[key],
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ في تحديث القسم: $e')),
      );
    }
  }

  Future<void> _openSeoEditor(String key, String defaultTitle) async {
    Map<String, dynamic>? existing;
    try {
      existing = await _supabase
          .from('seo_pages')
          .select('key,title,description')
          .eq('key', key)
          .maybeSingle();
    } catch (_) {
      existing = null;
    }

    final titleController = TextEditingController(
      text: existing != null && (existing['title'] as String?)?.isNotEmpty == true
          ? existing['title'] as String
          : defaultTitle,
    );
    final descController = TextEditingController(
      text: existing != null ? (existing['description'] as String? ?? '') : '',
    );

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        bool isSaving = false;
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('إعدادات SEO للصفحة'),
              content: SizedBox(
                width: 600,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: titleController,
                        decoration: const InputDecoration(
                          labelText: 'عنوان الصفحة (يظهر في شريط المتصفح ونتائج البحث)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: descController,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          labelText: 'وصف SEO (meta description)',
                          alignLabelWithHint: true,
                          border: OutlineInputBorder(),
                          hintText: 'اكتب وصفاً قصيراً يشجع الزائر على الدخول من نتائج البحث.',
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
                          setState(() => isSaving = true);
                          try {
                            final title = titleController.text.trim().isEmpty
                                ? defaultTitle
                                : titleController.text.trim();
                            final desc = descController.text.trim();

                            await _supabase.from('seo_pages').upsert({
                              'key': key,
                              'title': title,
                              'description': desc,
                            });

                            if (!mounted) return;
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('تم حفظ إعدادات SEO بنجاح')),
                            );
                          } catch (e) {
                            setState(() => isSaving = false);
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('خطأ في حفظ إعدادات SEO: $e')),
                            );
                          }
                        },
                  icon: isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.save),
                  label: const Text('حفظ'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0A2647),
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _persistHomeSectionsOrder() async {
    try {
      final futures = <Future<void>>[];
      for (var i = 0; i < _homeSectionsOrder.length; i++) {
        final key = _homeSectionsOrder[i];
        final sort = i + 1;
        _homeSectionsSortOrder[key] = sort;
        futures.add(_supabase.from('home_sections').upsert({
          'key': key,
          'enabled': _homeSectionsEnabled[key] ?? true,
          'title': _homeSectionsTitle[key],
          'subtitle': _homeSectionsSubtitle[key],
          'sort_order': sort,
        }));
      }
      if (futures.isNotEmpty) {
        await Future.wait(futures);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ في حفظ ترتيب الأقسام: $e')),
      );
    }
  }

  void _moveHomeSection(String key, int delta) {
    final currentIndex = _homeSectionsOrder.indexOf(key);
    if (currentIndex == -1) return;
    final newIndex = currentIndex + delta;
    if (newIndex < 0 || newIndex >= _homeSectionsOrder.length) return;

    setState(() {
      final item = _homeSectionsOrder.removeAt(currentIndex);
      _homeSectionsOrder.insert(newIndex, item);
    });

    _persistHomeSectionsOrder();
  }

  Future<void> _openHomeSectionTextsEditor(String key, String adminTitle) async {
    final currentTitle = _homeSectionsTitle[key] ?? '';
    final currentSubtitle = _homeSectionsSubtitle[key] ?? '';

    final titleController = TextEditingController(text: currentTitle);
    final subtitleController = TextEditingController(text: currentSubtitle);

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        bool isSaving = false;
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('نص قسم "$adminTitle" في الصفحة الرئيسية'),
              content: SizedBox(
                width: 600,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: titleController,
                        decoration: const InputDecoration(
                          labelText: 'العنوان الظاهر فوق القسم',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: subtitleController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'نص فرعي / وصف قصير (اختياري)',
                          alignLabelWithHint: true,
                          border: OutlineInputBorder(),
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
                          setState(() => isSaving = true);
                          try {
                            final newTitle = titleController.text.trim();
                            final newSubtitle = subtitleController.text.trim();

                            await _supabase.from('home_sections').upsert({
                              'key': key,
                              'enabled': _homeSectionsEnabled[key] ?? true,
                              'title': newTitle,
                              'subtitle': newSubtitle,
                            });

                            if (!mounted) return;

                            setState(() {
                              _homeSectionsTitle[key] = newTitle;
                              _homeSectionsSubtitle[key] = newSubtitle;
                            });

                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('تم حفظ نصوص القسم بنجاح')),
                            );
                          } catch (e) {
                            setState(() => isSaving = false);
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('خطأ في حفظ نص القسم: $e')),
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
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0A2647),
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _saveSettings() async {
    setState(() => _isLoading = true);
    try {
      final thresholdText = _freeShippingThresholdController.text.trim();
      final threshold = double.tryParse(thresholdText);

      await _supabase.from('app_settings').update({
        'whatsapp_number': _whatsappController.text,
        'facebook_url': _facebookController.text,
        'instagram_url': _instagramController.text,
        'tiktok_url': _tiktokController.text,
        'owner_name': _ownerNameController.text,
        'owner_bio': _ownerBioController.text,
        'owner_image_url': _ownerImageUrl,
        'free_shipping_enabled': _freeShippingEnabled,
        if (threshold != null) 'free_shipping_threshold': threshold,
      }).eq('id', 1);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم حفظ إعدادات التواصل بنجاح')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في حفظ الإعدادات: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _openStaticPageEditor(String key, String defaultTitle) async {
    Map<String, dynamic>? existing;
    try {
      existing = await _supabase
          .from('static_pages')
          .select('key,title,content')
          .eq('key', key)
          .maybeSingle();
    } catch (_) {
      existing = null;
    }

    final titleController = TextEditingController(
      text: existing != null && (existing['title'] as String?)?.isNotEmpty == true
          ? existing['title'] as String
          : defaultTitle,
    );
    final contentController = TextEditingController(
      text: existing != null ? (existing['content'] as String? ?? '') : '',
    );

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        bool isSaving = false;
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('تعديل $defaultTitle'),
              content: SizedBox(
                width: 600,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: titleController,
                        decoration: const InputDecoration(
                          labelText: 'عنوان الصفحة (يظهر في الأعلى)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: contentController,
                        maxLines: 10,
                        decoration: const InputDecoration(
                          labelText: 'محتوى الصفحة',
                          alignLabelWithHint: true,
                          border: OutlineInputBorder(),
                          hintText: 'يمكنك كتابة النص الكامل للصفحة هنا، مع استخدام أسطر جديدة للفقرات.',
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
                          setState(() => isSaving = true);
                          try {
                            final title =
                                titleController.text.trim().isEmpty ? defaultTitle : titleController.text.trim();
                            final content = contentController.text.trim();

                            await _supabase.from('static_pages').upsert({
                              'key': key,
                              'title': title,
                              'content': content,
                            });

                            if (!mounted) return;
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('تم حفظ "$title" بنجاح')),
                            );
                          } catch (e) {
                            setState(() => isSaving = false);
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('خطأ في حفظ الصفحة: $e')),
                            );
                          }
                        },
                  icon: isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.save),
                  label: const Text('حفظ الصفحة'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0A2647),
                    foregroundColor: Colors.white,
                  ),
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
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        backgroundColor: Colors.grey[50],
        body: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) {
            return [
              SliverAppBar(
                pinned: true,
                floating: true,
                snap: true,
                elevation: 0,
                scrolledUnderElevation: 2,
                backgroundColor: Colors.white,
                title: const Text(
                  'إعدادات الموقع',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0A2647),
                  ),
                ),
                centerTitle: true,
                iconTheme: const IconThemeData(color: Color(0xFF0A2647)),
                bottom: PreferredSize(
                  preferredSize: const Size.fromHeight(52),
                  child: Material(
                    color: Colors.white,
                    elevation: 0,
                    child: TabBar(
                      isScrollable: true,
                      indicatorColor: const Color(0xFF0A2647),
                      labelColor: const Color(0xFF0A2647),
                      unselectedLabelColor: Colors.grey[600],
                      labelStyle: const TextStyle(
                        fontWeight: FontWeight.w700,
                      ),
                      tabs: const [
                        Tab(
                          icon: Icon(Icons.chat_outlined, size: 18),
                          text: 'التواصل وصاحب المتجر',
                        ),
                        Tab(
                          icon: Icon(Icons.description_outlined, size: 18),
                          text: 'الصفحات الثابتة',
                        ),
                        Tab(
                          icon: Icon(Icons.search, size: 18),
                          text: 'SEO الموقع',
                        ),
                        Tab(
                          icon: Icon(Icons.home_outlined, size: 18),
                          text: 'الصفحة الرئيسية',
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ];
          },
          body: TabBarView(
            children: [
              _buildContactAndOwnerTab(),
              _buildStaticPagesTab(),
              _buildSeoTab(),
              _buildHomeTab(),
            ],
          ),
        ),
        bottomNavigationBar: _buildStickySaveBar(),
      ),
    );
  }

  // شريط الحفظ الثابت في الأسفل
  Widget? _buildStickySaveBar() {
    // Only show on first tab (Contact & Owner) where auto-save applies
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: SafeArea(
        child: Row(
          children: [
            // Status indicator
            Expanded(
              child: Row(
                children: [
                  if (_isAutoSaving)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFF0A2647),
                      ),
                    )
                  else if (_hasUnsavedChanges)
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.orange,
                        shape: BoxShape.circle,
                      ),
                    )
                  else if (_lastSaveStatus != null)
                    const Icon(
                      Icons.check_circle_outline,
                      color: Colors.green,
                      size: 18,
                    ),
                  const SizedBox(width: 8),
                  Text(
                    _isAutoSaving
                        ? 'جاري الحفظ...'
                        : _lastSaveStatus ??
                            (_hasUnsavedChanges
                                ? 'تغييرات غير محفوظة'
                                : 'تم الحفظ'),
                    style: TextStyle(
                      fontSize: 13,
                      color: _hasUnsavedChanges ? Colors.orange : Colors.grey[600],
                      fontWeight: _hasUnsavedChanges ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
            // Manual save button (prominent when unsaved)
            if (_hasUnsavedChanges)
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _saveSettings,
                icon: _isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.save, size: 18),
                label: const Text('حفظ الآن'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0A2647),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              )
            else
              OutlinedButton.icon(
                onPressed: _isLoading ? null : _saveSettings,
                icon: const Icon(Icons.save, size: 18),
                label: const Text('حفظ'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF0A2647),
                  side: const BorderSide(color: Color(0xFF0A2647)),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // تبويب 1: إعدادات التواصل + صاحب المتجر
  Widget _buildContactAndOwnerTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          elevation: 1,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "إعدادات التواصل",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                const Text(
                  'تُستخدم هذه البيانات في صفحة اتصل بنا وزر الواتساب في الواجهة.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 16),
                _buildTextField("رقم واتساب (بدون +)", _whatsappController,
                    icon: Icons.phone_android),
                _buildTextField("رابط فيسبوك", _facebookController,
                    icon: Icons.facebook),
                _buildTextField("رابط انستجرام", _instagramController,
                    icon: Icons.camera_alt),
                _buildTextField("رابط تيك توك", _tiktokController,
                    icon: Icons.video_library),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          elevation: 1,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "إعدادات الشحن المجاني",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                const Text(
                  'تحكم بإظهار بانر الشحن المجاني في السلة وتحديد قيمة الحد الأدنى للحصول عليه.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _freeShippingEnabled,
                  onChanged: (val) {
                    setState(() {
                      _freeShippingEnabled = val;
                      _hasUnsavedChanges = true;
                    });
                    _debouncedAutoSave();
                  },
                  title: const Text('تفعيل بانر الشحن المجاني في السلة'),
                  activeThumbColor: const Color(0xFF0A2647),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _freeShippingThresholdController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'حد الشحن المجاني (دينار)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.local_shipping_outlined),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          elevation: 1,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "قسم صاحب المتجر",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                const Text(
                  'النص والصورة التي تظهر في قسم التعريف بصاحب المتجر في الصفحة الرئيسية.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: Column(
                        children: [
                          AspectRatio(
                            aspectRatio: 3 / 4,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: _ownerImageUrl.trim().isNotEmpty
                                  ? AppNetworkImage(
                                      url: _ownerImageUrl,
                                      variant: ImageVariant.homeBanner,
                                      fit: BoxFit.cover,
                                      placeholder: Container(color: Colors.grey[200]),
                                      errorWidget: Container(
                                        color: Colors.grey[200],
                                        child: const Icon(
                                          Icons.person,
                                          size: 50,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    )
                                  : Container(
                                      color: Colors.grey[200],
                                      child: const Icon(
                                        Icons.person,
                                        size: 50,
                                        color: Colors.grey,
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextButton.icon(
                            onPressed: _pickOwnerImage,
                            icon: const Icon(Icons.image_outlined),
                            label: const Text('تغيير صورة صاحب المتجر'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 5,
                      child: Column(
                        children: [
                          _buildTextField(
                            "اسم صاحب المتجر",
                            _ownerNameController,
                            icon: Icons.person,
                          ),
                          _buildTextField(
                            "نبذة مختصرة",
                            _ownerBioController,
                            icon: Icons.info,
                            maxLines: 3,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          height: 48,
          child: ElevatedButton.icon(
            onPressed: _isLoading ? null : _saveSettings,
            icon: const Icon(Icons.save),
            label: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text("حفظ إعدادات التواصل وصاحب المتجر"),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0A2647),
              foregroundColor: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  // تبويب 2: الصفحات الثابتة
  Widget _buildStaticPagesTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "الصفحات الثابتة",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'اضغط على أي صفحة لتعديل عنوانها ومحتواها كما يظهر للعميل.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 12),
                ListTile(
                  leading: const Icon(
                    Icons.privacy_tip_outlined,
                    color: Color(0xFF0A2647),
                  ),
                  title: const Text("سياسة الخصوصية"),
                  subtitle: const Text(
                    "تحرير النص كاملاً كما يظهر في صفحة سياسة الخصوصية",
                  ),
                  onTap: () =>
                      _openStaticPageEditor('privacy', 'سياسة الخصوصية'),
                  trailing: const Icon(Icons.chevron_left),
                ),
                const SizedBox(height: 8),
                ListTile(
                  leading: const Icon(
                    Icons.article_outlined,
                    color: Color(0xFF0A2647),
                  ),
                  title: const Text("الشروط والأحكام"),
                  subtitle: const Text(
                    "تحرير نص الشروط والأحكام كما يظهر للعميل",
                  ),
                  onTap: () =>
                      _openStaticPageEditor('terms', 'الشروط والأحكام'),
                  trailing: const Icon(Icons.chevron_left),
                ),
                const SizedBox(height: 8),
                ListTile(
                  leading: const Icon(
                    Icons.info_outline,
                    color: Color(0xFF0A2647),
                  ),
                  title: const Text("من نحن"),
                  subtitle: const Text("تحرير محتوى صفحة من نحن"),
                  onTap: () => _openStaticPageEditor('about', 'من نحن'),
                  trailing: const Icon(Icons.chevron_left),
                ),
                const SizedBox(height: 8),
                ListTile(
                  leading: const Icon(
                    Icons.call_outlined,
                    color: Color(0xFF0A2647),
                  ),
                  title: const Text("مقدمة اتصل بنا"),
                  subtitle: const Text(
                    "تحرير العنوان والنص التعريفي أعلى صفحة اتصل بنا",
                  ),
                  onTap: () => _openStaticPageEditor('contact', 'اتصل بنا'),
                  trailing: const Icon(Icons.chevron_left),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // تبويب 3: إعدادات SEO
  Widget _buildSeoTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "SEO الموقع",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'اضبط عناوين ووصف الصفحات كما تظهر في نتائج محركات البحث.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 12),
                ListTile(
                  leading: const Icon(
                    Icons.home_outlined,
                    color: Color(0xFF0A2647),
                  ),
                  title: const Text("الصفحة الرئيسية"),
                  subtitle: const Text(
                    "عنوان ووصف السيو لصفحة الهوم",
                  ),
                  onTap: () => _openSeoEditor(
                    'home',
                    'متجر الدكتور - حلول النوم والراحة',
                  ),
                  trailing: const Icon(Icons.chevron_left),
                ),
                const SizedBox(height: 8),
                ListTile(
                  leading: const Icon(
                    Icons.info_outline,
                    color: Color(0xFF0A2647),
                  ),
                  title: const Text("من نحن"),
                  subtitle: const Text(
                    "عنوان ووصف السيو لصفحة من نحن",
                  ),
                  onTap: () =>
                      _openSeoEditor('about', 'من نحن - متجر الدكتور'),
                  trailing: const Icon(Icons.chevron_left),
                ),
                const SizedBox(height: 8),
                ListTile(
                  leading: const Icon(
                    Icons.call_outlined,
                    color: Color(0xFF0A2647),
                  ),
                  title: const Text("اتصل بنا"),
                  subtitle: const Text(
                    "عنوان ووصف السيو لصفحة اتصل بنا",
                  ),
                  onTap: () =>
                      _openSeoEditor('contact', 'اتصل بنا - متجر الدكتور'),
                  trailing: const Icon(Icons.chevron_left),
                ),
                const SizedBox(height: 8),
                ListTile(
                  leading: const Icon(
                    Icons.privacy_tip_outlined,
                    color: Color(0xFF0A2647),
                  ),
                  title: const Text("سياسة الخصوصية"),
                  subtitle: const Text(
                    "عنوان ووصف السيو لصفحة سياسة الخصوصية",
                  ),
                  onTap: () => _openSeoEditor(
                    'privacy',
                    'سياسة الخصوصية - متجر الدكتور',
                  ),
                  trailing: const Icon(Icons.chevron_left),
                ),
                const SizedBox(height: 8),
                ListTile(
                  leading: const Icon(
                    Icons.article_outlined,
                    color: Color(0xFF0A2647),
                  ),
                  title: const Text("الشروط والأحكام"),
                  subtitle: const Text(
                    "عنوان ووصف السيو لصفحة الشروط والأحكام",
                  ),
                  onTap: () => _openSeoEditor(
                    'terms',
                    'الشروط والأحكام - متجر الدكتور',
                  ),
                  trailing: const Icon(Icons.chevron_left),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // تبويب 4: الصفحة الرئيسية (الأقسام + الترتيب)
  Widget _buildHomeTab() {
    if (_isHomeSectionsLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "أقسام الصفحة الرئيسية",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'فعّل أو أوقف كل قسم، واضغط على أيقونة النص لتعديل العنوان والوصف.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 8),
                const Column(
                  children: [
                    _HomeSectionToggle(
                      sectionKey: 'hero',
                      title: 'سلايدر البانرات (أعلى الصفحة)',
                      subtitle: 'الجزء السينمائي الرئيسي في بداية الصفحة',
                    ),
                    _HomeSectionToggle(
                      sectionKey: 'categories',
                      title: 'قسم تصفح الأقسام',
                      subtitle: 'الكروت الأفقية للأقسام الرئيسية',
                    ),
                    _HomeSectionToggle(
                      sectionKey: 'flash_sale',
                      title: 'قسم عروض الفلاش',
                      subtitle: 'سلايدر العروض السريعة مع العداد التنازلي',
                    ),
                    _HomeSectionToggle(
                      sectionKey: 'latest',
                      title: 'قسم وصل حديثاً',
                      subtitle: 'عنوان + سلايدر آخر المنتجات المضافة',
                    ),
                    _HomeSectionToggle(
                      sectionKey: 'middle_banner',
                      title: 'بانر منتصف الصفحة',
                      subtitle: 'بانر إعلاني في منتصف الصفحة الرئيسية',
                    ),
                    _HomeSectionToggle(
                      sectionKey: 'dining',
                      title: 'قسم طاولات السفرة',
                      subtitle: 'قسم مخصص لمنتجات قسم السفرة',
                    ),
                    _HomeSectionToggle(
                      sectionKey: 'owner_section',
                      title: 'قسم صاحب المتجر / خدمة التفصيل',
                      subtitle: 'الكارت الذي يحتوي صورة صاحب المتجر وزر الاستشارة',
                    ),
                    _HomeSectionToggle(
                      sectionKey: 'baby_section',
                      title: 'قسم عالم الطفل السعيد',
                      subtitle: 'البانر الملون لمنتجات الأطفال في الأسفل',
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Card(
                  elevation: 1,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'ترتيب أقسام الصفحة الرئيسية',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'استخدم الأسهم لتحريك القسم للأعلى أو للأسفل. الترتيب هنا يطابق ترتيب الظهور للزائر.',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        const SizedBox(height: 8),
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _homeSectionsOrder.length,
                          itemBuilder: (context, index) {
                            final key = _homeSectionsOrder[index];
                            String label;
                            switch (key) {
                              case 'hero':
                                label = 'سلايدر البانرات';
                                break;
                              case 'categories':
                                label = 'تصفح الأقسام';
                                break;
                              case 'flash_sale':
                                label = 'عروض الفلاش';
                                break;
                              case 'latest':
                                label = 'وصل حديثاً';
                                break;
                              case 'middle_banner':
                                label = 'بانر منتصف الصفحة';
                                break;
                              case 'dining':
                                label = 'قسم طاولات السفرة';
                                break;
                              case 'owner_section':
                                label = 'قسم صاحب المتجر';
                                break;
                              case 'baby_section':
                                label = 'قسم عالم الطفل';
                                break;
                              default:
                                label = key;
                            }

                            return Card(
                              margin:
                                  const EdgeInsets.symmetric(vertical: 4),
                              child: ListTile(
                                dense: true,
                                leading: const Icon(Icons.drag_indicator),
                                title: Text(label),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(
                                        Icons.arrow_upward,
                                        size: 18,
                                      ),
                                      onPressed: index == 0
                                          ? null
                                          : () => _moveHomeSection(key, -1),
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.arrow_downward,
                                        size: 18,
                                      ),
                                      onPressed:
                                          index == _homeSectionsOrder.length - 1
                                              ? null
                                              : () => _moveHomeSection(key, 1),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _pickOwnerImage() async {
    final picker = ImagePicker();
    try {
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);
      if (image == null) return;

      final originalBytes = await image.readAsBytes();
      final originalExt = image.name.split('.').last;

      final compressed = await AppImageCompressor.compress(
        originalBytes,
        originalExtension: originalExt,
      );

      final path =
          'owner/owner_${DateTime.now().millisecondsSinceEpoch}.${compressed.extension}';
      await _supabase.storage
          .from('assets')
          .uploadBinary(path, compressed.bytes, fileOptions: const FileOptions(upsert: true));
      final url = _supabase.storage.from('assets').getPublicUrl(path);

      if (!mounted) return;
      setState(() {
        _ownerImageUrl = url;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم تحديث صورة صاحب المتجر بنجاح')), 
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ في رفع الصورة: $e')),
      );
    }
  }

  Widget _buildTextField(String label, TextEditingController controller, {IconData? icon, int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: icon != null ? Icon(icon) : null,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }
}