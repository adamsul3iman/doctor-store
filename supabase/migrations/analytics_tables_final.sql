-- ============================================
-- Analytics Tables for Doctor Store (FIXED VERSION)
-- ============================================

-- جدول الأحداث العامة
CREATE TABLE IF NOT EXISTS events (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  name TEXT NOT NULL,
  user_id UUID REFERENCES auth.users(id),
  props JSONB DEFAULT '{}',
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- جدول زيارات الموقع
CREATE TABLE IF NOT EXISTS site_visits (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  visitor_id TEXT NOT NULL, -- معرف فريد للزائر (حتى للزوار غير المسجلين)
  user_id UUID REFERENCES auth.users(id),
  ip_address TEXT,
  user_agent TEXT,
  referrer TEXT,
  page_url TEXT,
  country TEXT,
  device_type TEXT, -- mobile, desktop, tablet
  browser TEXT,
  os TEXT,
  session_start TIMESTAMP WITH TIME ZONE DEFAULT now(),
  session_end TIMESTAMP WITH TIME ZONE,
  duration_seconds INTEGER DEFAULT 0
);

-- جدول مشاهدات المنتجات (FIXED: category_id is now TEXT to match products.category)
CREATE TABLE IF NOT EXISTS product_views (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  product_id UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,
  visitor_id TEXT NOT NULL,
  user_id UUID REFERENCES auth.users(id),
  category_id TEXT, -- FIXED: Changed to TEXT to match products.category type
  view_count INTEGER DEFAULT 1,
  last_viewed_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  view_duration_seconds INTEGER DEFAULT 0,
  added_to_cart BOOLEAN DEFAULT false,
  purchased BOOLEAN DEFAULT false,
  UNIQUE(product_id, visitor_id)
);

-- جدول إحصائيات يومية مجمعة (للأداء)
CREATE TABLE IF NOT EXISTS daily_analytics (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  date DATE NOT NULL UNIQUE,
  total_visits INTEGER DEFAULT 0,
  unique_visitors INTEGER DEFAULT 0,
  registered_users_visits INTEGER DEFAULT 0,
  guest_visits INTEGER DEFAULT 0,
  total_page_views INTEGER DEFAULT 0,
  total_product_views INTEGER DEFAULT 0,
  total_cart_additions INTEGER DEFAULT 0,
  total_orders INTEGER DEFAULT 0,
  total_revenue DECIMAL(10,2) DEFAULT 0,
  avg_session_duration_seconds INTEGER DEFAULT 0,
  bounce_rate DECIMAL(5,2) DEFAULT 0,
  top_products JSONB DEFAULT '[]', -- مصفوفة من IDs المنتجات الأكثر مشاهدة
  top_categories JSONB DEFAULT '[]', -- مصفوفة من IDs التصنيفات الأكثر زيارة
  devices_breakdown JSONB DEFAULT '{"mobile": 0, "desktop": 0, "tablet": 0}',
  countries_breakdown JSONB DEFAULT '{}',
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- جدول إحصائيات المنتجات
CREATE TABLE IF NOT EXISTS product_analytics (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  product_id UUID NOT NULL UNIQUE REFERENCES products(id) ON DELETE CASCADE,
  total_views INTEGER DEFAULT 0,
  unique_viewers INTEGER DEFAULT 0,
  avg_view_duration_seconds INTEGER DEFAULT 0,
  cart_additions INTEGER DEFAULT 0,
  purchases INTEGER DEFAULT 0,
  conversion_rate DECIMAL(5,2) DEFAULT 0, -- نسبة الشراء من المشاهدة
  last_viewed_at TIMESTAMP WITH TIME ZONE,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- ============================================
-- Indexes for Performance
-- ============================================

CREATE INDEX IF NOT EXISTS idx_events_name ON events(name);
CREATE INDEX IF NOT EXISTS idx_events_user_id ON events(user_id);
CREATE INDEX IF NOT EXISTS idx_events_created_at ON events(created_at DESC);

CREATE INDEX IF NOT EXISTS idx_visits_visitor_id ON site_visits(visitor_id);
CREATE INDEX IF NOT EXISTS idx_visits_user_id ON site_visits(user_id);
CREATE INDEX IF NOT EXISTS idx_visits_created_at ON site_visits(session_start DESC);
CREATE INDEX IF NOT EXISTS idx_visits_country ON site_visits(country);
CREATE INDEX IF NOT EXISTS idx_visits_device ON site_visits(device_type);

CREATE INDEX IF NOT EXISTS idx_product_views_product_id ON product_views(product_id);
CREATE INDEX IF NOT EXISTS idx_product_views_visitor_id ON product_views(visitor_id);
CREATE INDEX IF NOT EXISTS idx_product_views_category ON product_views(category_id);
CREATE INDEX IF NOT EXISTS idx_product_views_last_viewed ON product_views(last_viewed_at DESC);

CREATE INDEX IF NOT EXISTS idx_daily_analytics_date ON daily_analytics(date DESC);

-- ============================================
-- Functions & Triggers
-- ============================================

-- دالة لتحديث إحصائيات المنتج عند المشاهدة
CREATE OR REPLACE FUNCTION update_product_analytics_on_view()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO product_analytics (product_id, total_views, unique_viewers, last_viewed_at)
  VALUES (NEW.product_id, 1, 1, NEW.last_viewed_at)
  ON CONFLICT (product_id) DO UPDATE SET
    total_views = product_analytics.total_views + 1,
    unique_viewers = (
      SELECT COUNT(DISTINCT visitor_id) 
      FROM product_views 
      WHERE product_id = NEW.product_id
    ),
    last_viewed_at = NEW.last_viewed_at,
    updated_at = now();
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_product_analytics
AFTER INSERT OR UPDATE ON product_views
FOR EACH ROW
EXECUTE FUNCTION update_product_analytics_on_view();

-- ============================================
-- Views (for easy querying)
-- ============================================

-- View: المنتجات الأكثر مشاهدة (FIXED: removed categories join)
CREATE OR REPLACE VIEW top_products_view AS
SELECT 
  p.id,
  p.title,
  p.price,
  p.old_price,
  p.image_url,
  p.category,
  p.category as category_name, -- FIXED: Since category is TEXT, use it directly
  pa.total_views,
  pa.unique_viewers,
  pa.cart_additions,
  pa.purchases,
  pa.conversion_rate,
  pa.last_viewed_at
FROM products p
JOIN product_analytics pa ON p.id = pa.product_id
WHERE p.is_active = true
ORDER BY pa.total_views DESC;

-- View: إحصائيات اليوم الحالي
CREATE OR REPLACE VIEW today_stats_view AS
SELECT 
  date,
  total_visits,
  unique_visitors,
  total_product_views,
  total_cart_additions,
  total_orders,
  total_revenue,
  avg_session_duration_seconds
FROM daily_analytics
WHERE date = CURRENT_DATE;

-- View: إحصائيات آخر 7 أيام
CREATE OR REPLACE VIEW last_7_days_stats_view AS
SELECT 
  date,
  total_visits,
  unique_visitors,
  total_product_views,
  total_cart_additions,
  total_orders,
  total_revenue,
  avg_session_duration_seconds
FROM daily_analytics
WHERE date >= CURRENT_DATE - INTERVAL '7 days'
ORDER BY date DESC;

-- ============================================
-- RLS Policies (Security)
-- ============================================

ALTER TABLE events ENABLE ROW LEVEL SECURITY;
ALTER TABLE site_visits ENABLE ROW LEVEL SECURITY;
ALTER TABLE product_views ENABLE ROW LEVEL SECURITY;
ALTER TABLE daily_analytics ENABLE ROW LEVEL SECURITY;
ALTER TABLE product_analytics ENABLE ROW LEVEL SECURITY;

-- فقط الأدمن يمكنه رؤية جميع البيانات
CREATE POLICY admin_events_policy ON events
  FOR ALL TO authenticated
  USING (auth.uid() IN (SELECT user_id FROM admin_users));

CREATE POLICY admin_visits_policy ON site_visits
  FOR ALL TO authenticated
  USING (auth.uid() IN (SELECT user_id FROM admin_users));

CREATE POLICY admin_product_views_policy ON product_views
  FOR ALL TO authenticated
  USING (auth.uid() IN (SELECT user_id FROM admin_users));

CREATE POLICY admin_daily_analytics_policy ON daily_analytics
  FOR ALL TO authenticated
  USING (auth.uid() IN (SELECT user_id FROM admin_users));

CREATE POLICY admin_product_analytics_policy ON product_analytics
  FOR ALL TO authenticated
  USING (auth.uid() IN (SELECT user_id FROM admin_users));

-- السماح بالإدراج للجميع (للزوار)
CREATE POLICY insert_events_policy ON events
  FOR INSERT TO anon, authenticated
  WITH CHECK (true);

CREATE POLICY insert_visits_policy ON site_visits
  FOR INSERT TO anon, authenticated
  WITH CHECK (true);

CREATE POLICY insert_product_views_policy ON product_views
  FOR INSERT TO anon, authenticated
  WITH CHECK (true);

-- ============================================
-- Helper Functions for Admin Dashboard
-- ============================================

-- دالة للحصول على الإحصائيات العامة
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
    'total_users', (SELECT COUNT(*) FROM auth.users),
    'online_users_now', (
      SELECT COUNT(DISTINCT visitor_id) 
      FROM site_visits 
      WHERE session_start > now() - INTERVAL '5 minutes'
    )
  ) INTO result;
  
  RETURN result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- دالة للحصول على المنتجات الأكثر مشاهدة (FIXED: removed categories join)
CREATE OR REPLACE FUNCTION get_top_products(limit_count INTEGER DEFAULT 10)
RETURNS TABLE (
  product_id UUID,
  title TEXT,
  views INTEGER,
  category_name TEXT,
  image_url TEXT
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    p.id,
    p.title,
    pa.total_views,
    p.category, -- FIXED: Use category directly since it's TEXT
    p.image_url
  FROM products p
  JOIN product_analytics pa ON p.id = pa.product_id
  WHERE p.is_active = true
  ORDER BY pa.total_views DESC
  LIMIT limit_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- دالة للحصول على إحصائيات آخر N يوم
CREATE OR REPLACE FUNCTION get_analytics_for_days(days_count INTEGER DEFAULT 7)
RETURNS TABLE (
  stats_date DATE,
  visits INTEGER,
  unique_visitors INTEGER,
  product_views INTEGER,
  orders INTEGER,
  revenue DECIMAL
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    da.date,
    da.total_visits,
    da.unique_visitors,
    da.total_product_views,
    da.total_orders,
    da.total_revenue
  FROM daily_analytics da
  WHERE da.date >= CURRENT_DATE - (days_count || ' days')::INTERVAL
  ORDER BY da.date DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
