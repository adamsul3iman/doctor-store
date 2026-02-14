import 'package:flutter/material.dart';

/// أنواع الأقسام المتاحة في الصفحة الرئيسية
class HomeSectionType {
  final String key;
  final String label;
  final String labelAr;
  final IconData icon;

  const HomeSectionType._(this.key, this.label, this.labelAr, this.icon);

  static const hero = HomeSectionType._(
    'hero',
    'Hero Banner',
    'بانر رئيسي',
    Icons.image,
  );
  static const categories = HomeSectionType._(
    'categories',
    'Categories Grid',
    'شبكة الأقسام',
    Icons.grid_view,
  );
  static const flashSale = HomeSectionType._(
    'flash_sale',
    'Flash Sale',
    'عروض محدودة',
    Icons.timer,
  );
  static const latestProducts = HomeSectionType._(
    'latest',
    'Latest Products',
    'وصل حديثاً',
    Icons.new_releases,
  );
  static const featuredProducts = HomeSectionType._(
    'featured',
    'Featured Products',
    'منتجات مميزة',
    Icons.star,
  );
  static const bestSellers = HomeSectionType._(
    'best_sellers',
    'Best Sellers',
    'الأكثر مبيعاً',
    Icons.trending_up,
  );
  static const customBanner = HomeSectionType._(
    'custom_banner',
    'Custom Banner',
    'بانر مخصص',
    Icons.ad_units,
  );
  static const productCarousel = HomeSectionType._(
    'product_carousel',
    'Product Carousel',
    'سلة منتجات',
    Icons.view_carousel,
  );
  static const categoryShowcase = HomeSectionType._(
    'category_showcase',
    'Category Showcase',
    'عرض قسم',
    Icons.category,
  );
  static const trustSignals = HomeSectionType._(
    'trust_signals',
    'Trust Signals',
    'عناصر الثقة',
    Icons.verified,
  );
  static const testimonials = HomeSectionType._(
    'testimonials',
    'Testimonials',
    'آراء العملاء',
    Icons.reviews,
  );
  static const newsletter = HomeSectionType._(
    'newsletter',
    'Newsletter',
    'النشرة البريدية',
    Icons.email,
  );
  static const ownerSection = HomeSectionType._(
    'owner_section',
    'Owner Section',
    'قسم صاحب المتجر',
    Icons.person,
  );
  static const babySection = HomeSectionType._(
    'baby_section',
    'Baby Section',
    'عالم الطفل',
    Icons.baby_changing_station,
  );
  static const diningSection = HomeSectionType._(
    'dining_section',
    'Dining Section',
    'طاولات السفرة',
    Icons.table_restaurant,
  );
  static const mattressSection = HomeSectionType._(
    'mattress_section',
    'Mattress Section',
    'الفرشات الطبية',
    Icons.bed,
  );
  static const pillowSection = HomeSectionType._(
    'pillow_section',
    'Pillow Section',
    'الوسائد',
    Icons.hotel,
  );
  static const middleBanner = HomeSectionType._(
    'middle_banner',
    'Middle Banner',
    'بانر وسط الصفحة',
    Icons.ad_units,
  );
  static const liveActivity = HomeSectionType._(
    'live_activity',
    'Live Activity',
    'النشاط الحي',
    Icons.notifications_active,
  );
  static const personalized = HomeSectionType._(
    'personalized',
    'Personalized',
    'خصيصاً لك',
    Icons.recommend,
  );
  static const custom = HomeSectionType._(
    'custom',
    'Custom Section',
    'قسم مخصص',
    Icons.dashboard_customize,
  );

  static const List<HomeSectionType> values = [
    hero,
    categories,
    flashSale,
    latestProducts,
    featuredProducts,
    bestSellers,
    customBanner,
    productCarousel,
    categoryShowcase,
    trustSignals,
    testimonials,
    newsletter,
    ownerSection,
    babySection,
    diningSection,
    mattressSection,
    pillowSection,
    middleBanner,
    liveActivity,
    personalized,
    custom,
  ];

  static HomeSectionType fromKey(String key) {
    return values.firstWhere(
      (t) => t.key == key,
      orElse: () => custom,
    );
  }
}

/// شروط عرض القسم
class DisplayCondition {
  final String key;
  final String labelAr;

  const DisplayCondition._(this.key, this.labelAr);

