import 'dart:async';

import 'package:flutter/material.dart';

/// أداة موحدة لعرض رسائل تنبيه (نجاح / خطأ) كـ Toast عائم أعلى الشاشة
/// بدون أن تدفع الصفحة كاملة للأسفل.
class AppNotifier {
  AppNotifier._();

  static const _defaultDuration = Duration(seconds: 3);
  static OverlayEntry? _currentEntry;

  static void _showBanner(
    BuildContext context, {
    required String message,
    required Color background,
    required IconData icon,
  }) {
    final overlay = Overlay.of(context);

    // إزالة أي Toast سابق
    _currentEntry?.remove();
    _currentEntry = null;

    final entry = OverlayEntry(
      builder: (ctx) {
        final mediaQuery = MediaQuery.of(ctx);
        final topPadding = mediaQuery.padding.top + 8;

        return Positioned(
          top: topPadding,
          left: 8,
          right: 8,
          child: SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: background,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, color: Colors.white),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          message,
                          style: const TextStyle(
                            fontFamily: 'Almarai',
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () {
                          _currentEntry?.remove();
                          _currentEntry = null;
                        },
                        child: const Text(
                          'إغلاق',
                          style: TextStyle(
                            fontFamily: 'Almarai',
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );

    overlay.insert(entry);
    _currentEntry = entry;

    // إخفاء تلقائي بعد مدة قصيرة
    Timer(_defaultDuration, () {
      if (_currentEntry == entry) {
        _currentEntry?.remove();
        _currentEntry = null;
      }
    });
  }

  /// رسالة خطأ عامة (أعلى الشاشة).
  static void showError(BuildContext context, String message) {
    _showBanner(
      context,
      message: message,
      background: Colors.red.shade800,
      icon: Icons.error_outline,
    );
  }

  /// رسالة نجاح عامة (أعلى الشاشة).
  static void showSuccess(BuildContext context, String message) {
    _showBanner(
      context,
      message: message,
      background: const Color(0xFF0A8F3C),
      icon: Icons.check_circle_outline,
    );
  }

  /// رسالة معلومات / تنبيه خفيفة.
  static void showInfo(BuildContext context, String message) {
    _showBanner(
      context,
      message: message,
      background: const Color(0xFF0A2647),
      icon: Icons.info_outline,
    );
  }
}
