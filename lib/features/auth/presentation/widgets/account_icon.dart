import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'package:doctor_store/features/auth/application/user_data_manager.dart';
import 'package:doctor_store/shared/utils/image_url_helper.dart';

class AccountIcon extends ConsumerWidget {
  final Color? color;

  const AccountIcon({super.key, this.color});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userProfileProvider);

    return InkWell(
      borderRadius: BorderRadius.circular(50),
      onTap: () {
        if (user.isGuest) {
          // زائر: نرسله إلى صفحة /login الجديدة
          context.go('/login');
        } else {
          // مسجل: نذهب به للملف الشخصي
          context.push('/profile');
        }
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8),
        padding: const EdgeInsets.all(2), // حدود خفيفة
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: user.isGuest ? Colors.transparent : const Color(0xFFD4AF37), // إطار ذهبي للمسجل
            width: 1.5,
          ),
        ),
        child: CircleAvatar(
          radius: 15, // حجم الأيقونة
          backgroundColor: user.isGuest || user.avatarUrl.isNotEmpty
              ? Colors.transparent
              : const Color(0xFF0A2647),
          backgroundImage: !user.isGuest && user.avatarUrl.isNotEmpty
              ? CachedNetworkImageProvider(
                  buildOptimizedImageUrl(
                    user.avatarUrl,
                    variant: ImageVariant.thumbnail,
                  ),
                )
              : null,
          child: user.isGuest
              ? Icon(
                  PhosphorIcons.user(),
                  color: color ?? const Color(0xFF0A2647),
                  size: 22,
                )
              : (user.avatarUrl.isNotEmpty
                  ? null
                  : Text(
                      user.name.isNotEmpty ? user.name[0].toUpperCase() : "U",
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    )),
        ),
      ),
    );
  }
}