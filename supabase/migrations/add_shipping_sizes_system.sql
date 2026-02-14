-- ========================================
-- نظام أحجام الشحن - Shipping Sizes System
-- التاريخ: 22 يناير 2026
-- ========================================

-- 1️⃣ إضافة حقل shipping_size في جدول products
ALTER TABLE public.products 
  ADD COLUMN IF NOT EXISTS shipping_size text DEFAULT 'small';

-- إضافة قيد للتأكد من القيم الصحيحة
ALTER TABLE public.products
  DROP CONSTRAINT IF EXISTS products_shipping_size_check;

ALTER TABLE public.products
  ADD CONSTRAINT products_shipping_size_check 
  CHECK (shipping_size IN ('small', 'medium', 'large', 'x_large'));

COMMENT ON COLUMN public.products.shipping_size IS 
  'حجم الشحن: small (صغير), medium (متوسط), large (كبير), x_large (كبير جداً)';

-- 2️⃣ إنشاء جدول shipping_costs
CREATE TABLE IF NOT EXISTS public.shipping_costs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  zone_id text NOT NULL,
  zone_name text NOT NULL,
  shipping_size text NOT NULL,
  cost numeric NOT NULL DEFAULT 0,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  UNIQUE(zone_id, shipping_size),
  CONSTRAINT shipping_costs_size_check 
    CHECK (shipping_size IN ('small', 'medium', 'large', 'x_large'))
);

-- إضافة تعليقات
COMMENT ON TABLE public.shipping_costs IS 'أسعار الشحن حسب المحافظة وحجم المنتج';
COMMENT ON COLUMN public.shipping_costs.zone_id IS 'معرف المحافظة (مثل: amman, irbid)';
COMMENT ON COLUMN public.shipping_costs.zone_name IS 'اسم المحافظة بالعربية';
COMMENT ON COLUMN public.shipping_costs.shipping_size IS 'حجم الشحن';
COMMENT ON COLUMN public.shipping_costs.cost IS 'تكلفة الشحن بالدينار';

-- 3️⃣ إدراج بيانات افتراضية لأسعار الشحن
INSERT INTO public.shipping_costs (zone_id, zone_name, shipping_size, cost) VALUES
  -- عمان
  ('amman', 'عمان', 'small', 2),
  ('amman', 'عمان', 'medium', 5),
  ('amman', 'عمان', 'large', 10),
  ('amman', 'عمان', 'x_large', 15),
  
  -- إربد
  ('irbid', 'إربد', 'small', 3),
  ('irbid', 'إربد', 'medium', 6),
  ('irbid', 'إربد', 'large', 12),
  ('irbid', 'إربد', 'x_large', 18),
  
  -- الزرقاء
  ('zarqa', 'الزرقاء', 'small', 3),
  ('zarqa', 'الزرقاء', 'medium', 6),
  ('zarqa', 'الزرقاء', 'large', 11),
  ('zarqa', 'الزرقاء', 'x_large', 17),
  
  -- عجلون
  ('ajloun', 'عجلون', 'small', 4),
  ('ajloun', 'عجلون', 'medium', 7),
  ('ajloun', 'عجلون', 'large', 13),
  ('ajloun', 'عجلون', 'x_large', 20),
  
  -- جرش
  ('jerash', 'جرش', 'small', 4),
  ('jerash', 'جرش', 'medium', 7),
  ('jerash', 'جرش', 'large', 13),
  ('jerash', 'جرش', 'x_large', 20),
  
  -- السلط
  ('salt', 'السلط', 'small', 3),
  ('salt', 'السلط', 'medium', 6),
  ('salt', 'السلط', 'large', 11),
  ('salt', 'السلط', 'x_large', 17),
  
  -- مادبا
  ('madaba', 'مادبا', 'small', 3),
  ('madaba', 'مادبا', 'medium', 6),
  ('madaba', 'مادبا', 'large', 12),
  ('madaba', 'مادبا', 'x_large', 18),
  
  -- الكرك
  ('karak', 'الكرك', 'small', 5),
  ('karak', 'الكرك', 'medium', 8),
  ('karak', 'الكرك', 'large', 15),
  ('karak', 'الكرك', 'x_large', 22),
  
  -- الطفيلة
  ('tafilah', 'الطفيلة', 'small', 6),
  ('tafilah', 'الطفيلة', 'medium', 9),
  ('tafilah', 'الطفيلة', 'large', 16),
  ('tafilah', 'الطفيلة', 'x_large', 24),
  
  -- معان
  ('maan', 'معان', 'small', 7),
  ('maan', 'معان', 'medium', 10),
  ('maan', 'معان', 'large', 18),
  ('maan', 'معان', 'x_large', 26),
  
  -- العقبة
  ('aqaba', 'العقبة', 'small', 8),
  ('aqaba', 'العقبة', 'medium', 12),
  ('aqaba', 'العقبة', 'large', 20),
  ('aqaba', 'العقبة', 'x_large', 30),
  
  -- المفرق
  ('mafraq', 'المفرق', 'small', 4),
  ('mafraq', 'المفرق', 'medium', 7),
  ('mafraq', 'المفرق', 'large', 14),
  ('mafraq', 'المفرق', 'x_large', 21)
