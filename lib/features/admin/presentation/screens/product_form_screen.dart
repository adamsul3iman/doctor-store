import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:flex_color_picker/flex_color_picker.dart';
import 'package:doctor_store/features/product/domain/models/product_model.dart';
import 'package:doctor_store/shared/utils/categories_provider.dart';
import 'package:doctor_store/shared/utils/image_compressor.dart';
import 'package:doctor_store/shared/utils/image_url_helper.dart';
import 'package:doctor_store/shared/widgets/image_shimmer_placeholder.dart';
import 'package:doctor_store/shared/widgets/app_network_image.dart';
import 'package:doctor_store/features/auth/application/user_data_manager.dart';
import 'package:doctor_store/features/admin/data/admin_product_repository.dart';

enum _ProductFormPanel {
  basic,
  pricing,
  inventory,
  media,
  mattress,
  options,
  variants,
}

class ProductFormScreen extends ConsumerStatefulWidget {
  final Object? extra;
  final Product? productToEdit;

  const ProductFormScreen({
    super.key,
    this.extra,
    this.productToEdit,
  });

  @override
  ConsumerState<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends ConsumerState<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();

  final AdminProductRepository _adminProductRepo = AdminProductRepository();

  final _titleController = TextEditingController();
  final _slugController = TextEditingController();
  final _descController = TextEditingController();
  final _priceController = TextEditingController();
  final _oldPriceController = TextEditingController();

  final _baseStockController = TextEditingController();

  String _inventoryPolicy = 'track_qty';
  bool _statusBasedInStock = true;

  String _selectedCategory = 'bedding';
  String? _selectedSubCategoryId;
  String _shippingSize = 'small'; // ✅ حجم الشحن
  bool _isFeatured = false;
  bool _isFlashDeal = false; // ✅
  bool _isLoading = false;

  bool _isLoadingSubCategories = false;
  List<Map<String, dynamic>> _subCategories = [];

  // ✅ نوع المنتج / وضع التسعير
  bool _isOfferMode = false;
  bool _useAdvancedVariants =
      false; // لتفعيل إدارة المتغيرات (لون + مقاس + وحدة + سعر)

  // ✅ وضع الفرشات (تسعير تلقائي حسب المقاس)
  bool _isMattressMode = false;

  final TextEditingController _mattressWidthMinCtrl =
      TextEditingController(text: '90');
  final TextEditingController _mattressWidthMaxCtrl =
      TextEditingController(text: '200');
  final TextEditingController _mattressWidthStepCtrl =
      TextEditingController(text: '10');

  // عرض الفرشة (cm) كقائمة مخصصة (اختياري).
  // إذا تم تعبئتها سيتم تجاهل min/max/step في توليد المقاسات.
  final TextEditingController _mattressWidthsCtrl = TextEditingController();

  // طول الفرشة (cm) - غالباً 190/195/200 (يمكن إدخالها مفصولة بفواصل)
  final TextEditingController _mattressLengthsCtrl =
      TextEditingController(text: '190,195,200');

  // ====== تسعير الفرشات ======
  // الوضع الافتراضي: per_sqm (حسب متر مربع).
  // الوضع الجديد: by_width (سعر يدوي حسب العرض فقط)
  String _mattressPricingMode = 'per_sqm'; // per_sqm | by_width

  // تسعير احترافي حسب المساحة (م²): السعر = base_fee + (area_m2 * price_per_sqm)
  final TextEditingController _mattressBaseFeeCtrl =
      TextEditingController(text: '0');
  final TextEditingController _mattressPricePerSqmCtrl =
      TextEditingController(text: '0');

  // تسعير يدوي حسب العرض (cm)
  final TextEditingController _mattressDefaultWidthPriceCtrl =
      TextEditingController();
  final List<_MattressWidthPriceRow> _mattressWidthPriceRows = [];

  // خريطة بسيطة لتحويل الحروف العربية إلى أحرف لاتينية للـ slug
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

  final List<Map<String, TextEditingController>> _offerTiers = [];
  List<String> _sizes = [];
  final TextEditingController _sizeInputCtrl = TextEditingController();

  final List<_DynamicOptionRow> _dynamicOptions = [];

  // إعدادات تسعير بالوحدة/المتر
  final TextEditingController _unitLabelCtrl =
      TextEditingController(text: 'حبة');
  final TextEditingController _unitMinCtrl = TextEditingController(text: '1');
  final TextEditingController _unitStepCtrl = TextEditingController(text: '1');

  // المتغيرات المتقدمة في واجهة الأدمن
  final List<_VariantRow> _variantRows = [];

  final Set<_ProductFormPanel> _expandedPanels = <_ProductFormPanel>{
    _ProductFormPanel.basic,
    _ProductFormPanel.pricing,
    _ProductFormPanel.inventory,
  };

  void _togglePanel(_ProductFormPanel id) {
    setState(() {
      if (_expandedPanels.contains(id)) {
        _expandedPanels.remove(id);
      } else {
        _expandedPanels.add(id);
      }
    });
  }

  List<_ProductFormPanel> _currentPanelIds() {
    return <_ProductFormPanel>[
      _ProductFormPanel.basic,
      _ProductFormPanel.pricing,
      _ProductFormPanel.inventory,
      _ProductFormPanel.media,
      if (_selectedCategory == 'mattresses') _ProductFormPanel.mattress,
      _ProductFormPanel.options,
      _ProductFormPanel.variants,
    ];
  }

  _ImageWrapper? _mainImage;
  List<_ImageWrapper> _galleryImages = [];
  bool _isPickingGalleryImages = false;

  /// القيم المسموح بها لحقل القسم في المنتجات.
  ///
  /// مهمة جداً:
  /// - يجب أن تطابق تماماً قيم enum `public.product_category` في قاعدة البيانات.
  /// - عند إضافة قسم جديد في المتجر، تأكد أولاً من إضافته للـ enum عبر Migration
  ///   في Supabase، ثم أضِفه هنا وفي `AppConstants` و `Product.categoryArabic`.
  final List<String> _categories = [
    'bedding',
    'mattresses',
    'pillows',
    'furniture',
    'dining_table',
    'carpets',
    'baby_supplies',
    'home_decor',
    'towels',
    'curtains', // تمت إضافتها أيضاً إلى enum public.product_category في قاعدة البيانات
  ];

  Product? productToEdit;

  @override
  void initState() {
    super.initState();
    _handleArguments();

    // تحميل الفئات الفرعية للفئة الحالية في حالة إنشاء منتج جديد
    if (productToEdit == null) {
      _loadSubCategoriesFor(_selectedCategory);
    }

    // توليد slug تلقائياً أثناء كتابة اسم المنتج (ما لم يعدّل المستخدم slug يدوياً)
    _titleController.addListener(_onTitleChangedForSlug);

    // إضافة صف مبدئي للعروض إذا كانت القائمة فارغة
    if (_offerTiers.isEmpty) {
      _addOfferTier(qty: '2', price: '');
    }
  }

  @override
  void dispose() {
    _titleController.removeListener(_onTitleChangedForSlug);
    _titleController.dispose();
    _slugController.dispose();
    _descController.dispose();
    _priceController.dispose();
    _oldPriceController.dispose();
    _baseStockController.dispose();
    _sizeInputCtrl.dispose();
    _unitLabelCtrl.dispose();
    _unitMinCtrl.dispose();
    _unitStepCtrl.dispose();

    _mattressWidthMinCtrl.dispose();
    _mattressWidthMaxCtrl.dispose();
    _mattressWidthStepCtrl.dispose();
    _mattressWidthsCtrl.dispose();
    _mattressLengthsCtrl.dispose();
    _mattressBaseFeeCtrl.dispose();
    _mattressPricePerSqmCtrl.dispose();
    _mattressDefaultWidthPriceCtrl.dispose();
    for (final r in _mattressWidthPriceRows) {
      r.dispose();
    }

    for (final v in _variantRows) {
      v.dispose();
    }

    for (final o in _dynamicOptions) {
      o.dispose();
    }

    for (final img in _galleryImages) {
      img.dispose();
    }
    super.dispose();
  }

  void _handleArguments() {
    if (widget.productToEdit != null) {
      productToEdit = widget.productToEdit;
      _loadProductData();
      return;
    }

    if (widget.extra is Product) {
      productToEdit = widget.extra as Product;
      _loadProductData();
    } else if (widget.extra is Map) {
      final map = widget.extra as Map;

      if (map['isOfferMode'] == true) {
        _isOfferMode = true;
      }

      // ✅ preset خاص بالفرشات
      if (map['preset'] == 'mattress') {
        _isOfferMode = false;
        _selectedCategory = 'mattresses';
        _isMattressMode = true;
      }
    }
  }

  void _loadProductData() {
    final p = productToEdit!;
    _titleController.text = p.title;
    _slugController.text = p.slug ?? '';

    _descController.text = p.description;
    _priceController.text = p.price.toString();
    if (p.oldPrice != null) _oldPriceController.text = p.oldPrice.toString();
    _selectedCategory = p.category;
    _selectedSubCategoryId = p.subCategoryId;
    _shippingSize = p.options['shipping_size'] ?? 'small'; // ✅ تحميل حجم الشحن
    _isFeatured = p.isFeatured;
    _isFlashDeal = p.isFlashDeal;

    if (p.hasOffers) {
      _isOfferMode = true;
      _offerTiers.clear(); // مسح الافتراضي
      for (var tier in p.offerTiers) {
        _addOfferTier(
            qty: tier.quantity.toString(), price: tier.price.toString());
      }
    }

    if (p.options['sizes'] != null) {
      _sizes = List<String>.from(p.options['sizes']);
    }

    final invPolicy = p.options['inventory_policy'];
    if (invPolicy is String && invPolicy.isNotEmpty) {
      _inventoryPolicy = invPolicy;
    }
    final inStock = p.options['in_stock'];
    if (inStock is bool) {
      _statusBasedInStock = inStock;
    }
    final baseStock = p.options['stock'];
    if (baseStock is num) {
      _baseStockController.text = baseStock.toInt().toString();
    }

    final rawDynOptions = p.options['product_options'];
    if (rawDynOptions is List) {
      _dynamicOptions.clear();
      for (final item in rawDynOptions) {
        if (item is Map<String, dynamic>) {
          _dynamicOptions.add(_DynamicOptionRow.fromJson(item));
        } else if (item is Map) {
          _dynamicOptions.add(
            _DynamicOptionRow.fromJson(Map<String, dynamic>.from(item)),
          );
        }
      }
    }

    // تحميل إعدادات التسعير بالوحدة/المتر إن وُجدت
    final unitLabel = p.options['pricing_unit'];
    if (unitLabel is String && unitLabel.isNotEmpty) {
      _unitLabelCtrl.text = unitLabel;
    }
    final unitMin = p.options['unit_min'];
    if (unitMin is num) {
      _unitMinCtrl.text = unitMin.toString();
    }
    final unitStep = p.options['unit_step'];
    if (unitStep is num) {
      _unitStepCtrl.text = unitStep.toString();
    }

    // ✅ تحميل إعدادات الفرشات (إن وُجدت)
    final mattress = p.options['mattress'];
    if (p.category == 'mattresses' || p.options['product_type'] == 'mattress') {
      _isMattressMode = true;
      if (mattress is Map) {
        final m = Map<String, dynamic>.from(mattress);
        final wMin = m['width_min'];
        final wMax = m['width_max'];
        final wStep = m['width_step'];
        if (wMin is num) _mattressWidthMinCtrl.text = wMin.toInt().toString();
        if (wMax is num) _mattressWidthMaxCtrl.text = wMax.toInt().toString();
        if (wStep is num) _mattressWidthStepCtrl.text = wStep.toInt().toString();

        final widths = m['widths'];
        if (widths is List && widths.isNotEmpty) {
          _mattressWidthsCtrl.text = widths.map((e) => e.toString()).join(',');
        }

        final lengths = m['lengths'];
        if (lengths is List && lengths.isNotEmpty) {
          _mattressLengthsCtrl.text = lengths.map((e) => e.toString()).join(',');
        }

        final pricing = m['pricing'];
        if (pricing is Map) {
          final pMap = Map<String, dynamic>.from(pricing);

          final mode = pMap['mode'];
          if (mode is String && mode.isNotEmpty) {
            _mattressPricingMode = mode;
          }

          final baseFee = pMap['base_fee'];
          final perSqm = pMap['price_per_sqm'];
          if (baseFee is num) {
            _mattressBaseFeeCtrl.text = baseFee.toDouble().toString();
          }
          if (perSqm is num) {
            _mattressPricePerSqmCtrl.text = perSqm.toDouble().toString();
          }

          // ✅ تسعير يدوي حسب العرض
          final widthPrices = pMap['width_prices'];
          if (widthPrices is Map) {
            _mattressWidthPriceRows.clear();
            final entries = Map<String, dynamic>.from(widthPrices).entries.toList();
            // ترتيب حسب العرض
            entries.sort((a, b) {
              final wa = int.tryParse(a.key) ?? 0;
              final wb = int.tryParse(b.key) ?? 0;
              return wa.compareTo(wb);
            });
            for (final e in entries) {
              final w = int.tryParse(e.key);
              final price = e.value is num ? (e.value as num).toDouble() : double.tryParse(e.value.toString());
              if (w != null && price != null) {
                _mattressWidthPriceRows.add(
                  _MattressWidthPriceRow(widthCm: w, price: price),
                );
              }
            }
          }
        }
      }
    }

    // تحميل المتغيرات المتقدمة إن وُجدت
    if (p.variants.isNotEmpty ||
        p.options['product_type'] == 'variable_with_variants') {
      _useAdvancedVariants = true;
      _variantRows.clear();
      for (final v in p.variants) {
        _variantRows.add(_VariantRow.fromVariant(v));
      }
    }

    _mainImage = _ImageWrapper(serverUrl: p.imageUrl);

    _galleryImages = p.gallery
        .map((img) => _ImageWrapper(
              serverUrl: img.url,
              colorName: img.colorName,
              colorValue: Color(img.colorValue),
            ))
        .toList();

    _loadSubCategoriesFor(_selectedCategory);
  }

