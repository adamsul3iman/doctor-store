CREATE TABLE IF NOT EXISTS public.sub_categories (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  code text UNIQUE,
  parent_category_id text NOT NULL,
  sort_order integer NOT NULL DEFAULT 0,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.sub_categories
  ADD CONSTRAINT sub_categories_parent_fk
  FOREIGN KEY (parent_category_id)
  REFERENCES public.categories(id)
  ON DELETE CASCADE;

ALTER TABLE public.products
  ADD COLUMN IF NOT EXISTS sub_category_id uuid REFERENCES public.sub_categories(id);

CREATE INDEX IF NOT EXISTS products_sub_category_idx
  ON public.products(sub_category_id);