import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

// الموديلات والخدمات
import 'package:doctor_store/features/product/domain/models/product_model.dart';
import 'package:doctor_store/features/cart/application/cart_manager.dart';
import 'package:doctor_store/shared/utils/settings_provider.dart';
import 'package:doctor_store/shared/utils/seo_manager.dart';
import 'package:doctor_store/providers/products_provider.dart';
import 'package:doctor_store/shared/utils/image_url_helper.dart';
import 'package:doctor_store/shared/utils/app_notifier.dart';
import 'package:doctor_store/shared/utils/product_nav_helper.dart';
import 'package:doctor_store/shared/utils/link_share_helper.dart';
import 'package:doctor_store/shared/utils/analytics_service.dart';
import 'package:doctor_store/shared/widgets/custom_app_bar.dart';
import 'package:doctor_store/shared/utils/categories_provider.dart';
import 'package:doctor_store/features/product/presentation/widgets/product_search_delegate.dart';

// الويدجت (Widgets)
import '../widgets/similar_products_section.dart';
import '../widgets/product_poster_dialog.dart';
import '../widgets/reviews_section.dart';
import '../widgets/smart_description.dart';
import '../widgets/quick_checkout_sheet.dart';
import '../widgets/product_bottom_bar.dart';
import 'package:doctor_store/shared/widgets/app_footer.dart';

class ProductDetailsScreen extends ConsumerStatefulWidget {
  final Product product;
  const ProductDetailsScreen({super.key, required this.product});

  @override
  ConsumerState<ProductDetailsScreen> createState() => _ProductDetailsScreenState();
}

class _ProductDetailsScreenState extends ConsumerState<ProductDetailsScreen> {
  String? _selectedColor;
  String? _selectedSize;
  int _quantity = 1;
  int _currentImageIndex = 0;
  late PageController _pageController;
  List<String> _displayImages = [];

  // المتغير النشط وفقاً لاختيارات العميل
  ProductVariant? _selectedVariant;
  late final List<ProductVariant> _variants;

  /// تمثيل سطر طلب واحد لنفس هذا المنتج (لون + مقاس + كمية + سعر وحدة)
  /// يستخدم لبناء "سلة هذا المنتج" داخل صفحة التفاصيل قبل الإرسال للسلة العامة أو الطلب السريع.
  final List<_VariantOrderLine> _orderLines = [];

  bool get _hasOrderLines => _orderLines.isNotEmpty;

  /// إجمالي القطع في كل الأسطر المضافة لسلة هذا المنتج
  int get _orderLinesTotalQuantity =>
      _orderLines.fold<int>(0, (sum, line) => sum + line.quantity);

  /// إجمالي السعر (بدون توصيل) لكل الأسطر المضافة لسلة هذا المنتج
  double get _orderLinesTotalPrice => _orderLines.fold<double>(
        0,
        (sum, line) => sum + (line.unitPrice * line.quantity),
      );

  // ألوان الهوية
  final Color _primaryDark = const Color(0xFF0A2647);
  final Color _accentOrange = Colors.orange.shade800;

  bool get _hasColors {
    final colors = widget.product.options['colors'];
    return colors is List && colors.isNotEmpty;
  }

  bool get _hasSizes {
    final sizes = widget.product.options['sizes'];
    return sizes is List && sizes.isNotEmpty;
  }

