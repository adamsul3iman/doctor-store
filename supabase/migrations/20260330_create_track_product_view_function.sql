-- Migration: Create track_product_view RPC function
-- Created: 2026-03-30
-- Purpose: Atomic upsert for product views to avoid 409 conflicts
-- Updated: Accept TEXT parameters for flexibility with Supabase client

CREATE OR REPLACE FUNCTION track_product_view(
  p_product_id TEXT,
  p_visitor_id TEXT,
  p_user_id TEXT DEFAULT NULL,
  p_category_id TEXT DEFAULT NULL,
  p_last_viewed_at TEXT DEFAULT NULL,
  p_view_duration_seconds INT DEFAULT 0
)
RETURNS VOID 
LANGUAGE plpgsql
AS $$
BEGIN
  INSERT INTO product_views (
    product_id, 
    visitor_id, 
    user_id, 
    category_id, 
    view_count, 
    last_viewed_at, 
    view_duration_seconds,
    created_at,
    updated_at
  )
  VALUES (
    p_product_id::UUID, 
    p_visitor_id, 
    p_user_id::UUID, 
    p_category_id,
    1, 
    COALESCE(p_last_viewed_at::TIMESTAMPTZ, NOW()), 
    p_view_duration_seconds,
    NOW(),
    NOW()
  )
  ON CONFLICT (product_id, visitor_id) 
  DO UPDATE SET
    user_id = EXCLUDED.user_id,
    category_id = EXCLUDED.category_id,
    view_count = product_views.view_count + 1,
    last_viewed_at = EXCLUDED.last_viewed_at,
    view_duration_seconds = EXCLUDED.view_duration_seconds,
    updated_at = NOW();
END;
$$;

-- Grant execute permission to authenticated and anon roles
GRANT EXECUTE ON FUNCTION track_product_view(TEXT, TEXT, TEXT, TEXT, TEXT, INT) TO authenticated;
GRANT EXECUTE ON FUNCTION track_product_view(TEXT, TEXT, TEXT, TEXT, TEXT, INT) TO anon;

COMMENT ON FUNCTION track_product_view IS 
  'Atomically tracks product views with upsert behavior. Creates new record or updates existing one based on product_id + visitor_id unique constraint. Accepts TEXT parameters for compatibility with Supabase client.';