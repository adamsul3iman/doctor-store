/// Enum for order status values in the database
enum OrderStatus {
  new_,      // 'new' in DB (reserved keyword in Dart)
  pending,
  processing,
  shipped,
  delivered,
  completed,
  cancelled,
  refunded;

  /// Convert DB string to enum
  factory OrderStatus.fromString(String? value) {
    switch (value?.toLowerCase()) {
      case 'new':
        return OrderStatus.new_;
      case 'pending':
        return OrderStatus.pending;
      case 'processing':
        return OrderStatus.processing;
      case 'shipped':
        return OrderStatus.shipped;
      case 'delivered':
        return OrderStatus.delivered;
      case 'completed':
        return OrderStatus.completed;
      case 'cancelled':
        return OrderStatus.cancelled;
      case 'refunded':
        return OrderStatus.refunded;
      default:
        return OrderStatus.new_;
    }
  }

  /// Convert enum to DB string
  String toDbString() {
    switch (this) {
      case OrderStatus.new_:
        return 'new';
      case OrderStatus.pending:
        return 'pending';
      case OrderStatus.processing:
        return 'processing';
      case OrderStatus.shipped:
        return 'shipped';
      case OrderStatus.delivered:
        return 'delivered';
      case OrderStatus.completed:
        return 'completed';
      case OrderStatus.cancelled:
        return 'cancelled';
      case OrderStatus.refunded:
        return 'refunded';
    }
  }

  /// Arabic display name for UI
  String get displayName {
    switch (this) {
      case OrderStatus.new_:
        return 'جديد';
      case OrderStatus.pending:
        return 'قيد الانتظار';
      case OrderStatus.processing:
        return 'قيد المعالجة';
      case OrderStatus.shipped:
        return 'تم الشحن';
      case OrderStatus.delivered:
        return 'تم التوصيل';
      case OrderStatus.completed:
        return 'مكتمل';
      case OrderStatus.cancelled:
        return 'ملغى';
      case OrderStatus.refunded:
        return 'مسترجع';
    }
  }

  /// Color indicator for UI (returns hex color value)
  int get colorValue {
    switch (this) {
      case OrderStatus.new_:
        return 0xFF2196F3; // Blue
      case OrderStatus.pending:
        return 0xFFFF9800; // Orange
      case OrderStatus.processing:
        return 0xFF9C27B0; // Purple
      case OrderStatus.shipped:
        return 0xFF03A9F4; // Light Blue
      case OrderStatus.delivered:
        return 0xFF4CAF50; // Green
      case OrderStatus.completed:
        return 0xFF2E7D32; // Dark Green
      case OrderStatus.cancelled:
        return 0xFFE53935; // Red
      case OrderStatus.refunded:
        return 0xFF757575; // Grey
    }
  }
}

/// Order model matching the DB schema exactly
class Order {
  final String id;                    // uuid PK
  final DateTime createdAt;           // timestamptz NOT NULL
  final String customerName;          // text NOT NULL
  final String customerPhone;         // text NOT NULL
  final String customerAddress;       // text NOT NULL
  final double totalAmount;           // numeric NOT NULL
  final OrderStatus status;           // text (with default 'new')
  final String platform;              // text (with default 'whatsapp')
  final String? userId;               // uuid (nullable - for guest orders)

  const Order({
    required this.id,
    required this.createdAt,
    required this.customerName,
    required this.customerPhone,
    required this.customerAddress,
    required this.totalAmount,
    required this.status,
    required this.platform,
    this.userId,
  });

  /// Create from Supabase JSON response
  factory Order.fromJson(Map<String, dynamic> json) {
    // Parse created_at safely
    DateTime? parsedCreatedAt;
    final rawCreatedAt = json['created_at'];
    if (rawCreatedAt is String) {
      parsedCreatedAt = DateTime.tryParse(rawCreatedAt);
    }
    
    return Order(
      id: json['id']?.toString() ?? '',
      createdAt: parsedCreatedAt ?? DateTime.now(),
      customerName: json['customer_name']?.toString() ?? '',
      customerPhone: json['customer_phone']?.toString() ?? '',
      customerAddress: json['customer_address']?.toString() ?? '',
      totalAmount: (json['total_amount'] as num?)?.toDouble() ?? 0.0,
      status: OrderStatus.fromString(json['status']?.toString()),
      platform: json['platform']?.toString() ?? 'whatsapp',
      userId: json['user_id']?.toString(),
    );
  }

