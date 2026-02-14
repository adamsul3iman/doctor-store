import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:doctor_store/shared/widgets/constrained_dialog.dart';

class WelcomeDialog extends ConsumerStatefulWidget {
  const WelcomeDialog({super.key});

  @override
  ConsumerState<WelcomeDialog> createState() => _WelcomeDialogState();
}

class _WelcomeDialogState extends ConsumerState<WelcomeDialog> {
  final _emailController = TextEditingController();
  bool _isLoading = false;
  
  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _registerClient() async {
    final email = _emailController.text.trim();
    
    // التحقق من صحة الإيميل
    if (email.isEmpty || !email.contains('@')) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("يرجى كتابة بريد إلكتروني صحيح لإكمال التسجيل."),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 1. محاولة الحفظ في Supabase (تخزين العميل)
      try {
        await Supabase.instance.client.from('clients').insert({'email': email});
      } catch (e) {
        // نتجاهل الخطأ إذا كان الإيميل مسجلاً مسبقاً في قاعدة البيانات
        debugPrint("Email might already exist: $e");
      }

      // 2. الحفظ المحلي في الهاتف
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('is_registered_client', true);
      // لا نستخدم user_email هنا لأن المفضلة أصبحت بعد تسجيل الدخول فقط.
      // نحتفظ بالإيميل كاشتراك (newsletter) فقط.
      await prefs.setString('newsletter_email', email);

      // ✅ الإصلاح الأساسي: التحقق من أن الواجهة لا تزال موجودة قبل التفاعل معها
      if (mounted) {
        Navigator.pop(context); // إغلاق النافذة
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("تم التسجيل بنجاح! ❤️"), 
            backgroundColor: Color(0xFF25D366),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text("تعذّر إتمام التسجيل حالياً، حاول مرة أخرى لاحقاً."),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      elevation: 5,
      child: ConstrainedDialog(
        maxWidth: 550,
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
            // أيقونة في الأعلى
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                // ✅ استخدام withValues (الطريقة الحديثة)
                color: const Color(0xFF0A2647).withValues(alpha: 0.1), 
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.favorite, size: 40, color: Color(0xFF0A2647)),
            ),
            
            const SizedBox(height: 20),
            
            Text(
              "احفظ مفضلتك للأبد!", 
              style: GoogleFonts.almarai(fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            
            const SizedBox(height: 10),
            
            Text(
              "سجل بريدك الإلكتروني لنحفظ لك المنتجات التي تعجبك في حسابك، ولتصلك أحدث العروض.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600], height: 1.5, fontSize: 13),
            ),
            
            const SizedBox(height: 20),
            
            // حقل الإدخال
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: "البريد الإلكتروني",
                prefixIcon: const Icon(Icons.email_outlined, color: Colors.grey),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                filled: true,
                fillColor: Colors.grey[50],
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF0A2647), width: 1.5),
                ),
              ),
            ),
            
            const SizedBox(height: 25),
            
            // زر التسجيل
            SizedBox(
              width: double.infinity,
              height: 45,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _registerClient,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0A2647),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: _isLoading 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                  : const Text("حفظ وانضمام", style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
            
            const SizedBox(height: 10),
            
            // زر التخطي
            TextButton(
              onPressed: () async {
                // ✅ حفظ خيار "تمت المشاهدة" حتى لا تظهر النافذة مرة أخرى
                final prefs = await SharedPreferences.getInstance();
                await prefs.setBool('is_registered_client', true);
                
                // ✅ الحماية هنا أيضاً (آمن لأنه يتحقق من mounted قبل استخدام context)
                // ignore: use_build_context_synchronously
                if (mounted) Navigator.pop(context);
              },
              child: const Text("تصفح كزائر (تخطي)", style: TextStyle(color: Colors.grey, fontSize: 12)),
            ),
            ],
          ),
        ),
      ),
    );
  }
}