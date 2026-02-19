import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:meta_seo/meta_seo.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:timeago/timeago.dart' as timeago;
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

import 'app/app.dart';

Future<void> main() async {
  // ✅ استخدام Path URL Strategy قبل أي تهيئة أخرى
  if (kIsWeb) {
    setUrlStrategy(PathUrlStrategy());
  }
  
  WidgetsFlutterBinding.ensureInitialized();

  // BUILD_VERSION: 9 - Path URL Strategy with redirect-based deep links
  if (kIsWeb) {
    MetaSEO().config();
    debugPrint('URL Strategy: Path (clean URLs without #)');
  }

  // Service Worker cleanup
  if (kIsWeb) {
    html.window.navigator.serviceWorker?.getRegistrations().then((regs) {
      for (var reg in regs) {
        reg.unregister();
      }
      debugPrint('Service Workers unregistered: ${regs.length}');
    }).catchError((e) {
      debugPrint('SW cleanup error: $e');
    });
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
