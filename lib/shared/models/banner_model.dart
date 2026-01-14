import 'package:flutter/material.dart';

class AppBanner {
  final String id;
  final String title;
  final String subtitle;
  final String imageUrl;
  final bool isActive;
  // الحقول الجديدة
  final String buttonText;
  final String linkTarget;
  final String textColorString; // نخزن السترنج القادم من الداتابيس
  final int sortOrder;
  final String position;

  AppBanner({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.imageUrl,
    required this.isActive,
    required this.buttonText,
    required this.linkTarget,
    required this.textColorString,
    required this.sortOrder,
    required this.position,
  });

  factory AppBanner.fromJson(Map<String, dynamic> json) {
    return AppBanner(
      id: json['id']?.toString() ?? '',
      title: json['title'] as String? ?? '',
      subtitle: json['subtitle'] as String? ?? '',
      imageUrl: json['image_url'] as String? ?? '',
      // يتوافق مع عمود is_active في قاعدة البيانات
      isActive: json['is_active'] as bool? ?? true,
      buttonText: json['button_text'] as String? ?? 'تسوق الآن',
      linkTarget: json['link_target'] as String? ?? '/',
      textColorString: (json['text_color'] as String?) ?? '0xFFFFFFFF',
      sortOrder: (json['sort_order'] as int?) ?? 0,
      position: json['position'] as String? ?? 'top',
    );
  }

  // دالة مساعدة لتحويل النص إلى لون حقيقي
  Color get textColor {
    try {
      var hex = textColorString.trim().toLowerCase();
      // إزالة البادئة 0x أو # إن وُجدت
      if (hex.startsWith('0x')) {
        hex = hex.substring(2);
      } else if (hex.startsWith('#')) {
        hex = hex.substring(1);
      }
      // في حال كان الطول 6 أحرف فقط (RGB) نضيف قيمة ألفا كاملة
      if (hex.length == 6) {
        hex = 'ff$hex';
      }
      final value = int.parse(hex, radix: 16);
      return Color(value);
    } catch (_) {
      // في حال أي خطأ، نرجع أبيض كخيار آمن
      return Colors.white;
    }
  }
}
