# Doctor Store - Database Schema (Supabase/PostgreSQL)

## Tables Overview
20 tables total for medical furniture e-commerce platform

---

## 1. addresses
User delivery addresses
- `id` (bigint, PK)
- `user_id` (uuid, NOT NULL)
- `title` (text, NOT NULL)
- `city` (text, NOT NULL)
- `address` (text, NOT NULL)
- `is_default` (boolean, default: false)

---

## 2. app_settings
Global application settings (singleton table)
- `id` (integer, NOT NULL, default: 1)
- `whatsapp_number` (text, default: '962790000000')
- `facebook_url` (text, nullable)
- `instagram_url` (text, nullable)
- `tiktok_url` (text, nullable)
- `owner_name` (text, default: 'د. آدم')
- `owner_bio` (text, default: 'خبرة 10 سنوات في مجال الراحة والنوم الصحي.')

---

## 3. banners
Homepage and promotional banners
- `id` (uuid, PK, default: gen_random_uuid())
- `created_at` (timestamp with time zone, default: now())
- `title` (text, nullable)
- `subtitle` (text, nullable)
- `image_url` (text, NOT NULL)
- `is_active` (boolean, default: true)
- `button_text` (text, default: 'تسوق الآن')
- `link_target` (text, default: '/category/bedding')
- `text_color` (text, default: '0xFFFFFFFF')
- `sort_order` (integer, default: 0)
- `position` (text, default: 'top')

---

## 4. categories
Product categories
- `id` (text, PK)
- `name` (text, NOT NULL)
- `subtitle` (text, default: '')
- `color_value` (bigint, default: 4278855239)
- `is_active` (boolean, default: true)
- `sort_order` (integer, default: 0)

## 4b. sub_categories
Dynamic sub-categories linked to main categories
- `id` (uuid, PK, default: gen_random_uuid())
- `name` (text, NOT NULL)
- `code` (text, unique, nullable)
- `parent_category_id` (text, NOT NULL, FK → categories.id)
- `sort_order` (integer, default: 0)
- `is_active` (boolean, default: true)
- `created_at` (timestamp with time zone, default: now())

---

## 5. clients
Newsletter/email subscribers
- `id` (uuid, PK, default: gen_random_uuid())
- `email` (text, NOT NULL)
- `created_at` (timestamp with time zone, default: now())

---

## 6. coupons
Discount coupons
- `id` (uuid, PK, default: gen_random_uuid())
- `code` (text, NOT NULL)
- `discount_type` (text, NOT NULL)
- `value` (numeric, NOT NULL)
- `expiration_date` (timestamp with time zone, nullable)
- `usage_limit` (integer, default: 1000)
- `used_count` (integer, default: 0)
- `is_active` (boolean, default: true)
- `created_at` (timestamp with time zone, default: now())

---

## 7. coupon_usage
Tracks coupon redemptions
- `id` (uuid, PK, default: gen_random_uuid())
- `coupon_id` (uuid, FK → coupons)
- `customer_phone` (text, NOT NULL)
- `order_id` (uuid, FK → orders)
- `used_at` (timestamp with time zone, default: now())

---

## 8. events
Analytics/tracking events
- `id` (uuid, PK, default: gen_random_uuid())
- `user_id` (uuid, nullable)
- `name` (text, NOT NULL)
- `props` (jsonb, nullable)
- `created_at` (timestamp with time zone, default: now())

---

## 9. favorites
User favorite products (alternative to wishlist)
- `id` (bigint, PK)
- `user_id` (uuid, NOT NULL)
- `product_id` (uuid, NOT NULL, FK → products)
- `created_at` (timestamp without time zone, default: now())

---

## 10. home_sections
Dynamic homepage section configuration
- `key` (text, PK)
- `enabled` (boolean, NOT NULL, default: true)
- `title` (text, nullable)
- `subtitle` (text, nullable)

---

## 11. order_items
Line items within orders
- `id` (uuid, PK, default: gen_random_uuid())
- `order_id` (uuid, NOT NULL, FK → orders)
- `product_id` (uuid, FK → products)
- `product_title` (text, NOT NULL)
- `quantity` (integer, NOT NULL)
- `price` (numeric, NOT NULL)
- `selected_size` (text, nullable)
- `selected_color` (text, nullable)
- `image_url` (text, nullable)

---

## 12. orders
Customer orders
- `id` (uuid, PK, default: gen_random_uuid())
- `created_at` (timestamp with time zone, default: now())
- `customer_name` (text, NOT NULL)
- `customer_phone` (text, NOT NULL)
- `customer_address` (text, NOT NULL)
- `total_amount` (numeric, NOT NULL)
- `status` (text, default: 'new')
- `platform` (text, default: 'whatsapp')
- `user_id` (uuid, nullable, FK → profiles)

