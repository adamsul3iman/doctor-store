// lib/utils/app_constants.dart

class AppConstants {
  // رابط الأساس للموقع (يُستخدم لبناء روابط المشاركة)
  // تأكد من مطابقته للدومين الفعلي في الإنتاج.
  static const String webBaseUrl = 'https://drstore.me';

  // جداول Supabase
  static const String productsTable = 'products';
  static const String bannersTable = 'banners';
  static const String ordersTable = 'orders';
  static const String orderItemsTable = 'order_items';
  static const String couponsTable = 'coupons';
  static const String clientsTable = 'clients';
  static const String reviewsTable = 'reviews';
  static const String wishlistTable = 'wishlist';
  static const String appSettingsTable = 'app_settings';

  // الأقسام (Categories)
  // ملاحظة مهمة جداً:
  // - هذه القيم يجب أن تطابق enum `public.product_category` في قاعدة البيانات.
  // - عند تعديل enum في Supabase (إضافة/إزالة قسم)، يجب تحديث هذه الثوابت
  //   وكذلك قائمة `_categories` في ProductFormScreen و `Product.categoryArabic`.
  static const String catBedding = 'bedding';
  static const String catMattresses = 'mattresses';
  static const String catPillows = 'pillows';
  static const String catFurniture = 'furniture';
  static const String catDining = 'dining_table';
  static const String catCarpets = 'carpets';
  static const String catBaby = 'baby_supplies';
  static const String catDecor = 'home_decor';
  static const String catTowels = 'towels'; // أضيفت بناء على SQL
  static const String catCurtains = 'curtains'; // تأكدت من إضافتها للـ enum في Postgres

  // حالات الطلب
  static const String statusNew = 'new';
  static const String statusCompleted = 'completed';
  static const String statusCancelled = 'cancelled';
}