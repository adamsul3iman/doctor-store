import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:doctor_store/features/product/domain/models/product_model.dart';
import 'package:doctor_store/features/product/presentation/widgets/product_card.dart';
import 'package:doctor_store/features/product/presentation/widgets/product_card_skeleton.dart';
import 'package:doctor_store/features/cart/application/cart_manager.dart';
import 'package:doctor_store/shared/utils/product_nav_helper.dart';
import 'package:google_fonts/google_fonts.dart';

class SimilarProductsSection extends StatefulWidget {
  final String categoryId;
  final String currentProductId;

  const SimilarProductsSection({
    super.key,
    required this.categoryId,
    required this.currentProductId,
  });

  @override
  State<SimilarProductsSection> createState() => _SimilarProductsSectionState();
}

class _SimilarProductsSectionState extends State<SimilarProductsSection> {
  List<Product> _products = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchSimilarProducts();
  }

  Future<void> _fetchSimilarProducts() async {
    final supabase = Supabase.instance.client;
    List<dynamic> rawData = [];

    try {
      // 1. نفس القسم
      var response = await supabase
          .from('products')
          .select()
          .eq('category', widget.categoryId)
          .eq('is_active', true)
          .neq('id', widget.currentProductId)
          .limit(6);
      
      rawData = response as List<dynamic>;

      // 2. Fallback 1: المنتجات المميزة
      if (rawData.isEmpty) {
        var response2 = await supabase
            .from('products')
            .select()
            .eq('is_featured', true)
            .eq('is_active', true)
            .neq('id', widget.currentProductId)
            .limit(6);
        rawData = response2 as List<dynamic>;
      }

      // 3. Fallback 2: أحدث المنتجات
      if (rawData.isEmpty) {
        var response3 = await supabase
            .from('products')
            .select()
            .eq('is_active', true)
            .neq('id', widget.currentProductId)
            .limit(6);
        rawData = response3 as List<dynamic>;
      }

      if (mounted) {
        setState(() {
          _products = rawData.map((e) => Product.fromJson(e)).toList();
          _isLoading = false;
        });
      }

    } catch (e) {
      debugPrint("Error fetching similar products: $e");
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const double tileHeight = 260; // ارتفاع تقريبي لكل كرت في الشبكة

    if (_isLoading) {
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          mainAxisExtent: tileHeight,
        ),
        itemCount: 4,
        itemBuilder: (_, __) => const ProductCardSkeleton(),
      );
    }

    if (_products.isEmpty) {
      return const SizedBox.shrink();
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        mainAxisExtent: tileHeight,
      ),
      itemCount: _products.length,
      itemBuilder: (context, index) {
        final product = _products[index];
        return ProductCard(
          product: product,
          isCompact: false,
          heroTag: 'similar_${product.id}',
        );
      },
    );
  }
}

/// شريط مبسّط يعرض صوراً مصغّرة ومنتجات مقترَحة
/// للاستخدام داخل صفحة تفاصيل المنتج (تحت الكمية المطلوبة).
class InlineSimilarProductsStrip extends ConsumerStatefulWidget {
  final String categoryId;
  final String currentProductId;

  const InlineSimilarProductsStrip({
    super.key,
    required this.categoryId,
    required this.currentProductId,
  });

  @override
  ConsumerState<InlineSimilarProductsStrip> createState() => _InlineSimilarProductsStripState();
}

class _InlineSimilarProductsStripState extends ConsumerState<InlineSimilarProductsStrip> {
  List<Product> _products = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchSimilarProducts();
  }

  Future<void> _fetchSimilarProducts() async {
    final supabase = Supabase.instance.client;
    List<dynamic> rawData = [];

    try {
      // 1) منتجات من نفس القسم
      var response = await supabase
          .from('products')
          .select('id, title, price, old_price, category, options, gallery, image_url, is_active')
          .eq('category', widget.categoryId)
          .eq('is_active', true)
          .neq('id', widget.currentProductId)
          .limit(10);

      rawData = response as List<dynamic>;

      // 2) Fallback: أحدث المنتجات النشطة في حال لم نجد شيئاً
      if (rawData.isEmpty) {
        var response2 = await supabase
            .from('products')
            .select('id, title, price, old_price, category, options, gallery, image_url, is_active')
            .eq('is_active', true)
            .neq('id', widget.currentProductId)
            .limit(10);
        rawData = response2 as List<dynamic>;
      }

      if (!mounted) return;

      setState(() {
        _products = rawData.map((e) => Product.fromJson(e)).toList();
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error fetching inline similar products: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _products.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'منتجات مقترحة لك',
          style: GoogleFonts.almarai(
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 120,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _products.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final product = _products[index];
              return SizedBox(
                width: 100,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    context.push(
                      buildProductDetailsPath(product),
                      extra: product,
                    );
                  },
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: AspectRatio(
                            aspectRatio: 1,
                            child: Image.network(
                              product.thumbnailUrl,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Text(
                              '${product.price} د.أ',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.almarai(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          IconButton(
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            iconSize: 18,
                            tooltip: 'إضافة للسلة',
                            icon: const Icon(Icons.add_shopping_cart_rounded,
                                color: Colors.green, size: 18),
                            onPressed: () {
                              final hasColors =
                                  (product.options['colors'] is List &&
                                      (product.options['colors'] as List).isNotEmpty);
                              final hasSizes =
                                  (product.options['sizes'] is List &&
                                      (product.options['sizes'] as List).isNotEmpty);

                              if (hasColors || hasSizes) {
                                // منتج يحتاج اختيار لون/مقاس → نفتح صفحة التفاصيل لاختيارها أولاً
                                context.push(
                                  buildProductDetailsPath(product),
                                  extra: product,
                                );
                                return;
                              }

                              ref.read(cartProvider.notifier).addItem(product);
                              ScaffoldMessenger.of(context)
                                ..hideCurrentSnackBar()
                                ..showSnackBar(
                                  const SnackBar(
                                    content: Text('تمت إضافة المنتج للسلة'),
                                    duration: Duration(seconds: 1),
                                  ),
                                );
                            },
                          ),
                        ],
                      ),
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
}
