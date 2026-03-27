-- ============================================
-- 🔍 فحص وإصلاح نهائي لـ product_views
-- ============================================

-- 1️⃣ التحقق من حالة RLS على الجدول
SELECT 
  relname as table_name,
  relrowsecurity as rls_enabled,
  relforcerowsecurity as rls_forced
FROM pg_class 
WHERE relname = 'product_views';

-- إذا كان relrowsecurity = false، شغل هذا الأمر:
-- ALTER TABLE product_views ENABLE ROW LEVEL SECURITY;

-- 2️⃣ إضافة سياسة SELECT للمستخدمين المجهولين (نقص حالي)
-- التحقق إذا كانت موجودة أولاً
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'product_views' 
    AND policyname = 'Allow anonymous product views select'
  ) THEN
    CREATE POLICY "Allow anonymous product views select" ON product_views
      FOR SELECT 
      TO anon, authenticated
      USING (true);
  END IF;
END $$;

-- 3️⃣ التحقق النهائي من جميع السياسات
SELECT 
  policyname,
  roles::text,
  cmd,
  CASE WHEN relrowsecurity THEN 'RLS ENABLED' ELSE 'RLS DISABLED' END as rls_status
FROM pg_policies p
JOIN pg_class c ON c.relname = p.tablename
WHERE p.tablename = 'product_views'
ORDER BY cmd;