ON CONFLICT (zone_id, shipping_size) DO NOTHING;

-- 4️⃣ إنشاء فهرس لتسريع الاستعلامات
CREATE INDEX IF NOT EXISTS idx_shipping_costs_zone_size 
  ON public.shipping_costs(zone_id, shipping_size);

CREATE INDEX IF NOT EXISTS idx_products_shipping_size 
  ON public.products(shipping_size);

-- 5️⃣ إضافة سياسات RLS
ALTER TABLE public.shipping_costs ENABLE ROW LEVEL SECURITY;

-- سياسة القراءة للجميع
DROP POLICY IF EXISTS "shipping_costs_public_read" ON public.shipping_costs;
CREATE POLICY "shipping_costs_public_read" 
  ON public.shipping_costs
  FOR SELECT
  USING (true);

-- سياسة الأدمن لكل العمليات
DROP POLICY IF EXISTS "shipping_costs_admin_all" ON public.shipping_costs;
CREATE POLICY "shipping_costs_admin_all" 
  ON public.shipping_costs
  FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM public.admins 
      WHERE user_id = auth.uid()
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.admins 
      WHERE user_id = auth.uid()
    )
  );

-- 6️⃣ دالة للحصول على سعر الشحن
CREATE OR REPLACE FUNCTION get_shipping_cost(
  p_zone_id text,
  p_shipping_size text
) RETURNS numeric AS $$
DECLARE
  v_cost numeric;
BEGIN
  SELECT cost INTO v_cost
  FROM public.shipping_costs
  WHERE zone_id = p_zone_id 
    AND shipping_size = p_shipping_size;
  
  -- إذا لم يوجد سعر محدد، نرجع السعر الافتراضي للحجم الصغير
  IF v_cost IS NULL THEN
    SELECT cost INTO v_cost
    FROM public.shipping_costs
    WHERE zone_id = p_zone_id 
      AND shipping_size = 'small'
    LIMIT 1;
  END IF;
  
  -- إذا لم يوجد حتى سعر افتراضي، نرجع 3 دينار
  RETURN COALESCE(v_cost, 3);
END;
$$ LANGUAGE plpgsql;

-- 7️⃣ التحقق من النتائج
DO $$
BEGIN
  RAISE NOTICE '========================================';
  RAISE NOTICE '✅ تم إضافة نظام أحجام الشحن بنجاح!';
  RAISE NOTICE '========================================';
END $$;

-- عرض ملخص البيانات
SELECT 
  zone_name as "المحافظة",
  COUNT(*) as "عدد الأحجام",
  MIN(cost) as "أقل سعر",
  MAX(cost) as "أعلى سعر"
FROM public.shipping_costs
GROUP BY zone_name
ORDER BY zone_name;

-- عرض أمثلة على الأسعار
SELECT 
  zone_name as "المحافظة",
  shipping_size as "الحجم",
  cost as "السعر (د.أ)"
FROM public.shipping_costs
WHERE zone_id IN ('amman', 'irbid', 'aqaba')
ORDER BY zone_name, 
  CASE shipping_size
    WHEN 'small' THEN 1
    WHEN 'medium' THEN 2
    WHEN 'large' THEN 3
    WHEN 'x_large' THEN 4
  END;