---

## 13. products
Medical furniture products catalog
- `id` (uuid, PK, default: gen_random_uuid())
- `created_at` (timestamp with time zone, default: now())
- `title` (text, NOT NULL)
- `description` (text, nullable)
- `price` (numeric, NOT NULL)
- `image_url` (text, NOT NULL)
- `category` (USER-DEFINED enum, NOT NULL)
- `sub_category_id` (uuid, nullable, FK → sub_categories.id)
- `is_featured` (boolean, default: false)
- `options` (jsonb, default: {})
- `gallery` (jsonb, default: [])
- `old_price` (numeric, nullable)
- `rating_average` (double precision, default: 0)
- `rating_count` (integer, default: 0)
- `slug` (text, nullable)
- `is_flash_deal` (boolean, default: false)
- `short_description` (text, nullable)
- `tags` (text[], nullable)
- `variants` (jsonb, NOT NULL, default: [])
- `image_urls` (text[], nullable)

---

## 14. profiles
User profiles (extends Supabase auth.users)
- `id` (uuid, PK, FK → auth.users)
- `updated_at` (timestamp with time zone, default: now())
- `full_name` (text, nullable)
- `avatar_url` (text, nullable)
- `phone` (text, nullable)

---

## 15. reviews
Product reviews and ratings
- `id` (uuid, PK, default: gen_random_uuid())
- `created_at` (timestamp with time zone, default: now())
- `product_id` (uuid, NOT NULL, FK → products)
- `user_id` (uuid, NOT NULL, FK → profiles)
- `rating` (integer, NOT NULL)
- `comment` (text, nullable)
- `is_verified` (boolean, default: false)

---

## 16. seo_pages
SEO metadata for dynamic pages
- `id` (uuid, PK, default: gen_random_uuid())
- `page_path` (text, NOT NULL, unique)
- `title` (text, NOT NULL)
- `description` (text, nullable)
- `keywords` (text[], nullable)
- `og_image` (text, nullable)

---

## 17. static_pages
CMS-managed static pages (About, Privacy, Terms, etc.)
- `id` (uuid, PK, default: gen_random_uuid())
- `slug` (text, NOT NULL, unique)
- `title` (text, NOT NULL)
- `content` (text, NOT NULL)
- `is_published` (boolean, default: false)
- `created_at` (timestamp with time zone, default: now())
- `updated_at` (timestamp with time zone, default: now())

---

## 18. support_tickets
Customer support tickets
- `id` (uuid, PK, default: gen_random_uuid())
- `created_at` (timestamp with time zone, default: now())
- `user_id` (uuid, FK → profiles)
- `subject` (text, NOT NULL)
- `message` (text, NOT NULL)
- `status` (text, default: 'open')
- `priority` (text, default: 'medium')

---

## 19. user_carts
Shopping cart items
- `id` (uuid, PK, default: gen_random_uuid())
- `user_id` (uuid, NOT NULL, FK → profiles)
- `product_id` (uuid, NOT NULL, FK → products)
- `quantity` (integer, NOT NULL)
- `selected_size` (text, nullable)
- `selected_color` (text, nullable)
- `created_at` (timestamp with time zone, default: now())

---

## 20. wishlist
User wishlist (alternative to favorites)
- `id` (uuid, PK, default: gen_random_uuid())
- `user_id` (uuid, NOT NULL, FK → profiles)
- `product_id` (uuid, NOT NULL, FK → products)
- `created_at` (timestamp with time zone, default: now())

---

## Key Relationships

### User-Related
- `profiles.id` → `auth.users.id` (Supabase auth)
- `addresses.user_id` → `profiles.id`
- `orders.user_id` → `profiles.id`
- `favorites.user_id` → `profiles.id`
- `wishlist.user_id` → `profiles.id`
- `user_carts.user_id` → `profiles.id`
- `reviews.user_id` → `profiles.id`
- `support_tickets.user_id` → `profiles.id`

### Product-Related
- `order_items.product_id` → `products.id`
- `favorites.product_id` → `products.id`
- `wishlist.product_id` → `products.id`
- `user_carts.product_id` → `products.id`
- `reviews.product_id` → `products.id`

### Order-Related
- `order_items.order_id` → `orders.id`
- `coupon_usage.order_id` → `orders.id`

### Coupon-Related
- `coupon_usage.coupon_id` → `coupons.id`

---

## Notes
- All timestamps use UTC timezone
- UUIDs generated via `gen_random_uuid()`
- Categories use custom ENUM type
- JSONB fields: `products.options`, `products.gallery`, `products.variants`, `events.props`
- Array fields: `products.tags`, `products.image_urls`, `seo_pages.keywords`
