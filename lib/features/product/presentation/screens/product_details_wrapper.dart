import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:doctor_store/features/product/domain/models/product_model.dart';
import 'package:doctor_store/features/recently_viewed/application/recently_viewed_manager.dart';
import 'package:doctor_store/shared/services/analytics_service.dart';
import 'product_details_screen.dart';

class ProductDetailsWrapper extends ConsumerStatefulWidget {
  final Product? productObj;
  final String? productId;
  final String? productSlug; // ✅ متغير جديد

  const ProductDetailsWrapper({super.key, this.productObj, this.productId, this.productSlug});

  @override
  ConsumerState<ProductDetailsWrapper> createState() => _ProductDetailsWrapperState();
}

class _ProductDetailsWrapperState extends ConsumerState<ProductDetailsWrapper> {
  late final Future<Product?> _productFuture;
  late final int _startMs;

  @override
  void initState() {
    super.initState();
    _startMs = DateTime.now().millisecondsSinceEpoch;

    if (widget.productObj != null) {
      // في هذه الحالة لن نستخدم FutureBuilder عملياً، لكن نعيّن future صالحاً لتفادي الأخطاء
      _productFuture = Future.value(widget.productObj);
      return;
    }

    // تحديد طريقة الجلب: بالآيدي أو بالـ slug، أو إرجاع null بأمان في حال عدم توفر أي معلومة
    if (widget.productId != null) {
      _productFuture = _fetchProduct('id', widget.productId!);
    } else if (widget.productSlug != null) {
      _productFuture = _fetchProduct('slug', widget.productSlug!);
    } else {
      _productFuture = Future.value(null);
    }
  }

  // دالة موحدة للجلب
  Future<Product?> _fetchProduct(String column, String value) async {
    try {
      final data = await Supabase.instance.client
          .from('products')
          .select()
          .eq(column, value) // ✅ بحث مرن (id أو slug)
          .single();

      final durationMs = DateTime.now().millisecondsSinceEpoch - _startMs;
      AnalyticsService.instance.trackEvent('product_details_loaded', props: {
        'duration_ms': durationMs,
        'id': data['id'],
        'by': column,
      });

      return Product.fromJson(data);
    } catch (e) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    // الحالة 1: المستخدم جاء من التطبيق والبيانات موجودة
    if (widget.productObj != null) {
      // Add to recently viewed
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(recentlyViewedProvider.notifier).addToRecentlyViewed(widget.productObj!);
      });
      
      return ProductDetailsScreen(product: widget.productObj!);
    }

    // الحالة 2: المستخدم جاء من رابط واتساب (نحتاج تحميل البيانات)
    return Scaffold(
      body: FutureBuilder<Product?>(
        future: _productFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Color(0xFF0A2647)),
                  SizedBox(height: 20),
                  Text("جاري تحضير المنتج...", style: TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
            );
          }

          if (snapshot.hasError || !snapshot.hasData || snapshot.data == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 60, color: Colors.red),
                  const SizedBox(height: 20),
                  const Text("عذراً، هذا المنتج لم يعد متوفراً أو الرابط خاطئ"),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () => context.go('/'), // العودة للرئيسية باستخدام GoRouter لضمان سلاسة التنقل
                    child: const Text("الذهاب للمتجر"),
                  )
                ],
              ),
            );
          }

          // تم تحميل البيانات بنجاح، اعرض الصفحة
          final product = snapshot.data!;
          
          // Add to recently viewed
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ref.read(recentlyViewedProvider.notifier).addToRecentlyViewed(product);
          });
          
          return ProductDetailsScreen(product: product);
        },
      ),
    );
  }
}