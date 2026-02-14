-- ========================================
-- Security hardening (RLS policies)
-- Date: 2026-01-23
-- هدف السكريبت:
-- - منع أي صلاحيات خطيرة للـ anon/public (خصوصاً storage و wishlist)
-- - جعل wishlist بعد تسجيل الدخول فقط
-- - منع anon SELECT على الطلبات
-- ========================================

-- ========================================
-- 1) Wishlist: بعد تسجيل الدخول فقط
-- ========================================
ALTER TABLE public.wishlist ENABLE ROW LEVEL SECURITY;

-- إزالة السياسات العامة غير الآمنة
DROP POLICY IF EXISTS "Allow public delete wishlist" ON public.wishlist;
DROP POLICY IF EXISTS "Allow public insert wishlist" ON public.wishlist;
DROP POLICY IF EXISTS "Allow public select wishlist" ON public.wishlist;

-- إزالة السياسات الحالية لإعادة تعريفها بشكل صريح
DROP POLICY IF EXISTS wishlist_user_all ON public.wishlist;
DROP POLICY IF EXISTS wishlist_admin_all ON public.wishlist;

-- المستخدم: يدير مفضلته فقط بناءً على ايميله في JWT
CREATE POLICY wishlist_user_all
  ON public.wishlist
  FOR ALL
  TO authenticated
  USING ((auth.jwt() ->> 'email') = user_email)
  WITH CHECK ((auth.jwt() ->> 'email') = user_email);

-- الأدمن: صلاحية كاملة
CREATE POLICY wishlist_admin_all
  ON public.wishlist
  FOR ALL
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.admins a
      WHERE a.user_id = auth.uid()
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.admins a
      WHERE a.user_id = auth.uid()
    )
  );

-- منع التكرار (نفس المنتج لنفس المستخدم)
CREATE UNIQUE INDEX IF NOT EXISTS wishlist_user_email_product_id_uniq
  ON public.wishlist(user_email, product_id);


-- ========================================
-- 2) Orders: منع anon SELECT (تسريب بيانات)
-- ========================================
ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS orders_anon_whatsapp_select ON public.orders;

-- ملاحظة: نُبقي سياسة INSERT للـ anon (whatsapp + user_id is null) كما هي إن كانت موجودة.


-- ========================================
-- 3) Order items: anon INSERT فقط لطلبات whatsapp الخاصة بالزائر
-- ========================================
ALTER TABLE public.order_items ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS order_items_anon_whatsapp_all ON public.order_items;

CREATE POLICY order_items_anon_whatsapp_insert
  ON public.order_items
  FOR INSERT
  TO anon
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.orders o
      WHERE o.id = order_items.order_id
        AND o.user_id IS NULL
        AND o.platform = 'whatsapp'
    )
  );


-- ========================================
-- 4) Storage: منع anon من الرفع/التعديل على صور المنتجات والبانرات
-- ========================================
ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;

-- إزالة سياسات خطيرة تسمح للـ anon بالرفع/التعديل
DROP POLICY IF EXISTS "Allow All Access 1ifhysk_1" ON storage.objects;
DROP POLICY IF EXISTS "Allow All Access 1ifhysk_2" ON storage.objects;

-- إزالة سياسات واسعة للمستخدمين المسجّلين (غير أدمن) إن كانت موجودة
DROP POLICY IF EXISTS "Allow Uploads" ON storage.objects;
DROP POLICY IF EXISTS "Allow Updates" ON storage.objects;
DROP POLICY IF EXISTS "Allow Deletes" ON storage.objects;

-- إزالة سياسة إدخال بانرات للأي authenticated بدون تحقق أدمن
DROP POLICY IF EXISTS "Admin Upload Banners" ON storage.objects;

-- إعادة تعريف إدارة صور المنتجات: أدمن فقط
DROP POLICY IF EXISTS "Admins manage product images" ON storage.objects;
CREATE POLICY "Admins manage product images"
  ON storage.objects
  FOR ALL
  TO authenticated
  USING (
    bucket_id = 'products'
    AND EXISTS (SELECT 1 FROM public.admins a WHERE a.user_id = auth.uid())
  )
  WITH CHECK (
    bucket_id = 'products'
    AND EXISTS (SELECT 1 FROM public.admins a WHERE a.user_id = auth.uid())
  );

-- إدارة البانرات: أدمن فقط
DROP POLICY IF EXISTS "Admins manage banners" ON storage.objects;
CREATE POLICY "Admins manage banners"
  ON storage.objects
  FOR ALL
  TO authenticated
  USING (
    bucket_id = 'banners'
    AND EXISTS (SELECT 1 FROM public.admins a WHERE a.user_id = auth.uid())
  )
  WITH CHECK (
    bucket_id = 'banners'
    AND EXISTS (SELECT 1 FROM public.admins a WHERE a.user_id = auth.uid())
  );

-- (نُبقي سياسات القراءة العامة للصور/البانرات/الأفاتار إن كانت موجودة).

DO $$
BEGIN
  RAISE NOTICE '✅ Security hardening migration applied.';
END $$;
