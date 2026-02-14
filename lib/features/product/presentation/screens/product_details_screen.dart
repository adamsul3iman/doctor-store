import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:auto_size_text/auto_size_text.dart';

// Models and Services
import '../../../../shared/services/analytics_service.dart';
import '../../../../shared/services/supabase_service.dart';
import '../../../../shared/utils/image_url_helper.dart';
import '../../../../shared/widgets/custom_app_bar.dart';
import '../../../../shared/widgets/image_shimmer_placeholder.dart';
import '../../../../shared/widgets/app_network_image.dart';
import '../../../../shared/widgets/responsive_center_wrapper.dart';
import '../../../../shared/utils/responsive_layout.dart';
import '../../../../shared/utils/seo_manager.dart';
import '../../../../shared/utils/product_nav_helper.dart';
import '../../../../shared/utils/app_notifier.dart';
import '../../../../shared/utils/link_share_helper.dart';
import '../../../../shared/utils/categories_provider.dart';
import '../../../../shared/utils/sub_categories_provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../features/cart/application/cart_manager.dart';
import '../../../../shared/utils/settings_provider.dart';
import '../../../../shared/utils/delivery_zones_provider.dart';
import '../../../../shared/utils/network_status_provider.dart';
import '../../../../shared/utils/shipping_calculator.dart';
import '../../../../shared/utils/app_settings_provider.dart';
import '../../../../shared/widgets/free_shipping_progress_bar.dart';
import '../widgets/similar_products_section.dart';
import '../widgets/product_poster_dialog.dart';
import '../widgets/reviews_section.dart';

class ProductDetailsScreen extends ConsumerStatefulWidget {
  final Product? productObj;
  final String? productId;
  final String? productSlug;

  const ProductDetailsScreen({
    super.key,
    this.productObj,
    this.productId,
    this.productSlug,
  });

  @override
  ConsumerState<ProductDetailsScreen> createState() => _ProductDetailsScreenState();
}

class _ProductDetailsScreenState extends ConsumerState<ProductDetailsScreen> {
  // Page controller for image gallery
  late PageController _pageController;

  // Product data
  late Product _product;
  ProductVariant? _selectedVariant;
  List<ProductVariant> _variants = [];

  // UI state
  bool _isExpanded = false;
  bool _isLoading = false;
  bool _isAddingToCart = false;
  bool _showSizeGuide = false;
  bool _showColorGuide = false;
  bool _showMattressGuide = false;
  bool _isFavorite = false;
  int _currentImageIndex = 0;

  // Selection state
  String? _selectedColor;
  String? _selectedSize;
  bool _hasColors = false;
  bool _hasSizes = false;
  bool _hasStandardSizes = false;
  bool _isMattressAuto = false;
  bool _hasStandardMattressSizes = false;
  final List<String> _mattressWidthsCm = ['80', '90', '100', '120', '140', '160', '180', '200'];
  final List<String> _mattressLengthsCm = ['200', '190', '180', '170', '160', '150'];
  String? _selectedMattressWidthCm;
  String? _selectedMattressLengthCm;

  // Form controllers
  final _quantityController = TextEditingController();
  final _customWidthController = TextEditingController();
  final _customLengthController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _mattressSizeKey = GlobalKey<FormState>();
  final _mattressWidthKey = GlobalKey<FormState>();
  final _mattressLengthKey = GlobalKey<FormState>();

  // Performance tracking
  late final int _pageLoadStartTime;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _pageLoadStartTime = DateTime.now().millisecondsSinceEpoch;

    // Initialize product data
    if (widget.productObj != null) {
      _product = widget.productObj!;
    } else {
      _loadProductData();
    }

    // Initialize selection state
    _initializeSelectionState();

    // Setup SEO
    SeoManager.setProductSeo(_product);

