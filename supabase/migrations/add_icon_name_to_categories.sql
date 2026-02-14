-- إضافة حقل icon_name إلى جدول categories
-- هذا الحقل سيُستخدم لتخزين اسم الأيقونة من قائمة الأيقونات المتاحة

ALTER TABLE public.categories 
  ADD COLUMN IF NOT EXISTS icon_name text DEFAULT 'box';

-- تحديث الأقسام الموجودة بأيقونات افتراضية
UPDATE public.categories
SET icon_name = CASE id
  WHEN 'bedding' THEN 'bed'
  WHEN 'mattresses' THEN 'mattress'
  WHEN 'pillows' THEN 'pillow'
  WHEN 'furniture' THEN 'couch'
  WHEN 'dining_table' THEN 'table'
  WHEN 'carpets' THEN 'carpet'
  WHEN 'baby_supplies' THEN 'baby'
  WHEN 'home_decor' THEN 'leaf'
  WHEN 'towels' THEN 'shower'
  ELSE 'box'
END
WHERE icon_name IS NULL OR icon_name = 'box';

-- إنشاء تعليق على الحقل
COMMENT ON COLUMN public.categories.icon_name IS 'اسم الأيقونة من قائمة الأيقونات المتاحة (bed, table, baby, carpet, pillow, couch, leaf, shower, curtains, mattress, box, star, heart, home, gift, percent, fire, tag)';
