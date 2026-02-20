import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';

import 'package:doctor_store/core/theme/app_theme.dart';
import 'package:doctor_store/app/router/app_router.dart';
import 'package:doctor_store/shared/utils/supabase_auth_listener.dart';
import 'package:doctor_store/shared/utils/app_scroll_behavior.dart';

class DoctorStoreApp extends ConsumerStatefulWidget {
  const DoctorStoreApp({super.key});

  @override
  ConsumerState<DoctorStoreApp> createState() => _DoctorStoreAppState();
}

class _DoctorStoreAppState extends ConsumerState<DoctorStoreApp> {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    
    // ✅ قراءة URL المتصفح وتهيئة الـ Router به
    String initialLocation = '/';
    if (kIsWeb) {
      initialLocation = Uri.base.path + (Uri.base.hasQuery ? '?${Uri.base.query}' : '');
      if (initialLocation.isEmpty) initialLocation = '/';
      
      // استخدام print بدلاً من debugPrint للإنتاج
      // ignore: avoid_print
      print('🌐 Initial location from browser: $initialLocation');
    }
    
    _router = createAppRouterWithLocation(initialLocation);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'متجر الدكتور - Doctor Store',
      theme: AppTheme.lightTheme,
      scrollBehavior: const AppScrollBehavior(),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('ar', 'AE')],
      locale: const Locale('ar', 'AE'),
      routerConfig: _router,
      builder: (context, child) {
        return SupabaseAuthListener(
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
