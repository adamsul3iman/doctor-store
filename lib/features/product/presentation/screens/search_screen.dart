import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:doctor_store/features/product/domain/models/product_model.dart';
import 'package:doctor_store/features/product/presentation/widgets/product_card.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _controller = TextEditingController();
  List<Product> _results = [];
  bool _isLoading = false;

  void _search(String query) async {
    if (query.isEmpty) {
      setState(() => _results = []);
      return;
    }
    
    setState(() => _isLoading = true);
    
    try {
      // ✅ تم التصحيح: استبدال 'name' بـ 'title' ليتوافق مع قاعدة بياناتك
      final response = await Supabase.instance.client
          .from('products')
          .select()
          .eq('is_active', true)
          // البحث في: العنوان + الوصف
          .or('title.ilike.%$query%,description.ilike.%$query%')
          .order('created_at', ascending: false)
          .limit(60); // لا نرجع أكثر من 60 نتيجة في آن واحد لتخفيف الضغط

      setState(() {
        _results = (response as List).map((e) => Product.fromJson(e)).toList();
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("خطأ في عملية البحث: $e");
      setState(() {
        _isLoading = false;
        _results = [];
      });
      // إظهار رسالة خطأ للمستخدم
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("حدث خطأ أثناء الاتصال بقاعدة البيانات")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          textInputAction: TextInputAction.search, // تغيير زر الكيبورد لـ "بحث"
          decoration: const InputDecoration(
            hintText: "ابحث عن منتج بالاسم أو الوصف...",
            hintStyle: TextStyle(color: Colors.white70),
            border: InputBorder.none,
          ),
          onSubmitted: _search,
        ),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : _results.isEmpty && _controller.text.isNotEmpty
          ? const Center(child: Text("لم نجد نتائج تطابق بحثك!"))
          : _results.isEmpty && _controller.text.isEmpty
            ? const Center(child: Text("ابدأ بكتابة اسم المنتج للبحث"))
            : GridView.builder(
                padding: const EdgeInsets.all(10),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 260,
                  childAspectRatio: 0.64,
                  crossAxisSpacing: 15,
                  mainAxisSpacing: 15,
                ),
                itemCount: _results.length,
                itemBuilder: (context, index) => ProductCard(product: _results[index]),
              ),
    );
  }
}