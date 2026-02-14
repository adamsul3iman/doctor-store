import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flex_color_picker/flex_color_picker.dart'; // ✅ مكتبة اختيار الألوان
import 'package:doctor_store/shared/utils/app_notifier.dart';
import 'package:doctor_store/shared/utils/image_compressor.dart';
import 'package:doctor_store/shared/utils/image_url_helper.dart';
import 'package:doctor_store/shared/widgets/app_network_image.dart';

class AdminBannersView extends StatefulWidget {
  const AdminBannersView({super.key});

  @override
  State<AdminBannersView> createState() => _AdminBannersViewState();
}

class _AdminBannersViewState extends State<AdminBannersView> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true; // ✅ تم تفعيل التحميل
  List<Map<String, dynamic>> _banners = [];
  String? _updatingBannerId;

  @override
  void initState() {
    super.initState();
    _fetchBanners();
  }

  Future<void> _fetchBanners() async {
    setState(() => _isLoading = true);
    try {
      final data = await _supabase
          .from('banners')
          .select()
          .order('created_at', ascending: false);
      
      if (mounted) {
        setState(() {
          _banners = List<Map<String, dynamic>>.from(data);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching banners: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteBanner(String id, String? imageUrl) async {
    // تأكيد الحذف
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("تأكيد الحذف"),
        content: const Text("هل أنت متأكد من حذف هذا البانر؟"),
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

    if (confirm != true) return;

    setState(() => _isLoading = true);

    try {
      // 1. حذف الصورة من Storage (إذا وجد الرابط)
      if (imageUrl != null) {
        try {
          // استخراج اسم الملف من الرابط
          final uri = Uri.parse(imageUrl);
          final pathSegments = uri.pathSegments;
          // عادة يكون المسار banners/filename.png
          final fileName = pathSegments.last;
          await _supabase.storage.from('banners').remove(['banners/$fileName']);
        } catch (e) {
          debugPrint("Note: Could not delete image file: $e");
        }
      }

      // 2. حذف السجل من الداتابيز
      await _supabase.from('banners').delete().eq('id', id);

      await _fetchBanners(); // تحديث القائمة

      if (mounted) {
        AppNotifier.showSuccess(context, "تم حذف البانر");
      }
    } catch (e) {
      if (mounted) {
        AppNotifier.showError(context, "خطأ في حذف البانر: $e");
      }
      setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleBannerActive(
      Map<String, dynamic> banner, bool isActive) async {
    final id = banner['id'];
    if (id == null) return;

    setState(() {
      _updatingBannerId = id.toString();
    });

    try {
      await _supabase
          .from('banners')
          .update({'is_active': isActive}).eq('id', id);
      await _fetchBanners();
    } catch (e) {
      if (mounted) {
        AppNotifier.showError(context, 'خطأ في تحديث حالة البانر: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _updatingBannerId = null;
        });
      }
    }
  }

  Future<void> _showAddBannerDialog() async {
    await showDialog(
      context: context,
      builder: (context) => const _AddBannerDialog(),
    );
    _fetchBanners(); // تحديث القائمة بعد الإغلاق
  }

  Future<void> _showEditBannerDialog(Map<String, dynamic> banner) async {
    await showDialog(
      context: context,
      builder: (context) => _EditBannerDialog(banner: banner),
    );
    _fetchBanners();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(title: const Text("إدارة البانرات")),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddBannerDialog,
        backgroundColor: const Color(0xFF0A2647),
        icon: const Icon(Icons.add_photo_alternate, color: Colors.white),
        label: const Text("إضافة بانر جديد", style: TextStyle(color: Colors.white)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _banners.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.image_not_supported_outlined, size: 80, color: Colors.grey[300]),
                      const SizedBox(height: 10),
                      const Text("لا توجد بانرات حالياً", style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _banners.length,
                  itemBuilder: (context, index) {
                    final banner = _banners[index];
                    final isTop = banner['position'] == 'top';
                    
                    return Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 2,
                      child: Column(
                        children: [
                          // الصورة
                          Stack(
                            children: [
                              ClipRRect(
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                                child: SizedBox(
                                  height: 150,
                                  width: double.infinity,
                                  child: AppNetworkImage(
                                    url: (banner['image_url'] ?? '').toString(),
                                    variant: ImageVariant.homeBanner,
                                    fit: BoxFit.cover,
                                    placeholder: Container(color: Colors.grey[200]),
                                    errorWidget: const Center(child: Icon(Icons.error)),
                                  ),
                                ),
                              ),
                              // شارة الموقع
                              Positioned(
                                top: 10, left: 10,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: isTop ? Colors.blue.withValues(alpha: 0.9) : Colors.orange.withValues(alpha: 0.9),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    isTop ? "واجهة رئيسية" : "فاصل وسطي",
                                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                              // زر الحذف
                              Positioned(
                                top: 10, right: 10,
                                child: CircleAvatar(
                                  backgroundColor: Colors.white,
                                  radius: 16,
                                  child: IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.red, size: 18),
                                    onPressed: () => _deleteBanner(banner['id'], banner['image_url']),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          
                          // التفاصيل
                          Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.title, size: 16, color: Colors.grey),
                                    const SizedBox(width: 8),
                                    Text(banner['title'] ?? 'بدون عنوان',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold)),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(Icons.link, size: 16, color: Colors.grey),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        "يوجه إلى: ${banner['link_target'] ?? 'لا يوجد'}",
                                        style: const TextStyle(
                                            color: Colors.grey, fontSize: 12),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    const Icon(Icons.visibility,
                                        size: 16, color: Colors.grey),
                                    const SizedBox(width: 8),
                                    Text(
                                      banner['is_active'] == true
                                          ? 'معروض للمستخدمين'
                                          : 'مخفي حالياً',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: banner['is_active'] == true
                                            ? Colors.green
                                            : Colors.red,
                                      ),
                                    ),
                                    const Spacer(),
                                    Switch.adaptive(
                                      value: banner['is_active'] == true,
                                      onChanged:
                                          (_updatingBannerId == banner['id']?.toString())
                                              ? null
                                              : (value) =>
                                                  _toggleBannerActive(banner, value),
                                      activeThumbColor: Colors.green,
                                    ),
                                    const SizedBox(width: 4),
                                    TextButton.icon(
                                      onPressed: () =>
                                          _showEditBannerDialog(banner),
                                      icon: const Icon(Icons.edit, size: 18),
                                      label: const Text('تعديل'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}

// ✅ نافذة إضافة البانر
class _AddBannerDialog extends StatefulWidget {
  const _AddBannerDialog();

  @override
  State<_AddBannerDialog> createState() => _AddBannerDialogState();
}

class _AddBannerDialogState extends State<_AddBannerDialog> {
  final _formKey = GlobalKey<FormState>();
  
  // Controllers
  final _titleCtrl = TextEditingController();
  final _subtitleCtrl = TextEditingController();
  final _btnTextCtrl = TextEditingController(text: 'تسوق الآن');
  final _linkCtrl = TextEditingController(text: '/all_products');
  
  String _position = 'top'; // top, middle
  Color _textColor = Colors.white;
  Uint8List? _imageBytes;
  String? _imageExtension;
  bool _isLoading = false;

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    try {
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);
      if (image == null) return;

      final originalBytes = await image.readAsBytes();
      final originalExt = image.name.split('.').last;

      final compressed = await AppImageCompressor.compress(
        originalBytes,
        originalExtension: originalExt,
      );

      setState(() {
        _imageBytes = compressed.bytes;
        _imageExtension = compressed.extension;
      });
    } catch (e) {
      if (!mounted) return;
      AppNotifier.showError(
        context,
        'تعذر معالجة صورة البانر، حاول مرة أخرى. (تفاصيل تقنية: $e)',
      );
    }
  }

  Future<void> _uploadAndSave() async {
    if (!_formKey.currentState!.validate()) return;
    if (_imageBytes == null) {
      AppNotifier.showError(context, "يرجى اختيار صورة للبانر أولاً");
      return;
    }

    // ✅ حماية: الرفع يجب أن يتم بعد تسجيل الدخول
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) {
      AppNotifier.showError(context, 'يرجى تسجيل الدخول أولاً');
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 1. رفع الصورة
      final fileName = 'banner_${DateTime.now().millisecondsSinceEpoch}.$_imageExtension';
      final path = 'banners/$fileName';
      
      await client.storage.from('banners').uploadBinary(path, _imageBytes!);
      final imageUrl = client.storage.from('banners').getPublicUrl(path);

      // 2. حفظ البيانات
      await Supabase.instance.client.from('banners').insert({
        'title': _titleCtrl.text,
        'subtitle': _subtitleCtrl.text,
        'button_text': _btnTextCtrl.text,
        'link_target': _linkCtrl.text,
        'position': _position,
        'image_url': imageUrl,
        // نخزن اللون كقيمة هيكس متوافقة مع القيمة الافتراضية في قاعدة البيانات
        'text_color': '0x${_textColor.toARGB32().toRadixString(16).padLeft(8, '0')}',
        'is_active': true,
        'sort_order': 0,
      });

      if (mounted) {
        Navigator.pop(context);
        AppNotifier.showSuccess(context, "تم إضافة البانر بنجاح");
      }

    } catch (e) {
      if (mounted) {
        AppNotifier.showError(context, "تعذر حفظ البانر: $e");
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        padding: const EdgeInsets.all(20),
        width: 400,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("إضافة بانر جديد",
                    style:
                        TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),

                // اختيار الصورة
                GestureDetector(
                  onTap: _pickImage,
                  child: Container(
                    height: 120,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: _imageBytes != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.memory(
                              _imageBytes!,
                              fit: BoxFit.cover,
                            ),
                          )
                        : const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_a_photo, color: Colors.grey),
                              SizedBox(height: 5),
                              Text("اضغط لاختيار صورة",
                                  style: TextStyle(color: Colors.grey)),
                            ],
                          ),
                  ),
                ),

                const SizedBox(height: 15),

                // اختيار الموقع
                DropdownButtonFormField<String>(
                  initialValue: _position,
                  decoration: const InputDecoration(
                    labelText: "مكان الظهور",
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                        value: 'top',
                        child: Text("الواجهة الرئيسية (كبير)")),
                    DropdownMenuItem(
                        value: 'middle',
                        child: Text("فاصل في الوسط (صغير)")),
                  ],
                  onChanged: (v) => setState(() => _position = v ?? 'top'),
                ),

                const SizedBox(height: 15),
                TextFormField(
                  controller: _titleCtrl,
                  decoration: const InputDecoration(
                    labelText: "العنوان الرئيسي",
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _subtitleCtrl,
                  decoration: const InputDecoration(
                    labelText: "العنوان الفرعي",
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),

                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _btnTextCtrl,
                        decoration: const InputDecoration(
                          labelText: "نص الزر",
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // اختيار لون النص
                    GestureDetector(
                      onTap: () async {
                        final color = await showColorPickerDialog(
                          context,
                          _textColor,
                          title: const Text('لون النص'),
                          width: 40,
                          height: 40,
                          spacing: 0,
                          runSpacing: 0,
                          borderRadius: 4,
                          wheelDiameter: 165,
                          enableOpacity: false,
                          showColorCode: true,
                          pickersEnabled: <ColorPickerType, bool>{
                            ColorPickerType.wheel: true,
                            ColorPickerType.accent: true,
                          },
                        );
                        setState(() => _textColor = color);
                      },
                      child: Container(
                        height: 55,
                        width: 55,
                        decoration: BoxDecoration(
                          color: _textColor,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey),
                        ),
                        child:
                            const Icon(Icons.colorize, color: Colors.black54),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),
                TextFormField(
                  controller: _linkCtrl,
                  decoration: const InputDecoration(
                    labelText: "رابط التوجيه",
                    hintText: "/all_products أو /category/bedding",
                    border: OutlineInputBorder(),
                  ),
                ),

                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _uploadAndSave,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0A2647),
                      foregroundColor: Colors.white,
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text("نشر البانر"),
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EditBannerDialog extends StatefulWidget {
  final Map<String, dynamic> banner;

  const _EditBannerDialog({required this.banner});

  @override
  State<_EditBannerDialog> createState() => _EditBannerDialogState();
}

class _EditBannerDialogState extends State<_EditBannerDialog> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _titleCtrl = TextEditingController();
  final _subtitleCtrl = TextEditingController();
  final _btnTextCtrl = TextEditingController();
  final _linkCtrl = TextEditingController();

  String _position = 'top';
  Color _textColor = Colors.white;
  Uint8List? _imageBytes;
  String? _imageExtension;
  String? _existingImageUrl;
  bool _isLoading = false;
  bool _isActive = true;

  @override
  void initState() {
    super.initState();
    final banner = widget.banner;
    _titleCtrl.text = (banner['title'] ?? '').toString();
    _subtitleCtrl.text = (banner['subtitle'] ?? '').toString();
    _btnTextCtrl.text = (banner['button_text'] ?? 'تسوق الآن').toString();
    _linkCtrl.text = (banner['link_target'] ?? '/all_products').toString();
    _position = (banner['position'] ?? 'top').toString();
    _existingImageUrl = banner['image_url']?.toString();
    _isActive = banner['is_active'] == true;
    _textColor = _parseColorFromHex(banner['text_color']?.toString());
  }

  Color _parseColorFromHex(String? hex) {
    if (hex == null || hex.isEmpty) return Colors.white;
    try {
      var cleanHex = hex.toLowerCase();
      if (cleanHex.startsWith('0x')) {
        cleanHex = cleanHex.substring(2);
      }
      final value = int.parse(cleanHex, radix: 16);
      return Color(value);
    } catch (_) {
      return Colors.white;
    }
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    try {
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);
      if (image == null) return;

      final originalBytes = await image.readAsBytes();
      final originalExt = image.name.split('.').last;

      final compressed = await AppImageCompressor.compress(
        originalBytes,
        originalExtension: originalExt,
      );

      setState(() {
        _imageBytes = compressed.bytes;
        _imageExtension = compressed.extension;
      });
    } catch (e) {
      if (!mounted) return;
      AppNotifier.showError(
        context,
        'تعذر معالجة صورة البانر، حاول مرة أخرى. (تفاصيل تقنية: $e)',
      );
    }
  }

  Future<void> _uploadAndSave() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      String? imageUrl = _existingImageUrl;

      if (_imageBytes != null) {
        final fileName =
            'banner_${DateTime.now().millisecondsSinceEpoch}.$_imageExtension';
        final path = 'banners/$fileName';

        await Supabase.instance.client.storage
            .from('banners')
            .uploadBinary(path, _imageBytes!);
        imageUrl = Supabase.instance.client.storage
            .from('banners')
            .getPublicUrl(path);
      }

      await Supabase.instance.client.from('banners').update({
        'title': _titleCtrl.text,
        'subtitle': _subtitleCtrl.text,
        'button_text': _btnTextCtrl.text,
        'link_target': _linkCtrl.text,
        'position': _position,
        'image_url': imageUrl,
        'text_color': '0x${_textColor.toARGB32().toRadixString(16).padLeft(8, '0')}',
        'is_active': _isActive,
      }).eq('id', widget.banner['id']);

      if (mounted) {
        Navigator.pop(context);
        AppNotifier.showSuccess(context, 'تم تحديث البانر بنجاح');
      }
    } catch (e) {
      if (mounted) {
        AppNotifier.showError(context, 'تعذر حفظ تعديلات البانر: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        padding: const EdgeInsets.all(20),
        width: 400,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('تعديل البانر',
                    style:
                        TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                GestureDetector(
                  onTap: _pickImage,
                  child: Container(
                    height: 120,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: _imageBytes != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.memory(
                              _imageBytes!,
                              fit: BoxFit.cover,
                            ),
                          )
                        : (_existingImageUrl != null &&
                                _existingImageUrl!.isNotEmpty)
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: AppNetworkImage(
                                  url: _existingImageUrl!,
                                  variant: ImageVariant.homeBanner,
                                  fit: BoxFit.cover,
                                  placeholder: Container(color: Colors.grey[200]),
                                  errorWidget: const Icon(
                                    Icons.broken_image,
                                    color: Colors.grey,
                                  ),
                                ),
                              )
                            : const Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.add_a_photo, color: Colors.grey),
                                  SizedBox(height: 5),
                                  Text('اضغط لتغيير الصورة',
                                      style: TextStyle(color: Colors.grey)),
                                ],
                              ),
                  ),
                ),
                const SizedBox(height: 15),
                DropdownButtonFormField<String>(
                  initialValue: _position,
                  decoration: const InputDecoration(
                    labelText: 'مكان الظهور',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                        value: 'top',
                        child: Text('الواجهة الرئيسية (كبير)')),
                    DropdownMenuItem(
                        value: 'middle',
                        child: Text('فاصل في الوسط (صغير)')),
                  ],
                  onChanged: (v) => setState(() => _position = v ?? 'top'),
                ),
                const SizedBox(height: 15),
                TextFormField(
                  controller: _titleCtrl,
                  decoration: const InputDecoration(
                    labelText: 'العنوان الرئيسي',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _subtitleCtrl,
                  decoration: const InputDecoration(
                    labelText: 'العنوان الفرعي',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _btnTextCtrl,
                        decoration: const InputDecoration(
                          labelText: 'نص الزر',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    GestureDetector(
                      onTap: () async {
                        final color = await showColorPickerDialog(
                          context,
                          _textColor,
                          title: const Text('لون النص'),
                          width: 40,
                          height: 40,
                          spacing: 0,
                          runSpacing: 0,
                          borderRadius: 4,
                          wheelDiameter: 165,
                          enableOpacity: false,
                          showColorCode: true,
                          pickersEnabled: <ColorPickerType, bool>{
                            ColorPickerType.wheel: true,
                            ColorPickerType.accent: true,
                          },
                        );
                        setState(() => _textColor = color);
                      },
                      child: Container(
                        height: 55,
                        width: 55,
                        decoration: BoxDecoration(
                          color: _textColor,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey),
                        ),
                        child:
                            const Icon(Icons.colorize, color: Colors.black54),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _linkCtrl,
                  decoration: const InputDecoration(
                    labelText: 'رابط التوجيه',
                    hintText: '/all_products أو /category/bedding',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                SwitchListTile.adaptive(
                  title: const Text('عرض البانر للمستخدمين'),
                  value: _isActive,
                  onChanged: (v) => setState(() => _isActive = v),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _uploadAndSave,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0A2647),
                      foregroundColor: Colors.white,
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('حفظ التغييرات'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
