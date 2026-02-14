-- ============================================
-- Live Users Counter - عدد المتصلين الآن
-- ============================================

-- دالة للحصول على عدد المتصلين الآن (آمنة للـ RLS)
CREATE OR REPLACE FUNCTION get_online_users_count()
RETURNS INTEGER AS $$
DECLARE
  count_result INTEGER;
BEGIN
  SELECT COUNT(DISTINCT visitor_id) INTO count_result
  FROM site_visits
  WHERE session_start > now() - INTERVAL '5 minutes';
  
  RETURN COALESCE(count_result, 0);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- دالة للحصول على تفاصيل المتصلين الآن
CREATE OR REPLACE FUNCTION get_online_users_details()
RETURNS TABLE (
  visitor_id TEXT,
  user_id UUID,
  country TEXT,
  device_type TEXT,
  page_url TEXT,
  session_start TIMESTAMP WITH TIME ZONE
) AS $$
BEGIN
  RETURN QUERY
  SELECT DISTINCT ON (sv.visitor_id)
    sv.visitor_id,
    sv.user_id,
    sv.country,
    sv.device_type,
    sv.page_url,
    sv.session_start
  FROM site_visits sv
  WHERE sv.session_start > now() - INTERVAL '5 minutes'
  ORDER BY sv.visitor_id, sv.session_start DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- View للمتصلين الآن (للاستعلام السريع)
CREATE OR REPLACE VIEW online_users_now AS
SELECT 
  COUNT(DISTINCT visitor_id) as online_count,
  (SELECT COUNT(*) FROM auth.users) as total_registered_users,
  (SELECT COUNT(*) FROM products WHERE is_active = true) as active_products
FROM site_visits
WHERE session_start > now() - INTERVAL '5 minutes';

-- جدول للـ real-time subscriptions
CREATE TABLE IF NOT EXISTS live_users_heartbeat (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  visitor_id TEXT NOT NULL UNIQUE,
  user_id UUID REFERENCES auth.users(id),
  page_url TEXT,
  last_heartbeat TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- Function to update heartbeat
CREATE OR REPLACE FUNCTION update_user_heartbeat(
  p_visitor_id TEXT,
  p_page_url TEXT DEFAULT NULL
)
RETURNS VOID AS $$
BEGIN
  INSERT INTO live_users_heartbeat (visitor_id, page_url, last_heartbeat)
  VALUES (p_visitor_id, p_page_url, now())
  ON CONFLICT (visitor_id) DO UPDATE SET
    page_url = EXCLUDED.page_url,
    last_heartbeat = EXCLUDED.last_heartbeat;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to cleanup old heartbeats
CREATE OR REPLACE FUNCTION cleanup_old_heartbeats()
RETURNS VOID AS $$
BEGIN
  DELETE FROM live_users_heartbeat
  WHERE last_heartbeat < now() - INTERVAL '10 minutes';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create policy for heartbeats
ALTER TABLE live_users_heartbeat ENABLE ROW LEVEL SECURITY;

CREATE POLICY heartbeat_insert_policy ON live_users_heartbeat
  FOR ALL TO anon, authenticated
  WITH CHECK (true);