  String _buildSlug(String source) {
    String lower = source.trim().toLowerCase();

    // 1) تحويل الحروف العربية إلى مكافئ لاتيني بسيط
    final buffer = StringBuffer();
    for (final codeUnit in lower.runes) {
      final ch = String.fromCharCode(codeUnit);
      final mapped = _arabicToLatin[ch];
      if (mapped != null) {
        buffer.write(mapped);
      } else if (RegExp(r'[a-z0-9]').hasMatch(ch)) {
        buffer.write(ch);
      } else if (RegExp(r'[\s_-]').hasMatch(ch)) {
        // المسافات أو الشرطات → مسافة واحدة، نحولها لاحقاً إلى "-"
        buffer.write(' ');
      } else {
        // نتجاهل أي رموز أخرى (إيموجي، علامات خاصة...)
        buffer.write(' ');
      }
    }

    String slug = buffer.toString();

    // 2) استبدال الفراغات المتتالية بـ "-" وتوحيد الشرطات
    slug = slug.replaceAll(RegExp(r'\s+'), '-');
    slug = slug.replaceAll(RegExp(r'-+'), '-');

    // 3) إزالة الشرطات من البداية والنهاية إن وُجدت
    slug = slug.replaceAll(RegExp(r'^-+|-+$'), '');

    return slug;
  }

  Future<void> _loadSubCategoriesFor(String parentCategoryId) async {
    setState(() {
      _isLoadingSubCategories = true;
      _subCategories = [];
      // ملاحظة: لا نعيد تعيين _selectedSubCategoryId هنا حتى لا نخسر الاختيار
      // في حالة تعديل منتج موجود. إذا كانت null أو غير موجودة في القائمة
      // الجديدة، سيتم تعيين أول فئة فرعية تلقائياً بعد الجلب.
    });

    try {
      final data = await Supabase.instance.client
          .from('sub_categories')
          .select('id,name,parent_category_id,sort_order,is_active')
          .eq('parent_category_id', parentCategoryId)
          .eq('is_active', true)
          .order('sort_order', ascending: true);

      final list = List<Map<String, dynamic>>.from(data as List);

      setState(() {
        _subCategories = list;
        if (_subCategories.isNotEmpty &&
            (_selectedSubCategoryId == null ||
                !_subCategories
                    .any((s) => s['id'] == _selectedSubCategoryId))) {
          _selectedSubCategoryId = _subCategories.first['id'] as String?;
        }
        _isLoadingSubCategories = false;
      });
    } catch (e) {
      setState(() => _isLoadingSubCategories = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ في تحميل الفئات الفرعية: $e')),
      );
    }
  }

  /// توليد slug قصير وفريد على مستوى المتجر بالكامل (منتجات + أقسام رئيسية + فئات فرعية).
  ///
  /// - يعتمد على العنوان بعد تحويله إلى slug لاتيني.
  /// - يضمن عدم التعارض مع:
  ///   - products.slug
  ///   - categories.id
  ///   - sub_categories.code
  Future<String> _generateShortUniqueSlug(String title,
      {String? currentId}) async {
    final supabase = Supabase.instance.client;

    final base = _buildSlug(title);
    if (base.isEmpty) return '';

    int attempt = 0;
    while (true) {
      String candidate;
      if (attempt == 0) {
        candidate = base;
      } else {
        final suffix = DateTime.now().millisecondsSinceEpoch.toRadixString(36) +
            attempt.toRadixString(36);
        candidate = '$base-$suffix';
      }

      // 1) تحقق من تعارض مع منتجات أخرى (مع استثناء المنتج الحالي لو في وضع التعديل)
      final prodRows = await supabase
          .from('products')
          .select('id')
          .eq('slug', candidate)
          .limit(1);
      final prodList = List<Map<String, dynamic>>.from(prodRows as List);
      final existsInOtherProduct = prodList.isNotEmpty &&
          (currentId == null || prodList.first['id'] != currentId);

      // 2) تحقق من تعارض مع أكواد الأقسام الرئيسية (categories.id)
      final catRows = await supabase
          .from('categories')
          .select('id')
          .eq('id', candidate)
          .limit(1);
      final catList = List<Map<String, dynamic>>.from(catRows as List);

      // 3) تحقق من تعارض مع أكواد الفئات الفرعية (sub_categories.code)
      final subRows = await supabase
          .from('sub_categories')
          .select('id')
          .eq('code', candidate)
          .limit(1);
      final subList = List<Map<String, dynamic>>.from(subRows as List);

      if (!existsInOtherProduct && catList.isEmpty && subList.isEmpty) {
        return candidate;
      }

      attempt++;
    }
  }

  void _onTitleChangedForSlug() {
    // معاينة سريعة لـ slug أثناء كتابة العنوان (غير ملزم، slug الحقيقي يُولّد عند الحفظ)
    final title = _titleController.text.trim();
    if (title.isEmpty) return;

    final slug = _buildSlug(title);
    if (_slugController.text != slug) {
      _slugController.text = slug;
    }
  }

  String _buildShortDescription() {
    final title = _titleController.text.trim();
    if (title.isEmpty) return '';
    final categoryName = _getCategoryName(_selectedCategory);
    return 'احصل على $title ضمن مجموعة $categoryName الآن واستمتع بجودة عالية!';
  }

  List<String> _buildTags() {
    final title = _titleController.text.trim();
    final categoryCode = _selectedCategory.trim();
    final categoryName = _getCategoryName(_selectedCategory).trim();
    final all = '$title $categoryCode $categoryName';
    final tags = all
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .map((w) => w.toLowerCase())
        .toSet()
        .toList();
    return tags;
  }

  void _addOfferTier({String qty = '', String price = ''}) {
    setState(() {
      _offerTiers.add({
        'qty': TextEditingController(text: qty),
        'price': TextEditingController(text: price),
      });
    });
  }

  void _removeOfferTier(int index) {
    setState(() {
      _offerTiers.removeAt(index);
    });
  }

