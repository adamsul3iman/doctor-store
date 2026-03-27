-- ============================================
-- 1️⃣ أوامر الفحص (Run these first to see current state)
-- ============================================

-- عرض بنية جدول product_views
SELECT column_name, data_type, is_nullable 
FROM information_schema.columns 
WHERE table_name = 'product_views';

-- عرض السياسات الحالية على الجدول
SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual, with_check
FROM pg_policies 
WHERE tablename = 'product_views';

-- عرض حالة RLS على الجدول
SELECT relname, relrowsecurity, relforcerowsecurity
FROM pg_class 
WHERE relname = 'product_views';

-- عرض عدد السجلات في الجدول
SELECT COUNT(*) as total_views FROM product_views;

-- ============================================
-- 2️⃣ أوامر الإصلاح (Run these after checking)
-- ============================================

-- تفعيل RLS إذا لم يكن مفعلاً
ALTER TABLE product_views ENABLE ROW LEVEL SECURITY;

-- حذف السياسات القديمة إذا كانت تتعارض (اختياري - شغل فقط إذا لزم الأمر)
-- DROP POLICY IF EXISTS "product_views_insert_policy" ON product_views;
-- DROP POLICY IF EXISTS "product_views_select_policy" ON product_views;

-- إنشاء سياسة جديدة للإدخال - السماح للجميع
CREATE POLICY IF NOT EXISTS "Allow anonymous product views insert" ON product_views
  FOR INSERT 
  TO anon, authenticated
  WITH CHECK (true);

-- إنشاء سياسة جديدة للقراءة - السماح للجميع
CREATE POLICY IF NOT EXISTS "Allow anonymous product views select" ON product_views
  FOR SELECT 
  TO anon, authenticated
  USING (true);

-- ============================================
-- 3️⃣ التحقق بعد الإصلاح
-- ============================================

-- التأكد من السياسات الجديدة
SELECT * FROM pg_policies WHERE tablename = 'product_views';
