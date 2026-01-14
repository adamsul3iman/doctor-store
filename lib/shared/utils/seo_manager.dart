import 'package:flutter/foundation.dart';
import 'package:meta_seo/meta_seo.dart';
import 'package:doctor_store/features/product/domain/models/product_model.dart';

class SeoManager {
  // 1. إنشاء نسخة من المكتبة
  static final _meta = MetaSEO();

  // 2. تهيئة المكتبة (يتم استدعاؤها في main.dart)
  static void init() {
    if (kIsWeb) {
      _meta.config();
    }
  }

  /// ضبط SEO لصفحة عامة (الهوم، من نحن، اتصل بنا، ...)
  static void setPageSeo({
    required String title,
    required String description,
    String? imageUrl,
  }) {
    if (!kIsWeb) return;

    _meta.author(author: 'Doctor Store');
    _meta.description(description: description);

    // استخدم نفس العنوان للوصف في Open Graph و Twitter
    _meta.ogTitle(ogTitle: title);
    _meta.ogDescription(ogDescription: description);

    if (imageUrl != null && imageUrl.isNotEmpty) {
      _meta.ogImage(ogImage: imageUrl);
    }

    _meta.twitterCard(twitterCard: TwitterCard.summaryLargeImage);
    _meta.twitterTitle(twitterTitle: title);
    _meta.twitterDescription(twitterDescription: description);
    if (imageUrl != null && imageUrl.isNotEmpty) {
      _meta.twitterImage(twitterImage: imageUrl);
    }
  }

  // 3. دالة ضبط إعدادات المنتج
  static void setProductSeo(Product product) {
    if (!kIsWeb) return;

    // وصف مختصر مخصص للسيو (يفضل من الحقل المخصص إن وجد)
    String desc;
    if (product.shortDescription != null && product.shortDescription!.trim().isNotEmpty) {
      desc = product.shortDescription!.trim();
    } else if (product.description.length > 100) {
      desc = "${product.description.substring(0, 100)}...";
    } else {
      desc = product.description;
    }

    // بناء كلمات مفتاحية ديناميكية من الاسم، الفئة والوسوم
    final keywordParts = <String>{
      'متجر الدكتور',
      'فرشات طبية',
      'مراتب',
      product.category,
      product.categoryArabic,
      ...product.tags,
      'الأردن',
    }.where((e) => e.trim().isNotEmpty).toList();

    // بيانات الميتا الأساسية (لجوجل)
    _meta.author(author: 'Doctor Store');
    _meta.description(description: "تسوق ${product.title} بسعر ${product.price} د.أ. $desc");
    _meta.keywords(keywords: keywordParts.join(', '));

    // بيانات المشاركة (Open Graph) - واتساب وفيسبوك
    _meta.ogTitle(ogTitle: product.title);
    _meta.ogDescription(ogDescription: desc.isNotEmpty ? desc : "🔥 عرض خاص: ${product.price} د.أ - اضغط للتفاصيل");
    _meta.ogImage(ogImage: product.imageUrl);

    // بيانات تويتر (Twitter Cards)
    _meta.twitterCard(twitterCard: TwitterCard.summaryLargeImage);
    _meta.twitterTitle(twitterTitle: product.title);
    _meta.twitterDescription(twitterDescription: desc.isNotEmpty ? desc : "الجودة والراحة الطبية بين يديك.");
    _meta.twitterImage(twitterImage: product.imageUrl);
  }
}
