-- ========================================
-- سكريبت التحقق من السياسات المكررة
-- ========================================

-- 1. عرض جميع السياسات الحالية
SELECT 
  schemaname,
  tablename,
  policyname,
  permissive,
  roles,
  cmd,
  qual,
  with_check
FROM pg_policies 
WHERE schemaname = 'public'
ORDER BY tablename, policyname;

-- 2. البحث عن السياسات المكررة
SELECT 
  tablename,
  policyname,
  COUNT(*) as count
FROM pg_policies 
WHERE schemaname = 'public'
GROUP BY tablename, policyname
HAVING COUNT(*) > 1;

-- 3. عرض السياسات حسب الجدول
SELECT 
  tablename,
  COUNT(DISTINCT policyname) as unique_policies,
  COUNT(*) as total_policies,
  CASE 
    WHEN COUNT(*) = COUNT(DISTINCT policyname) THEN '✅ لا توجد مكررات'
    ELSE '⚠️ يوجد مكررات!'
  END as status
FROM pg_policies 
WHERE schemaname = 'public'
GROUP BY tablename
ORDER BY tablename;

-- ========================================
-- حذف جميع السياسات القديمة (تنظيف شامل)
-- ========================================

-- categories
DROP POLICY IF EXISTS "admin_manage_categories" ON public.categories;
DROP POLICY IF EXISTS "categories_admin_all" ON public.categories;
DROP POLICY IF EXISTS "categories_public_select" ON public.categories;
DROP POLICY IF EXISTS "public_read_categories" ON public.categories;

-- home_sections
DROP POLICY IF EXISTS "home_sections_admin_all" ON public.home_sections;
DROP POLICY IF EXISTS "home_sections_public_read" ON public.home_sections;

-- reviews
DROP POLICY IF EXISTS "reviews_admin_all" ON public.reviews;
DROP POLICY IF EXISTS "reviews_public_approved_only" ON public.reviews;
DROP POLICY IF EXISTS "reviews_public_insert" ON public.reviews;

-- products
DROP POLICY IF EXISTS "products_admin_all" ON public.products;
DROP POLICY IF EXISTS "products_public_read" ON public.products;

-- banners
DROP POLICY IF EXISTS "banners_admin_all" ON public.banners;
DROP POLICY IF EXISTS "banners_public_read" ON public.banners;

-- sub_categories
DROP POLICY IF EXISTS "sub_categories_admin_all" ON public.sub_categories;
DROP POLICY IF EXISTS "sub_categories_public_read" ON public.sub_categories;

-- app_settings
DROP POLICY IF EXISTS "app_settings_admin_all" ON public.app_settings;
DROP POLICY IF EXISTS "app_settings_public_read" ON public.app_settings;
DROP POLICY IF EXISTS "Public view settings" ON public.app_settings;

-- order_items
DROP POLICY IF EXISTS "order_items_admin_all" ON public.order_items;
DROP POLICY IF EXISTS "order_items_user_select" ON public.order_items;

-- orders
DROP POLICY IF EXISTS "orders_admin_all" ON public.orders;
DROP POLICY IF EXISTS "orders_auth_user_all" ON public.orders;
DROP POLICY IF EXISTS "orders_anon_whatsapp_insert" ON public.orders;
DROP POLICY IF EXISTS "orders_anon_whatsapp_select" ON public.orders;

-- profiles
DROP POLICY IF EXISTS "profiles_admin_all" ON public.profiles;
DROP POLICY IF EXISTS "profiles_user_own_row" ON public.profiles;
DROP POLICY IF EXISTS "profiles_user_update_own_row" ON public.profiles;

-- admins
DROP POLICY IF EXISTS "admins_own_row" ON public.admins;

-- clients
DROP POLICY IF EXISTS "clients_admin_all" ON public.clients;
DROP POLICY IF EXISTS "clients_admin_select" ON public.clients;
DROP POLICY IF EXISTS "clients_public_insert" ON public.clients;

-- coupons
DROP POLICY IF EXISTS "coupons_admin_all" ON public.coupons;
DROP POLICY IF EXISTS "coupons_public_select" ON public.coupons;

-- coupon_usage
DROP POLICY IF EXISTS "coupon_usage_admin_all" ON public.coupon_usage;
DROP POLICY IF EXISTS "coupon_usage_admin_insert" ON public.coupon_usage;
DROP POLICY IF EXISTS "coupon_usage_user_select" ON public.coupon_usage;

-- favorites
DROP POLICY IF EXISTS "favorites_admin_all" ON public.favorites;
DROP POLICY IF EXISTS "favorites_user_all" ON public.favorites;

-- wishlist
DROP POLICY IF EXISTS "wishlist_admin_all" ON public.wishlist;
DROP POLICY IF EXISTS "wishlist_user_all" ON public.wishlist;

-- user_carts
DROP POLICY IF EXISTS "user_carts_admin_all" ON public.user_carts;
DROP POLICY IF EXISTS "user_carts_user_all" ON public.user_carts;
DROP POLICY IF EXISTS "User can manage own cart" ON public.user_carts;

-- addresses
DROP POLICY IF EXISTS "addresses_user_all" ON public.addresses;
DROP POLICY IF EXISTS "User manages own addresses" ON public.addresses;

-- events
DROP POLICY IF EXISTS "User can insert own events" ON public.events;
DROP POLICY IF EXISTS "User can read own events" ON public.events;

-- seo_pages
DROP POLICY IF EXISTS "seo_pages_admin_all" ON public.seo_pages;
DROP POLICY IF EXISTS "seo_pages_public_read" ON public.seo_pages;

-- static_pages
DROP POLICY IF EXISTS "static_pages_admin_all" ON public.static_pages;
DROP POLICY IF EXISTS "static_pages_public_read" ON public.static_pages;

-- support_tickets
DROP POLICY IF EXISTS "support_tickets_admin_all" ON public.support_tickets;
DROP POLICY IF EXISTS "support_tickets_user_own" ON public.support_tickets;

-- ========================================
-- التحقق النهائي
-- ========================================

-- عرض الجداول بدون سياسات
SELECT 
  t.tablename,
  COALESCE(COUNT(p.policyname), 0) as policy_count,
  CASE 
    WHEN COUNT(p.policyname) = 0 THEN '⚠️ لا توجد سياسات'
    ELSE '✅ يوجد سياسات'
  END as status
FROM information_schema.tables t
LEFT JOIN pg_policies p ON p.tablename = t.tablename AND p.schemaname = 'public'
WHERE t.table_schema = 'public' 
  AND t.table_type = 'BASE TABLE'
  AND t.tablename NOT LIKE 'pg_%'
  AND t.tablename NOT LIKE 'sql_%'
GROUP BY t.tablename
ORDER BY policy_count ASC, t.tablename;

-- عرض إجمالي السياسات
SELECT 
  COUNT(DISTINCT tablename) as total_tables,
  COUNT(*) as total_policies,
  COUNT(DISTINCT policyname) as unique_policy_names
FROM pg_policies 
WHERE schemaname = 'public';

DO $$
BEGIN
  RAISE NOTICE '========================================';
  RAISE NOTICE '✅ تم تنظيف جميع السياسات القديمة';
  RAISE NOTICE 'الآن يمكنك تنفيذ fix_all_issues.sql';
  RAISE NOTICE '========================================';
END $$;
