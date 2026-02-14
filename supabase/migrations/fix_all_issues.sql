-- ========================================
-- سكريبت إصلاح شامل لقاعدة بيانات متجر الدكتور
-- تاريخ: 22 يناير 2026
-- ========================================

-- ========================================
-- 1. إضافة حقل icon_name لجدول categories
-- ========================================
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

COMMENT ON COLUMN public.categories.icon_name IS 'اسم الأيقونة من قائمة الأيقونات المتاحة';

-- ========================================
-- 2. إضافة المستخدم كأدمن
-- ========================================
-- إضافة أول مستخدم مسجل كأدمن
INSERT INTO public.admins (user_id)
SELECT id 
FROM auth.users 
ORDER BY created_at ASC 
LIMIT 1
ON CONFLICT (user_id) DO NOTHING;

-- إضافة المستخدم المحدد كأدمن (إذا كان موجوداً)
INSERT INTO public.admins (user_id) 
VALUES ('c8349fe8-790f-4675-9c48-d8862a071ab8')
ON CONFLICT (user_id) DO NOTHING;

-- ========================================
-- 3. إصلاح سياسات RLS لجدول home_sections
-- ========================================
-- حذف السياسات القديمة إن وجدت
DROP POLICY IF EXISTS "home_sections_admin_all" ON public.home_sections;
DROP POLICY IF EXISTS "home_sections_public_read" ON public.home_sections;

-- إنشاء سياسة للأدمن (كامل الصلاحيات)
CREATE POLICY "home_sections_admin_all" 
ON public.home_sections
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

-- إنشاء سياسة للقراءة العامة
CREATE POLICY "home_sections_public_read" 
ON public.home_sections
FOR SELECT
USING (true);

-- التأكد من تفعيل RLS
ALTER TABLE public.home_sections ENABLE ROW LEVEL SECURITY;

-- ========================================
-- 4. إصلاح سياسات RLS لجدول reviews (إذا لم تكن موجودة)
-- ========================================
-- حذف السياسات القديمة
DROP POLICY IF EXISTS "reviews_admin_all" ON public.reviews;
DROP POLICY IF EXISTS "reviews_public_approved_only" ON public.reviews;
DROP POLICY IF EXISTS "reviews_public_insert" ON public.reviews;

-- سياسة الأدمن - كامل الصلاحيات
CREATE POLICY "reviews_admin_all" 
ON public.reviews
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

-- سياسة القراءة للعامة - فقط المراجعات المعتمدة
CREATE POLICY "reviews_public_approved_only" 
ON public.reviews
FOR SELECT
USING (is_approved = true);

-- سياسة الإضافة للجميع
CREATE POLICY "reviews_public_insert" 
ON public.reviews
FOR INSERT
WITH CHECK (true);

-- التأكد من تفعيل RLS
ALTER TABLE public.reviews ENABLE ROW LEVEL SECURITY;

-- ========================================
-- 5. إصلاح سياسات RLS لجدول sub_categories
-- ========================================
DROP POLICY IF EXISTS "sub_categories_admin_all" ON public.sub_categories;
DROP POLICY IF EXISTS "sub_categories_public_read" ON public.sub_categories;

CREATE POLICY "sub_categories_admin_all" 
ON public.sub_categories
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

CREATE POLICY "sub_categories_public_read" 
ON public.sub_categories
FOR SELECT
USING (is_active = true);

ALTER TABLE public.sub_categories ENABLE ROW LEVEL SECURITY;

-- ========================================
-- 6. إصلاح سياسات RLS لجدول banners
-- ========================================
DROP POLICY IF EXISTS "banners_admin_all" ON public.banners;
DROP POLICY IF EXISTS "banners_public_read" ON public.banners;

CREATE POLICY "banners_admin_all" 
ON public.banners
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

CREATE POLICY "banners_public_read" 
ON public.banners
FOR SELECT
USING (is_active = true);

ALTER TABLE public.banners ENABLE ROW LEVEL SECURITY;

