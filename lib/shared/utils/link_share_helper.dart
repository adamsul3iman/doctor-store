import 'package:share_plus/share_plus.dart';

import 'app_constants.dart';

/// Helper لبناء رابط كامل (Full URL) لأي صفحة داخل المتجر.
/// يستخدم صيغة https://domain.com/path للـ Path URL Strategy (بدون #)
String buildFullUrl(String path) {
  final normalized = path.startsWith('/') ? path : '/$path';
  const base = AppConstants.webBaseUrl;

  if (base.isEmpty) {
    return normalized;
  }

  return '$base$normalized';
}

/// مشاركة صفحة عامة داخل المتجر (الرئيسية، السلة، قسم، صفحة كل المنتجات...)
Future<void> shareAppPage({
  required String path,
  required String title,
  String? message,
}) async {
  final url = buildFullUrl(path);
  final buffer = StringBuffer(title);

  if (message != null && message.trim().isNotEmpty) {
    buffer.writeln('\n$message');
  }

  buffer.writeln('\n$url');

  // استخدام Share.share من share_plus (يتوافق مع المنصات المختلفة)
  // في حال ظهور تحذير deprecation من المكتبة يمكن ترقيتها لاحقاً،
  // لكن هذا الاستدعاء مستقر حالياً ومجرب.
  // ignore: deprecated_member_use
  await Share.share(
    buffer.toString(),
    subject: title,
  );
}
