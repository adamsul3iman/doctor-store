import 'package:flutter/material.dart';

class AppTheme {
  // الألوان الأساسية (هوية المتجر)
  static const Color primary = Color(0xFF0A2647); // كحلي غامق (فخامة)
  static const Color secondary = Color(0xFFD4AF37); // ذهبي (تميز)
  static const Color background = Color(0xFFFAFAFA); // أبيض مائل للرمادي (راحة للعين)
  static const Color surface = Colors.white;
  static const Color error = Color(0xFFD32F2F);

  // إعدادات الثيم العام
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: background,
      primaryColor: primary,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        primary: primary,
        secondary: secondary,
        surface: surface,
        error: error,
      ),
      
      // إعدادات النصوص (الخط العربي الموحد من ملف محلي لتفادي مشكلة المربعات على الويب)
      fontFamily: 'Almarai',
      textTheme: const TextTheme(
        displayLarge: TextStyle(fontFamily: 'Almarai', color: primary, fontWeight: FontWeight.bold, fontSize: 24),
        displayMedium: TextStyle(fontFamily: 'Almarai', color: primary, fontWeight: FontWeight.bold, fontSize: 20),
        bodyLarge: TextStyle(fontFamily: 'Almarai', color: Colors.black87, fontSize: 16),
        bodyMedium: TextStyle(fontFamily: 'Almarai', color: Colors.black54, fontSize: 14),
      ),

      // إعدادات الأزرار (موحدة في كل التطبيق)
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 2,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontFamily: 'Almarai', fontWeight: FontWeight.bold),
        ),
      ),

      // إعدادات الحقول (Input Fields)
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.grey[50],
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: primary, width: 1.5)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: error)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),

      // إعدادات البار العلوي
      appBarTheme: AppBarTheme(
        backgroundColor: surface,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: primary),
        titleTextStyle: const TextStyle(
          fontFamily: 'Almarai',
          color: primary,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
        surfaceTintColor: Colors.transparent,
      ),

      // كروت موحّدة لكل المتجر (منتجات، حساب، إدارة)
      cardTheme: CardThemeData(
        color: surface,
        elevation: 2,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),

      // شكل الـ BottomSheet الحديث (شيتات تسجيل الدخول، تعديل البروفايل..)
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        showDragHandle: true,
      ),

      // Snackbar موحّد للنجاح/الفشل
      snackBarTheme: SnackBarThemeData(
        backgroundColor: primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        contentTextStyle: const TextStyle(
          fontFamily: 'Almarai',
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),

      scrollbarTheme: ScrollbarThemeData(
        thumbVisibility: const WidgetStatePropertyAll(true),
        trackVisibility: const WidgetStatePropertyAll(false),
        thickness: const WidgetStatePropertyAll(8),
        radius: const Radius.circular(8),
        thumbColor: WidgetStatePropertyAll(
          Colors.grey.withValues(alpha: 0.5),
        ),
      ),

      // Chip / Tag (مثل التاجات الصغيرة في البروفايل والمنتجات)
      chipTheme: ChipThemeData(
        backgroundColor: Colors.grey[100]!,
        selectedColor: secondary.withValues(alpha: 0.12),
        secondarySelectedColor: primary.withValues(alpha: 0.12),
        labelStyle: const TextStyle(
          fontFamily: 'Almarai',
          color: Colors.black87,
          fontWeight: FontWeight.w600,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        brightness: Brightness.light,
      ),

      dividerColor: Colors.grey.withValues(alpha: 0.2),
    );
  }
}