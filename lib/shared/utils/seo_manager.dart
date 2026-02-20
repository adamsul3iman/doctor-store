import 'dart:html' as html;
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

  /// ضبط عنوان الصفحة (Tab Title) - يعمل فقط على الويب
  static void setTitle(String title) {
    if (!kIsWeb) return;
    html.document.title = title;
  }

  /// ضبط SEO لصفحة عامة (الهوم، من نحن، اتصل بنا، ...)
  static void setPageSeo({
    required String title,
    required String description,
    String? imageUrl,
  }) {
    if (!kIsWeb) return;

    // تعيين عنوان الصفحة
    setTitle(title);

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

    // تعيين عنوان الصفحة للمنتج
    setTitle('${product.title} | متجر الدكتور');

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
    _meta.ogDescription(ogDescription: desc.isNotEmpty ? desc : "عرض خاص: ${product.price} د.أ - اضغط للتفاصيل");
    _meta.ogImage(ogImage: product.imageUrl);

    // بيانات تويتر (Twitter Cards)
    _meta.twitterCard(twitterCard: TwitterCard.summaryLargeImage);
    _meta.twitterTitle(twitterTitle: product.title);
    _meta.twitterDescription(twitterDescription: desc.isNotEmpty ? desc : "الجودة والراحة الطبية بين يديك.");
    _meta.twitterImage(twitterImage: product.imageUrl);

    // 4. إضافة Product Schema (JSON-LD) لـ Google Rich Snippets
    _injectProductSchema(product, desc);
  }

  /// إضافة بيانات المنظمة (Structured Data) للمنتج
  static void _injectProductSchema(Product product, String description) {
    if (!kIsWeb) return;

    // إزالة أي script سابق للمنتج
    final existingScripts = html.document.querySelectorAll('script[data-type="product-schema"]');
    for (final script in existingScripts) {
      script.remove();
    }

    // بناء بيانات JSON-LD للمنتج
    final schemaData = {
      '@context': 'https://schema.org',
      '@type': 'Product',
      'name': product.title,
      'image': product.imageUrl,
      'description': description.isNotEmpty ? description : product.description,
      'brand': {
        '@type': 'Brand',
        'name': 'متجر الدكتور'
      },
      'offers': {
        '@type': 'Offer',
        'url': 'https://drstore.me/product/${product.slug ?? product.id}',
        'priceCurrency': 'JOD',
        'price': product.price.toStringAsFixed(2),
        'availability': product.isActive ? 'https://schema.org/InStock' : 'https://schema.org/OutOfStock',
        'itemCondition': 'https://schema.org/NewCondition',
        'seller': {
          '@type': 'Organization',
          'name': 'متجر الدكتور | Doctor Store'
        }
      },
      'aggregateRating': product.ratingCount > 0 ? {
        '@type': 'AggregateRating',
        'ratingValue': product.ratingAverage.toStringAsFixed(1),
        'reviewCount': product.ratingCount.toString()
      } : null,
      'category': product.categoryArabic,
    };

    // إنشاء عنصر script جديد
    final scriptElement = html.document.createElement('script');
    scriptElement.setAttribute('type', 'application/ld+json');
    scriptElement.setAttribute('data-type', 'product-schema');
    scriptElement.text = _jsonEncode(schemaData);

    // إضافة إلى head
    html.document.head?.append(scriptElement);
  }

  /// ترميز JSON بشكل مبسط
  static String _jsonEncode(Map<String, dynamic> data) {
    // إزالة القيم null
    final cleanData = <String, dynamic>{};
    data.forEach((key, value) {
      if (value != null) {
        cleanData[key] = value;
      }
    });

    // ترميز يدوي بسيط
    final parts = <String>[];
    cleanData.forEach((key, value) {
      if (value is String) {
        parts.add('"$key": "${_escapeJson(value)}"');
      } else if (value is num) {
        parts.add('"$key": $value');
      } else if (value is bool) {
        parts.add('"$key": $value');
      } else if (value is Map<String, dynamic>) {
        parts.add('"$key": ${_jsonEncode(value)}');
      }
    });

    return '{${parts.join(', ')}}';
  }

  /// تهرب من أحرف خاصة في JSON
  static String _escapeJson(String text) {
    return text
      .replaceAll('\\', '\\\\')
      .replaceAll('"', '\\"')
      .replaceAll('\n', '\\n')
      .replaceAll('\r', '\\r')
      .replaceAll('\t', '\\t');
  }
}
