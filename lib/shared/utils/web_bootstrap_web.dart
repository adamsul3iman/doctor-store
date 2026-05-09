// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:html' as html;

import 'package:flutter/foundation.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';

void setupUrlStrategy() {
  setUrlStrategy(PathUrlStrategy());
  if (kDebugMode) {
    debugPrint('URL Strategy: Path (clean URLs without #)');
  }
}

Future<void> cleanupServiceWorkers() async {
  try {
    // ✅ Optimization: Only cleanup if version mismatch to improve startup performance
    const currentVersion = '2.0.0'; // Bump this when deploying new builds
    final storedVersion = html.window.localStorage['sw_version'];

    if (storedVersion != currentVersion) {
      final regs =
          await html.window.navigator.serviceWorker?.getRegistrations();
      if (regs != null && regs.isNotEmpty) {
        for (final reg in regs) {
          await reg.unregister();
        }
        if (kDebugMode) {
          debugPrint(
              'Service Workers unregistered: ${regs.length} (version change)');
        }
      }
      html.window.localStorage['sw_version'] = currentVersion;
    } else {
      if (kDebugMode) {
        debugPrint('Service Workers: Version matches, skipping cleanup');
      }
    }
  } catch (e) {
    if (kDebugMode) {
      debugPrint('SW cleanup error: $e');
    }
  }
}
