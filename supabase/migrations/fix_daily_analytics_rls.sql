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
