-- ============================================
-- FIX: Analytics Schema & RLS Issues
-- ============================================

-- 1. إضافة عمود visitor_id المفقود في جدول events
ALTER TABLE events ADD COLUMN IF NOT EXISTS visitor_id TEXT;

-- 2. إنشاء index للبحث السريع
CREATE INDEX IF NOT EXISTS idx_events_visitor_id ON events(visitor_id);

-- 3. إصلاح RLS Policies - السماح بالقراءة للأدمن

-- حذف السياسات القديمة المعقدة
DROP POLICY IF EXISTS admin_events_policy ON events;
DROP POLICY IF EXISTS admin_visits_policy ON site_visits;
DROP POLICY IF EXISTS admin_product_views_policy ON product_views;
DROP POLICY IF EXISTS admin_daily_analytics_policy ON daily_analytics;
DROP POLICY IF EXISTS admin_product_analytics_policy ON product_analytics;

-- سياسة جديدة: السماح للجميع بالإدراج (للتتبع)
CREATE POLICY insert_events_policy ON events
  FOR INSERT TO anon, authenticated
  WITH CHECK (true);

CREATE POLICY insert_visits_policy ON site_visits
  FOR INSERT TO anon, authenticated
  WITH CHECK (true);

CREATE POLICY insert_product_views_policy ON product_views
  FOR INSERT TO anon, authenticated
  WITH CHECK (true);

-- سياسة: السماح بالقراءة للمستخدمين المسجلين (للداشبورد)
CREATE POLICY read_events_policy ON events
  FOR SELECT TO authenticated
  USING (true);

CREATE POLICY read_visits_policy ON site_visits
  FOR SELECT TO authenticated
  USING (true);

CREATE POLICY read_product_views_policy ON product_views
  FOR SELECT TO authenticated
  USING (true);

CREATE POLICY read_daily_analytics_policy ON daily_analytics
  FOR SELECT TO authenticated
  USING (true);

CREATE POLICY read_product_analytics_policy ON product_analytics
  FOR SELECT TO authenticated
  USING (true);

-- 4. إصلاح دالة get_dashboard_stats لاستخدام site_visits مباشرة
-- (بدلاً من auth.users الذي يتطلب صلاحيات خاصة)
CREATE OR REPLACE FUNCTION get_dashboard_stats()
RETURNS JSONB AS $$
DECLARE
  result JSONB;
BEGIN
  SELECT jsonb_build_object(
    'today_visits', COALESCE((SELECT total_visits FROM daily_analytics WHERE date = CURRENT_DATE), 0),
    'today_product_views', COALESCE((SELECT total_product_views FROM daily_analytics WHERE date = CURRENT_DATE), 0),
    'today_orders', COALESCE((SELECT total_orders FROM daily_analytics WHERE date = CURRENT_DATE), 0),
    'today_revenue', COALESCE((SELECT total_revenue FROM daily_analytics WHERE date = CURRENT_DATE), 0),
    'total_products', (SELECT COUNT(*) FROM products WHERE is_active = true),
    'total_users', (SELECT COUNT(DISTINCT user_id) FROM site_visits WHERE user_id IS NOT NULL),
    'online_users_now', (
      SELECT COUNT(DISTINCT visitor_id) 
      FROM site_visits 
      WHERE session_start > now() - INTERVAL '5 minutes'
    )
  ) INTO result;
  
  RETURN result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 5. إعادة تحميل الجدول لتحديث schema cache
NOTIFY pgrst, 'reload schema';
