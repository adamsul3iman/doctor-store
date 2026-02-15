import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import 'package:doctor_store/shared/utils/wishlist_manager.dart';
import 'package:doctor_store/features/product/domain/models/product_model.dart';
import 'package:doctor_store/features/product/presentation/widgets/product_card.dart';
import 'package:doctor_store/features/cart/application/cart_manager.dart';
import 'package:doctor_store/shared/services/analytics_service.dart';
import 'package:doctor_store/shared/widgets/quick_nav_bar.dart';
import 'package:doctor_store/shared/utils/responsive_layout.dart';

class WishlistScreen extends ConsumerStatefulWidget {
  const WishlistScreen({super.key});

  @override
  ConsumerState<WishlistScreen> createState() => _WishlistScreenState();
}

class _WishlistScreenState extends ConsumerState<WishlistScreen> {
  // ✅ تخزين مؤقت للمنتجات لتجنب وميض الواجهة
  List<Product>? _cachedProducts;

  @override
  void initState() {
    super.initState();
    // تتبع زيارة شاشة المفضلة
    AnalyticsService.instance.trackEvent('wishlist_view');
  }

  // لجلب تفاصيل المنتجات بناءً على الـ IDs المحفوظة
  Future<List<Product>> _fetchWishlistProducts(List<String> ids) async {
    if (ids.isEmpty) return [];
    
    final data = await Supabase.instance.client
        .from('products')
        .select()
        .eq('is_active', true)
        .inFilter('id', ids);

    return data.map((e) => Product.fromJson(e)).toList();
  }

