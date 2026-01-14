import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:doctor_store/features/auth/application/user_data_manager.dart';
import 'package:doctor_store/shared/utils/wishlist_manager.dart';

class SmartHeader extends ConsumerWidget {
  const SmartHeader({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userProfileProvider);
    final wishlistCount = ref.watch(wishlistProvider).length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.withValues(alpha: 0.1))), // خط فاصل خفيف
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // ================= الجزء الخاص بالحساب (الذكي) =================
          Expanded(
            child: InkWell(
              onTap: () {
                if (user.isGuest) {
                  // زائر: التوجيه لصفحة /login الجديدة
                  context.go('/login');
                } else {
                  // الذهاب للملف الشخصي
                  context.push('/profile');
                }
              },
              child: Row(
                children: [
                  // الأيقونة أو الصورة
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: user.isGuest ? const Color(0xFF0A2647) : const Color(0xFFD4AF37), // لون مختلف للمسجل
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 4),
                      ],
                    ),
                    child: Center(
                      child: user.isGuest
                          ? const Icon(Icons.person_outline, color: Colors.white, size: 20)
                          : Text(
                              user.name.isNotEmpty ? user.name[0].toUpperCase() : "U",
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  
                  // النصوص الترحيبية
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.isGuest ? "أهلاً بك زائرنا" : "مرحباً، ${user.name.split(' ')[0]}", // نأخذ الاسم الأول فقط
                        style: GoogleFonts.almarai(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF0A2647),
                        ),
                      ),
                      Text(
                        user.isGuest ? "سجل الدخول للمزيد" : "عرض حسابي",
                        style: GoogleFonts.almarai(
                          fontSize: 10,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // ================= الجزء الخاص بالمفضلة (الإضافي) =================
          InkWell(
            onTap: () => context.push('/wishlist'), // تأكد من وجود route للمفضلة
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Row(
                children: [
                  Icon(
                    wishlistCount > 0 ? Icons.favorite : Icons.favorite_border,
                    size: 18,
                    color: wishlistCount > 0 ? Colors.red : Colors.grey,
                  ),
                  if (wishlistCount > 0) ...[
                    const SizedBox(width: 6),
                    Text(
                      "$wishlistCount",
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ]
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}