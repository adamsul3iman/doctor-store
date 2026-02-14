-- جدول إعدادات التطبيق
-- يُنفذ في Supabase SQL Editor

-- حذف الجدول إذا كان موجوداً (للتجربة فقط)
DROP TABLE IF EXISTS app_settings CASCADE;

-- إنشاء الجدول بالشكل الصحيح
CREATE TABLE app_settings (
    id INTEGER PRIMARY KEY,
    free_shipping_threshold NUMERIC NOT NULL,
    bundle_discount_percent NUMERIC NOT NULL,
    first_time_discount_percent NUMERIC NOT NULL,
    first_time_discount_code TEXT NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    CONSTRAINT single_row CHECK (id = 1)
);

-- إدراج القيم الافتراضية
INSERT INTO app_settings (id, free_shipping_threshold, bundle_discount_percent, first_time_discount_percent, first_time_discount_code)
VALUES (1, 100.0, 10.0, 15.0, 'WELCOME15')
ON CONFLICT (id) DO NOTHING;

-- تفعيل Row Level Security
ALTER TABLE app_settings ENABLE ROW LEVEL SECURITY;

-- السياسة: الجميع يمكنهم قراءة الإعدادات
CREATE POLICY "Allow public read access" ON app_settings
    FOR SELECT
    TO public
    USING (true);

-- السياسة: Admin فقط يمكنهم التعديل
CREATE POLICY "Allow admin update" ON app_settings
    FOR UPDATE
    TO authenticated
    USING (true)
    WITH CHECK (true);

-- تعليق على الجدول
COMMENT ON TABLE app_settings IS 'إعدادات التطبيق العامة مثل حد الشحن المجاني ونسب الخصومات';
COMMENT ON COLUMN app_settings.free_shipping_threshold IS 'الحد الأدنى للشحن المجاني (بالدينار)';
COMMENT ON COLUMN app_settings.bundle_discount_percent IS 'نسبة خصم المجموعة (%)';
COMMENT ON COLUMN app_settings.first_time_discount_percent IS 'نسبة خصم العملاء الجدد (%)';
COMMENT ON COLUMN app_settings.first_time_discount_code IS 'كود خصم العملاء الجدد';