  static const always = DisplayCondition._('always', 'دائماً');
  static const userLoggedIn =
      DisplayCondition._('user_logged_in', 'المستخدم مسجل دخول');
  static const userGuest = DisplayCondition._('user_guest', 'المستخدم زائر');
  static const hasItemsInCart =
      DisplayCondition._('has_items_in_cart', 'يوجد منتجات في السلة');
  static const firstVisit = DisplayCondition._('first_visit', 'أول زيارة');
  static const returningUser =
      DisplayCondition._('returning_user', 'مستخدم عائد');
  static const specificTime = DisplayCondition._('specific_time', 'وقت محدد');
  static const deviceMobile =
      DisplayCondition._('device_mobile', 'جهاز محمول فقط');
  static const deviceDesktop = DisplayCondition._('device_desktop', 'كمبيوتر فقط');

  static const List<DisplayCondition> values = [
    always,
    userLoggedIn,
    userGuest,
    hasItemsInCart,
    firstVisit,
    returningUser,
    specificTime,
    deviceMobile,
    deviceDesktop,
  ];

  static DisplayCondition fromKey(String key) {
    return values.firstWhere(
      (c) => c.key == key,
      orElse: () => always,
    );
  }
}

/// إعدادات القسم
class HomeSectionConfig {
  final String id;
  final HomeSectionType type;
  final String title;
  final String? subtitle;
  final bool enabled;
  final int sortOrder;
  final Map<String, dynamic>? settings;
  final List<DisplayCondition> displayConditions;
  final String? backgroundColor;
  final String? textColor;
  final double paddingHorizontal;
  final double paddingVertical;
  final bool fullWidth;
  final bool animateEntrance;
  final String animationType;

  HomeSectionConfig({
    required this.id,
    required this.type,
    required this.title,
    this.subtitle,
    this.enabled = true,
    this.sortOrder = 0,
    this.settings,
    this.displayConditions = const [],
    this.backgroundColor,
    this.textColor,
    this.paddingHorizontal = 16,
    this.paddingVertical = 16,
    this.fullWidth = false,
    this.animateEntrance = false,
    this.animationType = 'fade',
  });

  factory HomeSectionConfig.fromJson(Map<String, dynamic> json) {
    return HomeSectionConfig(
      id: json['id'] as String,
      type: HomeSectionType.fromKey(json['type'] as String),
      title: json['title'] as String,
      subtitle: json['subtitle'] as String?,
      enabled: json['enabled'] as bool? ?? true,
      sortOrder: json['sort_order'] as int? ?? 0,
      settings: json['settings'] as Map<String, dynamic>?,
      displayConditions: (json['display_conditions'] as List<dynamic>?)
              ?.map((e) => DisplayCondition.fromKey(e as String))
              .toList() ??
          const [],
      backgroundColor: json['background_color'] as String?,
      textColor: json['text_color'] as String?,
      paddingHorizontal: (json['padding_horizontal'] as num?)?.toDouble() ?? 16,
      paddingVertical: (json['padding_vertical'] as num?)?.toDouble() ?? 16,
      fullWidth: json['full_width'] as bool? ?? false,
      animateEntrance: json['animate_entrance'] as bool? ?? false,
      animationType: json['animation_type'] as String? ?? 'fade',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.key,
      'title': title,
      'subtitle': subtitle,
      'enabled': enabled,
      'sort_order': sortOrder,
      'settings': settings,
      'display_conditions': displayConditions.map((c) => c.key).toList(),
      'background_color': backgroundColor,
      'text_color': textColor,
      'padding_horizontal': paddingHorizontal,
      'padding_vertical': paddingVertical,
      'full_width': fullWidth,
      'animate_entrance': animateEntrance,
      'animation_type': animationType,
    };
  }

  HomeSectionConfig copyWith({
    String? id,
    HomeSectionType? type,
    String? title,
    String? subtitle,
    bool? enabled,
    int? sortOrder,
    Map<String, dynamic>? settings,
    List<DisplayCondition>? displayConditions,
    String? backgroundColor,
    String? textColor,
    double? paddingHorizontal,
    double? paddingVertical,
    bool? fullWidth,
    bool? animateEntrance,
    String? animationType,
  }) {
    return HomeSectionConfig(
      id: id ?? this.id,
      type: type ?? this.type,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      enabled: enabled ?? this.enabled,
      sortOrder: sortOrder ?? this.sortOrder,
      settings: settings ?? this.settings,
      displayConditions: displayConditions ?? this.displayConditions,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      textColor: textColor ?? this.textColor,
      paddingHorizontal: paddingHorizontal ?? this.paddingHorizontal,
      paddingVertical: paddingVertical ?? this.paddingVertical,
      fullWidth: fullWidth ?? this.fullWidth,
      animateEntrance: animateEntrance ?? this.animateEntrance,
      animationType: animationType ?? this.animationType,
    );
  }
}

