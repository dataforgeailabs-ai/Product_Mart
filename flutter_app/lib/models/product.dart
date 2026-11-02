class Product {
  final int id;
  final int category;
  final String name;
  final String description;
  final String sku;
  final double price;
  final int stockQuantity;
  final int minimumOrderQuantity;
  final int minimumStockLevel;
  final bool isLowStock;
  final String unit;
  final String? image;
  final bool isActive;
  final Map<String, dynamic> categoryDetails;

  const Product({
    required this.id,
    required this.category,
    required this.name,
    required this.description,
    required this.sku,
    required this.price,
    required this.stockQuantity,
    required this.minimumOrderQuantity,
    required this.minimumStockLevel,
    required this.isLowStock,
    required this.unit,
    required this.image,
    required this.isActive,
    required this.categoryDetails,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'] as int,
      category: json['category'] as int,
      name: json['name'] as String,
      description: json['description'] as String? ?? '',
      sku: json['sku'] as String,
      price: double.parse(json['price'].toString()),
      stockQuantity: json['stock_quantity'] as int,
      minimumOrderQuantity: json['minimum_order_quantity'] as int,
      minimumStockLevel: json['minimum_stock_level'] as int,
      isLowStock: json['is_low_stock'] as bool,
      unit: json['unit'] as String,
      image: json['image'] as String?,
      isActive: json['is_active'] as bool,
      categoryDetails:
          json['category_details'] as Map<String, dynamic>? ?? {},
    );
  }

  factory Product.fromJsonMap(Map<String, dynamic> json) {
    return Product.fromJson(json);
  }

  String get categoryName =>
      categoryDetails['name'] as String? ?? 'Uncategorized';
}