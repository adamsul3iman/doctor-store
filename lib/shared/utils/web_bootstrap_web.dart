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
    final regs = await html.window.navigator.serviceWorker?.getRegistrations();
    if (regs == null) return;
    for (final reg in regs) {
      await reg.unregister();
    }
    if (kDebugMode) {
      debugPrint('Service Workers unregistered: ${regs.length}');
    }
  } catch (e) {
    if (kDebugMode) {
      debugPrint('SW cleanup error: $e');
    }
  }
}
