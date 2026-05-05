import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:google_fonts/google_fonts.dart'; // ⚠️ REMOVED for smaller bundle
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:url_launcher/url_launcher.dart';

// الموديلات والخدمات
import 'package:doctor_store/features/product/domain/models/product_model.dart';
import 'package:doctor_store/features/cart/application/cart_manager.dart';
import 'package:doctor_store/shared/utils/settings_provider.dart';
import 'package:doctor_store/shared/utils/seo_manager.dart';
import 'package:doctor_store/features/product/presentation/providers/products_provider.dart';
import 'package:doctor_store/shared/utils/app_notifier.dart';
import 'package:doctor_store/shared/utils/product_nav_helper.dart';
import 'package:doctor_store/shared/utils/link_share_helper.dart';
import 'package:doctor_store/shared/services/analytics_service.dart';
import 'package:doctor_store/shared/services/app_review_service.dart';
import 'package:doctor_store/shared/widgets/custom_app_bar.dart';
import 'package:doctor_store/features/product/presentation/widgets/product_search_delegate.dart';

// الويدجت (Widgets)
import '../product_details/widgets/product_image_gallery.dart';
import '../product_details/widgets/product_variant_selector.dart';
// import '../widgets/product_poster_dialog.dart'; // يُحمل بشكل مؤجل عند الحاجة
import '../widgets/quick_checkout_sheet.dart';
import '../widgets/product_bottom_bar.dart';

