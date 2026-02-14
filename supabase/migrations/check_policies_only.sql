-- ========================================
-- سكريبت التحقق من السياسات (بدون حذف)
-- ========================================

-- 1️⃣ عرض جميع السياسات حسب الجدول
SELECT 
  tablename,
  policyname,
  cmd as operation,
  CASE 
    WHEN roles = '{public}' THEN 'عام'
    WHEN roles = '{authenticated}' THEN 'مسجلين'
    WHEN roles = '{anon}' THEN 'زوار'
    ELSE roles::text
  END as for_role
FROM pg_policies 
WHERE schemaname = 'public'
ORDER BY tablename, policyname;

-- 2️⃣ البحث عن سياسات مكررة
SELECT 
  tablename,
  policyname,
  COUNT(*) as duplicates
FROM pg_policies 
WHERE schemaname = 'public'
GROUP BY tablename, policyname
HAVING COUNT(*) > 1;

-- 3️⃣ إحصائيات السياسات لكل جدول
SELECT 
  tablename,
  COUNT(*) as total_policies,
  COUNT(DISTINCT policyname) as unique_policies,
  CASE 
    WHEN COUNT(*) = COUNT(DISTINCT policyname) THEN '✅ لا مكررات'
    ELSE '⚠️ يوجد مكررات'
  END as status,
  STRING_AGG(DISTINCT policyname, ', ' ORDER BY policyname) as policy_names
FROM pg_policies 
WHERE schemaname = 'public'
GROUP BY tablename
ORDER BY tablename;

-- 4️⃣ الجداول المهمة وسياساتها
SELECT 
  tablename,
  COUNT(*) as policy_count,
  STRING_AGG(policyname, ', ') as policies
FROM pg_policies 
WHERE schemaname = 'public'
  AND tablename IN (
    'categories', 
    'products', 
    'reviews', 
    'home_sections', 
    'banners',
    'sub_categories',
    'app_settings',
    'admins'
  )
GROUP BY tablename
ORDER BY tablename;

-- 5️⃣ الجداول بدون سياسات (قد تحتاج سياسات)
SELECT 
  t.table_name as tablename,
  CASE 
    WHEN t.table_name IN ('admins', 'app_settings', 'banners', 'categories', 
                         'products', 'reviews', 'home_sections') 
    THEN '⚠️ يجب أن يكون لها سياسات'
    ELSE 'عادي'
  END as importance
FROM information_schema.tables t
LEFT JOIN pg_policies p ON p.tablename = t.table_name AND p.schemaname = 'public'
WHERE t.table_schema = 'public' 
  AND t.table_type = 'BASE TABLE'
  AND t.table_name NOT LIKE 'pg_%'
  AND t.table_name NOT LIKE 'sql_%'
  AND p.policyname IS NULL
ORDER BY importance DESC, t.table_name;

-- 6️⃣ التحقق من وجود سياسات للأدمن
SELECT 
  tablename,
  policyname,
  CASE 
    WHEN qual LIKE '%admins%' OR with_check LIKE '%admins%' 
    THEN '✅ سياسة أدمن'
    ELSE '❌ ليست للأدمن'
  END as admin_policy
FROM pg_policies 
WHERE schemaname = 'public'
  AND (qual LIKE '%admins%' OR with_check LIKE '%admins%')
ORDER BY tablename;

-- 7️⃣ ملخص شامل
DO $$
DECLARE
  total_tables INT;
  total_policies INT;
  duplicate_policies INT;
  tables_without_policies INT;
BEGIN
  SELECT COUNT(DISTINCT tablename) INTO total_tables
  FROM pg_policies WHERE schemaname = 'public';
  
  SELECT COUNT(*) INTO total_policies
  FROM pg_policies WHERE schemaname = 'public';
  
  SELECT COUNT(*) INTO duplicate_policies
  FROM (
    SELECT tablename, policyname, COUNT(*) as cnt
    FROM pg_policies 
    WHERE schemaname = 'public'
    GROUP BY tablename, policyname
    HAVING COUNT(*) > 1
  ) sub;
  
  SELECT COUNT(*) INTO tables_without_policies
  FROM information_schema.tables t
  LEFT JOIN pg_policies p ON p.tablename = t.table_name AND p.schemaname = 'public'
  WHERE t.table_schema = 'public' 
    AND t.table_type = 'BASE TABLE'
    AND t.table_name NOT LIKE 'pg_%'
    AND t.table_name NOT LIKE 'sql_%'
    AND p.policyname IS NULL;

  RAISE NOTICE '========================================';
  RAISE NOTICE '📊 ملخص السياسات';
  RAISE NOTICE '========================================';
  RAISE NOTICE 'عدد الجداول التي لها سياسات: %', total_tables;
  RAISE NOTICE 'إجمالي عدد السياسات: %', total_policies;
  RAISE NOTICE 'عدد السياسات المكررة: %', duplicate_policies;
  RAISE NOTICE 'عدد الجداول بدون سياسات: %', tables_without_policies;
  RAISE NOTICE '========================================';
  
  IF duplicate_policies > 0 THEN
    RAISE NOTICE '⚠️ تحذير: يوجد سياسات مكررة!';
    RAISE NOTICE 'استخدم check_and_cleanup_policies.sql للتنظيف';
  ELSE
    RAISE NOTICE '✅ لا توجد سياسات مكررة';
  END IF;
  
  RAISE NOTICE '========================================';
END $$;
