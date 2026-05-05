import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:timeago/timeago.dart' as timeago;

import 'app/app.dart';
import 'package:doctor_store/shared/utils/seo_manager.dart';
import 'package:doctor_store/shared/utils/web_bootstrap.dart';
import 'package:doctor_store/shared/services/image_cache_config.dart';
import 'package:doctor_store/shared/services/app_review_service.dart';

Future<void> main() async {
  // ✅ Web-only bootstrap (guarded via conditional imports)
  if (kIsWeb) {
    setupUrlStrategy();
  }
  
  WidgetsFlutterBinding.ensureInitialized();

  // تهيئة كاش الصور للأداء الأفضل على Android
  await ImageCacheConfig.init();

  // زيادة عدد فتحات التطبيق (لتقييم الاستخدام)
  await AppReviewService().incrementLaunchCount();

  // BUILD_VERSION: 9 - Path URL Strategy with redirect-based deep links
  if (kIsWeb) {
    SeoManager.init();
  }

  // Service Worker cleanup
  if (kIsWeb) {
    await cleanupServiceWorkers();
  }

  // تحميل الإعدادات - يدعم env.txt (محلي) أو --dart-define (Vercel/إنتاج)
  var envLoaded = false;
  try {
    await dotenv.load(fileName: "assets/env.txt");
    envLoaded = dotenv.isInitialized;
    if (kDebugMode) debugPrint("Env Loaded from assets/env.txt");
  } catch (e) {
    if (kDebugMode) debugPrint("Env Error (expected in production): $e");
  }

  String? safeEnv(String key) {
    // أولاً: تحقق من compile-time environment variables (--dart-define)
    const compileTimeValue = String.fromEnvironment('SUPABASE_URL');
    if (compileTimeValue.isNotEmpty && key == 'SUPABASE_URL') {
      return compileTimeValue;
    }
    const compileTimeKey = String.fromEnvironment('SUPABASE_ANON_KEY');
    if (compileTimeKey.isNotEmpty && key == 'SUPABASE_ANON_KEY') {
      return compileTimeKey;
    }
    // ثانياً: fallback إلى env.txt إذا كان محملاً
    if (!envLoaded || !dotenv.isInitialized) return null;
    return dotenv.maybeGet(key);
  }

  // تهيئة Supabase - يدعم env.txt محلياً أو --dart-define في الإنتاج
  final supabaseUrl = safeEnv('SUPABASE_URL');
  final supabaseAnonKey = safeEnv('SUPABASE_ANON_KEY');

  if (supabaseUrl == null || supabaseUrl.isEmpty) {
    throw StateError(
      'MISSING SUPABASE_URL: Add to assets/env.txt (local) or pass --dart-define=SUPABASE_URL=... (build).',
    );
  }
  if (supabaseAnonKey == null || supabaseAnonKey.isEmpty) {
    throw StateError(
      'MISSING SUPABASE_ANON_KEY: Add to assets/env.txt (local) or pass --dart-define=SUPABASE_ANON_KEY=... (build).',
    );
  }

  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );

  timeago.setLocaleMessages('ar', timeago.ArMessages());

  runApp(const ProviderScope(child: DoctorStoreApp()));
}
