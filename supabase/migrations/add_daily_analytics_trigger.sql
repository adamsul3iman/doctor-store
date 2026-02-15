-- Trigger لتحديث الإحصائيات اليومية تلقائياً
CREATE OR REPLACE FUNCTION update_daily_analytics()
RETURNS TRIGGER AS $$
BEGIN
    -- عند إضافة زيارة جديدة
    IF TG_TABLE_NAME = 'site_visits' THEN
        INSERT INTO daily_analytics (date, total_visits)
        VALUES (CURRENT_DATE, 1)
        ON CONFLICT (date) DO UPDATE SET
            total_visits = daily_analytics.total_visits + 1;
    
    -- عند إضافة حدث جديد (طلب جديد)
    ELSIF TG_TABLE_NAME = 'events' AND NEW.name = 'purchase' THEN
        INSERT INTO daily_analytics (date, total_orders, total_revenue)
        VALUES (CURRENT_DATE, 1, COALESCE(NEW.props->>'revenue', '0')::decimal)
        ON CONFLICT (date) DO UPDATE SET
            total_orders = daily_analytics.total_orders + 1,
            total_revenue = daily_analytics.total_revenue + COALESCE(NEW.props->>'revenue', '0')::decimal;
    
    -- عند مشاهدة منتج جديد
    ELSIF TG_TABLE_NAME = 'product_views' THEN
        INSERT INTO daily_analytics (date, total_product_views)
        VALUES (CURRENT_DATE, 1)
        ON CONFLICT (date) DO UPDATE SET
            total_product_views = daily_analytics.total_product_views + 1;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger لجدول الزيارات
CREATE TRIGGER trigger_daily_analytics_visits
AFTER INSERT ON site_visits
FOR EACH ROW
EXECUTE FUNCTION update_daily_analytics();

-- Trigger لجدول الأحداث
CREATE TRIGGER trigger_daily_analytics_events
AFTER INSERT ON events
FOR EACH ROW
EXECUTE FUNCTION update_daily_analytics();

-- Trigger لجدول مشاهدات المنتجات
CREATE TRIGGER trigger_daily_analytics_product_views
AFTER INSERT OR UPDATE ON product_views
FOR EACH ROW
EXECUTE FUNCTION update_daily_analytics();
