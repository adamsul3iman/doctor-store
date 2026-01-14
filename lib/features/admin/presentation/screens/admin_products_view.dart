import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:doctor_store/features/product/domain/models/product_model.dart';
import 'package:doctor_store/shared/utils/app_notifier.dart';
import 'package:doctor_store/shared/utils/categories_provider.dart';
import 'package:doctor_store/shared/utils/image_url_helper.dart';

class AdminProductsView extends StatefulWidget {
  const AdminProductsView({super.key});

  @override
  State<AdminProductsView> createState() => _AdminProductsViewState();
}

class _AdminProductsViewState extends State<AdminProductsView> {
  final _supabase = Supabase.instance.client;
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  String _searchQuery = '';

  // نحتفظ بآخر بيانات ناجحة من الستريم لتفادي وميض الأخطاء المؤقتة
  List<Map<String, dynamic>>? _lastProductsRaw;

  // فلاتر متقدمة
  String? _selectedCategoryId; // null = الكل
  bool? _isActiveFilter; // null = الكل، true = ظاهرة، false = مخفية
  bool? _isFlashFilter; // null = الكل، true = عروض فلاش فقط، false = غير عروض فلاش
  String _sortMode = 'created_desc'; // created_desc, price_asc, price_desc

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }
  // ✅ تم إصلاح الخطأ هنا بعد تحديث الموديل
  Future<void> _toggleFlashDeal(Product product) async {
    final newValue = !product.isFlashDeal; // لم يعد هناك خطأ لأن الموديل تعرف عليه

    await _supabase
        .from('products')
        .update({'is_flash_deal': newValue}).eq('id', product.id);
    // لا حاجة لإعادة الجلب، StreamBuilder سيلتقط التغيير تلقائياً
  }

  /// تفعيل / إخفاء المنتج من المتجر (soft delete) عبر is_active
  Future<void> _toggleActive(Product product) async {
    final newValue = !product.isActive;
    try {
      await _supabase
          .from('products')
          .update({'is_active': newValue}).eq('id', product.id);
      if (!mounted) return;
      AppNotifier.showSuccess(
        context,
        newValue ? 'تم تفعيل المنتج وظهوره في المتجر.' : 'تم إخفاء المنتج من المتجر (الطلبات القديمة تبقى سليمة).',
      );
    } on PostgrestException catch (e) {
      if (!mounted) return;
      final msg = e.message;
      AppNotifier.showError(context, msg);
    } catch (e) {
      if (!mounted) return;
      AppNotifier.showError(context, 'حدث خطأ أثناء تغيير الحالة: $e');
    }
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      setState(() => _searchQuery = query);
    });
  }

  Future<void> _deleteProduct(Product product) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("تأكيد الحذف"),
        content: Text("هل أنت متأكد من حذف ${product.title}؟"),
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

    try {
      final deleted = await _supabase
          .from('products')
          .delete()
          .eq('id', product.id)
          .select(); // نطلب الصفوف المحذوفة للتأكد أن العملية تمت فعلاً

      if (deleted.isEmpty) {
        // لم يتم حذف أي صف (قد يكون المنتج غير موجود أو RLS/قيود منعت الحذف)
        if (!mounted) return;
        AppNotifier.showError(
          context,
          'لم يتم حذف المنتج. تحقق من الصلاحيات أو من وجود ارتباطات في الجداول الأخرى.',
        );
        return;
      }

      if (!mounted) return;
      AppNotifier.showSuccess(context, 'تم حذف المنتج بنجاح.');
    } on PostgrestException catch (e) {
      if (!mounted) return;
      // 23503 = foreign_key_violation (المنتج مرتبط بطلبات/عناصر/تقييمات)
      // 23502 = not_null_violation (مثلاً: ON DELETE SET NULL مع عمود product_id NOT NULL في order_items)
      if (e.code == '23503' || e.code == '23502') {
        AppNotifier.showError(
          context,
          'لا يمكن حذف هذا المنتج لأنه مرتبط بطلبات أو تقييمات أو سجلات أخرى في قاعدة البيانات. للحفاظ على السجلات، يُفضّل إخفاؤه أو إيقافه عن الظهور بدلاً من حذفه نهائياً.',
        );
      } else {
        final msg = e.message;
        AppNotifier.showError(context, msg);
      }
    } catch (e) {
      if (!mounted) return;
      AppNotifier.showError(context, 'حدث خطأ أثناء الحذف: $e');
    }
  }

  void _showAddProductDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          height: 300,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10)))),
              const SizedBox(height: 20),
              const Text("ما نوع المنتج الذي تريد إضافته؟", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0A2647))),
              const SizedBox(height: 20),
              
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  // ✅ تم إصلاح التحذير: استخدام withValues بدلاً من withOpacity
                  decoration: BoxDecoration(color: Colors.blue.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.shopping_bag, color: Colors.blue),
                ),
                title: const Text("منتج قياسي"),
                subtitle: const Text("منتج بسعر واحد، مع خيارات ألوان ومقاسات."),
                onTap: () {
                  Navigator.pop(context);
                  // إنشاء منتج جديد (بدون id)
                  context.push('/admin/edit');
                },
              ),
              
              const Divider(height: 20),

              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  // ✅ تم إصلاح التحذير هنا أيضاً
                  decoration: BoxDecoration(color: Colors.orange.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.local_offer, color: Colors.orange),
                ),
                title: const Text("عرض كميات (Bundle)"),
                subtitle: const Text("مثال: مخدة بـ 10، واثنتين بـ 15."),
                onTap: () {
                  Navigator.pop(context);
                  // إنشاء منتج جديد بنظام العروض (بدون id)
                  context.push('/admin/edit', extra: {'isOfferMode': true});
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: "بحث عن منتج بالاسم أو الكود...",
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF0A2647), width: 1)),
              ),
            ),
          ),

          // شريط الفلاتر المتقدمة
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: _buildFiltersBar(),
          ),
          
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _supabase
                  .from('products')
                  .stream(primaryKey: ['id'])
                  .order('created_at', ascending: false),
              builder: (context, snapshot) {
                // لا نظهر الخطأ للمستخدم، فقط نطبعه في الكونسول
                if (snapshot.hasError) {
                  debugPrint('Products stream error: ${snapshot.error}');
                }

                List<Map<String, dynamic>>? rawProducts;

                if (snapshot.hasData && !snapshot.hasError) {
                  rawProducts = snapshot.data;
                  _lastProductsRaw = snapshot.data;
                } else if (_lastProductsRaw != null) {
                  // في حال حدوث خطأ مؤقت في Realtime نستخدم آخر بيانات ناجحة
                  rawProducts = _lastProductsRaw;
                }

                // في حال عدم وجود أي بيانات (في البداية أو بعد فشل أولي)
                if (rawProducts == null || rawProducts.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }

                var products = rawProducts
                    .map((e) => Product.fromJson(e))
                    .toList();

                // 1) فلتر البحث
                if (_searchQuery.trim().isNotEmpty) {
                  final q = _searchQuery.trim().toLowerCase();
                  products = products
                      .where((p) =>
                          p.title.toLowerCase().contains(q) ||
                          p.id.toLowerCase().contains(q))
                      .toList();
                }

                // 2) فلتر القسم (بناءً على product.category)
                if (_selectedCategoryId != null && _selectedCategoryId!.isNotEmpty) {
                  products = products
                      .where((p) => p.category == _selectedCategoryId)
                      .toList();
                }

                // 3) فلتر حالة الظهور
                if (_isActiveFilter != null) {
                  products = products
                      .where((p) => p.isActive == _isActiveFilter)
                      .toList();
                }

                // 4) فلتر عروض الفلاش
                if (_isFlashFilter != null) {
                  products = products
                      .where((p) => p.isFlashDeal == _isFlashFilter)
                      .toList();
                }

                // 5) الفرز
                switch (_sortMode) {
                  case 'price_asc':
                    products.sort((a, b) => a.price.compareTo(b.price));
                    break;
                  case 'price_desc':
                    products.sort((a, b) => b.price.compareTo(a.price));
                    break;
                  case 'created_desc':
                  default:
                    // القائمة أصلاً مرتبة من Supabase حسب created_at desc
                    break;
                }

                if (products.isEmpty) {
                  return const Center(child: Text("لا توجد منتجات مطابقة للفلاتر الحالية"));
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                  itemCount: products.length,
                  itemBuilder: (context, index) {
                    final product = products[index];
                      // ✅ تم إصلاح الخطأ: المتغير الآن معرف في الموديل
                      final isFlash = product.isFlashDeal; 

                      final isActive = product.isActive;

                      return Card(
                        elevation: isActive ? 2 : 0,
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        color: isActive ? Colors.white : Colors.grey[200],
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: CachedNetworkImage(
                                  imageUrl: buildOptimizedImageUrl(
                                    product.imageUrl,
                                    variant: ImageVariant.thumbnail,
                                  ),
                                  width: 70,
                                  height: 70,
                                  fit: BoxFit.cover,
                                  memCacheHeight: 200,
                                  placeholder: (c,u) => Container(color: Colors.grey[200]),
                                  errorWidget: (c,u,e) => const Icon(Icons.error),
                                ),
                              ),
                              const SizedBox(width: 15),
                              
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(product.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16), maxLines: 1, overflow: TextOverflow.ellipsis),
                                    const SizedBox(height: 4),
                                    Text(
                                      "${product.price} د.أ",
                                      style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0A2647)),
                                    ),
                                    // ✅ تم إصلاح التحذير (dead_null_aware) بحذف ?? false الزائدة
                                    if (product.hasOffers)
                                      Container(
                                        margin: const EdgeInsets.only(top: 4),
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(color: Colors.orange[50], borderRadius: BorderRadius.circular(4)),
                                        child: const Text("عرض كميات 🔥", style: TextStyle(fontSize: 10, color: Colors.deepOrange)),
                                      ),
                                  ],
                                ),
                              ),

                              Row(
                                children: [
                                  IconButton(
                                    icon: Icon(
                                      isFlash ? FontAwesomeIcons.bolt : FontAwesomeIcons.bolt,
                                      color: isFlash ? Colors.amber : Colors.grey[300],
                                      size: 20,
                                    ),
                                    tooltip: "عرض فلاش",
                                    onPressed: () => _toggleFlashDeal(product),
                                  ),
                                  IconButton(
                                    icon: Icon(
                                      isActive ? Icons.visibility : Icons.visibility_off,
                                      color: isActive ? Colors.green : Colors.grey,
                                    ),
                                    tooltip: isActive ? 'إخفاء من المتجر' : 'إظهار في المتجر',
                                    onPressed: () => _toggleActive(product),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.edit_outlined, color: Colors.blue),
                                    onPressed: () async {
                                      // تعديل منتج موجود: نمرر both extra + id لدعم Deep Link و Refresh
                                      await context.push(
                                        '/admin/edit?id=${product.id}',
                                        extra: product,
                                      );
                                    },
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                                    onPressed: () => _deleteProduct(product),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
              },
            ),
          ),
        ],
      ),
      
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddProductDialog(context),
        label: const Text("إضافة منتج", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        icon: const Icon(Icons.add, color: Colors.white),
        backgroundColor: const Color(0xFF0A2647),
      ),
    );
  }
  Widget _buildFiltersBar() {
    return FutureBuilder<List<AppCategoryConfig>>(
      future: Supabase.instance.client
          .from('categories')
          .select('id,name,is_active,sort_order')
          .order('sort_order', ascending: true)
          .then((data) => data
              .whereType<Map<String, dynamic>>()
              .map(AppCategoryConfig.fromMap)
              .toList()),
      builder: (context, snapshot) {
        final categories = snapshot.data ?? const <AppCategoryConfig>[];

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              // فلتر القسم
              Container(
                margin: const EdgeInsetsDirectional.only(end: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String?>(
                    hint: const Text('كل الأقسام'),
                    value: _selectedCategoryId,
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('كل الأقسام'),
                      ),
                      ...categories.map(
                        (cat) => DropdownMenuItem<String?>(
                          value: cat.id,
                          child: Text(cat.name),
                        ),
                      ),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _selectedCategoryId = value;
                      });
                    },
                  ),
                ),
              ),

              // فلتر حالة الظهور
              Container(
                margin: const EdgeInsetsDirectional.only(end: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<bool?>(
                    hint: const Text('الكل (الظهور)'),
                    value: _isActiveFilter,
                    items: const [
                      DropdownMenuItem<bool?>(
                        value: null,
                        child: Text('الكل (الظهور)'),
                      ),
                      DropdownMenuItem<bool?>(
                        value: true,
                        child: Text('ظاهرة في المتجر'),
                      ),
                      DropdownMenuItem<bool?>(
                        value: false,
                        child: Text('مخفية من المتجر'),
                      ),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _isActiveFilter = value;
                      });
                    },
                  ),
                ),
              ),

              // فلتر عروض الفلاش
              Container(
                margin: const EdgeInsetsDirectional.only(end: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<bool?>(
                    hint: const Text('كل المنتجات'),
                    value: _isFlashFilter,
                    items: const [
                      DropdownMenuItem<bool?>(
                        value: null,
                        child: Text('كل المنتجات'),
                      ),
                      DropdownMenuItem<bool?>(
                        value: true,
                        child: Text('عروض فلاش فقط'),
                      ),
                      DropdownMenuItem<bool?>(
                        value: false,
                        child: Text('بدون عروض فلاش'),
                      ),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _isFlashFilter = value;
                      });
                    },
                  ),
                ),
              ),

              // فرز
              Container(
                margin: const EdgeInsetsDirectional.only(end: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    hint: const Text('ترتيب حسب'),
                    value: _sortMode,
                    items: const [
                      DropdownMenuItem<String>(
                        value: 'created_desc',
                        child: Text('الأحدث أولاً'),
                      ),
                      DropdownMenuItem<String>(
                        value: 'price_asc',
                        child: Text('السعر: من الأقل للأعلى'),
                      ),
                      DropdownMenuItem<String>(
                        value: 'price_desc',
                        child: Text('السعر: من الأعلى للأقل'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() {
                        _sortMode = value;
                      });
                    },
                  ),
                ),
              ),

              // زر إعادة تعيين الفلاتر
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _selectedCategoryId = null;
                    _isActiveFilter = null;
                    _isFlashFilter = null;
                    _sortMode = 'created_desc';
                  });
                },
                icon: const Icon(Icons.clear, size: 18),
                label: const Text('تصفير الفلاتر'),
              ),
            ],
          ),
        );
      },
    );
  }
}
