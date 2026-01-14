import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:doctor_store/features/product/domain/models/product_model.dart';
import 'product_form_screen.dart';

/// Wrapper مخصص لصفحة تعديل المنتج في الأدمن
/// يسمح بفتح `/admin/edit?id=PRODUCT_ID` مباشرة (Deep Link)
/// مع إعادة تحميل بيانات المنتج عند عمل Refresh على المتصفح.
class AdminProductEditWrapper extends StatefulWidget {
  final String productId;

  const AdminProductEditWrapper({super.key, required this.productId});

  @override
  State<AdminProductEditWrapper> createState() => _AdminProductEditWrapperState();
}

class _AdminProductEditWrapperState extends State<AdminProductEditWrapper> {
  late final Future<Product?> _productFuture;

  @override
  void initState() {
    super.initState();
    _productFuture = _fetchProduct(widget.productId);
  }

  Future<Product?> _fetchProduct(String id) async {
    try {
      final data = await Supabase.instance.client
          .from('products')
          .select()
          .eq('id', id)
          .single();
      return Product.fromJson(Map<String, dynamic>.from(data as Map));
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: FutureBuilder<Product?>(
        future: _productFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF0A2647)),
            );
          }

          if (!snapshot.hasData || snapshot.data == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 60, color: Colors.red),
                  const SizedBox(height: 16),
                  const Text(
                    'تعذّر تحميل بيانات المنتج. ربما تم حذفه أو أن الرابط غير صحيح.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('رجوع'),
                  ),
                ],
              ),
            );
          }

          final product = snapshot.data!;
          return ProductFormScreen(
            extra: product,
            productToEdit: product,
          );
        },
      ),
    );
  }
}