  // ✅ بناء شبكة المنتجات مع تحسين الأداء
  Widget _buildProductsGrid(List<Product> products, int itemCount) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      sliver: SliverLayoutBuilder(
        builder: (context, constraints) {
          final crossAxisCount = ResponsiveLayout.gridCountForWidth(
            constraints.crossAxisExtent,
            desiredItemWidth: 120,
            minCount: 3,
            maxCount: 5,
          );
          final isCompact = crossAxisCount >= 3;
          const spacing = 12.0;
          final mainAxisExtent = ResponsiveLayout.productCardMainAxisExtent(
            constraints.crossAxisExtent,
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: spacing,
            isCompact: isCompact,
          );

          return SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              mainAxisExtent: mainAxisExtent,
              crossAxisSpacing: spacing,
              mainAxisSpacing: spacing,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final product = products[index];
                return Stack(
                  children: [
                    ProductCard(
                      product: product,
                      isCompact: isCompact,
                    ),
                    // زر إضافة سريع للسلة
                    Positioned(
                      bottom: 8,
                      right: 8,
                      child: GestureDetector(
                        onTap: () async {
                          final messenger = ScaffoldMessenger.of(context);
                          ref.read(cartProvider.notifier).addItem(product);
                          await AnalyticsService.instance.trackEvent('wishlist_add_to_cart');
                          messenger.showSnackBar(
                            const SnackBar(
                              content: Text("تمت إضافة المنتج إلى السلة 🛒"),
                              duration: Duration(seconds: 1),
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.95),
                            borderRadius: BorderRadius.circular(999),
                            boxShadow: const [
                              BoxShadow(color: Colors.black12, blurRadius: 4),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(Icons.add_shopping_cart, size: 16, color: Color(0xFF0A2647)),
                              SizedBox(width: 4),
                              Text('للسلة', style: TextStyle(fontSize: 11)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    // زر حذف سريع
                    Positioned(
                      top: 8,
                      left: 8,
                      child: GestureDetector(
                        onTap: () {
                          ref.read(wishlistProvider.notifier).toggleWishlist(product.id);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("تم الحذف من المفضلة 💔"), duration: Duration(seconds: 1)),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.9),
                            shape: BoxShape.circle,
                            boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
                          ),
                          child: const Icon(Icons.close, size: 16, color: Colors.grey),
                        ),
                      ),
                    ),
                  ],
                );
              },
              childCount: products.length,
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 1. مراقبة قائمة المعرفات (IDs) من البروفايدر
    final favIds = ref.watch(wishlistProvider);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: CustomScrollView(
        slivers: [
          // 2. الهيدر الأنيق
          SliverAppBar(
            pinned: true,
            expandedHeight: 140,
            backgroundColor: const Color(0xFFD32F2F), // أحمر داكن كلاسيكي
            foregroundColor: Colors.white,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, size: 20),
              onPressed: () => context.pop(),
            ),
            flexibleSpace: FlexibleSpaceBar(
              centerTitle: true,
              titlePadding: const EdgeInsets.only(bottom: 16),
              title: Text(
                "قائمتي المفضلة",
                style: GoogleFonts.almarai(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: Colors.white,
                ),
              ),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Color(0xFFD32F2F),
                          Color(0xFFE57373),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                  ),
                  // قلب كبير شفاف في الخلفية
                  Positioned(
                    right: -30,
                    bottom: -40,
                    child: Transform.rotate(
                      angle: -0.2,
                      child: Icon(
                        FontAwesomeIcons.solidHeart,
                        size: 180,
                        color: Colors.white.withValues(alpha: 0.15),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.menu_rounded, color: Colors.white),
                tooltip: 'القائمة السريعة',
                onPressed: () => showQuickNavBar(context),
              ),
              if (favIds.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.home, color: Colors.white),
                  onPressed: () => context.go('/'),
                  tooltip: "الرئيسية",
                ),
            ],
          ),

          // 3. شريط المعلومات
          if (favIds.isNotEmpty)
            SliverToBoxAdapter(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                color: Colors.white,
                child: Row(
                  children: [
                    const Icon(Icons.favorite, color: Colors.red, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "لديك ${favIds.length} منتجات مميزة",
                            style: GoogleFonts.almarai(
                              color: Colors.grey[800],
                              fontWeight: FontWeight.bold,
                              fontSize: 14
                            ),
                          ),
                          Text(
                            "اضغط على أي منتج لعرض التفاصيل، أو استخدم زر \"للسلة\" للإضافة المباشرة.",
                            style: GoogleFonts.almarai(fontSize: 11, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () async {
                        // سيتم تنفيذ النقل الكامل في الأسفل عند توفر المنتجات الفعلية
                        final messenger = ScaffoldMessenger.of(context);
                        await AnalyticsService.instance.trackEvent('wishlist_open_move_all_hint');
                        messenger.showSnackBar(
                          const SnackBar(content: Text('انزل لأسفل لنقل كل المفضلة إلى السلة'), duration: Duration(seconds: 2)),
                        );
                      },
                      child: const Text(
                        "نصيحة للشراء",
                        style: TextStyle(fontSize: 11),
                      ),
                    ),
                   ],
                 ),
               ),
             ),

          // 4. المحتوى (المنتجات أو الفارغ)
          favIds.isEmpty
              ? SliverFillRemaining(
                  hasScrollBody: false,
                  child: _buildEmptyState(),
                )
              : FutureBuilder<List<Product>>(
                  future: _fetchWishlistProducts(favIds),
                  builder: (context, snapshot) {
                    // ✅ تحسين: تخزين مؤقت للـ snapshot لتجنب وميض الواجهة
                    if (snapshot.connectionState == ConnectionState.waiting && _cachedProducts != null) {
                      return _buildProductsGrid(_cachedProducts!, favIds.length);
                    }
                    
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const SliverPadding(
                        padding: EdgeInsets.all(16),
                        sliver: SliverToBoxAdapter(
                          child: Center(child: CircularProgressIndicator()),
                        ),
                      );
                    }

                    if (snapshot.hasError) {
                      debugPrint('Wishlist products load error: ${snapshot.error}');
                      return const SliverFillRemaining(
                        child: Center(child: Text("تعذر تحميل المفضلة الآن، حاول مرة أخرى لاحقاً")),
                      );
                    }

                    final products = snapshot.data ?? [];
                    _cachedProducts = products; // ✅ تخزين مؤقت

                    if (products.isEmpty) {
                      return SliverFillRemaining(child: _buildEmptyState());
                    }

                    return _buildProductsGrid(products, products.length);
                  },
                ),

          // CTA في الأسفل لنقل كل المفضلة للسلة
          if (favIds.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                child: SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      final router = GoRouter.of(context);

                      final products = await _fetchWishlistProducts(favIds);
                      for (final p in products) {
                        ref.read(cartProvider.notifier).addItem(p);
                      }
                      await AnalyticsService.instance.trackEvent('wishlist_move_all_to_cart', props: {
                        'count': favIds.length,
                      });

                      messenger.showSnackBar(
                        const SnackBar(content: Text('تم نقل كل المفضلة إلى السلة 🛒'), duration: Duration(seconds: 2)),
                      );
                      router.push('/cart');
                    },
                    icon: const Icon(Icons.shopping_bag),
                    label: const Text('نقل كل المفضلة إلى السلة وإكمال الطلب'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0A2647),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ),
            ),

           const SliverToBoxAdapter(child: SizedBox(height: 50)),
        ],
      ),
    );
  }

  // تصميم الحالة الفارغة
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(30),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.05),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.favorite_border, size: 80, color: Colors.red.withValues(alpha: 0.3)),
          ),
          const SizedBox(height: 20),
          Text(
            "قائمتك فارغة حالياً",
            style: GoogleFonts.almarai(fontSize: 20, fontWeight: FontWeight.bold, color: const Color(0xFF0A2647)),
          ),
          const SizedBox(height: 10),
          Text(
            "اضغط على القلب ❤️ لحفظ المنتجات التي تعجبك هنا",
            textAlign: TextAlign.center,
            style: GoogleFonts.almarai(fontSize: 14, color: Colors.grey),
          ),
          const SizedBox(height: 30),
        ElevatedButton(
            // ✅ التصحيح: استخدمنا push بدلاً من go لنتمكن من الرجوع
            onPressed: () => context.push('/all_products'),
            
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0A2647),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text("تصفح المنتجات"),
          ),
        ],
      ),
    );
  }
}