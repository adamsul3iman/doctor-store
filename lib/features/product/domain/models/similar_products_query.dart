class SimilarProductsQuery {
  final String categoryId;
  final String excludeId;
  final int limit;

  const SimilarProductsQuery({
    required this.categoryId,
    required this.excludeId,
    this.limit = 6,
  });

  @override
  bool operator ==(Object other) {
    return other is SimilarProductsQuery &&
        other.categoryId == categoryId &&
        other.excludeId == excludeId &&
        other.limit == limit;
  }

  @override
  int get hashCode => Object.hash(categoryId, excludeId, limit);
}
