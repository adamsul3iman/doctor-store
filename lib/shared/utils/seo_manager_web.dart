// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:html' as html;

import 'package:flutter/foundation.dart';
import 'package:meta_seo/meta_seo.dart';
import 'package:doctor_store/features/product/domain/models/product_model.dart';

class SeoManager {
  static final _meta = MetaSEO();

  static void init() {
    if (kIsWeb) {
      _meta.config();
    }
  }

  static void setTitle(String title) {
    if (!kIsWeb) return;
    html.document.title = title;
  }

  static void setPageSeo({
    required String title,
    required String description,
    String? imageUrl,
  }) {
    if (!kIsWeb) return;

    setTitle(title);

    _meta.author(author: 'Doctor Store');
    _meta.description(description: description);

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

  static void setProductSeo(Product product) {
    if (!kIsWeb) return;

    setTitle('${product.title} | متجر الدكتور');

    String desc;
    if (product.shortDescription != null &&
        product.shortDescription!.trim().isNotEmpty) {
      desc = product.shortDescription!.trim();
    } else if (product.description.length > 100) {
      desc = "${product.description.substring(0, 100)}...";
    } else {
      desc = product.description;
    }

    final keywordParts = <String>{
      'متجر الدكتور',
      'فرشات طبية',
      'مراتب',
      product.category,
      product.categoryArabic,
      ...product.tags,
      'الأردن',
    }.where((e) => e.trim().isNotEmpty).toList();

    _meta.author(author: 'Doctor Store');
    _meta.description(
      description: 'تسوق ${product.title} بسعر ${product.price} د.أ. $desc',
    );
    _meta.keywords(keywords: keywordParts.join(', '));

    _meta.ogTitle(ogTitle: product.title);
    _meta.ogDescription(
      ogDescription: desc.isNotEmpty
          ? desc
          : 'عرض خاص: ${product.price} د.أ - اضغط للتفاصيل',
    );
    _meta.ogImage(ogImage: product.imageUrl);

    _meta.twitterCard(twitterCard: TwitterCard.summaryLargeImage);
    _meta.twitterTitle(twitterTitle: product.title);
    _meta.twitterDescription(
      twitterDescription:
          desc.isNotEmpty ? desc : 'الجودة والراحة الطبية بين يديك.',
    );
    _meta.twitterImage(twitterImage: product.imageUrl);

    _injectProductSchema(product, desc);
  }

  static void _injectProductSchema(Product product, String description) {
    if (!kIsWeb) return;

    final existingScripts =
        html.document.querySelectorAll('script[data-type="product-schema"]');
    for (final script in existingScripts) {
      script.remove();
    }

    final schemaData = {
      '@context': 'https://schema.org',
      '@type': 'Product',
      'name': product.title,
      'image': product.imageUrl,
      'description': description.isNotEmpty ? description : product.description,
      'brand': {
        '@type': 'Brand',
        'name': 'متجر الدكتور',
      },
      'offers': {
        '@type': 'Offer',
        'url': 'https://drstore.me/product/${product.slug ?? product.id}',
        'priceCurrency': 'JOD',
        'price': product.price.toStringAsFixed(2),
        'availability': product.isActive
            ? 'https://schema.org/InStock'
            : 'https://schema.org/OutOfStock',
        'itemCondition': 'https://schema.org/NewCondition',
        'seller': {
          '@type': 'Organization',
          'name': 'متجر الدكتور | Doctor Store',
        },
      },
      'aggregateRating': product.ratingCount > 0
          ? {
              '@type': 'AggregateRating',
              'ratingValue': product.ratingAverage.toStringAsFixed(1),
              'reviewCount': product.ratingCount.toString(),
            }
          : null,
      'category': product.categoryArabic,
    };

    final scriptElement = html.document.createElement('script');
    scriptElement.setAttribute('type', 'application/ld+json');
    scriptElement.setAttribute('data-type', 'product-schema');
    scriptElement.text = _jsonEncode(schemaData);

    html.document.head?.append(scriptElement);
  }

  static String _jsonEncode(Map<String, dynamic> data) {
    final cleanData = <String, dynamic>{};
    data.forEach((key, value) {
      if (value != null) {
        cleanData[key] = value;
      }
    });

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

  static String _escapeJson(String text) {
    return text
        .replaceAll('\\', '\\\\')
        .replaceAll('"', '\\"')
        .replaceAll('\n', '\\n')
        .replaceAll('\r', '\\r')
        .replaceAll('\t', '\\t');
  }
}
