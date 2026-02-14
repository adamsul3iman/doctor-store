import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'package:doctor_store/core/theme/app_theme.dart';
import 'package:doctor_store/app/router/app_router.dart';
import 'package:doctor_store/shared/utils/supabase_auth_listener.dart';
import 'package:doctor_store/shared/utils/app_scroll_behavior.dart';

class DoctorStoreApp extends ConsumerWidget {
  const DoctorStoreApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
      routerConfig: appRouter,
      builder: (context, child) {
        return SupabaseAuthListener(
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
