import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
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
import 'package:doctor_store/features/product/domain/models/product_model.dart';
import 'package:doctor_store/features/static/presentation/screens/about_screen.dart';
import 'package:doctor_store/features/static/presentation/screens/privacy_screen.dart';
import 'package:doctor_store/features/static/presentation/screens/terms_screen.dart';
import 'package:doctor_store/features/static/presentation/screens/contact_screen.dart';
import 'package:doctor_store/app/widgets/admin_guard.dart';

// مسارات الإدارة - تُستورد بشكل مؤجل (deferred loading)
import 'package:doctor_store/features/admin/presentation/screens/admin_dashboard.dart' deferred as admin_dashboard;
import 'package:doctor_store/features/admin/presentation/screens/product_form_screen.dart' deferred as admin_product;
import 'package:doctor_store/features/admin/presentation/screens/admin_product_edit_wrapper.dart' deferred as admin_edit;

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

/// بناء صفحة إدارة مع تحميل مؤجل (deferred loading)
/// هذا يُقلل حجم البندل الأساسي بشكل كبير
CustomTransitionPage _buildDeferredAdminPage(
  GoRouterState state,
  Future<Widget> Function() loader,
) {
  return CustomTransitionPage(
    key: state.pageKey,
    child: FutureBuilder<Widget>(
      future: loader(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done && snapshot.hasData) {
          return AdminGuard(child: snapshot.data!);
        }
        // Loading state
        return const Scaffold(
          body: Center(
            child: CircularProgressIndicator(),
          ),
        );
      },
    ),
    transitionsBuilder: (context, animation, secondaryAnimation, child) => child,
    transitionDuration: Duration.zero,
  );
}

// ================= Router Singleton & Factory =================

GoRouter? _appRouterInstance;
String? _initialLocation;

/// إنشاء Router بمسار أولي محدد (للـ Deep Links)
GoRouter createAppRouterWithLocation(String initialLocation) {
  return GoRouter(
    routerNeglect: false,
    initialLocation: initialLocation,
    debugLogDiagnostics: kDebugMode,
    errorBuilder: (context, state) => const Scaffold(
      body: Center(child: Text('صفحة غير موجودة')),
    ),
    routes: _buildRoutes(),
  );
}

/// تهيئة Router مع قراءة URL المتصفح
/// يجب استدعاؤها بعد WidgetsFlutterBinding.ensureInitialized()
void initAppRouter() {
  if (!kIsWeb) return;
  
  // قراءة URL المتصفح مرة واحدة عند التهيئة
  _initialLocation = Uri.base.path + (Uri.base.hasQuery ? '?${Uri.base.query}' : '');
  if (_initialLocation!.isEmpty || _initialLocation == '/') {
    _initialLocation = '/';
  }
  
  if (kDebugMode) {
    debugPrint('🌐 Deep Link detected: $_initialLocation');
  }
}

/// Getter للـ Router - ينشئ Router مرة واحدة فقط
GoRouter get appRouter {
  if (_appRouterInstance != null) {
    return _appRouterInstance!;
  }
  
  _appRouterInstance = _createAppRouter();
  return _appRouterInstance!;
}

GoRouter _createAppRouter() {
  // ✅ قراءة URL المتصفح باستخدام Uri.base (الطريقة المضمونة)
  String initialLocation = '/';
  if (kIsWeb) {
    // Uri.base يقرأ URL الحالي من المتصفح
    initialLocation = Uri.base.path;
    if (initialLocation.isEmpty) initialLocation = '/';
    
    // ignore: avoid_print
    print('🌐 Deep Link URL: ${Uri.base}');
    // ignore: avoid_print
    print('🌐 Path: $initialLocation');
  }
  
  return GoRouter(
    routerNeglect: false,
    initialLocation: initialLocation,
    debugLogDiagnostics: kDebugMode,
    errorBuilder: (context, state) => const Scaffold(
      body: Center(child: Text('صفحة غير موجودة')),
    ),
    routes: _buildRoutes(),
  );
}

List<RouteBase> _buildRoutes() {
  return [
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
    // مسارات الإدارة - تُحمل بشكل مؤجل (deferred loading)
    GoRoute(
      path: '/admin/dashboard',
      pageBuilder: (context, state) => _buildDeferredAdminPage(
        state,
        () async {
          await admin_dashboard.loadLibrary();
          return admin_dashboard.AdminDashboard();
        },
      ),
    ),
    GoRoute(
      path: '/admin/add',
      pageBuilder: (context, state) => _buildDeferredAdminPage(
        state,
        () async {
          await admin_product.loadLibrary();
          return admin_product.ProductFormScreen();
        },
      ),
    ),
    GoRoute(
      path: '/admin/edit',
      pageBuilder: (context, state) => _buildDeferredAdminPage(
        state,
        () async {
          final extra = state.extra;
          final id = state.uri.queryParameters['id'];
          
          if (extra is Product) {
            await admin_product.loadLibrary();
            return admin_product.ProductFormScreen(
              extra: extra,
              productToEdit: extra,
            );
          } else if (id != null && id.isNotEmpty) {
            await admin_edit.loadLibrary();
            return admin_edit.AdminProductEditWrapper(productId: id);
          }
          await admin_product.loadLibrary();
          return admin_product.ProductFormScreen();
        },
      ),
    ),
  ];
}
