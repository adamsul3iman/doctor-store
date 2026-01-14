import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:doctor_store/features/product/domain/models/product_model.dart';
import 'package:doctor_store/features/product/presentation/widgets/product_card.dart';
import 'package:doctor_store/features/product/presentation/widgets/product_card_skeleton.dart';
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
    const double tileHeight = 290; // ارتفاع مريح يمنع الـ overflow مع الكروت المدمجة

    if (_isLoading) {
      return SizedBox(
        height: tileHeight,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          cacheExtent: 800,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: 3,
          itemBuilder: (_, __) => const SizedBox(
            width: 170,
            child: Padding(
              padding: EdgeInsets.only(right: 15),
              child: ProductCardSkeleton(),
            ),
          ),
        ),
      );
    }

    if (_products.isEmpty) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      height: tileHeight,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        cacheExtent: 800,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        itemCount: _products.length,
        itemBuilder: (context, index) {
          final product = _products[index];
          return Container(
            width: 170,
            margin: EdgeInsets.only(
              right: 12,
              left: index == 0 ? 4 : 0,
            ),
            child: ProductCard(
              product: product,
              isCompact: true,
              heroTag: 'similar_${product.id}',
            ),
          );
        },
      ),
    );
  }
}

/// شريط مبسّط يعرض صوراً مصغّرة ومنتجات مقترَحة
/// للاستخدام داخل صفحة تفاصيل المنتج (تحت الكمية المطلوبة).
class InlineSimilarProductsStrip extends StatefulWidget {
  final String categoryId;
  final String currentProductId;

  const InlineSimilarProductsStrip({
    super.key,
    required this.categoryId,
    required this.currentProductId,
  });

  @override
  State<InlineSimilarProductsStrip> createState() => _InlineSimilarProductsStripState();
}

class _InlineSimilarProductsStripState extends State<InlineSimilarProductsStrip> {
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
          height: 110,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _products.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final product = _products[index];
              return SizedBox(
                width: 80,
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
                    Text(
                      '${product.price} د.أ',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.almarai(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
