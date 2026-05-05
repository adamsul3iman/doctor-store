-- Ensure saved order items keep the selected product variant details.
ALTER TABLE public.order_items
  ADD COLUMN IF NOT EXISTS selected_size text,
  ADD COLUMN IF NOT EXISTS selected_color text,
  ADD COLUMN IF NOT EXISTS image_url text;