  /// Convert to JSON for Supabase insert/update
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'created_at': createdAt.toIso8601String(),
      'customer_name': customerName,
      'customer_phone': customerPhone,
      'customer_address': customerAddress,
      'total_amount': totalAmount,
      'status': status.toDbString(),
      'platform': platform,
      if (userId != null) 'user_id': userId,
    };
  }

  /// Create a copy with modified fields
  Order copyWith({
    String? id,
    DateTime? createdAt,
    String? customerName,
    String? customerPhone,
    String? customerAddress,
    double? totalAmount,
    OrderStatus? status,
    String? platform,
    String? userId,
  }) {
    return Order(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      customerAddress: customerAddress ?? this.customerAddress,
      totalAmount: totalAmount ?? this.totalAmount,
      status: status ?? this.status,
      platform: platform ?? this.platform,
      userId: userId ?? this.userId,
    );
  }

  /// Whether this order belongs to a logged-in user (not guest)
  bool get isAuthenticatedOrder => userId != null && userId!.isNotEmpty;

  /// Whether this is a guest order (no user_id)
  bool get isGuestOrder => userId == null || userId!.isEmpty;

  @override
  String toString() {
    return 'Order(id: $id, status: ${status.displayName}, total: $totalAmount, platform: $platform)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Order && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

/// OrderItem model matching the DB schema exactly
class OrderItem {
  final String id;              // uuid PK
  final String orderId;         // uuid FK (NOT NULL)
  final String productId;       // uuid (NOT NULL)
  final String productTitle;    // text (NOT NULL)
  final int quantity;           // integer (NOT NULL)
  final double price;           // numeric (NOT NULL)
  final String? selectedSize;   // text (nullable)
  final String? selectedColor;  // text (nullable)
  final String? imageUrl;       // text (nullable)

  const OrderItem({
    required this.id,
    required this.orderId,
    required this.productId,
    required this.productTitle,
    required this.quantity,
    required this.price,
    this.selectedSize,
    this.selectedColor,
    this.imageUrl,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      id: json['id']?.toString() ?? '',
      orderId: json['order_id']?.toString() ?? '',
      productId: json['product_id']?.toString() ?? '',
      productTitle: json['product_title']?.toString() ?? '',
      quantity: (json['quantity'] as num?)?.toInt() ?? 0,
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      selectedSize: json['selected_size']?.toString(),
      selectedColor: json['selected_color']?.toString(),
      imageUrl: json['image_url']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'order_id': orderId,
      'product_id': productId,
      'product_title': productTitle,
      'quantity': quantity,
      'price': price,
      if (selectedSize != null) 'selected_size': selectedSize,
      if (selectedColor != null) 'selected_color': selectedColor,
      if (imageUrl != null) 'image_url': imageUrl,
    };
  }

  OrderItem copyWith({
    String? id,
    String? orderId,
    String? productId,
    String? productTitle,
    int? quantity,
    double? price,
    String? selectedSize,
    String? selectedColor,
    String? imageUrl,
  }) {
    return OrderItem(
      id: id ?? this.id,
      orderId: orderId ?? this.orderId,
      productId: productId ?? this.productId,
      productTitle: productTitle ?? this.productTitle,
      quantity: quantity ?? this.quantity,
      price: price ?? this.price,
      selectedSize: selectedSize ?? this.selectedSize,
      selectedColor: selectedColor ?? this.selectedColor,
      imageUrl: imageUrl ?? this.imageUrl,
    );
  }

  /// Calculate line total for this item
  double get lineTotal => price * quantity;

  @override
  String toString() {
    return 'OrderItem($productTitle x$quantity @ $price)';
  }
}
