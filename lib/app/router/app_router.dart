import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:doctor_store/core/theme/app_theme.dart';
import 'package:doctor_store/features/home/presentation/screens/home_screen_v2.dart';
import 'package:doctor_store/features/auth/presentation/screens/login_screen.dart';
import 'package:doctor_store/features/auth/presentation/screens/sign_up_screen.dart';
import 'package:doctor_store/features/auth/presentation/screens/reset_password_screen.dart';
import 'package:doctor_store/features/cart/presentation/screens/cart_screen.dart';
import 'package:doctor_store/features/product/presentation/screens/wishlist_screen.dart';
import 'package:doctor_store/features/recently_viewed/presentation/screens/recently_viewed_screen.dart';
import 'package:doctor_store/features/profile/presentation/screens/profile_screen.dart';
import 'package:doctor_store/features/orders/presentation/screens/orders_screen.dart';
import 'package:doctor_store/features/product/presentation/screens/search_screen.dart';
import 'package:doctor_store/features/product/presentation/screens/all_products_screen.dart';
import 'package:doctor_store/features/product/presentation/screens/category_screen.dart';
import 'package:doctor_store/features/browse/presentation/screens/browse_all_screen.dart';
import 'package:doctor_store/features/product/presentation/screens/product_details_wrapper.dart';
import 'package:doctor_store/features/admin/presentation/screens/admin_dashboard.dart';
import 'package:doctor_store/features/admin/presentation/screens/product_form_screen.dart';
import 'package:doctor_store/features/admin/presentation/screens/admin_product_edit_wrapper.dart';
import 'package:doctor_store/features/product/domain/models/product_model.dart';
import 'package:doctor_store/features/static/presentation/screens/about_screen.dart';
import 'package:doctor_store/features/static/presentation/screens/privacy_screen.dart';
import 'package:doctor_store/features/static/presentation/screens/terms_screen.dart';
import 'package:doctor_store/features/static/presentation/screens/contact_screen.dart';
import 'package:doctor_store/app/widgets/admin_guard.dart';

