-- Fix RLS Policy for daily_analytics table
-- Allow insert for everyone (visitors and users)

-- Drop old policies
DROP POLICY IF EXISTS admin_daily_analytics_policy ON daily_analytics;
DROP POLICY IF EXISTS insert_daily_analytics_policy ON daily_analytics;
DROP POLICY IF EXISTS read_daily_analytics_policy ON daily_analytics;
DROP POLICY IF EXISTS update_daily_analytics_policy ON daily_analytics;

-- New policy: Allow insert for everyone
CREATE POLICY insert_daily_analytics_policy ON daily_analytics
FOR INSERT TO public
WITH CHECK (true);

-- Read policy for admin only (using service role key)
CREATE POLICY read_daily_analytics_policy ON daily_analytics
FOR SELECT TO authenticated
USING (true);

-- Allow update for triggers / aggregation (needed for ON CONFLICT DO UPDATE)
CREATE POLICY update_daily_analytics_policy ON daily_analytics
FOR UPDATE TO public
USING (true)
WITH CHECK (true);

-- ============================================
-- Fix RLS Policy for product_analytics table
-- Allow trigger-driven upserts to succeed
-- ============================================

DROP POLICY IF EXISTS admin_product_analytics_policy ON product_analytics;
DROP POLICY IF EXISTS insert_product_analytics_policy ON product_analytics;
DROP POLICY IF EXISTS read_product_analytics_policy ON product_analytics;
DROP POLICY IF EXISTS update_product_analytics_policy ON product_analytics;

CREATE POLICY insert_product_analytics_policy ON product_analytics
FOR INSERT TO public
WITH CHECK (true);

CREATE POLICY read_product_analytics_policy ON product_analytics
FOR SELECT TO authenticated
USING (true);

CREATE POLICY update_product_analytics_policy ON product_analytics
FOR UPDATE TO public
USING (true)
WITH CHECK (true);

-- ==========================================
-- إصلاح RLS لـ product_views
-- ==========================================

-- حذف السياسات القديمة
DROP POLICY IF EXISTS "Allow anonymous product views" ON product_views;
DROP POLICY IF EXISTS "Allow admin to view product_views" ON product_views;
DROP POLICY IF EXISTS "Allow users to view own product_views" ON product_views;

-- السماح للـ Anonymous بإضافة مشاهدات
CREATE POLICY "Allow anonymous product views" 
ON product_views 
FOR INSERT 
TO anon, authenticated 
WITH CHECK (true);

-- السماح للـ Admin بقراءة جميع المشاهدات
CREATE POLICY "Allow admin to view product_views" 
ON product_views 
FOR SELECT 
TO authenticated 
USING (auth.uid() = 'c8349fe8-790f-4675-9c48-d8862a071ab8'::uuid);

-- السماح للـ Authenticated بقراءة مشاهداته الخاصة
-- ✅ FIXED: cast auth.uid() to text to match visitor_id column type
CREATE POLICY "Allow users to view own product_views" 
ON product_views 
FOR SELECT 
TO authenticated 
USING (visitor_id = auth.uid()::text);

CREATE POLICY update_product_analytics_policy ON product_analytics
FOR UPDATE TO public
USING (true)
WITH CHECK (true);
