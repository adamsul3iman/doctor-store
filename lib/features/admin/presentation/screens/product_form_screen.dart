import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:flex_color_picker/flex_color_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:doctor_store/features/product/domain/models/product_model.dart';
import 'package:doctor_store/shared/utils/categories_provider.dart';
import 'package:doctor_store/shared/utils/image_compressor.dart';
import 'package:doctor_store/shared/widgets/image_shimmer_placeholder.dart';

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

  final _titleController = TextEditingController();
  final _slugController = TextEditingController();
  final _descController = TextEditingController();
  final _priceController = TextEditingController();
  final _oldPriceController = TextEditingController();

  String _selectedCategory = 'bedding';
  String? _selectedSubCategoryId;
  bool _isFeatured = false;
  bool _isFlashDeal = false; // ✅
  bool _isLoading = false;

  bool _isLoadingSubCategories = false;
  List<Map<String, dynamic>> _subCategories = [];

  // ✅ نوع المنتج / وضع التسعير
  bool _isOfferMode = false;
  bool _useAdvancedVariants =
      false; // لتفعيل إدارة المتغيرات (لون + مقاس + وحدة + سعر)

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

  // إعدادات تسعير بالوحدة/المتر
  final TextEditingController _unitLabelCtrl =
      TextEditingController(text: 'حبة');
  final TextEditingController _unitMinCtrl = TextEditingController(text: '1');
  final TextEditingController _unitStepCtrl = TextEditingController(text: '1');

  // المتغيرات المتقدمة في واجهة الأدمن
  final List<_VariantRow> _variantRows = [];

  _ImageWrapper? _mainImage;
  List<_ImageWrapper> _galleryImages = [];

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
    _sizeInputCtrl.dispose();
    _unitLabelCtrl.dispose();
    _unitMinCtrl.dispose();
    _unitStepCtrl.dispose();
    for (final v in _variantRows) {
      v.dispose();
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

        setState(() {
          _galleryImages.addAll(newImages);
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تعذر معالجة الصورة، حاول مرة أخرى. (تفاصيل تقنية: $e)'),
        ),
      );
    }
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
    setState(() => _galleryImages[index].colorValue = newColor);
  }

  Future<void> _saveProduct() async {
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

    setState(() => _isLoading = true);
    final supabase = Supabase.instance.client;

    try {
      String mainImageUrl = _mainImage!.serverUrl ?? '';
      if (_mainImage!.localBytes != null) {
        final path =
            'products/main_${DateTime.now().millisecondsSinceEpoch}.${_mainImage!.fileExtension}';
        await supabase.storage
            .from('products')
            .uploadBinary(path, _mainImage!.localBytes!);
        mainImageUrl = supabase.storage.from('products').getPublicUrl(path);
      }

      List<Map<String, dynamic>> galleryData = [];
      List<String> colorsList = [];

      for (var img in _galleryImages) {
        String url = img.serverUrl ?? '';
        if (img.localBytes != null) {
          final path =
              'products/gallery_${DateTime.now().millisecondsSinceEpoch}_${_galleryImages.indexOf(img)}.${img.fileExtension}';
          await supabase.storage
              .from('products')
              .uploadBinary(path, img.localBytes!);
          url = supabase.storage.from('products').getPublicUrl(path);
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
            'price': price,
            if (row.stockCtrl.text.trim().isNotEmpty)
              'stock': int.tryParse(row.stockCtrl.text.trim()) ?? 0,
          });
        }
      }

      // تحديد نوع المنتج لحفظه في options
      String productType = 'standard';
      if (_isOfferMode) {
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
        'image_url': mainImageUrl,
        'is_featured': _isFeatured,
        'is_flash_deal': _isFlashDeal,
        'gallery': galleryData,
        'options': {
          'sizes': _sizes,
          'colors': colorsList,
          'is_offer': _isOfferMode,
          'price_tiers': _isOfferMode ? tiersData : null,
          'product_type': productType,
          'pricing_unit': _unitLabelCtrl.text.trim().isNotEmpty
              ? _unitLabelCtrl.text.trim()
              : 'حبة',
          'unit_min': double.tryParse(_unitMinCtrl.text.trim()) ?? 1,
          'unit_step': double.tryParse(_unitStepCtrl.text.trim()) ?? 1,
        },
      };

      // إذا كانت المتغيرات المتقدمة مفعّلة وهناك بيانات، نضيف حقل variants ديناميكياً
      if (_useAdvancedVariants && variantsPayload.isNotEmpty) {
        productData['variants'] = variantsPayload;
      }

      if (productToEdit != null) {
        await supabase
            .from('products')
            .update(productData)
            .eq('id', productToEdit!.id);
      } else {
        await supabase.from('products').insert(productData);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("تم حفظ المنتج بنجاح! ✅")));
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

              _buildBasicInfoCard(remoteCategories),
              const SizedBox(height: 16),

              // عرض بطاقة السعر أو العروض بناءً على الاختيار
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: _isOfferMode ? _buildOffersCard() : _buildPricingCard(),
              ),

              const SizedBox(height: 16),
              _buildMediaCard(),
              const SizedBox(height: 16),
              _buildOptionsCard(),
              const SizedBox(height: 16),
              _buildVariantsCard(),
              const SizedBox(height: 30),
            ],
          ),
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
          Row(
            children: [
              _buildSelectorOption(
                "منتج فردي (Standard)",
                Icons.shopping_bag_outlined,
                false,
              ),
              _buildSelectorOption(
                "عروض توفير (Bundles)",
                Icons.layers_outlined,
                true,
              ),
            ],
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

  Widget _buildSelectorOption(String title, IconData icon, bool isOffer) {
    final isSelected = _isOfferMode == isOffer;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          // فقط إذا كنا نضيف منتج جديد نسمح بالتغيير بحرية
          // إذا كان تعديل، نفضل عدم التغيير الجذري إلا بحذر، لكن سأتركه متاحاً
          setState(() => _isOfferMode = isOffer);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF0A2647) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 18,
                  color: isSelected ? Colors.white : Colors.grey[600]),
              const SizedBox(width: 8),
              Text(title,
                  style: TextStyle(
                      color: isSelected ? Colors.white : Colors.grey[600],
                      fontWeight: FontWeight.bold,
                      fontSize: 13)),
            ],
          ),
        ),
      ),
    );
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
                Text("نظام العروض (Bundles)",
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
            const Text("📝 المعلومات الأساسية",
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
                  decoration: const InputDecoration(
                    labelText: "القسم",
                    prefixIcon: Icon(Icons.category),
                    border: OutlineInputBorder(),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  items: items,
                  onChanged: (v) {
                    if (v == null) return;
                    // عند تغيير الفئة الرئيسية، نلغي اختيار الفئة الفرعية السابقة
                    setState(() {
                      _selectedCategory = v;
                      _selectedSubCategoryId = null;
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
                        child: Text(sub['name'] as String? ?? ''),
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
            SwitchListTile(
              title: const Text("منتج مميز (Featured)"),
              subtitle: const Text("يظهر في الشريط العلوي"),
              value: _isFeatured,
              onChanged: (v) => setState(() => _isFeatured = v),
            ),
            SwitchListTile(
              title: const Text("⚡ عرض فلاش (Flash Deal)"),
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
            const Text("📸 الصور والألوان",
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
                            : CachedNetworkImage(
                                imageUrl: _mainImage!.serverUrl!,
                                fit: BoxFit.cover,
                                memCacheHeight: 600,
                                placeholder: (context, url) =>
                                    const ShimmerImagePlaceholder(),
                                errorWidget: (context, url, error) => const Icon(
                                  Icons.image_not_supported_outlined,
                                  color: Colors.grey,
                                ),
                              )),
              ),
            ),
            const SizedBox(height: 20),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text("المعرض والألوان:", style: TextStyle(fontSize: 12)),
              TextButton.icon(
                  onPressed: () => _pickImage(false),
                  icon: const Icon(Icons.add_photo_alternate),
                  label: const Text("إضافة صورة"))
            ]),
            ..._galleryImages.asMap().entries.map((entry) {
              final index = entry.key;
              final img = entry.value;
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(8)),
                child: Row(
                  children: [
                    SizedBox(
                        width: 60,
                        height: 60,
                        child: img.localBytes != null
                            ? Image.memory(
                                img.localBytes!,
                                fit: BoxFit.cover,
                              )
                            : CachedNetworkImage(
                                imageUrl: img.serverUrl!,
                                fit: BoxFit.cover,
                                memCacheHeight: 300,
                                placeholder: (context, url) =>
                                    const ShimmerImagePlaceholder(),
                                errorWidget: (context, url, error) => const Icon(
                                  Icons.image_not_supported_outlined,
                                  color: Colors.grey,
                                ),
                              )),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("اللون المرتبط:",
                              style: TextStyle(fontSize: 10)),
                          Row(
                            children: [
                              SizedBox(
                                  width: 100,
                                  child: TextField(
                                      controller: TextEditingController(
                                          text: img.colorName),
                                      onChanged: (v) => img.colorName = v,
                                      decoration: const InputDecoration(
                                          hintText: "اسم اللون",
                                          isDense: true))),
                              const SizedBox(width: 10),
                              GestureDetector(
                                onTap: () => _showColorPicker(index),
                                child: Container(
                                  width: 30,
                                  height: 30,
                                  decoration: BoxDecoration(
                                      color: img.colorValue,
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.grey)),
                                ),
                              ),
                            ],
                          )
                        ],
                      ),
                    ),
                    IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () =>
                            setState(() => _galleryImages.removeAt(index)))
                  ],
                ),
              );
            }),
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
          children: [
            const Text("📏 المقاسات (أساسية)",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const Divider(),
            const Align(
              alignment: Alignment.centerRight,
              child: Text(
                "تُستخدم هذه المقاسات في تصفية المنتجات وتوليد المتغيرات تلقائياً.",
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _sizeInputCtrl,
                    decoration: const InputDecoration(
                      hintText: "أضف مقاس (مثلاً 200x200)",
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle, color: Color(0xFF0A2647)),
                  onPressed: () {
                    if (_sizeInputCtrl.text.isNotEmpty) {
                      setState(() {
                        _sizes.add(_sizeInputCtrl.text);
                        _sizeInputCtrl.clear();
                      });
                    }
                  },
                ),
              ],
            ),
            Wrap(
              spacing: 8,
              children: _sizes
                  .map((size) => Chip(
                        label: Text(size),
                        onDeleted: () => setState(() => _sizes.remove(size)),
                      ))
                  .toList(),
            ),
          ],
        ),
      ),
    );
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
                const Text(
                  "المتغيرات المتقدمة (لون + مقاس + وحدة + سعر)",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const Spacer(),
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
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: row.priceCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: "السعر",
                              prefixIcon: Icon(Icons.attach_money, size: 16),
                              isDense: true,
                            ),
                          ),
                        ),
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
                        const SizedBox(width: 6),
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

    // استنتاج الألوان المتاحة من صور المعرض
    final availableColors = _galleryImages
        .map((img) => img.colorName.trim())
        .where((name) => name.isNotEmpty)
        .toSet()
        .toList();

    // المقاسات المتاحة من بطاقة المقاسات الأساسية
    final availableSizes = List<String>.from(_sizes);

    if (availableColors.isEmpty && availableSizes.isEmpty) {
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
      for (final color in colorsToUse) {
        for (final size in sizesToUse) {
          final key = '${color.trim()}|${size.trim()}|$unit';
          if (existingKeys.contains(key)) continue;

          final newRow = _VariantRow.empty(defaultUnit: unit);
          newRow.colorCtrl.text = color.trim();
          newRow.sizeCtrl.text = size.trim();
          newRow.priceCtrl.text = price.toStringAsFixed(2);
          if (stock != null) {
            newRow.stockCtrl.text = stock.toString();
          }

          _variantRows.add(newRow);
          existingKeys.add(key);
        }
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
  Uint8List? localBytes;
  String? serverUrl;
  String fileExtension;
  String colorName;
  Color colorValue;
  _ImageWrapper(
      {this.localBytes,
      this.serverUrl,
      this.fileExtension = 'jpg',
      this.colorName = '',
      this.colorValue = Colors.grey});
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

  _VariantRow({
    required this.id,
    required this.colorCtrl,
    required this.sizeCtrl,
    required this.unitCtrl,
    required this.priceCtrl,
    required this.stockCtrl,
    required this.skuCtrl,
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
    );
  }

  bool get isCompletelyEmpty =>
      colorCtrl.text.trim().isEmpty &&
      sizeCtrl.text.trim().isEmpty &&
      unitCtrl.text.trim().isEmpty &&
      priceCtrl.text.trim().isEmpty &&
      stockCtrl.text.trim().isEmpty &&
      skuCtrl.text.trim().isEmpty;

  void dispose() {
    colorCtrl.dispose();
    sizeCtrl.dispose();
    unitCtrl.dispose();
    priceCtrl.dispose();
    stockCtrl.dispose();
    skuCtrl.dispose();
  }
}