  @override
  void initState() {
    super.initState();
    _pageController = PageController();

    // تهيئة قائمة المتغيرات لمرة واحدة وتحسين الأداء
    _variants = List<ProductVariant>.from(widget.product.variants);

    // إعداد SEO مرة واحدة فقط بدلاً من استدعائه في كل build لتحسين الأداء خاصة على الويب
    SeoManager.setProductSeo(widget.product);

    // تتبع مشاهدة صفحة المنتج
    AnalyticsService.instance.trackEvent('product_view', props: {
      'id': widget.product.id,
      'title': widget.product.title,
      'category': widget.product.category,
    });
    
    final Set<String> uniqueImages = {};
    uniqueImages.add(widget.product.originalImageUrl);
    if (widget.product.gallery.isNotEmpty) {
      uniqueImages.addAll(widget.product.gallery.map((e) => e.url));
    }
    _displayImages = uniqueImages.toList();

    // اختيار تلقائي إذا كان خياراً واحداً من الألوان/المقاسات العادية
    if (_hasColors) {
      final colors = List<String>.from(widget.product.options['colors']);
      if (colors.length == 1) _selectedColor = colors.first;
    }
    if (_hasSizes) {
      final sizes = List<String>.from(widget.product.options['sizes']);
      if (sizes.length == 1) _selectedSize = sizes.first;
    }

    // إذا كان هناك متغير واحد فقط، نعتبره المتغير الافتراضي
    if (_variants.length == 1) {
      _selectedVariant = _variants.first;
      _selectedColor ??= _selectedVariant!.color;
      _selectedSize ??= _selectedVariant!.size;
    } else if (_variants.isNotEmpty) {
      _updateSelectedVariant();
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  /// اسم القسم النهائي بعد دمج بيانات جدول الأقسام مع fallback من الموديل
  // ignore: unused_element
  String get _resolvedCategoryName {
    final catsAsync = ref.watch(categoriesConfigProvider);
    final cats = catsAsync.asData?.value;
    if (cats != null) {
      for (final c in cats) {
        if (c.id == widget.product.category && c.name.trim().isNotEmpty) {
          return c.name.trim();
        }
      }
    }
    return widget.product.categoryArabic;
  }

  Future<bool> _ensureSelection() async {
    // لو لم يتم اختيار اللون أو المقاس نفتح Bottom Sheet موحد يعرضهما معاً
    final needsColor = _hasColors && _selectedColor == null;
    final needsSize = _hasSizes && _selectedSize == null;

    if (needsColor || needsSize) {
      final confirmed = await _showOptionsSheet();
      if (!confirmed) return false;
    }

    // تحقق نهائي بعد الإغلاق (في حال المستخدم أغلق بدون اختيار كامل)
    if (_hasColors && _selectedColor == null) {
      _showError("الرجاء اختيار اللون قبل المتابعة.");
      return false;
    }
    if (_hasSizes && _selectedSize == null) {
      _showError("الرجاء اختيار المقاس قبل المتابعة.");
      return false;
    }

    // إذا كان هناك متغيرات متقدمة، نحاول التأكد من وجود متغير مطابق
    if (_variants.isNotEmpty) {
      _updateSelectedVariant();
      if (_selectedVariant == null) {
        _showError("هذا الخيار غير متوفر حالياً، جرّب لوناً أو مقاساً مختلفاً.");
        return false;
      }
      // التحقق من توفر المخزون لهذا المتغير
      final stock = _selectedVariant!.stock;
      if (stock != null && _quantity > stock) {
        _showError("الكمية المطلوبة أكبر من المتوفر حالياً ($stock ${widget.product.pricingUnitLabel})، قلّل الكمية أو تواصل معنا.");
        return false;
      }
    }
    return true;
  }

  void _showError(String message) {
    if (!mounted) return;
    AppNotifier.showError(context, message);
  }

  // ignore: unused_element
  void _showColorSelectionDialog() {
    final colors = List<String>.from(widget.product.options['colors']);
    
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _primaryDark.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.palette_outlined,
                      color: _primaryDark,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "اختر اللون المناسب",
                          style: GoogleFonts.almarai(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: _primaryDark,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "الرجاء اختيار لون المنتج للمتابعة",
                          style: GoogleFonts.almarai(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 20),
              
              // Color Options
              Wrap(
                spacing: 16,
                runSpacing: 16,
                alignment: WrapAlignment.center,
                children: colors.asMap().entries.map((entry) {
                  final index = entry.key;
                  final String colorName = entry.value.toString();
                  final color = _resolveColorSwatch(colorName, index);
                  final bool isSelected = _selectedColor == colorName;
                  
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        final willSelect = !isSelected;
                        _selectedColor = willSelect ? colorName : null;
                        if (willSelect) {
                          _scrollToColorImage(colorName);
                        }
                        _updateSelectedVariant();
                      });
                      Navigator.of(ctx).pop();
                    },
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected ? _primaryDark : Colors.grey.shade300,
                              width: isSelected ? 2.5 : 1.5,
                            ),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: _primaryDark.withValues(alpha: 0.25),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ]
                                : [
                                    BoxShadow(
                                      color: color.withValues(alpha: 0.25),
                                      blurRadius: 8,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                          ),
                          child: Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: color,
                            ),
                            child: isSelected
                                ? const Icon(
                                    Icons.check,
                                    size: 24,
                                    color: Colors.white,
                                  )
                                : null,
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: 80,
                          child: Text(
                            colorName,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.almarai(
                              fontSize: 12,
                              color: isSelected ? _primaryDark : Colors.grey.shade700,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
              
              const SizedBox(height: 24),
              
              // Close button
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                child: Text(
                  "إلغاء",
                  style: GoogleFonts.almarai(
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ignore: unused_element
  void _showSizeSelectionDialog() {
    final sizes = List<String>.from(widget.product.options['sizes']);
    
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _primaryDark.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.straighten,
                      color: _primaryDark,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "اختر المقاس المناسب",
                          style: GoogleFonts.almarai(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: _primaryDark,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "الرجاء اختيار مقاس المنتج للمتابعة",
                          style: GoogleFonts.almarai(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 20),
              
              // Size Options
              Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.center,
                children: sizes.map((sizeName) {
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedSize = sizeName;
                        _updateSelectedVariant();
                      });
                      Navigator.of(ctx).pop();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 16,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _primaryDark.withValues(alpha: 0.3),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: _primaryDark.withValues(alpha: 0.08),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        sizeName,
                        style: GoogleFonts.almarai(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: _primaryDark,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              
              const SizedBox(height: 24),
              
              // Close button
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                child: Text(
                  "إلغاء",
                  style: GoogleFonts.almarai(
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// نافذة وسط الشاشة لاختيار اللون والمقاس قبل الشراء أو الإضافة للسلة
  Future<bool> _showOptionsSheet() async {
    return await showDialog<bool>(
          context: context,
          barrierDismissible: true,
          barrierColor: Colors.black.withValues(alpha: 0.55),
          builder: (ctx) {
            final size = MediaQuery.of(ctx).size;
            return Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: 520,
                  maxHeight: size.height * 0.85,
                ),
                child: Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  elevation: 20,
                  child: StatefulBuilder(
                    builder:
                        (BuildContext context, StateSetter setModalState) {
                      return ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.tune,
                                      color: Colors.black87),
                                  const SizedBox(width: 8),
                                  Text(
                                    'اختر اللون والمقاس',
                                    style: GoogleFonts.almarai(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const Spacer(),
                                  IconButton(
                                    icon: const Icon(Icons.close),
                                    onPressed: () =>
                                        Navigator.of(ctx).pop(false),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),

                              if (_hasColors)
                                _buildSelectionSection(
                                  title: "اختر اللون",
                                  options: widget.product.options['colors'],
                                  isColor: true,
                                  showPreviewImage: true,
                                  modalSetState: setModalState,
                                ),
                              if (_hasSizes)
                                _buildSelectionSection(
                                  title: "اختر المقاس",
                                  options: widget.product.options['sizes'],
                                  isColor: false,
                                  modalSetState: setModalState,
                                ),

                              const SizedBox(height: 16),

                              // اختيار الكمية المطلوبة داخل نفس الشاشة (مع تحديث فوري داخل النافذة)
                              _buildQuantitySection(modalSetState: setModalState),

                              const SizedBox(height: 10),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: () {
                                    final okColor =
                                        !_hasColors || _selectedColor != null;
                                    final okSize =
                                        !_hasSizes || _selectedSize != null;
                                    if (okColor && okSize) {
                                      Navigator.of(ctx).pop(true);
                                    } else {
                                      AppNotifier.showError(
                                        ctx,
                                        'يرجى اختيار اللون والمقاس أولاً',
                                      );
                                    }
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _primaryDark,
                                    foregroundColor: Colors.white,
                                    padding:
                                        const EdgeInsets.symmetric(vertical: 14),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: Text(
                                    'متابعة',
                                    style: GoogleFonts.almarai(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            );
          },
        ) ??
        false;
  }

  double get _currentTotal {
    // أولوية لعروض البكجات للحفاظ على التوافق مع البيانات القديمة
    if (widget.product.hasOffers) {
      try {
        final offer = widget.product.offerTiers.firstWhere((tier) => tier.quantity == _quantity);
        return offer.price;
      } catch (e) {
        return widget.product.price * _quantity;
      }
    }

    final unitPrice = _selectedVariant?.price ?? widget.product.price;
    return unitPrice * _quantity;
  }

  bool get _isActiveOffer {
    if (!widget.product.hasOffers) return false;
    return widget.product.offerTiers.any((tier) => tier.quantity == _quantity);
  }

  double get _effectiveUnitPrice {
    if (_isActiveOffer) {
      return _currentTotal / _quantity;
    }
    return _selectedVariant?.price ?? widget.product.price;
  }

  String _getPreviewImageUrlForColor(String? colorName) {
    if (colorName != null && widget.product.gallery.isNotEmpty) {
      final target = colorName.toLowerCase().trim();
      final matchingIndex = widget.product.gallery.indexWhere(
        (img) => img.colorName.toLowerCase().trim() == target,
      );
      if (matchingIndex != -1) {
        return widget.product.gallery[matchingIndex].url;
      }
    }
    // افتراضي: الصورة الرئيسية للمنتج إن لم نجد صورة خاصة باللون
    return widget.product.originalImageUrl;
  }

  void _scrollToColorImage(String colorName) {
    final matchingImageIndex = widget.product.gallery.indexWhere((img) => img.colorName == colorName);
    if (matchingImageIndex != -1) {
      final url = widget.product.gallery[matchingImageIndex].url;
      final actualIndex = _displayImages.indexOf(url);
      if (actualIndex != -1) {
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted && _pageController.hasClients) {
            _pageController.animateToPage(actualIndex, duration: const Duration(milliseconds: 600), curve: Curves.easeInOutCubic);
          }
        });
      }
    }
  }

  Future<void> _showCheckoutSheet(String storePhone) async {
    if (!mounted) return;

    // في حال وجود أسطر في "سلة هذا المنتج" نستخدمها لبناء طلب متعدد العناصر
    if (_hasOrderLines) {
      final totalQuantity = _orderLinesTotalQuantity;
      final productsTotal = _orderLinesTotalPrice;

      AnalyticsService.instance.trackEvent('checkout_start', props: {
        'source': 'product_page',
        'mode': 'multi',
        'product_id': widget.product.id,
        'lines_count': _orderLines.length,
        'total_quantity': totalQuantity,
        'total': productsTotal,
      });

      final lines = _orderLines
          .map(
            (line) => QuickCheckoutLine(
              color: line.color,
              size: line.size,
              quantity: line.quantity,
              unitPrice: line.unitPrice,
            ),
          )
          .toList();

      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => QuickCheckoutSheet(
          product: widget.product,
          quantity: totalQuantity,
          selectedColor: null,
          selectedSize: null,
          storePhone: storePhone,
          unitPrice: widget.product.price,
          isMulti: true,
          lines: lines,
        ),
      );

      // بعد إتمام الطلب السريع يمكن تفريغ سلة هذا المنتج المحلية
      if (mounted) {
        setState(() {
          _orderLines.clear();
        });
      }
      return;
    }

    // السلوك القديم: اختيار واحد
    if (!await _ensureSelection()) return;
    if (!mounted) return;
    final unitPrice = _effectiveUnitPrice;

    AnalyticsService.instance.trackEvent('checkout_start', props: {
      'source': 'product_page',
      'mode': 'single',
      'product_id': widget.product.id,
      'quantity': _quantity,
      'color': _selectedColor,
      'size': _selectedSize,
      'unit_price': unitPrice,
      'total': _currentTotal,
    });

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => QuickCheckoutSheet(
        product: widget.product,
        quantity: _quantity,
        selectedColor: _selectedColor,
        selectedSize: _selectedSize,
        storePhone: storePhone,
        unitPrice: unitPrice,
      ),
    );
  }

  Future<void> _shareProduct() async {
    // نشارك رابط صفحة المنتج الرسمي مع نص مختصر احترافي
    final path = buildProductDetailsPath(widget.product);
    final short = widget.product.shortDescription;

    await shareAppPage(
      path: path,
      title: widget.product.title,
      message: (short != null && short.isNotEmpty)
          ? short
          : 'شاهد هذا المنتج من متجر الدكتور.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final liveProductAsync =
        ref.watch(productByIdStreamProvider(widget.product.id));
    final settingsAsync = ref.watch(settingsProvider);
    final cartNotifier = ref.read(cartProvider.notifier);

    // ضبط ارتفاع معرض الصور بما يتناسب مع ارتفاع الشاشة حتى لا يملأ الشاشة بالكامل
    final screenHeight = MediaQuery.of(context).size.height;
    final double galleryHeight = screenHeight > 820
        ? 430
        : screenHeight * 0.55; // على الشاشات الصغيرة يقل الارتفاع تلقائياً

    // في حال حدوث أي خطأ في الـ Stream نستخدم نسخة المنتج الممررة من الراوتر
    final currentProduct = liveProductAsync.maybeWhen(
      data: (p) => p ?? widget.product,
      orElse: () => widget.product,
    );

    // مزامنة عدد المشاهدات من جدول الأحداث (يشمل الضيوف وغير المسجلين)
    final viewsAsync = ref.watch(productViewsProvider(currentProduct.id));
 
    return Title(
      title: 'Doctor Store | ${currentProduct.title}',
      color: Colors.black,
      child: Scaffold(
        backgroundColor: Colors.white,
        bottomNavigationBar: settingsAsync.when(
          data: (settings) => ProductBottomBar(
            price: _currentTotal,
            quantity: _quantity,
            unitLabel: widget.product.pricingUnitLabel,
            onAddToCart: () => _handleAddToCart(cartNotifier),
            onBuyNow: () => _showCheckoutSheet(settings.whatsapp),
            onShare: _shareProduct,
          ),
          loading: () => const SizedBox.shrink(),
          error: (_,__) => const SizedBox.shrink(),
        ),
        body: CustomScrollView(
        slivers: [
          // ================= App Bar & Image Gallery =================
          SliverAppBar(
            backgroundColor: _primaryDark,
            expandedHeight: galleryHeight,
            pinned: true,
            automaticallyImplyLeading: false,
            centerTitle: true,
            title: CustomAppBarContent(
              isHome: false,
              centerWidget: const Text(
                'تفاصيل المنتج',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              showSearch: true,
              onSearchTap: () => showSearch(
                context: context,
                delegate: ProductSearchDelegate(),
              ),
              onShareTap: () => showDialog(
                context: context,
                builder: (_) => ProductPosterDialog(product: widget.product),
              ),
              iconColor: Colors.white,
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                alignment: Alignment.bottomCenter,
                children: [
                  PageView.builder(
                    controller: _pageController,
                    itemCount: _displayImages.length,
                    onPageChanged: (index) =>
                        setState(() => _currentImageIndex = index),
                    itemBuilder: (context, index) {
                      final imageUrl = _displayImages[index];
                      return GestureDetector(
                        onTap: () => _openFullScreenGallery(index),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Hero(
                              tag: 'product_${widget.product.id}_image_$index',
                              child: CachedNetworkImage(
                                // في عرض صفحة المنتج نستخدم نسخة تفاصيل (fullScreen)
                                // تعتمد على عرض 800px مع resize=contain عبر Supabase.
                                imageUrl: buildOptimizedImageUrl(
                                  imageUrl,
                                  variant: ImageVariant.fullScreen,
                                ),
                                fit: BoxFit.cover,
                                memCacheHeight: 900,
                                placeholder: (c, u) => Container(color: Colors.grey[100]),
                                errorWidget: (c, u, e) => const Icon(
                                  Icons.broken_image,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                            // طبقة تدرّج خفيفة لتحسين وضوح الأيقونات والنصوص
                            Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.black.withValues(alpha: 0.15),
                                    Colors.transparent,
                                    Colors.black.withValues(alpha: 0.35),
                                  ],
                                  stops: const [0.0, 0.5, 1.0],
                                ),
                              ),
                            ),
                            // شارات ترويجية أعلى الصورة
                            Positioned(
                              right: 16,
                              top: 60,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  if (widget.product.isFeatured)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 8.0),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withValues(alpha: 0.45),
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: Text(
                                          "منتج مختار بعناية",
                                          style: GoogleFonts.almarai(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 11),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  if (_displayImages.length > 1)
                    Positioned(
                      bottom: 18,
                      left: 0,
                      right: 0,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children:
                            List.generate(_displayImages.length, (index) {
                          final isActive = index == _currentImageIndex;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            width: isActive ? 16 : 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: isActive
                                  ? Colors.white
                                  : Colors.white.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          );
                        }),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // ================= Product Info Body =================
          SliverToBoxAdapter(
            child: Container(
              decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
              transform: Matrix4.translationValues(0, -25, 0),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeaderSection(viewsAsync),
                  const SizedBox(height: 25),
                  
                  if (currentProduct.hasOffers) ...[
                    _buildOffersSection(),
                    const SizedBox(height: 30),
                  ],

                  const SizedBox(height: 24),

                  _buildTrustSignals(),
                  const SizedBox(height: 16),

                  // قسم مساعدة قبل الشراء عبر الواتساب لزيادة الثقة والتحويل
                  settingsAsync.maybeWhen(
                    data: (settings) => _buildWhatsappHelpSection(settings.whatsapp),
                    orElse: () => const SizedBox.shrink(),
                  ),
                  const SizedBox(height: 30),
                  
                  const Divider(color: Colors.grey),
                  const SizedBox(height: 20),

                  // المواصفات
                  ExpansionTile(
                    title: AutoSizeText(
                      "المواصفات الفنية",
                      maxLines: 1,
                      minFontSize: 12,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.almarai(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: _primaryDark,
                      ),
                    ),
                    tilePadding: EdgeInsets.zero,
                    childrenPadding: const EdgeInsets.only(bottom: 20),
                    children: [
                      _buildSpecRow("القسم", currentProduct.categoryArabic),
                      _buildSpecRow("حالة المنتج", "أصلي 100%"),
                      if (_hasColors)
                        _buildSpecRow(
                          "الألوان المتوفرة",
                          (currentProduct.options['colors'] as List).join('، '),
                        ),
                    ],
                  ),
                  const Divider(color: Colors.grey),

                  // الوصف
                  ExpansionTile(
                    title: AutoSizeText(
                      "تفاصيل المنتج",
                      maxLines: 1,
                      minFontSize: 12,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.almarai(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: _primaryDark,
                      ),
                    ),
                    initiallyExpanded: true,
                    tilePadding: EdgeInsets.zero,
                    children: [
                      SmartDescription(description: currentProduct.description),
                    ],
                  ),
                  
                  const SizedBox(height: 40),
                  
                  ReviewsSection(
                    productId: currentProduct.id,
                    averageRating: currentProduct.ratingAverage,
                    ratingCount: currentProduct.ratingCount,
                  ),
                  
                  const SizedBox(height: 40),
                  
                  // ✅ قسم المنتجات المشابهة بمظهر غني أكثر
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.recommend_outlined, size: 22, color: Color(0xFF0A2647)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: AutoSizeText(
                                "قد يعجبك أيضاً",
                                maxLines: 1,
                                minFontSize: 14,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.almarai(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: _primaryDark,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "منتجات مختارة من نفس القسم لتكملة أناقة غرفتك.",
                          style: GoogleFonts.almarai(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 14),
                        SimilarProductsSection(
                          categoryId: widget.product.category,
                          currentProductId: widget.product.id,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 40),

                  // Footer موحّد أسفل صفحة المنتج
                  const AppFooter(),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
  }

  // ================= Helper Widgets =================
 
  Widget _buildHeaderSection(AsyncValue<int> viewsAsync) {
    final hasShortDescription = widget.product.shortDescription?.isNotEmpty == true;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // السطر الأول: فئة المنتج + شارات الحالة (منتج مميز / جديد)
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildCategoryChip(),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.product.isFeatured)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _accentOrange.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      "منتج مميز",
                      style: GoogleFonts.almarai(
                        color: _accentOrange,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ),
                if (widget.product.ratingCount == 0) ...[
                  if (widget.product.isFeatured) const SizedBox(width: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      "منتج جديد",
                      style: GoogleFonts.almarai(
                        color: Colors.blue.shade700,
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),

        const SizedBox(height: 8),

        // عنوان المنتج بعرض الصفحة بالكامل
        AutoSizeText(
          widget.product.title,
          maxLines: 3,
          minFontSize: 12,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.almarai(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            height: 1.4,
            color: _primaryDark,
          ),
        ),

        const SizedBox(height: 6),

        // التقييم + عدد المشاهدات في سطر واحد بشكل مضغوط
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            if (widget.product.ratingCount > 0)
              Row(
                children: [
                  const Icon(Icons.star_rounded,
                      color: Color(0xFFD4AF37), size: 18),
                  const SizedBox(width: 4),
                  Text(
                    widget.product.ratingAverage.toStringAsFixed(1),
                    style: GoogleFonts.almarai(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: _primaryDark,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    "(${widget.product.ratingCount} تقييم)",
                    style: GoogleFonts.almarai(
                      fontSize: 11,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              )
            else
              Text(
                "منتج جديد – كن أول من يجرّبه",
                style: GoogleFonts.almarai(
                  fontSize: 11,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
            viewsAsync.when(
              data: (count) => Row(
                children: [
                  const Icon(
                    Icons.remove_red_eye_outlined,
                    size: 16,
                    color: Colors.grey,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '$count مشاهدة',
                    style: GoogleFonts.almarai(
                      fontSize: 11,
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),
          ],
        ),

        const SizedBox(height: 10),

        // السعر بشكل مختصر واحترافي
        _buildInlinePriceRow(),

        const SizedBox(height: 10),

        // اختيار سريع للّون والمقاس تحت العنوان
        _buildCompactVariantRow(),
        const SizedBox(height: 6),

        // الكمية المطلوبة أسفل خيارات اللون مباشرة بشكل مدمج
        _buildQuantitySection(),
        const SizedBox(height: 8),

        // صور مصغّرة لمنتجات مقترحة من نفس القسم
        InlineSimilarProductsStrip(
          categoryId: widget.product.category,
          currentProductId: widget.product.id,
        ),
        const SizedBox(height: 6),

        if (_isActiveOffer)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Row(
              children: [
                const Icon(Icons.local_offer_rounded,
                    color: Colors.green, size: 18),
                const SizedBox(width: 5),
                Text(
                  "تم تطبيق سعر العرض الخاص 🔥",
                  style: TextStyle(
                    color: Colors.green.shade700,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

        if (hasShortDescription) ...[
          const SizedBox(height: 14),
          Text(
            widget.product.shortDescription!,
            style: GoogleFonts.almarai(
              fontSize: 14,
              height: 1.6,
              color: Colors.grey.shade800,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildInlinePriceRow() {
    final isMattress = widget.product.category == 'mattresses';

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  "$_currentTotal",
                  style: GoogleFonts.almarai(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color:
                        _isActiveOffer ? Colors.green.shade700 : _primaryDark,
                  ),
                ),
                const SizedBox(width: 3),
                Text(
                  "د.أ",
                  style: GoogleFonts.almarai(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade700,
                  ),
                ),
              ],
            ),
            if (widget.product.oldPrice != null && !_isActiveOffer)
              Text(
                "${widget.product.oldPrice} د.أ",
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade500,
                  fontWeight: FontWeight.w600,
                  decoration: TextDecoration.lineThrough,
                ),
              ),
          ],
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isMattress ? Icons.bed : Icons.verified_user,
              size: 16,
              color: Colors.green,
            ),
            const SizedBox(width: 4),
            Text(
              isMattress
                  ? "تجربة مريحة وضمان استبدال للعيوب"
                  : "ضمان جودة واستبدال للعيوب المصنعية",
              style: GoogleFonts.almarai(
                fontSize: 10,
                color: Colors.green.shade800,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// شريط صغير أسفل العنوان لعرض خيارات اللون والمقاس بشكل أنيق
  Widget _buildCompactVariantRow() {
    final List<String> colors =
        _hasColors ? List<String>.from(widget.product.options['colors']) : const [];
    final List<String> sizes =
        _hasSizes ? List<String>.from(widget.product.options['sizes']) : const [];

    if (colors.isEmpty && sizes.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (colors.isNotEmpty)
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                'اللون:',
                style: GoogleFonts.almarai(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: _primaryDark,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: colors.asMap().entries.map((entry) {
                      final index = entry.key;
                      final String optionStr = entry.value.toString();
                      final bool isSelected = _selectedColor == optionStr;
                      final color = _resolveColorSwatch(optionStr, index);

                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            final willSelect = !isSelected;
                            _selectedColor = willSelect ? optionStr : null;
                            if (willSelect) _scrollToColorImage(optionStr);
                            _updateSelectedVariant();
                          });
                        },
                        child: Padding(
                          padding: const EdgeInsetsDirectional.only(end: 8.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                padding: const EdgeInsets.all(2.5),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isSelected ? _primaryDark : Colors.grey.shade300,
                                    width: isSelected ? 2 : 1.2,
                                  ),
                                ),
                                child: Container(
                                  width: 20,
                                  height: 20,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: color,
                                  ),
                                  child: isSelected
                                      ? const Icon(
                                          Icons.check,
                                          size: 14,
                                          color: Colors.white,
                                        )
                                      : null,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
              if (_selectedColor != null)
                Padding(
                  padding: const EdgeInsetsDirectional.only(start: 6.0),
                  child: Text(
                    _selectedColor!,
                    style: GoogleFonts.almarai(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ),
            ],
          ),
        if (sizes.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  'المقاس:',
                  style: GoogleFonts.almarai(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: _primaryDark,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: sizes.map((s) {
                        final isSelected = _selectedSize == s;
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedSize = isSelected ? null : s;
                              _updateSelectedVariant();
                            });
                          },
                          child: Container(
                            margin: const EdgeInsetsDirectional.only(end: 6.0),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: isSelected ? _primaryDark : Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: isSelected ? _primaryDark : Colors.grey.shade300,
                                width: 1,
                              ),
                            ),
                            child: Text(
                              s,
                              style: GoogleFonts.almarai(
                                fontSize: 11,
                                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                color: isSelected ? Colors.white : _primaryDark,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildHeaderPriceBlock() {
    final isMattress = widget.product.category == 'mattresses';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.star_rounded,
                    color: Color(0xFFD4AF37), size: 18),
                const SizedBox(width: 4),
                Text(
                  widget.product.ratingAverage.toStringAsFixed(1),
                  style: GoogleFonts.almarai(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: _primaryDark,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  "(${widget.product.ratingCount} تقييم)",
                  style: GoogleFonts.almarai(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          const SizedBox(height: 6),

          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                "$_currentTotal",
                style: GoogleFonts.almarai(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color:
                      _isActiveOffer ? Colors.green.shade700 : _primaryDark,
                ),
              ),
              const SizedBox(width: 2),
              Text(
                "د.أ",
                style: GoogleFonts.almarai(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade700,
                ),
              ),
            ],
          ),

          if (widget.product.oldPrice != null && !_isActiveOffer)
            Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  "${widget.product.oldPrice} د.أ",
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade500,
                    fontWeight: FontWeight.w600,
                    decoration: TextDecoration.lineThrough,
                    decorationStyle: TextDecorationStyle.solid,
                    decorationThickness: 2,
                    decorationColor: Colors.grey,
                  ),
                ),
              ),
            ),

          const SizedBox(height: 4),

          // رسالة ضمان مبسطة داخل بطاقة السعر
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isMattress ? Icons.bed : Icons.verified_user,
                size: 16,
                color: Colors.green,
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  isMattress
                      ? "تجربة مريحة وضمان استبدال للعيوب"
                      : "ضمان جودة واستبدال للعيوب المصنعية",
                  style: GoogleFonts.almarai(
                    fontSize: 10,
                    color: Colors.green.shade800,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.end,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChip() {
    // نحاول أولاً قراءة إعدادات القسم من جدول الأقسام الديناميكي
    final catsAsync = ref.watch(categoriesConfigProvider);
    Color color = const Color(0xFF0A2647);
    String name = widget.product.categoryArabic;

    final cats = catsAsync.asData?.value;
    if (cats != null) {
      for (final c in cats) {
        if (c.id == widget.product.category) {
          if (c.name.trim().isNotEmpty) name = c.name.trim();
          color = c.color;
          break;
        }
      }
    }

    final visuals = _getCategoryVisuals(widget.product.category, fallbackColor: color);

    return InkWell(
      onTap: () => context.push(
        '/category/${widget.product.category}',
        extra: {
          'name': name,
          'color': visuals.color,
        },
      ),
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: visuals.color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: visuals.color.withValues(alpha: 0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(visuals.icon, size: 16, color: visuals.color),
            const SizedBox(width: 6),
            Text(
              name,
              style: GoogleFonts.almarai(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: visuals.color,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_left, size: 16, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  _CategoryVisual _getCategoryVisuals(String categoryId, {required Color fallbackColor}) {
    switch (categoryId) {
      case 'bedding':
        return const _CategoryVisual(FontAwesomeIcons.bed, Color(0xFF5C6BC0));
      case 'mattresses':
        return const _CategoryVisual(FontAwesomeIcons.layerGroup, Color(0xFF00897B));
      case 'pillows':
        return const _CategoryVisual(FontAwesomeIcons.cloudMoon, Color(0xFF26C6DA));
      case 'furniture':
        return const _CategoryVisual(FontAwesomeIcons.couch, Color(0xFF8D6E63));
      case 'dining_table':
        return const _CategoryVisual(FontAwesomeIcons.utensils, Color(0xFFF57C00));
      case 'carpets':
        return const _CategoryVisual(FontAwesomeIcons.rug, Color(0xFFAB47BC));
      case 'baby_supplies':
        return const _CategoryVisual(FontAwesomeIcons.baby, Color(0xFF42A5F5));
      case 'home_decor':
        return const _CategoryVisual(FontAwesomeIcons.bahai, Color(0xFFD4AF37));
      default:
        // للأقسام الجديدة نستخدم أيقونة عامة لكن مع اللون القادم من لوحة التحكم
        return _CategoryVisual(Icons.category, fallbackColor);
    }
  }

  Widget _buildOffersSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "عروض التوفير الحصرية",
          style: GoogleFonts.almarai(
            fontWeight: FontWeight.w800,
            fontSize: 18,
            color: _primaryDark,
          ),
        ),
        const SizedBox(height: 15),
        SizedBox(
          height: 130, // ارتفاع أكبر لمنع BOTTOM OVERFLOWED
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            itemCount: widget.product.offerTiers.length,
            itemBuilder: (context, index) {
              final tier = widget.product.offerTiers[index];
              final isSelected = _quantity == tier.quantity;
              final regularPrice = widget.product.price * tier.quantity;
              final saving = regularPrice - tier.price;

              return GestureDetector(
                onTap: () => setState(() => _quantity = tier.quantity),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 150,
                  margin: const EdgeInsets.only(right: 15),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected ? _primaryDark : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: isSelected ? _primaryDark : Colors.grey.shade200, width: 2),
                    // ✅ تحديث withValues
                    boxShadow: isSelected ? [BoxShadow(color: _primaryDark.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 6))] : [BoxShadow(color: Colors.grey.withValues(alpha: 0.1), blurRadius: 5, offset: const Offset(0, 2))],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        "${tier.quantity} قطع",
                        style: GoogleFonts.almarai(
                          color: isSelected ? Colors.white70 : Colors.black54,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "${tier.price} د.أ",
                        style: GoogleFonts.almarai(
                          color: isSelected ? Colors.white : _primaryDark,
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                        ),
                      ),
                      if (saving > 0)
                        Container(
                          margin: const EdgeInsets.only(top: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(color: _accentOrange, borderRadius: BorderRadius.circular(20)),
                          child: Text("وفر $saving د.أ", style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
                        )
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSelectionSection({
    required String title,
    required List<dynamic> options,
    required bool isColor,
    bool showPreviewImage = false,
    StateSetter? modalSetState,
  }) {
    final selectedValue = isColor ? _selectedColor : _selectedSize;

    // صورة معاينة للون مختارة (تستخدم فقط داخل BottomSheet عند showPreviewImage = true)
    Widget? previewImageWidget;
    if (isColor && showPreviewImage) {
      final previewUrl = _getPreviewImageUrlForColor(_selectedColor);
      previewImageWidget = Container(
        margin: const EdgeInsets.only(bottom: 8),
        height: 80,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Colors.grey.shade100,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: AspectRatio(
            aspectRatio: 4 / 3,
            child: CachedNetworkImage(
              imageUrl: buildOptimizedImageUrl(
                previewUrl,
                variant: ImageVariant.fullScreen,
              ),
              fit: BoxFit.cover,
              memCacheHeight: 500,
              placeholder: (context, url) => Container(color: Colors.grey[200]),
              errorWidget: (context, url, error) => const Icon(
                Icons.image_not_supported_outlined,
                color: Colors.grey,
              ),
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (previewImageWidget != null) previewImageWidget,
        Row(
          children: [
            Text(
              title,
              style: GoogleFonts.almarai(
                fontWeight: FontWeight.w800,
                fontSize: 18,
                color: _primaryDark,
              ),
            ),
            const SizedBox(width: 8),
            if (isColor && _selectedColor != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _selectedColor!,
                  style: GoogleFonts.almarai(fontSize: 12, color: Colors.grey.shade800, fontWeight: FontWeight.w600),
                ),
              ),
            if (selectedValue == null)
              Text(
                " * (مطلوب)",
                style: GoogleFonts.almarai(
                  color: Colors.redAccent,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
          ],
        ),
        if (isColor)
          Padding(
            padding: const EdgeInsets.only(top: 4.0),
            child: Text(
              "اضغط على اللون لاستعراض صورته والاختيار",
              style: GoogleFonts.almarai(fontSize: 11, color: Colors.grey.shade600),
            ),
          ),
        const SizedBox(height: 14),

        if (isColor)
          Wrap(
            spacing: 12,
            runSpacing: 14,
            children: options.asMap().entries.map((entry) {
              final index = entry.key;
              final String optionStr = entry.value.toString();
              final isSelected = selectedValue == optionStr;
              final color = _resolveColorSwatch(optionStr, index);

              return GestureDetector(
                onTap: () {
                  setState(() {
                    final willSelect = !isSelected;
                    _selectedColor = willSelect ? optionStr : null;
                    if (willSelect) _scrollToColorImage(optionStr);
                    _updateSelectedVariant();
                  });
                  // إعادة بناء الواجهة داخل الـ BottomSheet أيضاً
                  if (modalSetState != null) {
                    modalSetState(() {});
                  }
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? _primaryDark : Colors.grey.shade300,
                          width: isSelected ? 2 : 1.2,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: _primaryDark.withValues(alpha: 0.25),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ]
                            : null,
                      ),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: color,
                        ),
                        child: isSelected
                            ? const Icon(
                                Icons.check,
                                size: 18,
                                color: Colors.white,
                              )
                            : null,
                      ),
                    ),
                    const SizedBox(height: 6),
                    SizedBox(
                      width: 64,
                      child: Text(
                        optionStr,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.almarai(
                          fontSize: 11,
                          color: isSelected ? _primaryDark : Colors.grey.shade700,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          )
        else
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: options.map((o) {
              final String optionStr = o.toString();
              final isSelected = selectedValue == optionStr;
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedSize = isSelected ? null : optionStr;
                    _updateSelectedVariant();
                  });
                  if (modalSetState != null) {
                    modalSetState(() {});
                  }
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected ? _primaryDark : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected ? _primaryDark : Colors.grey.shade300,
                      width: 1.4,
                    ),
                  ),
                  child: Text(
                    optionStr,
                    style: GoogleFonts.almarai(
                      color: isSelected ? Colors.white : _primaryDark,
                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),

        const SizedBox(height: 26),
      ],
    );
  }

  void _updateSelectedVariant() {
    if (_variants.isEmpty) {
      _selectedVariant = null;
      return;
    }
    _selectedVariant = widget.product.findMatchingVariant(
      color: _selectedColor,
      size: _selectedSize,
      unit: null,
    );
  }

  Widget _buildQuantitySection({StateSetter? modalSetState}) {
    final unitLabel = widget.product.pricingUnitLabel;
    final int? stock = _selectedVariant?.stock;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              "الكمية المطلوبة ($unitLabel)",
              style: GoogleFonts.almarai(
                fontWeight: FontWeight.w700,
                fontSize: 15,
                color: _primaryDark,
              ),
            ),
            const Spacer(),
            Container(
              height: 36,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Row(
                children: [
                  _buildQtySmallButton(
                    icon: Icons.remove,
                    color: Colors.grey,
                    onTap: () {
                      if (_quantity > 1) {
                        setState(() => _quantity--);
                        if (modalSetState != null) {
                          modalSetState(() {});
                        }
                      }
                    },
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      "$_quantity",
                      style: GoogleFonts.almarai(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: _primaryDark,
                      ),
                    ),
                  ),
                  _buildQtySmallButton(
                    icon: Icons.add,
                    color: _primaryDark,
                    onTap: () {
                      setState(() {
                        if (stock == null || _quantity < stock) {
                          _quantity++;
                          if (modalSetState != null) {
                            modalSetState(() {});
                          }
                        }
                      });
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
        if (stock != null)
          Padding(
            padding: const EdgeInsets.only(top: 6.0),
            child: Text(
              stock > 0
                  ? "المتوفر في المخزون لهذا الاختيار: $stock $unitLabel"
                  : "هذا الاختيار غير متوفر حالياً في المخزون",
              style: GoogleFonts.almarai(
                fontSize: 12,
                color: stock > 0 ? Colors.green.shade700 : Colors.red.shade700,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _handleAddToCart(CartNotifier cartNotifier) async {
    // في حال لم يكن لدى المستخدم أسطر مخصصة، نستخدم السلوك القديم (اختيار واحد)
    if (!_hasOrderLines) {
      if (!await _ensureSelection()) return;

      cartNotifier.addItem(
        widget.product,
        quantity: _quantity,
        selectedColor: _selectedColor,
        selectedSize: _selectedSize,
        variantPrice: _effectiveUnitPrice,
      );

      AnalyticsService.instance.trackEvent('add_to_cart', props: {
        'product_id': widget.product.id,
        'mode': 'single',
        'quantity': _quantity,
        'color': _selectedColor,
        'size': _selectedSize,
        'unit_price': _effectiveUnitPrice,
        'total': _currentTotal,
      });
    } else {
      // في حال وجود أسطر في "سلة هذا المنتج" نضيف كل سطر كعنصر مستقل في السلة
      for (final line in _orderLines) {
        cartNotifier.addItem(
          widget.product,
          quantity: line.quantity,
          selectedColor: line.color,
          selectedSize: line.size,
          variantPrice: line.unitPrice,
        );
      }

      AnalyticsService.instance.trackEvent(
        'add_multiple_variants_to_cart',
        props: {
          'product_id': widget.product.id,
          'lines_count': _orderLines.length,
          'total_quantity': _orderLinesTotalQuantity,
          'total_price': _orderLinesTotalPrice,
        },
      );

      // بعد نقل الأسطر إلى السلة العامة يمكن تفريغ السلة المحلية للمنتج
      setState(() {
        _orderLines.clear();
      });
    }

    if (mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(children: [Icon(Icons.check_circle, color: Colors.white), SizedBox(width: 8), Text("تمت الإضافة للسلة بنجاح", style: TextStyle(fontWeight: FontWeight.bold))]),
          behavior: SnackBarBehavior.floating,
          backgroundColor: _primaryDark,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(20),
          action: SnackBarAction(label: "للسلة", onPressed: () => context.push('/cart'), textColor: Colors.orangeAccent),
        ),
      );
    }
  }

  Widget _buildQtySmallButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: SizedBox(
        width: 32,
        height: 32,
        child: Center(
          child: Icon(
            icon,
            size: 18,
            color: color,
          ),
        ),
      ),
    );
  }

  Widget _buildTrustSignals() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 340;

        final items = [
          _buildTrustItem(FontAwesomeIcons.shieldHalved, "ضمان الجودة", "منتجات أصلية 100%"),
          _buildTrustItem(FontAwesomeIcons.truckFast, "شحن سريع", "توصيل آمن لباب بيتك"),
          _buildTrustItem(FontAwesomeIcons.headset, "دعم متواصل", "خدمة عملاء على مدار الساعة"),
        ];

        return Container(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 15),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "لماذا تختار متجر الدكتور؟",
                style: GoogleFonts.almarai(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  color: _primaryDark,
                ),
              ),
              const SizedBox(height: 10),
              if (isNarrow)
                Wrap(
                  spacing: 16,
                  runSpacing: 12,
                  alignment: WrapAlignment.spaceAround,
                  children: items,
                )
              else
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: items,
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTrustItem(IconData icon, String title, String subtitle) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: _primaryDark.withValues(alpha: 0.8), size: 24),
        const SizedBox(height: 8),
        Text(
          title,
          style: GoogleFonts.almarai(
            fontWeight: FontWeight.w800,
            fontSize: 12,
            color: _primaryDark,
          ),
        ),
        const SizedBox(height: 4),
        SizedBox(
          width: 90,
          child: Text(
            subtitle,
            style: GoogleFonts.almarai(
              fontSize: 10,
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  void _openProductLocalBasketSheet() {
    if (!_hasColors && !_hasSizes) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
            top: 16,
            right: 16,
            left: 16,
          ),
          child: SingleChildScrollView(
            child: _buildProductLocalBasketSection(),
          ),
        );
      },
    );
  }

  /// قسم "سلة هذا المنتج" الذي يسمح بإضافة عدة ألوان/مقاسات في نفس الطلب
  Widget _buildProductLocalBasketSection() {
    if (!_hasColors && !_hasSizes) {
      // لو لم يكن للمنتج ألوان أو مقاسات، لا داعي لعرض هذا القسم
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.shopping_basket_outlined,
                  size: 18, color: Colors.black87),
              const SizedBox(width: 6),
              Text(
                'سلة هذا المنتج',
                style: GoogleFonts.almarai(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  color: _primaryDark,
                ),
              ),
              const Spacer(),
              if (_hasOrderLines)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _primaryDark.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${_orderLines.length} اختيار',
                    style: GoogleFonts.almarai(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: _primaryDark,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'يمكنك هنا إضافة أكثر من لون أو مقاس لنفس المنتج ضمن نفس الطلب قبل الإضافة للسلة أو الطلب السريع.',
            style: GoogleFonts.almarai(
              fontSize: 11,
              color: Colors.grey.shade700,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              onPressed: () async {
                if (!await _ensureSelection()) return;

                final unitPrice = _effectiveUnitPrice;
                final line = _VariantOrderLine(
                  color: _selectedColor,
                  size: _selectedSize,
                  quantity: _quantity,
                  unitPrice: unitPrice,
                );

                setState(() {
                  _orderLines.add(line);
                  // بعد إضافة السطر نعيد الكمية إلى 1 لتسهيل إضافة لون/مقاس آخر
                  _quantity = 1;
                });

                AnalyticsService.instance.trackEvent(
                  'product_local_basket_add_line',
                  props: {
                    'product_id': widget.product.id,
                    'color': line.color,
                    'size': line.size,
                    'quantity': line.quantity,
                    'unit_price': line.unitPrice,
                  },
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: _primaryDark,
                elevation: 0,
                side: BorderSide(color: Colors.grey.shade300),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              icon: const Icon(Icons.add_circle_outline, size: 18),
              label: Text(
                'إضافة هذا الاختيار إلى طلب هذا المنتج',
                style: GoogleFonts.almarai(fontSize: 11),
              ),
            ),
          ),
          if (_hasOrderLines) ...[
            const SizedBox(height: 8),
            Divider(color: Colors.grey.shade300, height: 16),
            Column(
              children: [
                for (int i = 0; i < _orderLines.length; i++)
                  _buildOrderLineRow(_orderLines[i], index: i),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'إجمالي سلة هذا المنتج:',
                  style: GoogleFonts.almarai(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade800,
                  ),
                ),
                Text(
                  '$_orderLinesTotalQuantity ${widget.product.pricingUnitLabel} • ${_orderLinesTotalPrice.toStringAsFixed(1)} د.أ',
                  style: GoogleFonts.almarai(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: _primaryDark,
                  ),
                ),
              ],
            ),
            if (_orderLines.length >= 2)
              Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Text(
                  'ملاحظة: عند الإضافة للسلة أو الطلب السريع سيتم استخدام كل هذه الاختيارات معاً.',
                  style: GoogleFonts.almarai(
                    fontSize: 10,
                    color: Colors.grey.shade600,
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildOrderLineRow(_VariantOrderLine line, {required int index}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (line.color != null) ...[
                      const Icon(Icons.palette_outlined,
                          size: 14, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(
                        line.color!,
                        style: GoogleFonts.almarai(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    if (line.size != null) ...[
                      if (line.color != null) const SizedBox(width: 10),
                      const Icon(Icons.straighten,
                          size: 14, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(
                        line.size!,
                        style: GoogleFonts.almarai(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${line.quantity} ${widget.product.pricingUnitLabel} • ${(line.unitPrice * line.quantity).toStringAsFixed(1)} د.أ',
                  style: GoogleFonts.almarai(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: _primaryDark,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'إزالة هذا السطر',
            icon: const Icon(Icons.delete_outline, size: 18),
            color: Colors.red.shade400,
            onPressed: () {
              setState(() {
                _orderLines.removeAt(index);
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSpecRow(String key, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(key, style: const TextStyle(color: Colors.grey)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
        ],
      ),
    );
  }

  /// قسم خاص بالاستفسار عن المنتج عبر الواتساب مع رسالة جاهزة
  Widget _buildWhatsappHelpSection(String storePhone) {
    if (storePhone.trim().isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF81C784)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "تحتاج مساعدة قبل الشراء؟",
            style: GoogleFonts.almarai(
              fontWeight: FontWeight.w800,
              fontSize: 14,
              color: _primaryDark,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            "فريق خدمة العملاء جاهز لمساعدتك في اختيار المقاس واللون الأنسب لك قبل تأكيد الطلب.",
            style: GoogleFonts.almarai(
              fontSize: 12,
              color: Colors.grey.shade800,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _launchWhatsAppProductHelp(storePhone),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF25D366),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const FaIcon(FontAwesomeIcons.whatsapp, size: 18),
              label: Text(
                "اسألنا عن هذا المنتج عبر واتساب",
                style: GoogleFonts.almarai(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _launchWhatsAppProductHelp(String storePhone) async {
    final phone = storePhone.trim();
    if (phone.isEmpty) {
      if (!mounted) return;
      AppNotifier.showError(context, 'خدمة الواتساب غير متاحة حالياً. حاول مرة أخرى لاحقاً.');
      return;
    }

    final colorText = _hasColors
        ? (_selectedColor ?? 'لم أحدد بعد')
        : 'غير متوفر';
    final sizeText = _hasSizes
        ? (_selectedSize ?? 'لم أحدد بعد')
        : 'غير متوفر';

    // رابط المنتج الكامل للاستخدام داخل رسالة الواتساب
    final productUrl = buildFullProductUrl(widget.product);

    final buffer = StringBuffer();
    buffer.writeln('مرحباً، لدي استفسار قبل الشراء عن هذا المنتج من متجر الدكتور:');
    buffer.writeln('• الاسم: ${widget.product.title}');
    buffer.writeln('• القسم: ${widget.product.categoryArabic}');
    buffer.writeln('• رابط المنتج: $productUrl');
    if (_hasColors) {
      buffer.writeln('• اللون المختار: $colorText');
    }
    if (_hasSizes) {
      buffer.writeln('• المقاس المختار: $sizeText');
    }
    buffer.writeln('• الكمية: $_quantity ${widget.product.pricingUnitLabel}');
    buffer.writeln('');
    buffer.writeln('أرغب بمساعدتكم في اختيار الأنسب وتأكيد تفاصيل الطلب، وشكراً لكم.');

    final encoded = Uri.encodeComponent(buffer.toString());
    final url = Uri.parse('https://wa.me/$phone?text=$encoded');

    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (!mounted) return;
      AppNotifier.showError(context, 'تعذر فتح الواتساب على هذا الجهاز.');
    }
  }

  void _openFullScreenGallery(int initialIndex) {
    if (_displayImages.isEmpty) return;

    final safeInitial = initialIndex.clamp(0, _displayImages.length - 1);
    // نستخدم رقم صفحة كبير مع modulo لخلق حلقة لا نهائية تقريباً بين الصور
    final pageController = PageController(
      initialPage: safeInitial + (_displayImages.length * 1000),
    );
    int current = safeInitial;

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.95),
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Stack(
              children: [
                // صور المعرض بكامل الشاشة مع إمكانية التكبير (بحلقة مستمرة)
                PageView.builder(
                    controller: pageController,
                    onPageChanged: (page) =>
                        setState(() => current = page % _displayImages.length),
                    itemBuilder: (context, page) {
                      final imageIndex = page % _displayImages.length;
                      final imageUrl = _displayImages[imageIndex];
                      return Center(
                        child: Hero(
                          tag: 'product_${widget.product.id}_image_$imageIndex',
                          child: InteractiveViewer(
                            panEnabled: true,
                            minScale: 0.7,
                            maxScale: 4,
                            child: CachedNetworkImage(
                              imageUrl: buildOptimizedImageUrl(
                                imageUrl,
                                variant: ImageVariant.fullScreen,
                              ),
                              fit: BoxFit.contain,
                              memCacheHeight: 1600,
                              placeholder: (context, url) => Container(
                                color: Colors.black,
                              ),
                              errorWidget: (context, url, error) => const Icon(
                                Icons.broken_image,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),

                // زر إغلاق علوي
                Positioned(
                  top: 40,
                  right: 20,
                  child: SafeArea(
                    child: CircleAvatar(
                      backgroundColor: Colors.black.withValues(alpha: 0.6),
                      child: IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ),
                  ),
                ),

                // مؤشر الصفحات بشكل كبسولة احترافية
                Positioned(
                  bottom: 26,
                  left: 0,
                  right: 0,
                  child: SafeArea(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.55),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.2),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
        "${current + 1}",
        style: GoogleFonts.almarai(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: 12,
          decoration: TextDecoration.none,
        ),
      ),
      Text(
        " / ${_displayImages.length}",
        style: GoogleFonts.almarai(
          color: Colors.white.withValues(alpha: 0.8),
          fontWeight: FontWeight.w500,
          fontSize: 11,
          decoration: TextDecoration.none,
        ),
      ),
                              const SizedBox(width: 10),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: List.generate(
                                  _displayImages.length,
                                  (index) {
                                    final isActive = index == current;
                                    return AnimatedContainer(
                                      duration: const Duration(milliseconds: 200),
                                      margin:
                                          const EdgeInsets.symmetric(horizontal: 2.5),
                                      width: isActive ? 14 : 6,
                                      height: 6,
                                      decoration: BoxDecoration(
                                        color: isActive
                                            ? Colors.white
                                            : Colors.white
                                                .withValues(alpha: 0.4),
                                        borderRadius: BorderRadius.circular(3),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Color _resolveColorSwatch(String optionStr, int index) {
    // 1) محاولة المطابقة مع صور الجاليري التي تحتوي على اسم اللون
    for (final img in widget.product.gallery) {
      if (img.colorName.toLowerCase() == optionStr.toLowerCase()) {
        try {
          return Color(img.colorValue);
        } catch (_) {
          // نتجاهل أي قيمة غير صالحة ونكمل بالمحاولات الأخرى
        }
      }
    }

    // 2) خريطة بسيطة لأسماء ألوان شائعة بالعربية والإنجليزية
    final normalized = optionStr.toLowerCase().trim();
    if (normalized.contains('أحمر') || normalized.contains('red')) return Colors.redAccent;
    if (normalized.contains('أزرق') || normalized.contains('blue')) return Colors.blueAccent;
    if (normalized.contains('أخضر') || normalized.contains('green')) return Colors.green;
    if (normalized.contains('رمادي') || normalized.contains('رمادى') || normalized.contains('gray') || normalized.contains('grey')) {
      return Colors.grey.shade500;
    }
    if (normalized.contains('أسود') || normalized.contains('black')) return Colors.black;
    if (normalized.contains('أبيض') || normalized.contains('white')) return Colors.white;
    if (normalized.contains('بيج') || normalized.contains('beige')) return const Color(0xFFF5F0E6);
    if (normalized.contains('بنفسجي') || normalized.contains('purple') || normalized.contains('موف')) {
      return Colors.purpleAccent;
    }
    if (normalized.contains('ذهبي') || normalized.contains('gold')) return const Color(0xFFD4AF37);

    // 3) ألوان افتراضية متناسقة بناءً على الترتيب (index)
    const palette = [
      Color(0xFF0A2647),
      Color(0xFF1565C0),
      Color(0xFFB71C1C),
      Color(0xFF2E7D32),
      Color(0xFF6A1B9A),
      Color(0xFF00897B),
      Color(0xFF5D4037),
    ];
    return palette[index % palette.length];
  }
}

class _CategoryVisual {
  final IconData icon;
  final Color color;

  const _CategoryVisual(this.icon, this.color);
}

/// نموذج داخلي يمثل سطر طلب واحد ضمن "سلة هذا المنتج" في صفحة التفاصيل
class _VariantOrderLine {
  final String? color;
  final String? size;
  final int quantity;
  final double unitPrice;

  const _VariantOrderLine({
    required this.color,
    required this.size,
    required this.quantity,
    required this.unitPrice,
  });
}
