-- ============================================
-- Unique Visits Logic: Prevent duplicate visits within 30 minutes
-- ============================================

-- 1) Create function to check if visitor already has recent visit
CREATE OR REPLACE FUNCTION has_recent_visit(
  p_visitor_id TEXT,
  p_page_url TEXT,
  p_window_minutes INTEGER DEFAULT 30
)
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 
    FROM site_visits 
    WHERE visitor_id = p_visitor_id
      AND page_url = p_page_url
      AND session_start > NOW() - (p_window_minutes || ' minutes')::INTERVAL
  );
END;
$$ LANGUAGE plpgsql;

-- 2) Update daily_analytics increment to only count unique visits
-- Drop existing triggers first
DROP TRIGGER IF EXISTS trigger_daily_analytics_visits ON site_visits;

-- Create new trigger that only counts non-duplicate visits
CREATE OR REPLACE FUNCTION update_daily_analytics_unique()
RETURNS TRIGGER AS $$
DECLARE
  v_is_duplicate BOOLEAN;
BEGIN
    -- Only site_visits has visitor_id/page_url (avoid referencing fields that don't exist on other tables)
    IF TG_TABLE_NAME = 'site_visits' THEN
        -- Check if this is a duplicate visit within 30 minutes for same page
        v_is_duplicate := has_recent_visit(
          NEW.visitor_id,
          NEW.page_url,
          30
        );

        -- Only count if NOT a duplicate
        IF NOT v_is_duplicate THEN
            INSERT INTO daily_analytics (date, total_visits, unique_visitors)
            VALUES (CURRENT_DATE, 1, 1)
            ON CONFLICT (date) DO UPDATE SET
                total_visits = daily_analytics.total_visits + 1,
                unique_visitors = daily_analytics.unique_visitors + 1;
        END IF;
    END IF;
    
    -- For events (orders), always count regardless of duplication
    -- Note: Only check NEW.name when TG_TABLE_NAME is 'events'
    IF TG_TABLE_NAME = 'events' THEN
      IF NEW.name = 'purchase' THEN
        INSERT INTO daily_analytics (date, total_orders, total_revenue)
        VALUES (CURRENT_DATE, 1, COALESCE((NEW.props->>'revenue')::decimal, 0))
        ON CONFLICT (date) DO UPDATE SET
            total_orders = daily_analytics.total_orders + 1,
            total_revenue = daily_analytics.total_revenue + COALESCE((NEW.props->>'revenue')::decimal, 0);
      END IF;
    END IF;
    
    -- For product views, always count (they have their own unique logic per product)
    IF TG_TABLE_NAME = 'product_views' THEN
        INSERT INTO daily_analytics (date, total_product_views)
        VALUES (CURRENT_DATE, 1)
        ON CONFLICT (date) DO UPDATE SET
            total_product_views = daily_analytics.total_product_views + 1;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create new trigger for site_visits with unique logic
CREATE TRIGGER trigger_daily_analytics_visits
AFTER INSERT ON site_visits
FOR EACH ROW
EXECUTE FUNCTION update_daily_analytics_unique();

-- Recreate other triggers
DROP TRIGGER IF EXISTS trigger_daily_analytics_events ON events;
CREATE TRIGGER trigger_daily_analytics_events
AFTER INSERT ON events
FOR EACH ROW
EXECUTE FUNCTION update_daily_analytics_unique();

DROP TRIGGER IF EXISTS trigger_daily_analytics_product_views ON product_views;
CREATE TRIGGER trigger_daily_analytics_product_views
AFTER INSERT OR UPDATE ON product_views
FOR EACH ROW
EXECUTE FUNCTION update_daily_analytics_unique();

-- ============================================
-- Backfill unique_visitors count for today based on actual data
-- ============================================
UPDATE daily_analytics
SET unique_visitors = (
    SELECT COUNT(DISTINCT visitor_id)
    FROM site_visits
    WHERE DATE(session_start) = daily_analytics.date
)
WHERE date = CURRENT_DATE;
