-- إصلاح خطأ 401 على product_views
-- المشكلة: on_conflict (upsert) يحتاج SELECT + INSERT

-- إضافة سياسة SELECT للمستخدمين المجهولين
CREATE POLICY "Allow anonymous product views select" ON product_views
  FOR SELECT 
  TO anon, authenticated
  USING (true);

-- التحقق من جميع السياسات
SELECT policyname, roles::text, cmd 
FROM pg_policies 
WHERE tablename = 'product_views'
ORDER BY cmd;