/// تعريف الراوتر الرئيسي للتطبيق في ملف مستقل لسهولة الصيانة والتوسع
/// 
/// يستخدم Path URL Strategy للويب لإزالة الـ # من الروابط
/// مثال: drstore.me/product/product-name بدلاً من drstore.me/#/product/product-name
final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  // استخدام Path URL Strategy للويب (إزالة # من الروابط)
  routerNeglect: kIsWeb,
  errorBuilder: (context, state) => const Scaffold(
    body: Center(child: Text('صفحة غير موجودة')),
  ),
  routes: [
    GoRoute(
      path: '/',
      pageBuilder: (context, state) => const NoTransitionPage(child: HomeScreenV2()),
    ),
    GoRoute(
      path: '/login',
      pageBuilder: (context, state) => _buildFadePage(state, const LoginScreen()),
    ),
    GoRoute(
      path: '/signup',
      pageBuilder: (context, state) =>
          _buildFadePage(state, const SignUpScreen()),
    ),
    GoRoute(
      path: '/reset-password',
      pageBuilder: (context, state) =>
          _buildFadePage(state, const ResetPasswordScreen()),
    ),
    GoRoute(
      path: '/cart',
      pageBuilder: (context, state) => _buildSlideUpPage(state, const CartScreen()),
    ),
    GoRoute(
      path: '/wishlist',
      pageBuilder: (context, state) => _buildFadePage(state, const WishlistScreen()),
    ),
    GoRoute(
      path: '/recently_viewed',
      pageBuilder: (context, state) => _buildFadePage(state, const RecentlyViewedScreen()),
    ),
    GoRoute(
      path: '/profile',
      pageBuilder: (context, state) => _buildFadePage(state, const ProfileScreen()),
    ),
    GoRoute(
      path: '/orders',
      pageBuilder: (context, state) => _buildFadePage(state, const OrdersScreen()),
    ),
    GoRoute(
      path: '/search',
      pageBuilder: (context, state) => _buildFadePage(
        state,
        SearchScreen(initialQuery: state.uri.queryParameters['q']),
      ),
    ),
    GoRoute(
      path: '/all_products',
      pageBuilder: (context, state) => _buildFadePage(
        state,
        AllProductsScreen(
          initialSort: state.uri.queryParameters['sort'],
        ),
      ),
    ),
    GoRoute(
      path: '/browse_all',
      pageBuilder: (context, state) => _buildFadePage(state, const BrowseAllScreen()),
    ),
    GoRoute(
      path: '/about',
      pageBuilder: (context, state) => _buildFadePage(state, const AboutScreen()),
    ),
    GoRoute(
      path: '/privacy',
      pageBuilder: (context, state) => _buildFadePage(state, const PrivacyScreen()),
    ),
    GoRoute(
      path: '/terms',
      pageBuilder: (context, state) => _buildFadePage(state, const TermsScreen()),
    ),
    GoRoute(
      path: '/contact',
      pageBuilder: (context, state) => _buildFadePage(state, const ContactScreen()),
    ),
    GoRoute(
      path: '/category/:id',
      pageBuilder: (context, state) {
        final id = state.pathParameters['id']!;
        final extra = state.extra as Map<String, dynamic>?;
        return _buildFadePage(
          state,
          CategoryScreen(
            categoryId: id,
            categoryName: extra?['name'] ?? 'القسم',
            themeColor: extra?['color'] ?? AppTheme.primary,
          ),
        );
      },
    ),
    // مسار عام بتفاصيل عبر query params (للتوافق الرجعي)
    GoRoute(
      path: '/product_details',
      pageBuilder: (context, state) {
        final extra = state.extra;
        Product? productObj;
        if (extra is Product) {
          productObj = extra;
        } else if (extra is Map<String, dynamic>) {
          // في حال تم تمرير JSON من Supabase أو من الويب
          productObj = Product.fromJson(extra);
        }

        return _buildFadePage(
          state,
          ProductDetailsWrapper(
            productObj: productObj,
            productId: state.uri.queryParameters['id'],
            productSlug: state.uri.queryParameters['slug'],
          ),
        );
      },
    ),
    // مسار سيو مختصر يعتمد على الـ slug: /product/my-product-slug
    GoRoute(
      path: '/product/:slug',
      pageBuilder: (context, state) {
        final slug = state.pathParameters['slug'];
        final extra = state.extra;
        Product? productObj;
        if (extra is Product) {
          productObj = extra;
        } else if (extra is Map<String, dynamic>) {
          productObj = Product.fromJson(extra);
        }

        return _buildFadePage(
          state,
          ProductDetailsWrapper(
            productObj: productObj,
            productSlug: slug,
            productId: state.uri.queryParameters['id'], // fallback اختياري
          ),
        );
      },
    ),
    // مسار احتياطي بالصيغة القديمة للتوافق الرجعي: /p/my-product-slug
    GoRoute(
      path: '/p/:slug',
      pageBuilder: (context, state) {
        final slug = state.pathParameters['slug'];
        final extra = state.extra;
        Product? productObj;
        if (extra is Product) {
          productObj = extra;
        } else if (extra is Map<String, dynamic>) {
          productObj = Product.fromJson(extra);
        }

        return _buildFadePage(
          state,
          ProductDetailsWrapper(
            productObj: productObj,
            productSlug: slug,
            productId: state.uri.queryParameters['id'], // fallback اختياري
          ),
        );
      },
    ),
    // مسارات الإدارة
    GoRoute(
      path: '/admin/dashboard',
      pageBuilder: (context, state) => _buildFadePage(
        state,
        const AdminGuard(child: AdminDashboard()),
      ),
    ),
    GoRoute(
      path: '/admin/add',
      pageBuilder: (context, state) => _buildFadePage(
        state,
        const AdminGuard(child: ProductFormScreen()),
      ),
    ),
    GoRoute(
      path: '/admin/edit',
      pageBuilder: (context, state) {
        final extra = state.extra;
        final id = state.uri.queryParameters['id'];

        Widget child;
        if (extra is Product) {
          // حالة التعديل من داخل لوحة الأدمن بدون Refresh
          child = ProductFormScreen(
            extra: extra,
            productToEdit: extra,
          );
        } else if (id != null && id.isNotEmpty) {
          // حالة فتح رابط مباشر /admin/edit?id=PRODUCT_ID أو بعد Refresh على هذه الصفحة
          child = AdminProductEditWrapper(productId: id);
        } else {
          // حالة إنشاء منتج جديد (بدون id ولا extra)
          child = const ProductFormScreen();
        }

        return _buildFadePage(state, AdminGuard(child: child));
      },
    ),
  ],
);

// ================= Helper transition builders =================

CustomTransitionPage _buildFadePage(GoRouterState state, Widget child) {
  // إلغاء أي أنيميشن انتقال بين الصفحات على الويب (Instant Navigation)
  return CustomTransitionPage(
    key: state.pageKey,
    child: child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) => child,
    transitionDuration: Duration.zero,
  );
}

CustomTransitionPage _buildSlideUpPage(GoRouterState state, Widget child) {
  // نفس الشيء: لا نستخدم Slide/Fade، فقط نعيد الـ child فوراً
  return CustomTransitionPage(
    key: state.pageKey,
    child: child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) => child,
    transitionDuration: Duration.zero,
  );
}
