// Point 8: Multiple images per product
class ProductImage {
  final int? id;
  final String productType; // 'installment' or 'electrical'
  final int productId;
  final String imagePath;
  final int sortOrder;
  final String createdAt;

  ProductImage({
    this.id,
    required this.productType,
    required this.productId,
    required this.imagePath,
    this.sortOrder = 0,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'product_type': productType,
        'product_id': productId,
        'image_path': imagePath,
        'sort_order': sortOrder,
        'created_at': createdAt,
      };

  factory ProductImage.fromMap(Map<String, dynamic> m) => ProductImage(
        id: m['id'] as int?,
        productType: m['product_type'] as String,
        productId: m['product_id'] as int,
        imagePath: m['image_path'] as String,
        sortOrder: m['sort_order'] as int? ?? 0,
        createdAt: m['created_at'] as String,
      );
}