-- ========================================
-- 7. إصلاح سياسات RLS لجدول products
-- ========================================
DROP POLICY IF EXISTS "products_admin_all" ON public.products;
DROP POLICY IF EXISTS "products_public_read" ON public.products;

CREATE POLICY "products_admin_all" 
ON public.products
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

CREATE POLICY "products_public_read" 
ON public.products
FOR SELECT
USING (true);

ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;

-- ========================================
-- 8. إصلاح سياسات RLS لجدول app_settings
-- ========================================
DROP POLICY IF EXISTS "app_settings_admin_all" ON public.app_settings;
DROP POLICY IF EXISTS "app_settings_public_read" ON public.app_settings;

CREATE POLICY "app_settings_admin_all" 
ON public.app_settings
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

CREATE POLICY "app_settings_public_read" 
ON public.app_settings
FOR SELECT
USING (true);

ALTER TABLE public.app_settings ENABLE ROW LEVEL SECURITY;

-- ========================================
-- 9. إنشاء فهارس لتحسين الأداء
-- ========================================
CREATE INDEX IF NOT EXISTS idx_categories_icon_name ON public.categories(icon_name);
CREATE INDEX IF NOT EXISTS idx_categories_sort_order ON public.categories(sort_order);
CREATE INDEX IF NOT EXISTS idx_reviews_is_approved ON public.reviews(is_approved);
CREATE INDEX IF NOT EXISTS idx_reviews_product_id ON public.reviews(product_id);
CREATE INDEX IF NOT EXISTS idx_sub_categories_parent ON public.sub_categories(parent_category_id);
CREATE INDEX IF NOT EXISTS idx_sub_categories_active ON public.sub_categories(is_active);

-- ========================================
-- 10. التحقق من النتائج
-- ========================================

-- عرض الأدمنز
DO $$
BEGIN
  RAISE NOTICE '========================================';
  RAISE NOTICE 'قائمة الأدمنز:';
  RAISE NOTICE '========================================';
END $$;

SELECT 
  a.user_id,
  u.email,
  u.created_at as registered_at
FROM public.admins a
LEFT JOIN auth.users u ON u.id = a.user_id
ORDER BY u.created_at;

-- عرض الأقسام مع الأيقونات
DO $$
BEGIN
  RAISE NOTICE '========================================';
  RAISE NOTICE 'الأقسام مع الأيقونات:';
  RAISE NOTICE '========================================';
END $$;

SELECT 
  id,
  name,
  icon_name,
  is_active,
  sort_order
FROM public.categories
ORDER BY sort_order;

-- عرض السياسات
DO $$
BEGIN
  RAISE NOTICE '========================================';
  RAISE NOTICE 'السياسات المطبقة:';
  RAISE NOTICE '========================================';
END $$;

SELECT 
  schemaname,
  tablename,
  policyname,
  permissive,
  roles,
  cmd
FROM pg_policies 
WHERE tablename IN ('categories', 'home_sections', 'reviews', 'products', 'banners', 'sub_categories', 'app_settings')
ORDER BY tablename, policyname;

-- ========================================
-- النتيجة النهائية
-- ========================================
DO $$
BEGIN
  RAISE NOTICE '========================================';
  RAISE NOTICE '✅ تم إصلاح جميع المشاكل بنجاح!';
  RAISE NOTICE '========================================';
  RAISE NOTICE 'التحسينات المطبقة:';
  RAISE NOTICE '1. ✅ إضافة حقل icon_name للأقسام';
  RAISE NOTICE '2. ✅ إضافة المستخدمين كأدمنز';
  RAISE NOTICE '3. ✅ إصلاح سياسات RLS لجميع الجداول';
  RAISE NOTICE '4. ✅ إضافة فهارس لتحسين الأداء';
  RAISE NOTICE '========================================';
  RAISE NOTICE 'الآن يمكنك:';
  RAISE NOTICE '- إدارة الأقسام والمنتجات';
  RAISE NOTICE '- ترتيب أقسام الصفحة الرئيسية';
  RAISE NOTICE '- الموافقة على المراجعات';
  RAISE NOTICE '- تعديل إعدادات التطبيق';
  RAISE NOTICE '========================================';
END $$;
