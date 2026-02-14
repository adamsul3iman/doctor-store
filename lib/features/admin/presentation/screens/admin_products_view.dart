import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:doctor_store/features/product/domain/models/product_model.dart';
import 'package:doctor_store/shared/utils/app_notifier.dart';
import 'package:doctor_store/shared/utils/categories_provider.dart';
import 'package:doctor_store/shared/utils/image_url_helper.dart';
import 'package:doctor_store/shared/widgets/app_network_image.dart';
import 'package:doctor_store/features/admin/data/admin_product_repository.dart';
import 'package:doctor_store/features/admin/data/category_repository.dart';

class AdminProductsView extends StatefulWidget {
  const AdminProductsView({super.key});

  @override
  State<AdminProductsView> createState() => _AdminProductsViewState();
}

class _AdminProductsViewState extends State<AdminProductsView> {
  final AdminProductRepository _repo = AdminProductRepository();
  final CategoryRepository _categoryRepo = CategoryRepository();
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  String _searchQuery = '';

  final ScrollController _scrollController = ScrollController();

  static const int _pageSize = 60;
  bool _isLoadingPage = false;
  bool _hasMore = true;
  String? _loadError;
  final List<Product> _products = <Product>[];

  bool _showFiltersDesktop = false;

  // فلاتر متقدمة
  String? _selectedCategoryId; // null = الكل
  bool? _isActiveFilter; // null = الكل، true = ظاهرة، false = مخفية
  bool? _isFlashFilter; // null = الكل، true = عروض فلاش فقط، false = غير عروض فلاش
  String _sortMode = 'created_desc'; // created_desc, price_asc, price_desc

  @override
  void initState() {
    super.initState();

    _scrollController.addListener(() {
      if (!_hasMore || _isLoadingPage) return;
      final pos = _scrollController.position;
      if (pos.pixels >= pos.maxScrollExtent - 260) {
        _loadNextPage();
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshProducts();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _refreshProducts() async {
    setState(() {
      _products.clear();
      _hasMore = true;
      _loadError = null;
    });
    await _loadNextPage();
  }

  Future<void> _loadNextPage() async {
    if (_isLoadingPage || !_hasMore) return;
    setState(() {
      _isLoadingPage = true;
      _loadError = null;
    });

    try {
      final raw = await _repo.fetchProductsPage(
        limit: _pageSize,
        offset: _products.length,
        searchQuery: _searchQuery,
        categoryId: _selectedCategoryId,
        isActive: _isActiveFilter,
        isFlashDeal: _isFlashFilter,
        sortMode: _sortMode,
      );

      final fetched = raw.map((e) => Product.fromJson(e)).toList();
      if (!mounted) return;
      setState(() {
        _products.addAll(fetched);
        _hasMore = fetched.length == _pageSize;
        _isLoadingPage = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingPage = false;
        _loadError = e.toString();
      });
    }
  }
  // ✅ تم إصلاح الخطأ هنا بعد تحديث الموديل
  Future<void> _toggleFlashDeal(Product product) async {
    final newValue = !product.isFlashDeal; // لم يعد هناك خطأ لأن الموديل تعرف عليه

    await _repo.setFlashDeal(productId: product.id, isFlashDeal: newValue);
    // لا حاجة لإعادة الجلب، StreamBuilder سيلتقط التغيير تلقائياً
  }

  /// تفعيل / إخفاء المنتج من المتجر (soft delete) عبر is_active
  Future<void> _toggleActive(Product product) async {
    final newValue = !product.isActive;
    try {
      await _repo.setActive(productId: product.id, isActive: newValue);
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
      _refreshProducts();
    });
  }

  int? _computeTotalStock(Product p) {
    // Prefer variant stock when present.
    if (p.variants.isNotEmpty) {
      int sum = 0;
      bool hasAny = false;
      for (final v in p.variants) {
        final s = v.stock;
        if (s == null) continue;
        hasAny = true;
        sum += s;
      }
      if (hasAny) return sum;
    }

    // Fallback to base stock stored in options when using track_qty.
    final raw = p.options['stock'];
    if (raw is num) return raw.toInt();
    return null;
  }

  ({String policy, bool? inStock}) _resolveInventory(Product p) {
    final raw = p.options['inventory_policy'];
    final policy = raw is String && raw.isNotEmpty ? raw : 'track_qty';

    if (policy == 'always_in_stock') {
      return (policy: policy, inStock: true);
    }

    if (policy == 'status_based') {
      final rawInStock = p.options['in_stock'];
      return (policy: policy, inStock: rawInStock is bool ? rawInStock : true);
    }

    // track_qty
    final total = _computeTotalStock(p);
    if (total == null) return (policy: policy, inStock: null);
    return (policy: policy, inStock: total > 0);
  }

  Widget _statusChip({required String label, required Color bg, required Color fg}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: fg.withValues(alpha: 0.25)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: fg,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildToolbar({required bool isDesktop}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'بحث بالاسم أو الكود...',
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFFF6F00), width: 1),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          OutlinedButton.icon(
            onPressed: () {
              if (isDesktop) {
                setState(() => _showFiltersDesktop = !_showFiltersDesktop);
              } else {
                _openFiltersBottomSheet();
              }
            },
            icon: Icon(
              Icons.filter_alt_outlined,
              color: _showFiltersDesktop && isDesktop
                  ? const Color(0xFFFF6F00)
                  : const Color(0xFF0A2647),
            ),
            label: const Text('فلاتر'),
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            onPressed: () => _showAddProductDialog(context),
            icon: const Icon(Icons.add),
            label: const Text('إضافة منتج'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0A2647),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openFiltersBottomSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final h = MediaQuery.of(context).size.height;
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: h * 0.8),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: _buildFiltersContent(isDesktop: false),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFiltersContent({required bool isDesktop}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(Icons.tune, color: Color(0xFFFF6F00)),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'الفلاتر',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
            ),
            if (!isDesktop)
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
          ],
        ),
        const SizedBox(height: 12),

        FutureBuilder<List<AppCategoryConfig>>(
          future: _categoryRepo.getCategories(),
          builder: (context, snapshot) {
            final categories = snapshot.data ?? const <AppCategoryConfig>[];
            return DropdownButtonFormField<String?>(
              initialValue: _selectedCategoryId,
              decoration: const InputDecoration(
                labelText: 'القسم',
                prefixIcon: Icon(Icons.category_outlined),
              ),
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
                setState(() => _selectedCategoryId = value);
                _refreshProducts();
              },
            );
          },
        ),
        const SizedBox(height: 12),

