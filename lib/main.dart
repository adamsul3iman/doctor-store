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

Future<void> main() async {
  // ✅ Web-only bootstrap (guarded via conditional imports)
  if (kIsWeb) {
    setupUrlStrategy();
  }
  
  WidgetsFlutterBinding.ensureInitialized();

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

  // تهيئة Supabase
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
