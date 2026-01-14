import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// موديل بسيط للإعدادات
class AppSettings {
  static const String storeName = 'متجر الدكتور';

  final String whatsapp;
  final String facebook;
  final String instagram;
  final String tiktok;
  final String ownerName;
  /// رابط صورة صاحب المتجر المستخدمة في قسم OwnerSection في الهوم
  final String ownerImageUrl;

  AppSettings({
    required this.whatsapp,
    required this.facebook,
    required this.instagram,
    required this.tiktok,
    required this.ownerName,
    required this.ownerImageUrl,
  });

  factory AppSettings.fromMap(Map<String, dynamic> map) {
    return AppSettings(
      whatsapp: map['whatsapp_number'] ?? '',
      facebook: map['facebook_url'] ?? '',
      instagram: map['instagram_url'] ?? '',
      tiktok: map['tiktok_url'] ?? '',
      ownerName: map['owner_name'] ?? '',
      ownerImageUrl: map['owner_image_url'] ?? '',
    );
  }
}

// المزود (Provider) الذي تستخدمه الشاشات
// تم تحويله إلى StreamProvider حتى تنعكس تغييرات لوحة الأدمن مباشرة
// على الهوم (زر الواتساب، قسم صاحب المتجر، إلخ) بدون إعادة تحميل.
final settingsProvider = StreamProvider<AppSettings>((ref) async* {
  final supabase = Supabase.instance.client;

  try {
    final stream = supabase
        .from('app_settings')
        .stream(primaryKey: ['id'])
        .eq('id', 1);

    await for (final rows in stream) {
      if (rows.isEmpty) {
        yield AppSettings(
          whatsapp: '',
          facebook: '',
          instagram: '',
          tiktok: '',
          ownerName: '',
          ownerImageUrl: '',
        );
      } else {
        yield AppSettings.fromMap(rows.first);
      }
    }
  } catch (_) {
    yield AppSettings(
      whatsapp: '',
      facebook: '',
      instagram: '',
      tiktok: '',
      ownerName: '',
      ownerImageUrl: '',
    );
  }
});