        DropdownButtonFormField<bool?>(
          initialValue: _isActiveFilter,
          decoration: const InputDecoration(
            labelText: 'حالة الظهور',
            prefixIcon: Icon(Icons.visibility_outlined),
          ),
          items: const [
            DropdownMenuItem<bool?>(value: null, child: Text('الكل')),
            DropdownMenuItem<bool?>(value: true, child: Text('نشط')),
            DropdownMenuItem<bool?>(value: false, child: Text('مخفي')),
          ],
          onChanged: (value) {
            setState(() => _isActiveFilter = value);
            _refreshProducts();
          },
        ),
        const SizedBox(height: 12),

        DropdownButtonFormField<bool?>(
          initialValue: _isFlashFilter,
          decoration: const InputDecoration(
            labelText: 'عروض الفلاش',
            prefixIcon: Icon(FontAwesomeIcons.bolt),
          ),
          items: const [
            DropdownMenuItem<bool?>(value: null, child: Text('الكل')),
            DropdownMenuItem<bool?>(value: true, child: Text('فلاش فقط')),
            DropdownMenuItem<bool?>(value: false, child: Text('بدون فلاش')),
          ],
          onChanged: (value) {
            setState(() => _isFlashFilter = value);
            _refreshProducts();
          },
        ),
        const SizedBox(height: 12),

        DropdownButtonFormField<String>(
          initialValue: _sortMode,
          decoration: const InputDecoration(
            labelText: 'الترتيب',
            prefixIcon: Icon(Icons.sort),
          ),
          items: const [
            DropdownMenuItem<String>(value: 'created_desc', child: Text('الأحدث أولاً')),
            DropdownMenuItem<String>(value: 'price_asc', child: Text('السعر: من الأقل للأعلى')),
            DropdownMenuItem<String>(value: 'price_desc', child: Text('السعر: من الأعلى للأقل')),
          ],
          onChanged: (value) {
            if (value == null) return;
            setState(() => _sortMode = value);
            _refreshProducts();
          },
        ),
        const SizedBox(height: 12),

