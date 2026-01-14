import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:meta_seo/meta_seo.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:timeago/timeago.dart' as timeago;

import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';
import 'shared/utils/supabase_auth_listener.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. إعداد الويب
  if (kIsWeb) {
    MetaSEO().config();
  }

  // 2. تحميل ملف الإعدادات (مع تقليل الضوضاء في الإصدار النهائي)
  var envLoaded = false;
  try {
    await dotenv.load(fileName: "assets/env.txt");
    envLoaded = dotenv.isInitialized;
    if (kDebugMode) {
      debugPrint("✅ Env Loaded");
    }
  } catch (e) {
    if (kDebugMode) {
      debugPrint("⚠️ Env Error: $e");
    }
  }

  String? safeEnv(String key) {
    if (!envLoaded || !dotenv.isInitialized) return null;
    return dotenv.maybeGet(key);
  }

  // 3. تهيئة Supabase مع حماية أفضل للإعدادات
  // ملاحظة:
  // - على الويب في وضع الإصدار (release) أحياناً لا يتم تحميل ملف env.txt كما هو متوقع،
  //   مما كان يسبب خطأ Uncaught Error في main.dart.js.
  // - لذلك نعتمد هنا على قيم افتراضية آمنة (نفس القيم الموجودة في env.txt)،
  //   مع إعطاء أولوية كاملة للقيم القادمة من ملف env إن وُجد.
  final supabaseUrl =
      safeEnv('SUPABASE_URL') ?? 'https://owgaklkhquntsqahmegt.supabase.co';
  final supabaseAnonKey = safeEnv('SUPABASE_ANON_KEY') ??
      'sb_publishable_smx9EmqfqEL-vAk6z29t3Q_6bHZXq7u';

  // طالما أن لدينا قيماً افتراضية، لن يكونان null في وقت التشغيل،
  // لذلك لا نرمي استثناءً يُسقط التطبيق على الويب.

  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );

  timeago.setLocaleMessages('ar', timeago.ArMessages());

  if (kIsWeb) {
    usePathUrlStrategy();
  }

  runApp(const ProviderScope(child: DoctorStoreApp()));
}

// تم نقل تعريف GoRouter إلى core/router/app_router.dart لسهولة الصيانة والتوسع

class DoctorStoreApp extends ConsumerWidget {
  const DoctorStoreApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'متجر الدكتور - Doctor Store',

      // ✅ استخدام الثيم الموحد
      theme: AppTheme.lightTheme,

      // ✅ إعدادات اللغة (العربية)
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('ar', 'AE')],
      locale: const Locale('ar', 'AE'),

      routerConfig: appRouter,

      // نغلف كامل الشجرة بـ SupabaseAuthListener حتى يتمكن من الوصول إلى GoRouter من الـ context
      builder: (context, child) {
        return SupabaseAuthListener(
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