/// تخطيط الصفحة الرئيسية الكامل
class HomeLayout {
  final String id;
  final String name;
  final List<HomeSectionConfig> sections;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? abTestVariant;
  final Map<String, dynamic> metadata;

  HomeLayout({
    required this.id,
    required this.name,
    this.sections = const [],
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
    this.abTestVariant,
    this.metadata = const {},
  });

  factory HomeLayout.fromJson(Map<String, dynamic> json) {
    return HomeLayout(
      id: json['id'] as String,
      name: json['name'] as String,
      sections: (json['sections'] as List<dynamic>?)
              ?.map(
                (e) =>
                    HomeSectionConfig.fromJson(e as Map<String, dynamic>),
              )
              .toList() ??
          const [],
      isActive: json['is_active'] as bool? ?? true,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
      abTestVariant: json['ab_test_variant'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>? ?? const {},
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'sections': sections.map((s) => s.toJson()).toList(),
      'is_active': isActive,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'ab_test_variant': abTestVariant,
      'metadata': metadata,
    };
  }

  HomeLayout copyWith({
    String? id,
    String? name,
    List<HomeSectionConfig>? sections,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? abTestVariant,
    Map<String, dynamic>? metadata,
  }) {
    return HomeLayout(
      id: id ?? this.id,
      name: name ?? this.name,
      sections: sections ?? this.sections,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      abTestVariant: abTestVariant ?? this.abTestVariant,
      metadata: metadata ?? this.metadata,
    );
  }
}

/// قالب ذكي للأقسام
class SmartSectionTemplate {
  final String id;
  final String name;
  final String nameAr;
  final String description;
  final String descriptionAr;
  final HomeSectionType type;
  final Map<String, dynamic> defaultSettings;
  final List<String> recommendedFor;
  final bool isAiGenerated;
  final String? previewImageUrl;

  SmartSectionTemplate({
    required this.id,
    required this.name,
    required this.nameAr,
    required this.description,
    required this.descriptionAr,
    required this.type,
    this.defaultSettings = const {},
    this.recommendedFor = const [],
    this.isAiGenerated = false,
    this.previewImageUrl,
  });

  factory SmartSectionTemplate.fromJson(Map<String, dynamic> json) {
    return SmartSectionTemplate(
      id: json['id'] as String,
      name: json['name'] as String,
      nameAr: json['name_ar'] as String,
      description: json['description'] as String,
      descriptionAr: json['description_ar'] as String,
      type: HomeSectionType.fromKey(json['type'] as String),
      defaultSettings:
          json['default_settings'] as Map<String, dynamic>? ?? const {},
      recommendedFor:
          (json['recommended_for'] as List<dynamic>?)?.cast<String>() ??
              const [],
      isAiGenerated: json['is_ai_generated'] as bool? ?? false,
      previewImageUrl: json['preview_image_url'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'name_ar': nameAr,
      'description': description,
      'description_ar': descriptionAr,
      'type': type.key,
      'default_settings': defaultSettings,
      'recommended_for': recommendedFor,
      'is_ai_generated': isAiGenerated,
      'preview_image_url': previewImageUrl,
    };
  }
}

/// اقتراحات الذكاء الاصطناعي للتخطيط
class LayoutAiSuggestion {
  final String id;
  final String title;
  final String description;
  final List<HomeSectionConfig> suggestedSections;
  final double confidenceScore;
  final String? reasoning;

  LayoutAiSuggestion({
    required this.id,
    required this.title,
    required this.description,
    required this.suggestedSections,
    this.confidenceScore = 0,
    this.reasoning,
  });

  factory LayoutAiSuggestion.fromJson(Map<String, dynamic> json) {
    return LayoutAiSuggestion(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      suggestedSections: (json['suggested_sections'] as List<dynamic>)
          .map(
            (e) => HomeSectionConfig.fromJson(e as Map<String, dynamic>),
          )
          .toList(),
      confidenceScore: (json['confidence_score'] as num).toDouble(),
      reasoning: json['reasoning'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'suggested_sections': suggestedSections.map((s) => s.toJson()).toList(),
      'confidence_score': confidenceScore,
      'reasoning': reasoning,
    };
  }
}