    // Track product view event
    AnalyticsService.instance.trackEvent('product_view', props: {
      'id': _product.id,
      'title': _product.title,
      'category': _product.category,
      'price': _product.price,
      'has_discount': _product.hasOffers || _product.isFlashDeal,
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    
    // Track site visit after context is available
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        AnalyticsService.instance.trackSiteVisit(
          pageUrl: '/product/${_product.id}',
          deviceType: _detectDeviceType(),
          country: 'Kuwait',
        );
        
        AnalyticsService.instance.trackProductView(
          productId: _product.id,
          categoryId: _product.category,
          viewDurationSeconds: 0, // Will be updated on exit
        );
      }
    });
  }

  // Device type detection
  String _detectDeviceType() {
    final data = MediaQuery.of(context);
    if (data.size.width < 768) {
      return 'mobile';
    } else if (data.size.width < 1024) {
      return 'tablet';
    } else {
      return 'desktop';
    }
  }

  void _initializeSelectionState() {
    // Check if product has options
    final options = _product.options;
    _hasColors = options.containsKey('colors') && (options['colors'] as List).isNotEmpty;
    _hasSizes = options.containsKey('sizes') && (options['sizes'] as List).isNotEmpty;
    _hasStandardSizes = options.containsKey('standard_mattress_sizes');
    _hasStandardMattressSizes = options.containsKey('standard_mattress_lengths');
    _isMattressAuto = _product.category.toLowerCase().contains('مراتب') || 
                       _product.category.toLowerCase().contains('مفرش') ||
                       _product.title.toLowerCase().contains('مراتب') ||
                       _product.title.toLowerCase().contains('مفرش');

    // Set initial selections
    if (_variants.isNotEmpty) {
      _selectedVariant = _variants.first;
      _selectedColor = _selectedVariant!.color;
      _selectedSize = _selectedVariant!.size;
    }
  }

  Future<void> _loadProductData() async {
    setState(() => _isLoading = true);
    
    try {
      final productId = widget.productId ?? widget.productSlug;
      final response = await SupabaseService.instance.getProductByIdOrSlug(productId);
      
      if (response['success'] == true && response['data'] != null) {
        _product = Product.fromJson(response['data']);
        _variants = List<ProductVariant>.from(_product.variants);
        _initializeSelectionState();
      } else {
        throw Exception('Product not found');
      }
    } catch (e) {
      // Handle error silently
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _quantityController.dispose();
    _customWidthController.dispose();
    _customLengthController.dispose();
    super.dispose();
  }

  // Update selected variant when color/size changes
  void _updateSelectedVariant() {
    if (_variants.isEmpty) return;
    
    // Find variant with matching color and size
    final matchingVariant = _variants.firstWhere(
      (variant) => variant.color == _selectedColor && variant.size == _selectedSize,
    );
    
    if (matchingVariant != null) {
      setState(() {
        _selectedVariant = matchingVariant;
      });
    }
  }

  // Toggle favorite status
  void _toggleFavorite() async {
    final userId = SupabaseService.instance.getCurrentUserId();
    if (userId == null) {
      // Show login prompt for guests
      _showLoginPrompt();
      return;
    }

    setState(() => _isFavorite = !_isFavorite);
    
    try {
      await SupabaseService.instance.toggleFavorite(_product.id, userId);
    } catch (e) {
      // Handle error silently
    }
  }

  void _showLoginPrompt() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('تسجيل الدخول مطلوب'),
        content: Text('يجب تسجيل الدخول لإضافة المنتج للمفضلة'),
        actions: [
          TextButton(
            onPressed: () => context.pop(),
            child: Text('حسناً'),
          ),
        ],
      ),
    );
  }

  // Add to cart with analytics
  Future<void> _addToCart() async {
    if (_isAddingToCart) return;
    
    setState(() => _isAddingToCart = true);
    
    try {
      final userId = SupabaseService.instance.getCurrentUserId();
      if (userId == null) {
        _showLoginPrompt();
        return;
      }

      // Track add to cart event
      AnalyticsService.instance.trackEvent('add_to_cart', props: {
        'product_id': _product.id,
        'quantity': _quantity,
        'color': _selectedColor,
        'size': _selectedSize,
        'price': _getSelectedPrice(),
      });

      // Add to cart using service
      await SupabaseService.instance.addToCart(
        _product,
        _selectedVariant ?? _variants.first,
        _quantity,
        _selectedColor,
        _selectedSize,
        _getCustomMattressDimensions(),
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("تمت إضافة المنتج إلى السلة 🛒"),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشلت الإضافة: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isAddingToCart = false);
      }
    }
  }

  // Get selected price
  double _getSelectedPrice() {
    if (_selectedVariant != null) {
      return _selectedVariant!.price;
    }
    return _product.price;
  }

  // Get custom mattress dimensions
  Map<String, double> _getCustomMattressDimensions() {
    if (!_isMattressAuto || 
        _customWidthController.text.isEmpty || 
        _customLengthController.text.isEmpty) {
      return {};
    }
    
    final width = double.tryParse(_customWidthController.text) ?? 0;
    final length = double.tryParse(_customLengthController.text) ?? 0;
    
    return {
      'width': width,
      'length': length,
    };
  }

  @override
  Widget build(BuildContext context) {
    final userId = SupabaseService.instance.getCurrentUserId();
    final isGuest = userId == null;
    final cartAsync = ref.watch(cartProvider);
    final wishlistAsync = ref.watch(wishlistProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: CustomAppBar(
        title: _product.title,
        actions: [
          // Share button
          IconButton(
            onPressed: () => _shareProduct(),
            icon: const Icon(Icons.share),
            tooltip: 'مشاركة',
          ),
          
          // Favorite button
          Consumer(
            builder: (context, ref) {
              final wishlist = ref.watch(wishlistProvider);
              final isFavorite = wishlist.contains(_product.id);
              
              return IconButton(
                onPressed: () => _toggleFavorite(),
                icon: Icon(
                  isFavorite ? Icons.favorite : Icons.favorite_border,
                  color: isFavorite ? Colors.red : Colors.grey,
                ),
                tooltip: isFavorite ? 'إزالة من المفضلة' : 'إضافة للمفضلة',
              );
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadProductData,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Product images gallery
                    _buildImageGallery(),
                    
                    const SizedBox(height: 24),
                    
                    // Product info
                    _buildProductInfo(),
                    
                    const SizedBox(height: 32),
                    
                    // Customization options
                    if (_hasColors || _hasSizes || _isMattressAuto) ...[
                      _buildCustomizationSection(),
                    ],
                    
                    const SizedBox(height: 32),
                    
                    // Action buttons
                    _buildActionButtons(cartAsync, wishlistAsync, isGuest),
                  ],
                ),
              ),
            ),
        ),
    );
  }

  // Build image gallery
  Widget _buildImageGallery() {
    return SizedBox(
      height: 400,
      child: PageView.builder(
        controller: _pageController,
        itemCount: _displayImages.length,
        itemBuilder: (context, index) {
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _currentImageIndex == index ? Colors.blue : Colors.transparent,
                width: 2,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: InteractiveViewer(
                transformationController: TransformationController(),
                child: AppNetworkImage(
                  imageUrl: _displayImages[index],
                  fit: BoxFit.contain,
                ),
              ),
            ),
          );
        },
        onPageChanged: (int index) {
          setState(() {
            _currentImageIndex = index;
          });
        },
      ),
    );
  }

  // Build product info section
  Widget _buildProductInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Product title and price
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _product.title,
                      style: GoogleFonts.almarai(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF0A2647),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          '${_getSelectedPrice()} دينار',
                          style: GoogleFonts.almarai(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.green[600],
                          ),
                        ),
                        if (_product.oldPrice != null && _product.oldPrice! > _product.price) ...[
                          const SizedBox(width: 8),
                          Text(
                            '${_product.oldPrice} دينار',
                            style: GoogleFonts.almarai(
                              fontSize: 16,
                              color: Colors.grey,
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                        ],
                      ],
                    ],
                  ],
                ),
              ),
              
              // Favorite button
              IconButton(
                onPressed: () => _toggleFavorite(),
                icon: Icon(
                  _isFavorite ? Icons.favorite : Icons.favorite_border,
                  color: _isFavorite ? Colors.red : Colors.grey,
                ),
              ),
            ],
          ),
          
          // Product description
          const SizedBox(height: 16),
          Text(
            _product.description ?? 'لا يوجد وصف لهذا المنتج',
            style: GoogleFonts.almarai(
              fontSize: 14,
              color: Colors.grey[600],
              height: 1.5,
            ),
          ),
          
          // Category
          if (_product.category.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.category, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 8),
                Text(
                  'التصنيف: ${_product.category}',
                  style: GoogleFonts.almarai(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ],
          
          // Stock status
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(
                _product.stock > 0 ? Icons.check_circle : Icons.error,
                color: _product.stock > 0 ? Colors.green : Colors.red,
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(
                _product.stock > 0 ? 'متوفر' : 'نفذ المخزون',
                style: GoogleFonts.almarai(
                  fontSize: 14,
                  color: _product.stock > 0 ? Colors.green : Colors.red,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Build customization section
  Widget _buildCustomizationSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'تخصيص المنتج',
            style: GoogleFonts.almarai(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF0A2647),
            ),
          ),
          
          // Color selection
          if (_hasColors) ...[
            const SizedBox(height: 16),
            Text(
              'اللون:',
              style: GoogleFonts.almarai(fontSize: 14),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: _product.options['colors']?.map<Widget>((color) {
                final isSelected = color == _selectedColor;
                return GestureDetector(
                  onTap: () => setState(() => _selectedColor = color),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.blue : Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSelected ? Colors.blue : Colors.grey[300],
                      ),
                    ),
                    child: Text(
                      color,
                      style: GoogleFonts.almarai(
                        fontSize: 12,
                        color: isSelected ? Colors.white : Colors.black,
                      ),
                    ),
                  ),
                );
              }).toList() ?? [],
            ),
          ],
          
          // Size selection
          if (_hasSizes) ...[
            const SizedBox(height: 16),
            Text(
              'المقاس:',
              style: GoogleFonts.almarai(fontSize: 14),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: _product.options['sizes']?.map<Widget>((size) {
                final isSelected = size == _selectedSize;
                return GestureDetector(
                  onTap: () => setState(() => _selectedSize = size),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.blue : Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSelected ? Colors.blue : Colors.grey[300],
                      ),
                    ),
                    child: Text(
                      size,
                      style: GoogleFonts.almarai(
                        fontSize: 12,
                        color: isSelected ? Colors.white : Colors.black,
                      ),
                    ),
                  ),
                );
              }).toList() ?? [],
            ),
          ],
          
          // Mattress customization
          if (_isMattressAuto) ...[
            const SizedBox(height: 16),
            Text(
              'أبعاد المرتبة (سم):',
              style: GoogleFonts.almarai(fontSize: 14),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: _mattressWidthsCm.map<Widget>((width) {
                final isSelected = width == _selectedMattressWidthCm;
                return GestureDetector(
                  onTap: () => setState(() => _selectedMattressWidthCm = width),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.blue : Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSelected ? Colors.blue : Colors.grey[300],
                      ),
                    ),
                    child: Text(
                      '${width} سم',
                      style: GoogleFonts.almarai(
                        fontSize: 12,
                        color: isSelected ? Colors.white : Colors.black,
                      ),
                    ),
                  ),
                );
              }).toList() ?? [],
            ),
            
            const SizedBox(height: 8),
            Text(
              'الطول (سم):',
              style: GoogleFonts.almarai(fontSize: 14),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: _mattressLengthsCm.map<Widget>((length) {
                final isSelected = length == _selectedMattressLengthCm;
                return GestureDetector(
                  onTap: () => setState(() => _selectedMattressLengthCm = length),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.blue : Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSelected ? Colors.blue : Colors.grey[300],
                      ),
                    ),
                    child: Text(
                      '${length} سم',
                      style: GoogleFonts.almarai(
                        fontSize: 12,
                        color: isSelected ? Colors.white : Colors.black,
                      ),
                    ),
                  ),
                );
              }).toList() ?? [],
            ),
            
            // Custom dimensions
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _customWidthController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'عرض (سم)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _customLengthController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'طول (سم)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // Build action buttons
  Widget _buildActionButtons(AsyncValue cartAsync, AsyncValue wishlistAsync, bool isGuest) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Quantity selector
          Row(
            children: [
              Text(
                'الكمية:',
                style: GoogleFonts.almarai(fontSize: 14),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _quantityController,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: () {
                  setState(() {
                    if (int.tryParse(_quantityController.text) != null) {
                      final current = int.parse(_quantityController.text);
                      if (current > 1) {
                        _quantityController.text = (current - 1).toString();
                      } else if (current < 99) {
                        _quantityController.text = (current + 1).toString();
                      }
                    }
                  });
                },
                icon: Icons.remove,
                iconSize: 20,
              ),
              IconButton(
                onPressed: () {
                  setState(() {
                    if (int.tryParse(_quantityController.text) != null) {
                      final current = int.parse(_quantityController.text);
                      if (current > 1) {
                        _quantityController.text = (current + 1).toString();
                      } else if (current < 99) {
                        _quantityController.text = (current - 1).toString();
                      }
                    }
                  });
                },
                icon: Icons.add,
                iconSize: 20,
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // Add to cart and buy buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _addToCart(),
                  icon: const Icon(Icons.shopping_cart),
                  label: 'إضافة للسلة',
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[600],
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _checkout(),
                  icon: const Icon(Icons.flash_on),
                  label: 'شراء الآن',
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange[600],
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Share and favorite buttons
          Row(
            children: [
              IconButton(
                onPressed: () => _shareProduct(),
                icon: const Icon(Icons.share),
                tooltip: 'مشاركة',
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: () => _toggleFavorite(),
                icon: Icon(
                  _isFavorite ? Icons.favorite : Icons.favorite_border,
                  color: _isFavorite ? Colors.red : Colors.grey,
                ),
                tooltip: _isFavorite ? 'إزالة من المفضلة' : 'إضافة للمفضلة',
              ),
            ],
          ],
        ],
      ),
    );
  }

  // Share product
  void _shareProduct() async {
    try {
      final url = await SupabaseService.instance.getProductShareUrl(_product.id);
      await Share.share(url, subject: _product.title);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشلت المشاركة: $e')),
      );
    }
  }

  // Checkout
  void _checkout() async {
    if (_selectedVariant == null) return;
    
    try {
      final userId = SupabaseService.instance.getCurrentUserId();
      if (userId == null) {
        _showLoginPrompt();
        return;
      }

      // Track checkout start
      AnalyticsService.instance.trackEvent('checkout_start', props: {
        'source': 'product_page',
        'product_id': _product.id,
        'quantity': int.tryParse(_quantityController.text) ?? 1,
        'price': _getSelectedPrice(),
      });

      // Create checkout data
      final checkoutData = {
        'product_id': _product.id,
        'variant_id': _selectedVariant!.id,
        'quantity': int.tryParse(_quantityController.text) ?? 1,
        'color': _selectedColor,
        'size': _selectedSize,
        'custom_dimensions': _getCustomMattressDimensions(),
      };

      // Navigate to checkout
      context.push('/checkout', extra: checkoutData);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشلت بدء الشراء: $e')),
      );
    }
  }
}