        OutlinedButton.icon(
          onPressed: () {
            setState(() {
              _selectedCategoryId = null;
              _isActiveFilter = null;
              _isFlashFilter = null;
              _sortMode = 'created_desc';
            });
            _refreshProducts();
          },
          icon: const Icon(Icons.restart_alt),
          label: const Text('إعادة تعيين'),
        ),
      ],
    );
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
      final deleted = await _repo.deleteProduct(product.id);

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
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final h = MediaQuery.of(context).size.height;
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: h * 0.75),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    "ما نوع المنتج الذي تريد إضافته؟",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0A2647),
                    ),
                  ),
                  const SizedBox(height: 20),

                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      // ✅ تم إصلاح التحذير: استخدام withValues بدلاً من withOpacity
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
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
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
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

                  const Divider(height: 20),

                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.teal.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.bed, color: Colors.teal),
                    ),
                    title: const Text("فرشة (مقاسات وتسعير تلقائي)"),
                    subtitle: const Text(
                      "إضافة فرشات بنظام مقاسات مع تسعير احترافي بدون إدخال كل مقاس يدوياً.",
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      context.push('/admin/edit', extra: {'preset': 'mattress'});
                    },
                  ),

                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth >= 900;

          return Column(
            children: [
              _buildToolbar(isDesktop: isDesktop),
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: _products.isEmpty
                          ? Center(
                              child: _isLoadingPage
                                  ? const CircularProgressIndicator()
                                  : Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const Text('لا توجد منتجات مطابقة للبحث/الفلاتر'),
                                        if (_loadError != null) ...[
                                          const SizedBox(height: 8),
                                          Text(
                                            'حدث خطأ أثناء التحميل: $_loadError',
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(color: Colors.red),
                                          ),
                                          const SizedBox(height: 8),
                                          OutlinedButton.icon(
                                            onPressed: _refreshProducts,
                                            icon: const Icon(Icons.refresh),
                                            label: const Text('إعادة المحاولة'),
                                          ),
                                        ],
                                      ],
                                    ),
                            )
                          : Scrollbar(
                              controller: _scrollController,
                              child: SingleChildScrollView(
                                controller: _scrollController,
                                child: Column(
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                                      child: Card(
                                        elevation: 1,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(16),
                                        ),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(16),
                                          child: SingleChildScrollView(
                                            scrollDirection: Axis.horizontal,
                                            child: ConstrainedBox(
                                              constraints: BoxConstraints(
                                                minWidth: isDesktop
                                                    ? constraints.maxWidth -
                                                        32 -
                                                        (_showFiltersDesktop ? 320 : 0)
                                                    : constraints.maxWidth - 32,
                                              ),
                                              child: SingleChildScrollView(
                                                child: DataTable(
                                                  headingRowColor: WidgetStatePropertyAll(
                                                    const Color(0xFF0A2647).withValues(alpha: 0.06),
                                                  ),
                                                  dataRowMinHeight: 64,
                                                  dataRowMaxHeight: 76,
                                                  columns: const [
                                                    DataColumn(label: Text('الصورة')),
                                                    DataColumn(label: Text('الاسم')),
                                                    DataColumn(label: Text('القسم')),
                                                    DataColumn(label: Text('السعر')),
                                                    DataColumn(label: Text('المخزون')),
                                                    DataColumn(label: Text('الحالة')),
                                                    DataColumn(label: Text('إجراءات')),
                                                  ],
                                                  rows: _products.map((product) {
                                                    final inv = _resolveInventory(product);
                                                    final totalStock = _computeTotalStock(product);
                                                    final isActive = product.isActive;
                                                    final isOutOfStock = inv.policy == 'track_qty'
                                                        ? (totalStock != null && totalStock <= 0)
                                                        : (inv.inStock == false);

                                                    Widget status;
                                                    if (!isActive) {
                                                      status = _statusChip(
                                                        label: 'مخفي',
                                                        bg: Colors.grey.withValues(alpha: 0.12),
                                                        fg: Colors.grey.shade700,
                                                      );
                                                    } else if (isOutOfStock) {
                                                      status = _statusChip(
                                                        label: 'نفد المخزون',
                                                        bg: Colors.red.withValues(alpha: 0.10),
                                                        fg: Colors.red.shade700,
                                                      );
                                                    } else {
                                                      status = _statusChip(
                                                        label: 'نشط',
                                                        bg: Colors.green.withValues(alpha: 0.10),
                                                        fg: Colors.green.shade700,
                                                      );
                                                    }

                                                    Widget stockCell;
                                                    if (inv.policy == 'always_in_stock') {
                                                      stockCell = _statusChip(
                                                        label: 'متوفر دائماً',
                                                        bg: Colors.green.withValues(alpha: 0.10),
                                                        fg: Colors.green.shade800,
                                                      );
                                                    } else if (inv.policy == 'status_based') {
                                                      stockCell = _statusChip(
                                                        label: (inv.inStock ?? true) ? 'متوفر' : 'غير متوفر',
                                                        bg: (inv.inStock ?? true)
                                                            ? Colors.green.withValues(alpha: 0.10)
                                                            : Colors.red.withValues(alpha: 0.10),
                                                        fg: (inv.inStock ?? true)
                                                            ? Colors.green.shade800
                                                            : Colors.red.shade800,
                                                      );
                                                    } else {
                                                      stockCell = Text(
                                                        totalStock?.toString() ?? '-',
                                                        style: const TextStyle(fontWeight: FontWeight.w600),
                                                      );
                                                    }

                                                    return DataRow(
                                                      cells: [
                                                        DataCell(
                                                          ClipRRect(
                                                            borderRadius: BorderRadius.circular(10),
                                                            child: SizedBox(
                                                              width: 46,
                                                              height: 46,
                                                              child: AppNetworkImage(
                                                                url: product.imageUrl,
                                                                variant: ImageVariant.thumbnail,
                                                                fit: BoxFit.cover,
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                        DataCell(
                                                          ConstrainedBox(
                                                            constraints: const BoxConstraints(maxWidth: 280),
                                                            child: Text(
                                                              product.title,
                                                              maxLines: 2,
                                                              overflow: TextOverflow.ellipsis,
                                                              style: const TextStyle(fontWeight: FontWeight.w700),
                                                            ),
                                                          ),
                                                        ),
                                                        DataCell(Text(product.categoryArabic)),
                                                        DataCell(Text('${product.price.toStringAsFixed(2)} د.أ')),
                                                        DataCell(stockCell),
                                                        DataCell(status),
                                                        DataCell(
                                                          Row(
                                                            children: [
                                                              IconButton(
                                                                tooltip: 'فلاش',
                                                                onPressed: () => _toggleFlashDeal(product),
                                                                icon: Icon(
                                                                  FontAwesomeIcons.bolt,
                                                                  size: 18,
                                                                  color: product.isFlashDeal
                                                                      ? Colors.amber
                                                                      : Colors.grey.withValues(alpha: 0.5),
                                                                ),
                                                              ),
                                                              IconButton(
                                                                tooltip: isActive ? 'إخفاء' : 'إظهار',
                                                                onPressed: () => _toggleActive(product),
                                                                icon: Icon(
                                                                  isActive ? Icons.visibility : Icons.visibility_off,
                                                                  color: isActive ? Colors.green : Colors.grey,
                                                                ),
                                                              ),
                                                              IconButton(
                                                                tooltip: 'تعديل',
                                                                onPressed: () async {
                                                                  await context.push(
                                                                    '/admin/edit?id=${product.id}',
                                                                    extra: product,
                                                                  );
                                                                },
                                                                icon: const Icon(
                                                                  Icons.edit_outlined,
                                                                  color: Color(0xFF0A2647),
                                                                ),
                                                              ),
                                                              IconButton(
                                                                tooltip: 'حذف',
                                                                onPressed: () => _deleteProduct(product),
                                                                icon: const Icon(
                                                                  Icons.delete_outline,
                                                                  color: Colors.red,
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                      ],
                                                    );
                                                  }).toList(),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    if (_isLoadingPage)
                                      const Padding(
                                        padding: EdgeInsets.only(bottom: 16),
                                        child: CircularProgressIndicator(),
                                      )
                                    else if (_loadError != null)
                                      Padding(
                                        padding: const EdgeInsets.only(bottom: 16),
                                        child: OutlinedButton.icon(
                                          onPressed: _loadNextPage,
                                          icon: const Icon(Icons.refresh),
                                          label: const Text('إعادة المحاولة'),
                                        ),
                                      )
                                    else if (_hasMore)
                                      Padding(
                                        padding: const EdgeInsets.only(bottom: 16),
                                        child: OutlinedButton.icon(
                                          onPressed: _loadNextPage,
                                          icon: const Icon(Icons.expand_more),
                                          label: const Text('تحميل المزيد'),
                                        ),
                                      )
                                    else
                                      const SizedBox(height: 16),
                                  ],
                                ),
                              ),
                            ),
                    ),

                    if (isDesktop)
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOut,
                        width: _showFiltersDesktop ? 320 : 0,
                        child: _showFiltersDesktop
                            ? Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  border: Border(
                                    left: BorderSide(
                                      color: Colors.grey.withValues(alpha: 0.2),
                                    ),
                                  ),
                                ),
                                child: _buildFiltersContent(isDesktop: true),
                              )
                            : null,
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
