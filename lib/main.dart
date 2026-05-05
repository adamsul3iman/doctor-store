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

  // تحميل الإعدادات
  var envLoaded = false;
  try {
    // Use correct path for Flutter Web - assets are served from root
    await dotenv.load(fileName: "assets/env.txt");
    envLoaded = dotenv.isInitialized;
    if (kDebugMode) debugPrint("Env Loaded");
  } catch (e) {
    if (kDebugMode) debugPrint("Env Error: $e");
  }

  String? safeEnv(String key) {
    if (!envLoaded || !dotenv.isInitialized) return null;
    return dotenv.maybeGet(key);
  }

  // تهيئة Supabase - يتطلب قيمًا من env.txt فقط (لا fallback hardcoded)
  final supabaseUrl = safeEnv('SUPABASE_URL');
  final supabaseAnonKey = safeEnv('SUPABASE_ANON_KEY');

  if (supabaseUrl == null || supabaseUrl.isEmpty) {
    throw StateError(
      'MISSING SUPABASE_URL: Add SUPABASE_URL to assets/env.txt. '
      'Example: SUPABASE_URL=https://your-project.supabase.co',
    );
  }
  if (supabaseAnonKey == null || supabaseAnonKey.isEmpty) {
    throw StateError(
      'MISSING SUPABASE_ANON_KEY: Add SUPABASE_ANON_KEY to assets/env.txt. '
      'Get it from Supabase Dashboard > Project Settings > API.',
    );
  }

  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );

  timeago.setLocaleMessages('ar', timeago.ArMessages());

  runApp(const ProviderScope(child: DoctorStoreApp()));
}
