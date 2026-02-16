import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:meta_seo/meta_seo.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:timeago/timeago.dart' as timeago;

import 'app/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. إعداد الويب - Path URL Strategy لإزالة الـ # من الروابط
  if (kIsWeb) {
    MetaSEO().config();
    // تفعيل Path URL Strategy لروابط نظيفة: drstore.me/product/name
    await SystemChannels.platform.invokeMethod<void>('SystemNavigator.setUrlStrategy', 'path');
    debugPrint('URL Strategy set to path');
  }

  // 2. تحميل ملف الإعدادات (مع تقليل الضوضاء في الإصدار النهائي)
  var envLoaded = false;
  try {
    await dotenv.load(fileName: "assets/env.txt");
    envLoaded = dotenv.isInitialized;
    if (kDebugMode) {
      debugPrint("Env Loaded");
    }
  } catch (e) {
    if (kDebugMode) {
      debugPrint("Env Error: $e");
    }
  }

  String? safeEnv(String key) {
    if (!envLoaded || !dotenv.isInitialized) return null;
    return dotenv.maybeGet(key);
  }

  // 3. تهيئة Supabase مع حماية أفضل للإعدادات
  final supabaseUrl =
      safeEnv('SUPABASE_URL') ?? 'https://owgaklkhquntsqahmegt.supabase.co';
  final supabaseAnonKey = safeEnv('SUPABASE_ANON_KEY') ??
      'sb_publishable_smx9EmqfqEL-vAk6z29t3Q_6bHZXq7u';

  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );

  timeago.setLocaleMessages('ar', timeago.ArMessages());

  runApp(const ProviderScope(child: DoctorStoreApp()));
}