// تحميل مؤجل للـ ProductPosterDialog لتقليل حجم البندل
import '../widgets/product_poster_dialog.dart' deferred as poster;

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
  final GlobalKey<ProductImageGalleryState> _galleryKey = GlobalKey();
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
    if (colors is List && colors.isNotEmpty) return true;
    // Also check variants for colors when using advanced variants
    if (_variants.isNotEmpty) {
      for (final v in _variants) {
        if (v.color != null && v.color!.trim().isNotEmpty) return true;
      }
    }
    return false;
  }

  bool get _hasSizes {
    final sizes = widget.product.options['sizes'];
    if (sizes is List && sizes.isNotEmpty) return true;
    // Also check variants for sizes when using advanced variants
    if (_variants.isNotEmpty) {
      for (final v in _variants) {
        // Check size field
        if (v.size != null && v.size!.trim().isNotEmpty) return true;
      }
    }
    return false;
  }

  /// Get colors list from options or variants
  List<String> _getColorsList() {
    final optionColors = widget.product.options['colors'];
    if (optionColors is List && optionColors.isNotEmpty) {
      return List<String>.from(optionColors);
    }
    // Extract from variants
    final variantColors = <String>{};
    for (final v in _variants) {
      if (v.color != null && v.color!.trim().isNotEmpty) {
        variantColors.add(v.color!);
      }
    }
    return variantColors.toList();
  }

  /// Get sizes list from options or variants
  List<String> _getSizesList() {
    final optionSizes = widget.product.options['sizes'];
    if (optionSizes is List && optionSizes.isNotEmpty) {
      return List<String>.from(optionSizes);
    }
    // Extract from variants
    final variantSizes = <String>{};
    for (final v in _variants) {
      // First check the size field
      if (v.size != null && v.size!.trim().isNotEmpty) {
        variantSizes.add(v.size!);
      }
    }
    return variantSizes.toList();
  }

  @override
  void initState() {
    super.initState();

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

    AnalyticsService.instance.trackProductView(
      productId: widget.product.id,
      categoryId: widget.product.category,
    );

    // طلب تقييم التطبيق بعد تجربة إيجابية (مشاهدة منتج)
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        AppReviewService().recordSuccessfulAction();
      }
    });
    
    final Set<String> uniqueImages = {};
    uniqueImages.add(widget.product.originalImageUrl);
    if (widget.product.gallery.isNotEmpty) {
      uniqueImages.addAll(widget.product.gallery.map((e) => e.url));
    }
    _displayImages = uniqueImages.toList();

    // اختيار تلقائي إذا كان خياراً واحداً من الألوان/المقاسات
    if (_hasColors) {
      final colors = _getColorsList();
      if (colors.length == 1) _selectedColor = colors.first;
    }
    if (_hasSizes) {
      final sizes = _getSizesList();
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
    super.dispose();
  }

  void _updateSelectedVariant() {
    final variant = widget.product.findMatchingVariant(
      color: _selectedColor,
      size: _selectedSize,
      unit: null,
    );
    if (!mounted) return;
    setState(() {
      _selectedVariant = variant;
    });
  }

  Future<void> _handleAddToCart(CartNotifier cartNotifier) async {
    if (_hasOrderLines) {
      var addedAny = false;
      for (final line in _orderLines) {
        final ok = await cartNotifier.addItem(
          widget.product,
          quantity: line.quantity,
          selectedColor: line.color,
          selectedSize: line.size,
          variantPrice: line.unitPrice,
        );
        if (ok) {
          addedAny = true;
        }
      }

      if (!mounted) return;
      if (addedAny) {
        AppNotifier.showSuccess(context, 'تمت الإضافة للسلة');
        setState(() {
          _orderLines.clear();
        });
      } else {
        AppNotifier.showError(context, 'تعذرت الإضافة للسلة (قد تكون الكمية أكبر من المخزون)');
      }
      return;
    }

    final okSelection = await _ensureSelection();
    if (!okSelection) return;

    final ok = await cartNotifier.addItem(
      widget.product,
      quantity: _quantity,
      selectedColor: _selectedColor,
      selectedSize: _selectedSize,
      variantPrice: _selectedVariant?.price,
    );

    if (!mounted) return;
    if (ok) {
      AppNotifier.showSuccess(context, 'تمت الإضافة للسلة');
    } else {
      AppNotifier.showError(context, 'تعذرت الإضافة للسلة (قد تكون الكمية أكبر من المخزون)');
    }
  }

  Widget _buildHeaderSection() {
    final currentPrice = _effectiveUnitPrice;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AutoSizeText(
          widget.product.title,
          maxLines: 2,
          minFontSize: 14,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 20,
            color: _primaryDark,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Text(
              '${currentPrice.toStringAsFixed(2)} د.أ',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: _accentOrange,
              ),
            ),
            const SizedBox(width: 10),
            if (widget.product.oldPrice != null && widget.product.oldPrice! > widget.product.price)
              Text(
                '${widget.product.oldPrice!.toStringAsFixed(2)} د.أ',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade600,
                  decoration: TextDecoration.lineThrough,
                  fontWeight: FontWeight.w700,
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildOffersSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'عروض الكمية',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 16,
            color: _primaryDark,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: widget.product.offerTiers.map((tier) {
            final isActive = _quantity == tier.quantity;
            return InkWell(
              onTap: () {
                setState(() {
                  _quantity = tier.quantity;
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isActive ? _primaryDark : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isActive ? _primaryDark : Colors.grey.shade300),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${tier.quantity} ${widget.product.pricingUnitLabel}',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        color: isActive ? Colors.white : Colors.grey.shade800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${tier.price.toStringAsFixed(2)} د.أ',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                        color: isActive ? Colors.white : _accentOrange,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildVariantOptionsSection() {
    if (!_hasColors && !_hasSizes) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ProductVariantSelector(
            product: widget.product,
            initialColor: _selectedColor,
            initialSize: _selectedSize,
            onColorChanged: (color) {
              setState(() {
                _selectedColor = color;
              });
              if (color != null) {
                _scrollToColorImage(color);
              }
              _updateSelectedVariant();
            },
            onSizeChanged: (size) {
              setState(() {
                _selectedSize = size;
              });
              _updateSelectedVariant();
            },
          ),
          if (_selectedVariant != null) ...[
            const SizedBox(height: 6),
            Text(
              '${_selectedVariant!.price.toStringAsFixed(2)} د.أ',
              style: TextStyle(
                color: _accentOrange,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTrustSignals() {
    return Row(
      children: [
        Expanded(
          child: _TrustChip(
            icon: Icons.verified,
            label: 'أصلي 100%',
            color: Colors.green.shade700,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _TrustChip(
            icon: Icons.local_shipping_outlined,
            label: 'توصيل سريع',
            color: Colors.blue.shade700,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _TrustChip(
            icon: Icons.support_agent,
            label: 'دعم واتساب',
            color: _primaryDark,
          ),
        ),
      ],
    );
  }

  Widget _buildSpecRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 13,
                color: _primaryDark,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: Colors.grey.shade800,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChip() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: _primaryDark.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          widget.product.categoryArabic,
          style: TextStyle(
            color: _primaryDark,
            fontWeight: FontWeight.w800,
            fontSize: 12,
          ),
        ),
      ),
    );
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

  /// نافذة وسط الشاشة لاختيار اللون والمقاس قبل الشراء أو الإضافة للسلة
  Future<bool> _showOptionsSheet() async {
    final result = await showDialog<VariantSelectionResult>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (ctx) => VariantSelectionDialog(
        product: widget.product,
        initialColor: _selectedColor,
        initialSize: _selectedSize,
        initialQuantity: _quantity,
      ),
    );

    if (result != null) {
      setState(() {
        _selectedColor = result.color;
        _selectedSize = result.size;
        _quantity = result.quantity;
        _selectedVariant = result.variant;
      });
      return true;
    }
    return false;
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
          if (mounted) {
            _galleryKey.currentState?.animateToImage(url);
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

      final didSubmit = await showModalBottomSheet<bool>(
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
      if (mounted && didSubmit == true) {
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

  Future<void> _showPosterDialog() async {
    // تحميل مؤجل للـ ProductPosterDialog لتقليل حجم البندل الأساسي
    await poster.loadLibrary();
    if (!mounted) return;
    
    showDialog(
      context: context,
      builder: (_) => poster.ProductPosterDialog(product: widget.product),
    );
  }

  void _launchWhatsApp() async {
    final settingsAsync = ref.read(settingsProvider);
    final phone = settingsAsync.valueOrNull?.whatsapp ?? '';
    if (phone.isEmpty) return;

    final url = 'https://wa.me/$phone';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    }
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
              onShareTap: () => _showPosterDialog(),
              iconColor: Colors.white,
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: ProductImageGallery(
                key: _galleryKey,
                productId: widget.product.id,
                imageUrls: _displayImages,
                height: galleryHeight,
                isFeatured: widget.product.isFeatured,
                onImageTap: () {
                  final currentIndex = _galleryKey.currentState?.currentIndex ?? 0;
                  showDialog(
                    context: context,
                    builder: (_) => ProductFullscreenGallery(
                      productId: widget.product.id,
                      imageUrls: _displayImages,
                      initialIndex: currentIndex,
                    ),
                  );
                },
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
                  _buildHeaderSection(),
                  const SizedBox(height: 25),
                  
                  if (currentProduct.hasOffers) ...[
                    _buildOffersSection(),
                    const SizedBox(height: 30),
                  ],

                  if (_hasColors || _hasSizes) ...[
                    _buildVariantOptionsSection(),
                    const SizedBox(height: 24),
                  ],

                  _buildTrustSignals(),
                  const SizedBox(height: 16),

                  // قسم مساعدة قبل الشراء عبر الواتساب لزيادة الثقة والتحويل
                  _WhatsAppHelpButton(onLaunch: _launchWhatsApp),
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
                      style: TextStyle(
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
                      if (currentProduct.options['colors'] is List &&
                          (currentProduct.options['colors'] as List).isNotEmpty)
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
                    ),
                    children: <Widget>[
                      _buildCategoryChip(),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (widget.product.isFeatured)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: _accentOrange.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                "منتج مميز",
                                style: TextStyle(
                                  color: _accentOrange,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          if (widget.product.ratingCount == 0) ...[
                            if (widget.product.isFeatured)
                              const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                "منتج جديد",
                                style: TextStyle(
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
                ],
              ),
            ),
          ),
          ],
        ),
      ),
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

class _ProductViewCounter extends ConsumerWidget {
  final String productId;

  const _ProductViewCounter({Key? key, required this.productId}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final viewsAsync = ref.watch(productViewsProvider(productId));

    return viewsAsync.when(
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
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

class _WhatsAppHelpButton extends ConsumerWidget {
  final VoidCallback onLaunch;

  const _WhatsAppHelpButton({Key? key, required this.onLaunch}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storePhone = ref.watch(settingsProvider).maybeWhen(
      data: (settings) => settings.whatsapp,
      orElse: () => '',
    );

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
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 14,
              color: Theme.of(context).primaryColor,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            "فريق خدمة العملاء جاهز لمساعدتك في اختيار المقاس واللون الأنسب لك قبل تأكيد الطلب.",
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade800,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onLaunch,
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
                style: TextStyle(
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

class _TrustChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _TrustChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 12,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