  Future<void> _pickImage(bool isMain) async {
    final ImagePicker picker = ImagePicker();

    try {
      if (isMain) {
        // صورة رئيسية واحدة فقط
        final XFile? image = await picker.pickImage(source: ImageSource.gallery);
        if (image == null) return;

        final originalBytes = await image.readAsBytes();
        final originalExt = image.name.split('.').last;

        final compressed = await AppImageCompressor.compress(
          originalBytes,
          originalExtension: originalExt,
        );

        setState(() {
          _mainImage = _ImageWrapper(
            localBytes: compressed.bytes,
            fileExtension: compressed.extension,
          );
        });
      } else {
        // ✅ السماح باختيار أكثر من صورة للمعرض دفعة واحدة بدون حد 5 صور
        final List<XFile> images = await picker.pickMultiImage();
        if (images.isEmpty) return;

        if (mounted) {
          setState(() => _isPickingGalleryImages = true);
        }

        final List<_ImageWrapper> newImages = [];
        for (final image in images) {
          final originalBytes = await image.readAsBytes();
          final originalExt = image.name.split('.').last;

          final compressed = await AppImageCompressor.compress(
            originalBytes,
            originalExtension: originalExt,
          );

          newImages.add(_ImageWrapper(
            localBytes: compressed.bytes,
            fileExtension: compressed.extension,
          ));
        }

        if (mounted) {
          setState(() {
            _galleryImages.addAll(newImages);
            _isPickingGalleryImages = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isPickingGalleryImages = false);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تعذر معالجة الصورة، حاول مرة أخرى. (تفاصيل تقنية: $e)'),
        ),
      );
    }
  }

  void _reorderGalleryImages(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final item = _galleryImages.removeAt(oldIndex);
      _galleryImages.insert(newIndex, item);
    });
  }

  void _setGalleryImageAsFirst(int index) {
    if (index <= 0 || index >= _galleryImages.length) return;
    setState(() {
      final item = _galleryImages.removeAt(index);
      _galleryImages.insert(0, item);
    });
  }

  String _autoColorName(Color c) {
    final hsl = HSLColor.fromColor(c);
    final h = hsl.hue;
    final s = hsl.saturation;
    final l = hsl.lightness;

    if (s < 0.10) {
      if (l >= 0.85) return 'أبيض';
      if (l <= 0.20) return 'أسود';
      return 'رمادي';
    }

    if (h < 15 || h >= 345) return 'أحمر';
    if (h < 40) return 'برتقالي';
    if (h < 65) return 'أصفر';
    if (h < 150) return 'أخضر';
    if (h < 200) return 'سماوي';
    if (h < 255) return 'أزرق';
    if (h < 290) return 'بنفسجي';
    if (h < 345) return 'وردي';
    return 'لون';
  }

  Future<void> _showColorPicker(int index) async {
    final Color newColor = await showColorPickerDialog(
      context,
      _galleryImages[index].colorValue,
      title: const Text('اختر لون الخامة',
          style: TextStyle(fontWeight: FontWeight.bold)),
      width: 40,
      height: 40,
      spacing: 0,
      runSpacing: 0,
      borderRadius: 4,
      wheelDiameter: 165,
      enableOpacity: false,
      showColorCode: true,
      colorCodeHasColor: true,
      pickersEnabled: <ColorPickerType, bool>{
        ColorPickerType.wheel: true,
        ColorPickerType.primary: true,
        ColorPickerType.accent: true,
      },
      actionButtons: const ColorPickerActionButtons(dialogActionButtons: true),
    );
    setState(() {
      final img = _galleryImages[index];
      img.colorValue = newColor;

      final suggested = _autoColorName(newColor);
      img.colorName = suggested;
      img.colorNameCtrl.text = suggested;
      img.colorNameManuallyEdited = false;
    });
  }

  Future<void> _saveProduct() async {
    // ✅ محاولة تعبئة السعر الأساسي تلقائياً لمنتجات الفرشات
    // لأن التسعير الفعلي قد يأتي من إعدادات الفرشات (حسب العرض).
    if (_isMattressMode && _selectedCategory == 'mattresses') {
      _tryAutoFillMattressBasePrice();
    }

    if (!_formKey.currentState!.validate()) return;
    if (_mainImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("يجب اختيار صورة رئيسية للمنتج")));
      return;
    }

    if (_isOfferMode) {
      if (_offerTiers.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("يجب إضافة شريحة سعر واحدة على الأقل")));
        return;
      }
      // في حالة العروض، السعر الأساسي هو سعر القطعة الواحدة (محسوب تقريبياً) أو نطلب إدخاله
      // هنا سنعتبر سعر القطعة الواحدة هو سعر أول عرض مقسوماً على كميته (للتبسيط) أو نأخذه من حقل السعر إذا كان موجوداً
      if (_priceController.text.isEmpty) {
        double firstPrice = double.tryParse(_offerTiers[0]['price']!.text) ?? 0;
        int firstQty = int.tryParse(_offerTiers[0]['qty']!.text) ?? 1;
        _priceController.text = (firstPrice / firstQty).toStringAsFixed(2);
      }
    }

    // ✅ حماية: الرفع/التعديل يجب أن يكون بعد تسجيل الدخول وبصلاحية أدمن
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    final profile = ref.read(userProfileProvider);

    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('يرجى تسجيل الدخول أولاً')),
        );
        context.go('/login');
      }
      return;
    }

    if (!profile.isAdmin) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ليس لديك صلاحية لرفع/تعديل المنتجات')),
        );
      }
      return;
    }

    setState(() => _isLoading = true);

    try {
      String mainImageUrl = _mainImage!.serverUrl ?? '';
      if (_mainImage!.localBytes != null) {
        final path =
            'products/main_${DateTime.now().millisecondsSinceEpoch}.${_mainImage!.fileExtension}';
        mainImageUrl = await _adminProductRepo.uploadProductImage(
          path: path,
          bytes: _mainImage!.localBytes!,
        );
      }

      List<Map<String, dynamic>> galleryData = [];
      List<String> colorsList = [];

      for (var img in _galleryImages) {
        String url = img.serverUrl ?? '';
        if (img.localBytes != null) {
          final path =
              'products/gallery_${DateTime.now().millisecondsSinceEpoch}_${_galleryImages.indexOf(img)}.${img.fileExtension}';
          url = await _adminProductRepo.uploadProductImage(
            path: path,
            bytes: img.localBytes!,
          );
        }

        galleryData.add({
          'url': url,
          'color_name': img.colorName,
          'color_value': ((img.colorValue.a * 255).round() & 0xff) << 24 |
              ((img.colorValue.r * 255).round() & 0xff) << 16 |
              ((img.colorValue.g * 255).round() & 0xff) << 8 |
              ((img.colorValue.b * 255).round() & 0xff),
        });

        if (img.colorName.isNotEmpty) {
          if (!colorsList.contains(img.colorName)) {
            colorsList.add(img.colorName);
          }
        }
      }

      List<Map<String, dynamic>> tiersData = [];
      if (_isOfferMode) {
        for (var tier in _offerTiers) {
          if (tier['qty']!.text.isNotEmpty && tier['price']!.text.isNotEmpty) {
            tiersData.add({
              'qty': int.parse(tier['qty']!.text),
              'price': double.parse(tier['price']!.text),
            });
          }
        }
      }

      // توليد slug تلقائياً وبشكل فريد (مع الحفاظ على slug القديم في وضع التعديل)
      String slug = productToEdit?.slug ?? '';
      final rawTitle = _titleController.text.trim();
      if (slug.isEmpty && rawTitle.isNotEmpty) {
        slug = await _generateShortUniqueSlug(
          rawTitle,
          currentId: productToEdit?.id,
        );
      }

      // مزامنة الـ controller لاستخدامه في أماكن أخرى مثل توليد SKU
      _slugController.text = slug;

      // التأكد أن كل منتج له رابط فريد وقابل للمشاركة (slug غير فارغ)
      if (slug.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text("تعذّر توليد رابط مخصص (Slug) للمنتج")),
          );
        }
        setState(() => _isLoading = false);
        return;
      }

      final shortDescription = _buildShortDescription();
      final tags = _buildTags();

      // ================== تجهيز المتغيرات المتقدمة ==================
      List<Map<String, dynamic>> variantsPayload = [];
      if (_useAdvancedVariants) {
        final Set<String> keys = {};
        for (final row in _variantRows) {
          if (row.isCompletelyEmpty) continue;

          String? variantImageUrl = row.variantImage?.serverUrl;
          if (row.variantImage?.localBytes != null) {
            final path =
                'products/variant_${DateTime.now().millisecondsSinceEpoch}_${row.id}.${row.variantImage!.fileExtension}';
            variantImageUrl = await _adminProductRepo.uploadProductImage(
              path: path,
              bytes: row.variantImage!.localBytes!,
            );
          }

          final price = double.tryParse(row.priceCtrl.text.trim());
          if (price == null) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("يرجى إدخال سعر صحيح لكل متغير")),
              );
            }
            throw Exception('Invalid variant price');
          }
          final key =
              '${row.colorCtrl.text.trim()}|${row.sizeCtrl.text.trim()}|${row.unitCtrl.text.trim()}';
          if (keys.contains(key)) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text("يوجد متغير مكرر بنفس اللون/المقاس/الوحدة")),
              );
            }
            throw Exception('Duplicate variant');
          }
          keys.add(key);

          variantsPayload.add({
            'id': row.id,
            if (row.skuCtrl.text.trim().isNotEmpty)
              'sku': row.skuCtrl.text.trim(),
            if (row.colorCtrl.text.trim().isNotEmpty)
              'color': row.colorCtrl.text.trim(),
            if (row.sizeCtrl.text.trim().isNotEmpty)
              'size': row.sizeCtrl.text.trim(),
            if (row.unitCtrl.text.trim().isNotEmpty)
              'unit': row.unitCtrl.text.trim(),
            if (variantImageUrl != null && variantImageUrl.trim().isNotEmpty)
              'image_url': variantImageUrl.trim(),
            if (row.attributes.isNotEmpty) 'attributes': row.attributes,
            'price': price,
            if (_inventoryPolicy == 'track_qty' &&
                row.stockCtrl.text.trim().isNotEmpty)
              'stock': int.tryParse(row.stockCtrl.text.trim()) ?? 0,
          });
        }
      }

      // ================== إعدادات الفرشات (اختياري) ==================
      Map<String, dynamic>? mattressOptions;
      if (_isMattressMode) {
        final customWidths = _parseCsvInts(_mattressWidthsCtrl.text);
        final wMin = int.tryParse(_mattressWidthMinCtrl.text.trim());
        final wMax = int.tryParse(_mattressWidthMaxCtrl.text.trim());
        final wStep = int.tryParse(_mattressWidthStepCtrl.text.trim());
        final lengths = _parseCsvInts(_mattressLengthsCtrl.text);

        final baseFee = double.tryParse(_mattressBaseFeeCtrl.text.trim()) ?? 0;
        final perSqm = double.tryParse(_mattressPricePerSqmCtrl.text.trim()) ?? 0;

        // تسعير يدوي حسب العرض
        final widthPrices = _buildMattressWidthPrices();

        if (customWidths.isEmpty) {
          if (wMin == null ||
              wMax == null ||
              wStep == null ||
              wStep <= 0 ||
              wMin <= 0 ||
              wMax < wMin) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content:
                        Text('يرجى إدخال مدى عرض صحيح للفرشة (min/max/step).')),
              );
            }
            setState(() => _isLoading = false);
            return;
          }
        }

        if (lengths.isEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('يرجى إدخال أطوال الفرشات (مثال: 190,195,200).')),
            );
          }
          setState(() => _isLoading = false);
          return;
        }

        if (_mattressPricingMode == 'by_width' && widthPrices.isEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('يرجى إدخال أسعار الفرشة حسب العرض (يدوي).')),
            );
          }
          setState(() => _isLoading = false);
          return;
        }

        final pricingPayload = <String, dynamic>{
          'mode': _mattressPricingMode,
          if (_mattressPricingMode == 'per_sqm') ...{
            'base_fee': baseFee,
            'price_per_sqm': perSqm,
          } else ...{
            'width_prices': widthPrices,
          }
        };

        mattressOptions = {
          'width_min': wMin,
          'width_max': wMax,
          'width_step': wStep,
          if (customWidths.isNotEmpty) 'widths': customWidths,
          'lengths': lengths,
          'pricing': pricingPayload,
        };
      }

      // تحديد نوع المنتج لحفظه في options
      String productType = 'standard';
      if (_isMattressMode) {
        productType = 'mattress';
      } else if (_isOfferMode) {
        productType = 'bundle';
      } else if (_useAdvancedVariants && variantsPayload.isNotEmpty) {
        productType = 'variable_with_variants';
      }

      final productData = {
        'title': _titleController.text,
        'slug': slug.isNotEmpty ? slug : null,
        'short_description':
            shortDescription.isNotEmpty ? shortDescription : null,
        'tags': tags.isNotEmpty ? tags : null,
        'description': _descController.text,
        'price': double.parse(_priceController.text),
        'old_price': _oldPriceController.text.isNotEmpty
            ? double.parse(_oldPriceController.text)
            : null,
        'category': _selectedCategory,
        'sub_category_id': _selectedSubCategoryId,
        'shipping_size': _shippingSize, // ✅ حفظ حجم الشحن
        'image_url': mainImageUrl,
        'is_featured': _isFeatured,
        'is_flash_deal': _isFlashDeal,
        'gallery': galleryData,
        'options': {
          'sizes': _isMattressMode ? <String>[] : _sizes,
          'colors': colorsList,
          'is_offer': _isOfferMode,
          'price_tiers': _isOfferMode ? tiersData : null,
          'product_type': productType,
          if (mattressOptions != null) 'mattress': mattressOptions,
          'pricing_unit': _unitLabelCtrl.text.trim().isNotEmpty
              ? _unitLabelCtrl.text.trim()
              : 'حبة',
          'unit_min': double.tryParse(_unitMinCtrl.text.trim()) ?? 1,
          'unit_step': double.tryParse(_unitStepCtrl.text.trim()) ?? 1,
          'inventory_policy': _inventoryPolicy,
          if (_inventoryPolicy == 'track_qty')
            'stock': int.tryParse(_baseStockController.text.trim()) ?? 0,
          if (_inventoryPolicy == 'status_based') 'in_stock': _statusBasedInStock,
          'product_options': _dynamicOptions.map((e) => e.toJson()).toList(),
        },
      };

      // إذا كانت المتغيرات المتقدمة مفعّلة وهناك بيانات، نضيف حقل variants ديناميكياً
      if (_useAdvancedVariants && variantsPayload.isNotEmpty) {
        productData['variants'] = variantsPayload;
      }

      await _adminProductRepo.upsertProduct(
        productData: productData,
        productId: productToEdit?.id,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("تم حفظ المنتج بنجاح")));
        context.pop();
      }
    } catch (e) {
      if (!mounted) return;

      // معالجة خاصة في حال تكرار الـ slug أو تعارض قيمة enum مع نوع الحقل في قاعدة البيانات
      final errorText = e.toString();
      String message;

      if (errorText.contains('products_slug_key') ||
          errorText.contains('duplicate key value')) {
        message =
            "هناك منتج آخر يستخدم نفس الرابط (Slug)، يرجى اختيار رابط مختلف.";
      } else if (errorText.contains('invalid input value for enum product_category') ||
          errorText.contains('enum product_category')) {
        message =
            "القسم المختار غير متوافق مع إعدادات قاعدة البيانات. تأكد أن قيمة حقل القسم (id في جدول الأقسام) تطابق قيم enum product_category في Supabase، أو حدِّث enum لإضافة هذا القسم.";
      } else {
        message = "خطأ غير متوقع أثناء حفظ المنتج، حاول مرة أخرى. (تفاصيل تقنية: $e)";
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // =================================== UI ===================================

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesConfigProvider);
    final remoteCategories =
        categoriesAsync.asData?.value ?? const <AppCategoryConfig>[];

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'رجوع',
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back_ios_new),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(productToEdit == null ? "إضافة منتج جديد" : "تعديل المنتج"),
        backgroundColor: const Color(0xFF0A2647),
        foregroundColor: Colors.white,
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        color: Colors.white,
        child: ElevatedButton.icon(
          onPressed: _isLoading ? null : _saveProduct,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF0A2647),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 15),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          icon: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2))
              : const Icon(Icons.save),
          label: Text(_isLoading ? "جاري الحفظ..." : "حفظ ونشر المنتج",
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // ✅ 1. محدد نوع المنتج (الذي طلبته) بتصميم احترافي
              _buildProductTypeSelector(),

              const SizedBox(height: 16),

              ExpansionPanelList(
                key: ValueKey<String>('$_selectedCategory-${_isMattressMode ? 'mattressOn' : 'mattressOff'}'),
                elevation: 0,
                expandedHeaderPadding: const EdgeInsets.symmetric(vertical: 6),
                expansionCallback: (panelIndex, isExpanded) {
                  final panelIds = _currentPanelIds();
                  if (panelIndex < 0 || panelIndex >= panelIds.length) return;
                  final id = panelIds[panelIndex];
                  _togglePanel(id);
                },
                children: [
                  ExpansionPanel(
                    canTapOnHeader: true,
                    isExpanded: _expandedPanels.contains(_ProductFormPanel.basic),
                    headerBuilder: (context, isExpanded) {
                      return InkWell(
                        onTap: () => _togglePanel(_ProductFormPanel.basic),
                        child: const ListTile(
                          leading: Icon(Icons.info_outline,
                              color: Color(0xFF0A2647)),
                          title: Text('المعلومات الأساسية'),
                        ),
                      );
                    },
                    body: _buildBasicInfoCard(remoteCategories),
                  ),
                  ExpansionPanel(
                    canTapOnHeader: true,
                    isExpanded: _expandedPanels.contains(_ProductFormPanel.pricing),
                    headerBuilder: (context, isExpanded) {
                      return InkWell(
                        onTap: () => _togglePanel(_ProductFormPanel.pricing),
                        child: const ListTile(
                          leading: Icon(Icons.price_change_outlined,
                              color: Color(0xFF0A2647)),
                          title: Text('التسعير'),
                        ),
                      );
                    },
                    body: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      child: _isOfferMode ? _buildOffersCard() : _buildPricingCard(),
                    ),
                  ),
                  ExpansionPanel(
                    canTapOnHeader: true,
                    isExpanded: _expandedPanels.contains(_ProductFormPanel.inventory),
                    headerBuilder: (context, isExpanded) {
                      return InkWell(
                        onTap: () => _togglePanel(_ProductFormPanel.inventory),
                        child: const ListTile(
                          leading: Icon(Icons.inventory_2_outlined,
                              color: Color(0xFF0A2647)),
                          title: Text('المخزون'),
                        ),
                      );
                    },
                    body: _buildInventoryCard(),
                  ),
                  ExpansionPanel(
                    canTapOnHeader: true,
                    isExpanded: _expandedPanels.contains(_ProductFormPanel.media),
                    headerBuilder: (context, isExpanded) {
                      return InkWell(
                        onTap: () => _togglePanel(_ProductFormPanel.media),
                        child: const ListTile(
                          leading: Icon(Icons.photo_library_outlined,
                              color: Color(0xFF0A2647)),
                          title: Text('الوسائط'),
                        ),
                      );
                    },
                    body: _buildMediaCard(),
                  ),
                  if (_selectedCategory == 'mattresses')
                    ExpansionPanel(
                      canTapOnHeader: true,
                      isExpanded: _expandedPanels.contains(_ProductFormPanel.mattress),
                      headerBuilder: (context, isExpanded) {
                        return InkWell(
                          onTap: () => _togglePanel(_ProductFormPanel.mattress),
                          child: const ListTile(
                            leading: Icon(Icons.bed_outlined,
                                color: Color(0xFF0A2647)),
                            title: Text('إعدادات الفرش'),
                          ),
                        );
                      },
                      body: _buildMattressModeCard(),
                    ),
                  ExpansionPanel(
                    canTapOnHeader: true,
                    isExpanded: _expandedPanels.contains(_ProductFormPanel.options),
                    headerBuilder: (context, isExpanded) {
                      return InkWell(
                        onTap: () => _togglePanel(_ProductFormPanel.options),
                        child: const ListTile(
                          leading:
                              Icon(Icons.tune, color: Color(0xFF0A2647)),
                          title: Text('الخيارات (السمات)'),
                        ),
                      );
                    },
                    body: _buildOptionsCard(),
                  ),
                  ExpansionPanel(
                    canTapOnHeader: true,
                    isExpanded: _expandedPanels.contains(_ProductFormPanel.variants),
                    headerBuilder: (context, isExpanded) {
                      return InkWell(
                        onTap: () => _togglePanel(_ProductFormPanel.variants),
                        child: const ListTile(
                          leading: Icon(Icons.grid_view_outlined,
                              color: Color(0xFF0A2647)),
                          title: Text('المتغيرات'),
                        ),
                      );
                    },
                    body: _buildVariantsCard(),
                  ),
                ],
              ),

              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openVariantImagePicker(_VariantRow row) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'صورة المتغير',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 12),
                ListTile(
                  leading: const Icon(Icons.photo_camera_back_outlined),
                  title: const Text('اختيار من الجهاز'),
                  onTap: () async {
                    Navigator.pop(context);
                    final picker = ImagePicker();
                    final image = await picker.pickImage(source: ImageSource.gallery);
                    if (image == null) return;
                    final originalBytes = await image.readAsBytes();
                    final originalExt = image.name.split('.').last;
                    final compressed = await AppImageCompressor.compress(
                      originalBytes,
                      originalExtension: originalExt,
                    );
                    setState(() {
                      row.variantImage = _ImageWrapper(
                        localBytes: compressed.bytes,
                        fileExtension: compressed.extension,
                      );
                    });
                  },
                ),
                if (_mainImage?.serverUrl != null && _mainImage!.serverUrl!.isNotEmpty)
                  ListTile(
                    leading: const Icon(Icons.star_outline),
                    title: const Text('استخدام الصورة الرئيسية'),
                    onTap: () {
                      setState(() {
                        row.variantImage = _ImageWrapper(serverUrl: _mainImage!.serverUrl);
                      });
                      Navigator.pop(context);
                    },
                  ),
                if (_galleryImages.isNotEmpty)
                  ListTile(
                    leading: const Icon(Icons.photo_library_outlined),
                    title: const Text('اختيار من معرض المنتج'),
                    onTap: () async {
                      Navigator.pop(context);
                      final url = await _openGalleryPickerDialog();
                      if (url == null || url.isEmpty) return;
                      setState(() {
                        row.variantImage = _ImageWrapper(serverUrl: url);
                      });
                    },
                  ),
                if (row.variantImage != null)
                  ListTile(
                    leading: const Icon(Icons.delete_outline, color: Colors.red),
                    title: const Text('إزالة الصورة'),
                    onTap: () {
                      setState(() {
                        row.variantImage = null;
                      });
                      Navigator.pop(context);
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<String?> _openGalleryPickerDialog() async {
    if (_galleryImages.isEmpty) return null;
    return showDialog<String?>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('اختيار صورة من المعرض'),
          content: SizedBox(
            width: 520,
            child: GridView.builder(
              shrinkWrap: true,
              itemCount: _galleryImages.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemBuilder: (context, index) {
                final img = _galleryImages[index];
                final url = img.serverUrl;
                return InkWell(
                  onTap: () => Navigator.pop(context, url),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: img.localBytes != null
                        ? Image.memory(img.localBytes!, fit: BoxFit.cover)
                        : (url == null || url.isEmpty)
                            ? Container(color: Colors.grey.shade200)
                            : AppNetworkImage(
                                url: url,
                                variant: ImageVariant.thumbnail,
                                fit: BoxFit.cover,
                                placeholder: const ShimmerImagePlaceholder(),
                                errorWidget: const Icon(Icons.image_not_supported_outlined),
                              ),
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildInventoryCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.inventory_2_outlined, color: Color(0xFF0A2647)),
                SizedBox(width: 8),
                Text(
                  'المخزون والتوفر',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'اختر سياسة المخزون الأنسب للمنتج. يمكن ربط المخزون على مستوى المنتج أو على مستوى المتغيرات.',
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
            const Divider(),

            DropdownButtonFormField<String>(
              initialValue: _inventoryPolicy,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'سياسة المخزون',
                prefixIcon: Icon(Icons.rule),
              ),
              items: const [
                DropdownMenuItem(
                  value: 'track_qty',
                  child: Text(
                    'تتبع الكمية',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                DropdownMenuItem(
                  value: 'always_in_stock',
                  child: Text(
                    'متوفر دائماً',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                DropdownMenuItem(
                  value: 'status_based',
                  child: Text(
                    'حسب الحالة',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
              onChanged: (v) {
                if (v == null) return;
                setState(() => _inventoryPolicy = v);
              },
            ),

            const SizedBox(height: 10),

            if (_inventoryPolicy == 'track_qty')
              const Text(
                'سيتم استخدام مخزون المنتج أو مخزون المتغيرات (إن وُجدت).',
                style: TextStyle(fontSize: 11, color: Colors.grey),
              )
            else if (_inventoryPolicy == 'always_in_stock')
              const Text(
                'لن يتم طلب رقم مخزون وسيُعتبر المنتج متاحاً دائماً.',
                style: TextStyle(fontSize: 11, color: Colors.grey),
              )
            else
              const Text(
                'سيتم حفظ حالة التوفر كقيمة (متوفر/غير متوفر) بدون مخزون رقمي.',
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),

            const SizedBox(height: 10),
            if (_inventoryPolicy == 'track_qty') ...[
              TextFormField(
                controller: _baseStockController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'مخزون المنتج (إن لم تستخدم المتغيرات)',
                  prefixIcon: Icon(Icons.numbers),
                ),
              ),
            ],

            if (_inventoryPolicy == 'status_based')
              SwitchListTile(
                value: _statusBasedInStock,
                contentPadding: EdgeInsets.zero,
                title: const Text('متوفر في المخزون'),
                onChanged: (v) => setState(() => _statusBasedInStock = v),
              ),
          ],
        ),
      ),
    );
  }

  // ✅ الويدجت الجديدة لتحديد نوع المنتج
  Widget _buildProductTypeSelector() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 520;

              if (isNarrow) {
                return Column(
                  children: [
                    _buildSelectorOption(
                      "منتج فردي (قياسي)",
                      Icons.shopping_bag_outlined,
                      false,
                      expand: false,
                    ),
                    const SizedBox(height: 6),
                    _buildSelectorOption(
                      "عروض توفير",
                      Icons.layers_outlined,
                      true,
                      expand: false,
                    ),
                  ],
                );
              }

              return Row(
                children: [
                  _buildSelectorOption(
                    "منتج فردي (قياسي)",
                    Icons.shopping_bag_outlined,
                    false,
                    expand: true,
                  ),
                  _buildSelectorOption(
                    "عروض توفير",
                    Icons.layers_outlined,
                    true,
                    expand: true,
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 4),
          Text(
            _isOfferMode
                ? "وضع العروض مناسب للبكجات (٢+١، كميات بالجملة، ...). سيتم اعتماد شرائح الأسعار فقط."
                : "وضع المنتج الفردي مناسب لمعظم المنتجات، مع سعر واحد أساسي ويمكن إضافة سعر قديم للخصم.",
            style: const TextStyle(fontSize: 11, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectorOption(
    String title,
    IconData icon,
    bool isOffer, {
    required bool expand,
  }) {
    final isSelected = _isOfferMode == isOffer;
    final child = GestureDetector(
      onTap: () {
        // فقط إذا كنا نضيف منتج جديد نسمح بالتغيير بحرية
        // إذا كان تعديل، نفضل عدم التغيير الجذري إلا بحذر، لكن سأتركه متاحاً
        if (_isMattressMode && isOffer) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'وضع العروض غير مدعوم في منتجات الفرشات بالتسعير التلقائي.'),
            ),
          );
          return;
        }
        setState(() => _isOfferMode = isOffer);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0A2647) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                size: 18, color: isSelected ? Colors.white : Colors.grey[600]),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.grey[600],
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (!expand) return child;
    return Expanded(child: child);
  }

  Widget _buildOffersCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Colors.orange[50], // تمييز لوني
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.local_offer, color: Colors.orange),
                SizedBox(width: 10),
                Text("نظام العروض",
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Color(0xFF0A2647))),
              ],
            ),
            const Text("مثال: اشترِ 2 بسعر 10 دنانير. سيتم تعطيل السعر الفردي.",
                style: TextStyle(fontSize: 12, color: Colors.grey)),
            const Divider(),
            ..._offerTiers.asMap().entries.map((entry) {
              final index = entry.key;
              final ctrl = entry.value;

              double? unitPrice;
              final qty = int.tryParse(ctrl['qty']!.text);
              final total = double.tryParse(ctrl['price']!.text);
              if (qty != null && qty > 0 && total != null && total > 0) {
                unitPrice = total / qty;
              }

              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text("الكمية"),
                        const SizedBox(width: 10),
                        SizedBox(
                          width: 60,
                          child: _buildTextField(
                            "",
                            ctrl['qty']!,
                            isNumber: true,
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Text("السعر الإجمالي"),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildTextField(
                            "",
                            ctrl['price']!,
                            isNumber: true,
                            icon: Icons.attach_money,
                          ),
                        ),
                        IconButton(
                          icon:
                              const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _removeOfferTier(index),
                        ),
                      ],
                    ),
                    if (unitPrice != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4, left: 4),
                        child: Text(
                          "≈ ${unitPrice.toStringAsFixed(2)} للسعر الفردي",
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                  ],
                ),
              );
            }),
            TextButton.icon(
              onPressed: () => _addOfferTier(),
              icon: const Icon(Icons.add),
              label: const Text("إضافة عرض آخر"),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildPricingCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("💰 الأسعار (منتج فردي)",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const Divider(),
            Row(
              children: [
                Expanded(
                    child: _buildTextField("السعر الحالي", _priceController,
                        icon: Icons.attach_money, isNumber: true)),
                const SizedBox(width: 10),
                Expanded(
                    child: _buildTextField(
                        "السعر القديم (اختياري)", _oldPriceController,
                        icon: Icons.money_off, isNumber: true)),
              ],
            ),
            const SizedBox(height: 12),
            const Text("إعدادات التسعير بالوحدة / المتر (اختياري)",
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            const Text(
              "تفيد للحالات التي يختار فيها العميل الطول/الكمية (مثل المتر، الحبة، الكرتونة).",
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _unitLabelCtrl,
                    decoration: const InputDecoration(
                      labelText: "اسم الوحدة (مثلاً: حبة، متر)",
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _unitMinCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: "الحد الأدنى",
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _unitStepCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: "الخطوة",
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBasicInfoCard(List<AppCategoryConfig> remoteCategories) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("المعلومات الأساسية",
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Color(0xFF0A2647))),
            const Divider(),
            _buildTextField("اسم المنتج", _titleController, icon: Icons.title),

            const SizedBox(height: 12),

            // حقل slug للمعاينة فقط (يُولّد تلقائياً عند الحفظ ولا يمكن تعديله)
            TextFormField(
              controller: _slugController,
              readOnly: true,
              decoration: InputDecoration(
                labelText: "الرابط (Slug)",
                helperText: "يتم توليده تلقائياً عند الحفظ. لا حاجة لتعديله.",
                prefixIcon: const Icon(Icons.link, color: Colors.grey),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                filled: true,
                fillColor: Colors.grey[50],
              ),
            ),
            const SizedBox(height: 12),

            // قائمة الأقسام: إما من Supabase (categories) أو القائمة الافتراضية
            Builder(
              builder: (context) {
                final hasRemote = remoteCategories.isNotEmpty;
                final List<DropdownMenuItem<String>> items = [];

                if (hasRemote) {
                  for (final c in remoteCategories) {
                    items.add(
                      DropdownMenuItem(
                        value: c.id,
                        child: Text(c.name),
                      ),
                    );
                  }
                } else {
                  for (final code in _categories) {
                    items.add(
                      DropdownMenuItem(
                        value: code,
                        child: Text(_getCategoryName(code)),
                      ),
                    );
                  }
                }

                // تأكد أن القيمة الحالية موجودة ضمن العناصر حتى لا يحدث خطأ في الـ Dropdown
                final exists =
                    items.any((item) => item.value == _selectedCategory);
                if (!exists && _selectedCategory.isNotEmpty) {
                  items.insert(
                    0,
                    DropdownMenuItem(
                      value: _selectedCategory,
                      child: Text(
                        '${_getCategoryName(_selectedCategory)} (غير مفعّل)',
                      ),
                    ),
                  );
                }

                return DropdownButtonFormField<String>(
                  key: ValueKey(_selectedCategory),
                  initialValue: _selectedCategory.isNotEmpty
                      ? _selectedCategory
                      : (items.isNotEmpty ? items.first.value : null),
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: "القسم",
                    prefixIcon: Icon(Icons.category),
                    border: OutlineInputBorder(),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  items: items,
                  selectedItemBuilder: (context) => items
                      .map(
                        (item) => Text(
                          (item.child is Text)
                              ? ((item.child as Text).data ?? '')
                              : (item.value ?? ''),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      )
                      .toList(),
                  onChanged: (v) {
                    if (v == null) return;
                    // عند تغيير الفئة الرئيسية، نلغي اختيار الفئة الفرعية السابقة
                    setState(() {
                      _selectedCategory = v;
                      _selectedSubCategoryId = null;
                      _isMattressMode = v == 'mattresses';
                      if (_isMattressMode) {
                        _isOfferMode = false;
                      }
                    });
                    _loadSubCategoriesFor(v);
                  },
                );
              },
            ),

            const SizedBox(height: 12),

            if (_isLoadingSubCategories)
              const LinearProgressIndicator(minHeight: 2)
            else if (_subCategories.isNotEmpty)
              DropdownButtonFormField<String>(
                initialValue: _selectedSubCategoryId,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: "الفئة الفرعية",
                  prefixIcon: Icon(Icons.label_outline),
                  border: OutlineInputBorder(),
                  filled: true,
                  fillColor: Colors.white,
                ),
                items: _subCategories
                    .map(
                      (sub) => DropdownMenuItem<String>(
                        value: sub['id'] as String,
                        child: Text(
                          sub['name'] as String? ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _selectedSubCategoryId = v),
              )
            else
              const Text(
                'لا توجد فئات فرعية لهذه الفئة حتى الآن.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),

            const SizedBox(height: 20),
            _buildDescriptionEditor(),

            const SizedBox(height: 12),
            
            // ✅ حقل حجم الشحن
            DropdownButtonFormField<String>(
              initialValue: _shippingSize,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: "حجم الشحن",
                prefixIcon: const Icon(Icons.local_shipping),
                border: const OutlineInputBorder(),
                filled: true,
                fillColor: Colors.white,
                helperText: "يحدد تكلفة التوصيل حسب حجم المنتج",
              ),
              items: const [
                DropdownMenuItem(
                    value: 'small', child: Text('صغير (وسائد، مناشف)')),
                DropdownMenuItem(
                    value: 'medium', child: Text('متوسط (لحاف، بطانية)')),
                DropdownMenuItem(
                    value: 'large', child: Text('كبير (طاولة، مرتبة)')),
                DropdownMenuItem(
                    value: 'x_large', child: Text('كبير جداً (غرفة نوم)')),
              ],
              onChanged: (v) => setState(() => _shippingSize = v!),
            ),
            
            const SizedBox(height: 12),
            SwitchListTile(
              title: const Text("منتج مميز (Featured)"),
              subtitle: const Text("يظهر في الشريط العلوي"),
              value: _isFeatured,
              onChanged: (v) => setState(() => _isFeatured = v),
            ),
            SwitchListTile(
              title: const Text("عرض فلاش (Flash Deal)"),
              subtitle: const Text("يظهر في قسم العروض المؤقتة"),
              value: _isFlashDeal,
              onChanged: (v) => setState(() => _isFlashDeal = v),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDescriptionEditor() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("وصف المنتج",
            style: TextStyle(
                fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(8)),
              border: Border.all(color: Colors.grey[300]!)),
          child: Row(
            children: [
              _EditorButton(
                  label: "عنوان فرعي",
                  icon: Icons.title,
                  onTap: () => _insertTextAtCursor("عنوان:\n")),
              _EditorButton(
                  label: "قائمة",
                  icon: Icons.list,
                  onTap: () => _insertTextAtCursor("- ")),
              const Spacer(),
              IconButton(
                  icon: const Icon(Icons.clear, size: 18, color: Colors.red),
                  onPressed: () => _descController.clear()),
            ],
          ),
        ),
        TextFormField(
          controller: _descController,
          keyboardType: TextInputType.multiline,
          maxLines: 5,
          decoration: const InputDecoration(
              border: OutlineInputBorder(
                  borderRadius:
                      BorderRadius.vertical(bottom: Radius.circular(8))),
              filled: true,
              fillColor: Colors.white),
          validator: (v) => v!.isEmpty ? "مطلوب" : null,
        ),
      ],
    );
  }

  void _insertTextAtCursor(String text) {
    final selection = _descController.selection;
    final newText =
        _descController.text.replaceRange(selection.start, selection.end, text);
    _descController.value = TextEditingValue(
        text: newText,
        selection:
            TextSelection.collapsed(offset: selection.start + text.length));
  }

  Widget _buildMediaCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("الصور والألوان",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const Divider(),
            GestureDetector(
              onTap: () => _pickImage(true),
              child: Container(
                height: 150,
                width: double.infinity,
                decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[300]!)),
                    child: _mainImage == null
                    ? const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                            Icon(Icons.add_a_photo,
                                size: 40, color: Colors.grey),
                            Text("الصورة الرئيسية")
                          ])
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: _mainImage!.localBytes != null
                            ? Image.memory(
                                _mainImage!.localBytes!,
                                fit: BoxFit.cover,
                              )
                            : AppNetworkImage(
                                url: _mainImage!.serverUrl!,
                                variant: ImageVariant.homeBanner,
                                fit: BoxFit.cover,
                                placeholder:
                                    const ShimmerImagePlaceholder(),
                                errorWidget: const Icon(
                                  Icons.image_not_supported_outlined,
                                  color: Colors.grey,
                                ),
                              )),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    "المعرض والألوان:",
                    style: TextStyle(fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _pickImage(false),
                  icon: const Icon(Icons.add_photo_alternate),
                  label: const Text(
                    "إضافة صورة",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                )
              ],
            ),
            if (_isPickingGalleryImages)
              const Padding(
                padding: EdgeInsets.only(top: 10, bottom: 6),
                child: LinearProgressIndicator(minHeight: 3),
              ),
            if (_galleryImages.isNotEmpty)
              ReorderableListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _galleryImages.length,
                onReorder: _reorderGalleryImages,
                itemBuilder: (context, index) {
                  final img = _galleryImages[index];
                  return Container(
                    key: ValueKey(img.id),
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: LayoutBuilder(
                      builder: (context, c) {
                        final isNarrow = c.maxWidth < 520;

                        final leading = Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ReorderableDragStartListener(
                              index: index,
                              child: const Padding(
                                padding: EdgeInsetsDirectional.only(end: 6),
                                child: Icon(Icons.drag_handle, color: Colors.grey),
                              ),
                            ),
                            SizedBox(
                              width: 60,
                              height: 60,
                              child: img.localBytes != null
                                  ? Image.memory(
                                      img.localBytes!,
                                      fit: BoxFit.cover,
                                    )
                                  : AppNetworkImage(
                                      url: img.serverUrl!,
                                      variant: ImageVariant.thumbnail,
                                      fit: BoxFit.cover,
                                      placeholder: const ShimmerImagePlaceholder(),
                                      errorWidget: const Icon(
                                        Icons.image_not_supported_outlined,
                                        color: Colors.grey,
                                      ),
                                    ),
                            ),
                          ],
                        );

                        final colorEditor = Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: img.colorNameCtrl,
                                onChanged: (v) {
                                  img.colorName = v;
                                  img.colorNameManuallyEdited = true;
                                },
                                decoration: const InputDecoration(
                                  hintText: "اسم اللون",
                                  isDense: true,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            GestureDetector(
                              onTap: () => _showColorPicker(index),
                              child: Container(
                                width: 30,
                                height: 30,
                                decoration: BoxDecoration(
                                  color: img.colorValue,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.grey),
                                ),
                              ),
                            ),
                          ],
                        );

                        final actions = Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Wrap(
                              spacing: 10,
                              runSpacing: 6,
                              children: [
                                IconButton(
                                  tooltip: 'تعيين كأول صورة في المعرض',
                                  icon: Icon(
                                    Icons.star_outline,
                                    color: index == 0
                                        ? Colors.amber
                                        : Colors.grey.withValues(alpha: 0.8),
                                  ),
                                  iconSize: 22,
                                  visualDensity: VisualDensity.compact,
                                  constraints: const BoxConstraints(
                                    minWidth: 36,
                                    minHeight: 36,
                                  ),
                                  padding: const EdgeInsets.all(6),
                                  onPressed: () => _setGalleryImageAsFirst(index),
                                ),
                                IconButton(
                                  tooltip: 'حذف',
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    color: Colors.red,
                                  ),
                                  iconSize: 22,
                                  visualDensity: VisualDensity.compact,
                                  constraints: const BoxConstraints(
                                    minWidth: 36,
                                    minHeight: 36,
                                  ),
                                  padding: const EdgeInsets.all(6),
                                  onPressed: () {
                                    setState(() {
                                      final removed = _galleryImages.removeAt(index);
                                      removed.dispose();
                                    });
                                  },
                                ),
                              ],
                            ),
                          ],
                        );

                        final editor = Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "اللون المرتبط:",
                              style: TextStyle(fontSize: 10),
                            ),
                            const SizedBox(height: 4),
                            colorEditor,
                          ],
                        );

                        if (!isNarrow) {
                          return Row(
                            children: [
                              leading,
                              const SizedBox(width: 12),
                              Expanded(child: editor),
                              const SizedBox(width: 10),
                              actions,
                            ],
                          );
                        }

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                leading,
                                const SizedBox(width: 10),
                                const Spacer(),
                                actions,
                              ],
                            ),
                            const SizedBox(height: 10),
                            editor,
                          ],
                        );
                      },
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionsCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  "الخيارات (Attributes)",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _dynamicOptions.add(_DynamicOptionRow.empty());
                    });
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('إضافة خيار'),
                ),
              ],
            ),
            const Divider(),
            const Text(
              'أضف خيارات مرنة مثل: اللون، نوع القماش، الخامة... ثم أدخل القيم كـ Chips.',
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            if (_dynamicOptions.isEmpty)
              const Text(
                'لا توجد خيارات بعد. اضغط "إضافة خيار".',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              )
            else
              ..._dynamicOptions.asMap().entries.map((entry) {
                final index = entry.key;
                final row = entry.value;

                void addValue() {
                  final v = row.valueInputCtrl.text.trim();
                  if (v.isEmpty) return;
                  setState(() {
                    if (!row.values.contains(v)) {
                      row.values.add(v);
                    }
                    row.valueInputCtrl.clear();
                  });
                }

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.grey[50],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: row.nameCtrl,
                              decoration: const InputDecoration(
                                labelText: 'اسم الخيار (مثال: Color)',
                                isDense: true,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () {
                              setState(() {
                                final removed = _dynamicOptions.removeAt(index);
                                removed.dispose();
                              });
                            },
                            icon: const Icon(Icons.delete_outline, color: Colors.red),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: row.valueInputCtrl,
                              onSubmitted: (_) => addValue(),
                              decoration: const InputDecoration(
                                labelText: 'إضافة قيمة',
                                hintText: 'مثال: Red',
                                isDense: true,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: addValue,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0A2647),
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('إضافة'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: row.values
                            .map(
                              (v) => Chip(
                                label: Text(v),
                                onDeleted: () {
                                  setState(() {
                                    row.values.remove(v);
                                  });
                                },
                              ),
                            )
                            .toList(),
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  /// ✅ يُستخدم لقراءة أرقام من إدخال مثل: "190,195,200" أو "190/195/200".
  List<int> _parseCsvInts(String input) {
    final matches = RegExp(r'\d+').allMatches(input);
    final values = <int>{};
    for (final m in matches) {
      final s = m.group(0);
      if (s == null) continue;
      final v = int.tryParse(s);
      if (v != null) values.add(v);
    }
    final list = values.toList()..sort();
    return list;
  }

  /// ✅ بطاقة إعداد الفرشات بنظام تسعير احترافي.
  ///
  /// يدعم الآن وضعين:
  /// - per_sqm: حسب متر مربع (معادلة)
  /// - by_width: سعر يدوي حسب العرض فقط (الطول لا يؤثر بالسعر)
  Widget _buildMattressModeCard() {
    final availableWidths = _deriveMattressWidthsFromInputs();
    final lengths = _parseCsvInts(_mattressLengthsCtrl.text);

    final baseFee = double.tryParse(_mattressBaseFeeCtrl.text.trim()) ?? 0;
    final perSqm = double.tryParse(_mattressPricePerSqmCtrl.text.trim()) ?? 0;

    int? widthsCount;
    int? totalCombinations;
    if (availableWidths.isNotEmpty) {
      widthsCount = availableWidths.length;
      totalCombinations = widthsCount * lengths.length;
    }

    double? example;
    if (_isMattressMode && availableWidths.isNotEmpty) {
      final w = availableWidths.first;
      if (_mattressPricingMode == 'by_width') {
        final map = _buildMattressWidthPrices();
        final v = map[w.toString()];
        if (v != null) {
          example = v;
        }
      } else if (lengths.isNotEmpty) {
        final widthM = w / 100.0;
        final lengthM = lengths.first / 100.0;
        final area = widthM * lengthM;
        example = baseFee + (area * perSqm);
      }
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.bed, color: Color(0xFF0A2647)),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    '🛏️ إعدادات الفرشات (تسعير تلقائي حسب المقاس)',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
                Switch(
                  value: _isMattressMode,
                  onChanged: (v) {
                    setState(() {
                      _isMattressMode = v;
                      if (v) _isOfferMode = false;
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'فعّل هذا الخيار لبيع الفرشة حسب العرض/الطول مع حساب السعر تلقائياً.\n'
              'بدل إدخال قائمة طويلة من المقاسات وأسعارها.',
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),

            if (!_isMattressMode) ...[
              const SizedBox(height: 10),
              const Text(
                'إذا عطّلت وضع الفرشات، سيتم استخدام المقاسات الأساسية مثل باقي المنتجات.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ] else ...[
              if (totalCombinations != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6.0),
                  child: Text(
                    'سيتم توليد ${totalCombinations.toString()} مقاس تلقائياً (عروض: ${widthsCount ?? '-'} × أطوال: ${lengths.length}).',
                    style: const TextStyle(fontSize: 11, color: Colors.blueGrey),
                  ),
                ),
              const Divider(height: 22),
              const Text(
                '١) المقاسات المتاحة (بالسنتيمتر)',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _mattressWidthsCtrl,
                keyboardType: TextInputType.text,
                decoration: const InputDecoration(
                  labelText: 'قائمة عروض مخصصة (اختياري)',
                  hintText: 'مثال: 90,95,115,125,135,145,155,165,175,185,195,205,210,215,220',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _mattressWidthMinCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'العرض من (cm)',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _mattressWidthMaxCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'العرض إلى (cm)',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _mattressWidthStepCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'الخطوة (cm)',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'ملاحظة: إذا أدخلت "قائمة عروض مخصصة" سيتم اعتمادها وتجاهل min/max/step.',
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _mattressLengthsCtrl,
                keyboardType: TextInputType.text,
                decoration: const InputDecoration(
                  labelText: 'الأطوال (cm) مفصولة بفواصل/سلاش',
                  hintText: 'مثال: 190,195,200',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 14),
              const Text(
                '٢) نظام التسعير',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  ChoiceChip(
                    label: const Text('حسب متر مربع'),
                    selected: _mattressPricingMode == 'per_sqm',
                    onSelected: (v) {
                      if (!v) return;
                      setState(() => _mattressPricingMode = 'per_sqm');
                    },
                  ),
                  ChoiceChip(
                    label: const Text('سعر يدوي حسب العرض'),
                    selected: _mattressPricingMode == 'by_width',
                    onSelected: (v) {
                      if (!v) return;
                      setState(() => _mattressPricingMode = 'by_width');
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),

              if (_mattressPricingMode == 'per_sqm') ...[
                const Text(
                  'هذا الوضع يحسب السعر حسب مساحة الفرشة (م²).',
                  style: TextStyle(fontSize: 11, color: Colors.grey),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _mattressBaseFeeCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'مبلغ ثابت (Base)',
                          isDense: true,
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.attach_money, size: 18),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _mattressPricePerSqmCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'سعر لكل متر مربع',
                          isDense: true,
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.square_foot, size: 18),
                        ),
                      ),
                    ),
                  ],
                ),
              ] else ...[
                const Text(
                  'هذا الوضع يجعل السعر يختلف حسب العرض فقط (الطول لا يؤثر على السعر).',
                  style: TextStyle(fontSize: 11, color: Colors.grey),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _mattressDefaultWidthPriceCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'سعر افتراضي (اختياري)',
                          isDense: true,
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.attach_money, size: 18),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    TextButton.icon(
                      onPressed: _applyDefaultPriceToAllWidths,
                      icon: const Icon(Icons.content_copy),
                      label: const Text('نسخ للجميع'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    TextButton.icon(
                      onPressed: _syncMattressWidthPriceRowsFromWidths,
                      icon: const Icon(Icons.auto_awesome),
                      label: const Text('توليد جدول الأسعار'),
                    ),
                    const SizedBox(width: 8),
                    if (_mattressWidthPriceRows.isNotEmpty)
                      Text(
                        'عدد الأسعار: ${_mattressWidthPriceRows.length}',
                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                ..._mattressWidthPriceRows.map((row) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Text(
                            'عرض ${row.widthCm} سم',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: row.priceCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'السعر',
                              isDense: true,
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.attach_money, size: 18),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                          onPressed: () {
                            setState(() {
                              _mattressWidthPriceRows.remove(row);
                              row.dispose();
                            });
                          },
                        ),
                      ],
                    ),
                  );
                }),
              ],

              if (example != null) ...[
                const SizedBox(height: 10),
                Text(
                  _mattressPricingMode == 'by_width'
                      ? 'معاينة (تقريباً) لأصغر عرض: ${example.toStringAsFixed(2)} د.أ'
                      : 'معاينة (تقريباً) لأصغر مقاس: ${example.toStringAsFixed(2)} د.أ',
                  style: const TextStyle(fontSize: 12, color: Colors.green),
                ),
              ],
              const SizedBox(height: 6),
              const Text(
                'ملاحظة: يمكنك أيضاً إضافة استثناءات أسعار عبر "المتغيرات المتقدمة" (لأحجام محددة فقط).',
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ],
          ],
        ),
      ),
    );
  }

  List<int> _deriveMattressWidthsFromInputs() {
    final custom = _parseCsvInts(_mattressWidthsCtrl.text);
    if (custom.isNotEmpty) return custom;

    final wMin = int.tryParse(_mattressWidthMinCtrl.text.trim());
    final wMax = int.tryParse(_mattressWidthMaxCtrl.text.trim());
    final wStep = int.tryParse(_mattressWidthStepCtrl.text.trim());

    if (wMin == null || wMax == null || wStep == null) return const [];
    if (wMin <= 0 || wMax < wMin || wStep <= 0) return const [];

    final count = ((wMax - wMin) ~/ wStep) + 1;
    if (count <= 0 || count > 500) return const [];

    final list = <int>[];
    for (int w = wMin; w <= wMax; w += wStep) {
      list.add(w);
    }
    return list;
  }

  /// يبني `Map<String, double>` لأسعار العرض.
  /// مثال: {"90": 22.1, "95": 23.0}
  Map<String, double> _buildMattressWidthPrices() {
    final map = <String, double>{};
    for (final row in _mattressWidthPriceRows) {
      final price = double.tryParse(row.priceCtrl.text.trim());
      if (price == null) continue;
      map[row.widthCm.toString()] = price;
    }
    return map;
  }

  void _syncMattressWidthPriceRowsFromWidths() {
    final widths = _deriveMattressWidthsFromInputs();
    if (widths.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('أدخل العروض (قائمة أو min/max/step) أولاً.')),
      );
      return;
    }

    setState(() {
      final existing = <int, _MattressWidthPriceRow>{
        for (final r in _mattressWidthPriceRows) r.widthCm: r,
      };

      // نعيد بناء القائمة حسب widths الحالية (مع الحفاظ على الأسعار القديمة)
      final rebuilt = <_MattressWidthPriceRow>[];
      for (final w in widths) {
        final old = existing[w];
        if (old != null) {
          rebuilt.add(old);
        } else {
          rebuilt.add(_MattressWidthPriceRow(widthCm: w));
        }
      }

      // تخلص من الصفوف التي لم تعد ضمن widths
      for (final r in _mattressWidthPriceRows) {
        if (!widths.contains(r.widthCm)) {
          r.dispose();
        }
      }

      _mattressWidthPriceRows
        ..clear()
        ..addAll(rebuilt);

      // إذا كان هناك سعر افتراضي، نملأ الفراغات
      _applyDefaultPriceToAllWidths();
    });
  }

  void _applyDefaultPriceToAllWidths() {
    final defaultPrice =
        double.tryParse(_mattressDefaultWidthPriceCtrl.text.trim());
    if (defaultPrice == null) return;

    setState(() {
      for (final row in _mattressWidthPriceRows) {
        if (row.priceCtrl.text.trim().isEmpty) {
          row.priceCtrl.text = defaultPrice.toStringAsFixed(2);
        }
      }
    });
  }

  void _tryAutoFillMattressBasePrice() {
    // لا نغيّر السعر إذا كان معبّأ
    if (_priceController.text.trim().isNotEmpty) return;

    if (_mattressPricingMode == 'by_width') {
      final map = _buildMattressWidthPrices();
      if (map.isEmpty) return;
      final min = map.values.reduce((a, b) => a < b ? a : b);
      _priceController.text = min.toStringAsFixed(2);
      return;
    }

    // per_sqm
    final widths = _deriveMattressWidthsFromInputs();
    final lengths = _parseCsvInts(_mattressLengthsCtrl.text);
    if (widths.isEmpty || lengths.isEmpty) return;

    final baseFee = double.tryParse(_mattressBaseFeeCtrl.text.trim()) ?? 0;
    final perSqm = double.tryParse(_mattressPricePerSqmCtrl.text.trim()) ?? 0;

    final w = widths.first;
    final l = lengths.first;
    final area = (w / 100.0) * (l / 100.0);
    final price = baseFee + (area * perSqm);
    if (price > 0) {
      _priceController.text = price.toStringAsFixed(2);
    }
  }

  Widget _buildVariantsCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.grid_view, color: Color(0xFF0A2647)),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    "المتغيرات المتقدمة (لون + مقاس + وحدة + سعر)",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
                const SizedBox(width: 8),
                Switch(
                  value: _useAdvancedVariants,
                  onChanged: (v) => setState(() => _useAdvancedVariants = v),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              "استخدم هذه المتغيرات فقط عند الحاجة لتسعير مختلف لكل لون/مقاس/وحدة.",
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
            const SizedBox(height: 4),
            if (_variantRows.isNotEmpty)
              Text(
                "عدد المتغيرات الحالية: ${_variantRows.length}",
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
            const SizedBox(height: 12),
            if (!_useAdvancedVariants)
              const Text(
                "سيتم استخدام السعر الأساسي مع خيارات الألوان/المقاسات العادية.",
                style: TextStyle(fontSize: 12, color: Colors.grey),
              )
            else ...[
              Column(
                children: _variantRows.map((row) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: TextField(
                            controller: row.colorCtrl,
                            decoration: const InputDecoration(
                              labelText: "اللون",
                              isDense: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          flex: 2,
                          child: TextField(
                            controller: row.sizeCtrl,
                            decoration: const InputDecoration(
                              labelText: "المقاس",
                              isDense: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: TextField(
                            controller: row.unitCtrl,
                            decoration: const InputDecoration(
                              labelText: "الوحدة",
                              isDense: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
              Column(
                children: _variantRows.map((row) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final isNarrow = constraints.maxWidth < 720;

                        final priceStockRow = Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: row.priceCtrl,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: "السعر",
                                  prefixIcon:
                                      Icon(Icons.attach_money, size: 16),
                                  isDense: true,
                                ),
                              ),
                            ),
                            if (_inventoryPolicy == 'track_qty') ...[
                              const SizedBox(width: 6),
                              Expanded(
                                child: TextField(
                                  controller: row.stockCtrl,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText: "المخزون",
                                    isDense: true,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        );

                        final skuImageDeleteRow = Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: TextField(
                                controller: row.skuCtrl,
                                decoration: const InputDecoration(
                                  labelText: "SKU (اختياري)",
                                  isDense: true,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              flex: 2,
                              child: Row(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: SizedBox(
                                      width: 44,
                                      height: 44,
                                      child: row.variantImage?.localBytes !=
                                              null
                                          ? Image.memory(
                                              row.variantImage!.localBytes!,
                                              fit: BoxFit.cover,
                                            )
                                          : (row.variantImage?.serverUrl !=
                                                      null &&
                                                  row.variantImage!.serverUrl!
                                                      .trim()
                                                      .isNotEmpty)
                                              ? AppNetworkImage(
                                                  url: row
                                                      .variantImage!.serverUrl!,
                                                  variant:
                                                      ImageVariant.thumbnail,
                                                  fit: BoxFit.cover,
                                                  placeholder:
                                                      const ShimmerImagePlaceholder(),
                                                  errorWidget: const Icon(
                                                    Icons
                                                        .image_not_supported_outlined,
                                                    color: Colors.grey,
                                                  ),
                                                )
                                              : Container(
                                                  color: Colors.grey.shade200,
                                                  child: const Icon(
                                                    Icons.image_outlined,
                                                    color: Colors.grey,
                                                  ),
                                                ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: () =>
                                          _openVariantImagePicker(row),
                                      icon: const Icon(Icons.photo_outlined,
                                          size: 18),
                                      label: Text(
                                        row.variantImage == null
                                            ? 'اختيار صورة'
                                            : 'تغيير',
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline,
                                  color: Colors.red),
                              onPressed: () {
                                setState(() {
                                  _variantRows.remove(row);
                                });
                              },
                            ),
                          ],
                        );

                        if (!isNarrow) {
                          return Row(
                            children: [
                              Expanded(child: priceStockRow),
                              const SizedBox(width: 6),
                              Expanded(flex: 5, child: skuImageDeleteRow),
                            ],
                          );
                        }

                        return Column(
                          children: [
                            priceStockRow,
                            const SizedBox(height: 8),
                            skuImageDeleteRow,
                          ],
                        );
                      },
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _variantRows.add(_VariantRow.empty(
                            defaultUnit: _unitLabelCtrl.text));
                      });
                    },
                    icon: const Icon(Icons.add),
                    label: const Text("إضافة متغير"),
                  ),
                  const SizedBox(width: 12),
                  TextButton.icon(
                    onPressed: _openVariantsGeneratorDialog,
                    icon: const Icon(Icons.auto_awesome),
                    label: const Text("توليد من الألوان/المقاسات"),
                  ),
                  const SizedBox(width: 12),
                  TextButton.icon(
                    onPressed: _generateSkusForVariants,
                    icon: const Icon(Icons.qr_code_2),
                    label: const Text("توليد SKU تلقائياً"),
                  ),
                  const SizedBox(width: 12),
                  if (_variantRows.isNotEmpty)
                    TextButton(
                      onPressed: () {
                        final base = double.tryParse(
                            _priceController.text.trim());
                        if (base == null) return;
                        setState(() {
                          for (final row in _variantRows) {
                            if (row.priceCtrl.text.trim().isEmpty) {
                              row.priceCtrl.text =
                                  base.toStringAsFixed(2);
                            }
                          }
                        });
                      },
                      child: const Text(
                        "نسخ السعر الأساسي للمتغيرات",
                        style: TextStyle(fontSize: 11),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController ctrl,
      {IconData? icon, bool isNumber = false, int maxLines = 1}) {
    return TextFormField(
        controller: ctrl,
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        maxLines: maxLines,
        validator: (v) => (v == null || v.isEmpty) &&
                !label.contains("اختياري") &&
                label.isNotEmpty
            ? "مطلوب"
            : null,
        decoration: InputDecoration(
            labelText: label,
            prefixIcon: icon != null ? Icon(icon, color: Colors.grey) : null,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            filled: true,
            fillColor: Colors.grey[50]));
  }

  void _generateSkusForVariants() {
    final baseSlug = _slugController.text.trim().isNotEmpty
        ? _slugController.text.trim().toUpperCase()
        : _buildSlug(_titleController.text).toUpperCase();
    for (int i = 0; i < _variantRows.length; i++) {
      final row = _variantRows[i];
      if (row.skuCtrl.text.trim().isEmpty) {
        row.skuCtrl.text = '$baseSlug-${i + 1}';
      }
    }
    setState(() {});
  }

  /// فتح أداة ذكية لتوليد المتغيرات تلقائياً من الألوان + المقاسات الحالية.
  Future<void> _openVariantsGeneratorDialog() async {
    // تفعيل المتغيرات المتقدمة تلقائياً عند فتح أداة التوليد
    if (!_useAdvancedVariants) {
      setState(() {
        _useAdvancedVariants = true;
      });
    }

    // المصدر 1 (الجديد): خيارات ديناميكية (Attributes)
    final dynOptions = _dynamicOptions
        .where((o) => o.nameCtrl.text.trim().isNotEmpty && o.values.isNotEmpty)
        .toList();

    // المصدر 2 (القديم): ألوان المعرض + مقاسات legacy
    final availableColors = _galleryImages
        .map((img) => img.colorName.trim())
        .where((name) => name.isNotEmpty)
        .toSet()
        .toList();
    final availableSizes = List<String>.from(_sizes);

    if (dynOptions.isEmpty && availableColors.isEmpty && availableSizes.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('أضف على الأقل لوناً أو مقاساً قبل توليد المتغيرات.')),
      );
      return;
    }

    final selectedColors = <String>{...availableColors};
    final selectedSizes = <String>{...availableSizes};

    // خيارات ديناميكية: نخليها كلها محددة افتراضياً
    final Map<String, Set<String>> selectedDyn = {
      for (final o in dynOptions) o.nameCtrl.text.trim(): {...o.values}
    };

    final unitCtrl = TextEditingController(
        text: _unitLabelCtrl.text.trim().isNotEmpty
            ? _unitLabelCtrl.text
            : 'حبة');
    final basePriceCtrl = TextEditingController(text: _priceController.text);
    final baseStockCtrl = TextEditingController();

    Map<String, dynamic>? result;

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              title: const Text('توليد المتغيرات تلقائياً'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'اختر الألوان والمقاسات التي تريد إنشاء متغيرات لها دفعة واحدة.\n'
                      'يمكنك تعديل الأسعار والمخزون لكل متغير لاحقاً.',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 12),
                    if (availableColors.isNotEmpty) ...[
                      const Text('الألوان',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: availableColors.map((color) {
                          final isSelected = selectedColors.contains(color);
                          return FilterChip(
                            label: Text(color),
                            selected: isSelected,
                            onSelected: (v) {
                              setStateDialog(() {
                                if (v) {
                                  selectedColors.add(color);
                                } else {
                                  selectedColors.remove(color);
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (availableSizes.isNotEmpty) ...[
                      const Text('المقاسات',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: availableSizes.map((size) {
                          final isSelected = selectedSizes.contains(size);
                          return FilterChip(
                            label: Text(size),
                            selected: isSelected,
                            onSelected: (v) {
                              setStateDialog(() {
                                if (v) {
                                  selectedSizes.add(size);
                                } else {
                                  selectedSizes.remove(size);
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 12),
                    ],

                    if (dynOptions.isNotEmpty) ...[
                      const Text('خيارات إضافية',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      ...dynOptions.map((opt) {
                        final name = opt.nameCtrl.text.trim();
                        final values = opt.values;
                        final selectedSet = selectedDyn[name] ?? <String>{};
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(name),
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: values.map((val) {
                                  final isSelected = selectedSet.contains(val);
                                  return FilterChip(
                                    label: Text(val),
                                    selected: isSelected,
                                    onSelected: (v) {
                                      setStateDialog(() {
                                        final set = selectedDyn.putIfAbsent(
                                          name,
                                          () => <String>{},
                                        );
                                        if (v) {
                                          set.add(val);
                                        } else {
                                          set.remove(val);
                                        }
                                      });
                                    },
                                  );
                                }).toList(),
                              ),
                            ],
                          ),
                        );
                      }),
                      const SizedBox(height: 12),
                    ],

                    const Divider(),
                    const SizedBox(height: 8),
                    TextField(
                      controller: unitCtrl,
                      decoration: const InputDecoration(
                        labelText: 'اسم الوحدة الافتراضية (مثلاً: متر، حبة)',
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: basePriceCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'سعر افتراضي لكل متغير',
                        prefixIcon: Icon(Icons.attach_money, size: 18),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: baseStockCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'مخزون افتراضي (اختياري)',
                        isDense: true,
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('إلغاء'),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (basePriceCtrl.text.trim().isEmpty) {
                      ScaffoldMessenger.of(dialogContext).showSnackBar(
                        const SnackBar(
                            content: Text('يرجى إدخال سعر افتراضي.')),
                      );
                      return;
                    }
                    final parsedPrice =
                        double.tryParse(basePriceCtrl.text.trim());
                    if (parsedPrice == null) {
                      ScaffoldMessenger.of(dialogContext).showSnackBar(
                        const SnackBar(content: Text('السعر غير صالح.')),
                      );
                      return;
                    }

                    final parsedStock = int.tryParse(baseStockCtrl.text.trim());

                    result = {
                      'unit': unitCtrl.text.trim().isNotEmpty
                          ? unitCtrl.text.trim()
                          : 'حبة',
                      'price': parsedPrice,
                      'stock': parsedStock,
                      'colors': selectedColors.toList(),
                      'sizes': selectedSizes.toList(),
                      'dyn': {
                        for (final e in selectedDyn.entries)
                          e.key: e.value.toList(),
                      },
                    };
                    Navigator.of(dialogContext).pop();
                  },
                  child: const Text('توليد المتغيرات'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == null) return;

    final String unit = result!['unit'] as String;
    final double price = result!['price'] as double;
    final int? stock = result!['stock'] as int?;
    final List<String> selectedColorsList =
        (result!['colors'] as List).cast<String>();
    final List<String> selectedSizesList =
        (result!['sizes'] as List).cast<String>();

    final Map<String, List<String>> dynSelected = {};
    if (result!['dyn'] is Map) {
      final m = Map<String, dynamic>.from(result!['dyn'] as Map);
      for (final e in m.entries) {
        if (e.value is List) {
          dynSelected[e.key.toString()] = (e.value as List)
              .map((x) => x.toString())
              .where((x) => x.trim().isNotEmpty)
              .toList();
        }
      }
    }

    // إذا لم يتم اختيار أي لون أو مقاس، نستخدم قيمة فارغة كي لا نمنع التوليد.
    final colorsToUse =
        selectedColorsList.isEmpty ? <String>[''] : selectedColorsList;
    final sizesToUse =
        selectedSizesList.isEmpty ? <String>[''] : selectedSizesList;

    // تجنّب إنشاء صفوف مكررة بنفس (لون + مقاس + وحدة).
    final existingKeys = <String>{};
    for (final row in _variantRows) {
      final key =
          '${row.colorCtrl.text.trim()}|${row.sizeCtrl.text.trim()}|${row.unitCtrl.text.trim()}';
      existingKeys.add(key);
    }

    setState(() {
      // مولد جديد: إذا في خيارات ديناميكية مختارة، نستخدمها لعمل combinations
      final dynEntries = dynSelected.entries
          .where((e) => e.key.trim().isNotEmpty && e.value.isNotEmpty)
          .toList();

      List<Map<String, String>> combinations = <Map<String, String>>[{}];
      for (final e in dynEntries) {
        final next = <Map<String, String>>[];
        for (final combo in combinations) {
          for (final v in e.value) {
            final c = Map<String, String>.from(combo);
            c[e.key] = v;
            next.add(c);
          }
        }
        combinations = next;
        if (combinations.length > 200) {
          combinations = combinations.take(200).toList();
          break;
        }
      }

      // fallback: إذا لا يوجد dyn combinations، نستخدم القديم colors x sizes
      if (combinations.length == 1 && combinations.first.isEmpty) {
        combinations = <Map<String, String>>[];
        for (final color in colorsToUse) {
          for (final size in sizesToUse) {
            combinations.add({
              if (color.trim().isNotEmpty) 'color': color.trim(),
              if (size.trim().isNotEmpty) 'size': size.trim(),
            });
          }
        }
      }

      for (final combo in combinations) {
        final color = combo['color'] ?? '';
        final size = combo['size'] ?? '';

        final key = '${color.trim()}|${size.trim()}|$unit|${combo.entries.map((e) => '${e.key}:${e.value}').join(',')}';
        if (existingKeys.contains(key)) continue;

        final newRow = _VariantRow.empty(defaultUnit: unit);
        if (color.trim().isNotEmpty) newRow.colorCtrl.text = color.trim();
        if (size.trim().isNotEmpty) newRow.sizeCtrl.text = size.trim();
        newRow.priceCtrl.text = price.toStringAsFixed(2);
        if (_inventoryPolicy == 'track_qty' && stock != null) {
          newRow.stockCtrl.text = stock.toString();
        }

        // أي مفاتيح غير color/size تحفظ في attributes
        for (final e in combo.entries) {
          if (e.key == 'color' || e.key == 'size') continue;
          if (e.key.trim().isEmpty || e.value.trim().isEmpty) continue;
          newRow.attributes[e.key] = e.value;
        }

        _variantRows.add(newRow);
        existingKeys.add(key);
      }
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('تم توليد ${_variantRows.length} متغير/متغيرات.'),
      ),
    );
  }

  String _getCategoryName(String cat) {
    switch (cat) {
      case 'bedding':
        return 'مفارش';
      case 'mattresses':
        return 'فرشات';
      case 'pillows':
        return 'وسائد';
      case 'furniture':
        return 'أثاث';
      case 'dining_table':
        return 'سفرة';
      case 'carpets':
        return 'سجاد';
      case 'baby_supplies':
        return 'أطفال';
      case 'home_decor':
        return 'ديكور';
      case 'towels':
        return 'مناشف';
      default:
        return cat;
    }
  }
}

class _EditorButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _EditorButton(
      {required this.label, required this.icon, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return InkWell(
        onTap: onTap,
        child: Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.grey[400]!)),
            child: Row(children: [
              Icon(icon, size: 14, color: const Color(0xFF0A2647)),
              const SizedBox(width: 4),
              Text(label,
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0A2647)))
            ])));
  }
}

class _ImageWrapper {
  final String id;
  Uint8List? localBytes;
  String? serverUrl;
  String fileExtension;
  String colorName;
  Color colorValue;
  final TextEditingController colorNameCtrl;
  bool colorNameManuallyEdited = false;

  _ImageWrapper({
    String? id,
    this.localBytes,
    this.serverUrl,
    this.fileExtension = 'jpg',
    this.colorName = '',
    this.colorValue = Colors.grey,
  })  : id = id ?? DateTime.now().microsecondsSinceEpoch.toString(),
        colorNameCtrl = TextEditingController(text: colorName);

  void dispose() {
    colorNameCtrl.dispose();
  }
}

class _DynamicOptionRow {
  final TextEditingController nameCtrl;
  final TextEditingController valueInputCtrl;
  final List<String> values;

  _DynamicOptionRow({
    required this.nameCtrl,
    required this.valueInputCtrl,
    required this.values,
  });

  factory _DynamicOptionRow.empty() {
    return _DynamicOptionRow(
      nameCtrl: TextEditingController(),
      valueInputCtrl: TextEditingController(),
      values: <String>[],
    );
  }

  factory _DynamicOptionRow.fromJson(Map<String, dynamic> json) {
    final rawValues = json['values'];
    final parsedValues = rawValues is List
        ? rawValues.map((e) => e.toString()).where((e) => e.trim().isNotEmpty).toList()
        : <String>[];
    return _DynamicOptionRow(
      nameCtrl: TextEditingController(text: json['name']?.toString() ?? ''),
      valueInputCtrl: TextEditingController(),
      values: parsedValues,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': nameCtrl.text.trim(),
      'values': values,
    };
  }

  void dispose() {
    nameCtrl.dispose();
    valueInputCtrl.dispose();
  }
}

/// كلاس مساعد لإدارة حقول المتغير في شاشة المنتج
class _VariantRow {
  final String id;
  final TextEditingController colorCtrl;
  final TextEditingController sizeCtrl;
  final TextEditingController unitCtrl;
  final TextEditingController priceCtrl;
  final TextEditingController stockCtrl;
  final TextEditingController skuCtrl;
  final Map<String, String> attributes;
  _ImageWrapper? variantImage;

  _VariantRow({
    required this.id,
    required this.colorCtrl,
    required this.sizeCtrl,
    required this.unitCtrl,
    required this.priceCtrl,
    required this.stockCtrl,
    required this.skuCtrl,
    required this.attributes,
    this.variantImage,
  });

  factory _VariantRow.empty({String? defaultUnit}) {
    return _VariantRow(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      colorCtrl: TextEditingController(),
      sizeCtrl: TextEditingController(),
      unitCtrl: TextEditingController(text: defaultUnit ?? 'حبة'),
      priceCtrl: TextEditingController(),
      stockCtrl: TextEditingController(),
      skuCtrl: TextEditingController(),
      attributes: <String, String>{},
    );
  }

  factory _VariantRow.fromVariant(ProductVariant v) {
    return _VariantRow(
      id: v.id,
      colorCtrl: TextEditingController(text: v.color ?? ''),
      sizeCtrl: TextEditingController(text: v.size ?? ''),
      unitCtrl: TextEditingController(text: v.unit ?? ''),
      priceCtrl: TextEditingController(text: v.price.toString()),
      stockCtrl: TextEditingController(text: v.stock?.toString() ?? ''),
      skuCtrl: TextEditingController(text: v.sku ?? ''),
      attributes: Map<String, String>.from(v.attributes),
      variantImage:
          (v.imageUrl != null && v.imageUrl!.trim().isNotEmpty)
              ? _ImageWrapper(serverUrl: v.imageUrl)
              : null,
    );
  }

  bool get isCompletelyEmpty =>
      colorCtrl.text.trim().isEmpty &&
      sizeCtrl.text.trim().isEmpty &&
      unitCtrl.text.trim().isEmpty &&
      priceCtrl.text.trim().isEmpty &&
      stockCtrl.text.trim().isEmpty &&
      skuCtrl.text.trim().isEmpty &&
      variantImage == null &&
      attributes.isEmpty;

  void dispose() {
    colorCtrl.dispose();
    sizeCtrl.dispose();
    unitCtrl.dispose();
    priceCtrl.dispose();
    stockCtrl.dispose();
    skuCtrl.dispose();
  }
}

/// صف بسيط لتسعير الفرشات يدوياً حسب العرض.
class _MattressWidthPriceRow {
  final int widthCm;
  final TextEditingController priceCtrl;

  _MattressWidthPriceRow({required this.widthCm, double? price})
      : priceCtrl = TextEditingController(
          text: price != null ? price.toStringAsFixed(2) : '',
        );

  void dispose() {
    priceCtrl.dispose();
  }
}
