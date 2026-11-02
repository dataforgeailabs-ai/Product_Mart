class CartItem {
  final int productId;
  final String productName;
  final String sku;
  final double price;
  final String unit;
  final int minimumOrderQuantity;
  final int stockQuantity;
  final String? image;
  int quantity;

  CartItem({
    required this.productId,
    required this.productName,
    required this.sku,
    required this.price,
    required this.unit,
    required this.minimumOrderQuantity,
    required this.stockQuantity,
    required this.image,
    required this.quantity,
  });

  double get lineTotal => price * quantity;

  factory CartItem.fromProductJson(
    Map<String, dynamic> json, {
    required int quantity,
  }) {
    return CartItem(
      productId: json['id'] as int,
      productName: json['name'] as String,
      sku: json['sku'] as String,
      price: double.parse(json['price'].toString()),
      unit: json['unit'] as String,
      minimumOrderQuantity: json['minimum_order_quantity'] as int,
      stockQuantity: json['stock_quantity'] as int,
      image: json['image'] as String?,
      quantity: quantity,
    );
  }

  factory CartItem.fromJson(Map<String, dynamic> json) {
    return CartItem(
      productId: json['product_id'] as int,
      productName: json['product_name'] as String,
      sku: json['sku'] as String,
      price: (json['price'] as num).toDouble(),
      unit: json['unit'] as String,
      minimumOrderQuantity:
          json['minimum_order_quantity'] as int,
      stockQuantity: json['stock_quantity'] as int,
      image: json['image'] as String?,
      quantity: json['quantity'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'product_id': productId,
      'product_name': productName,
      'sku': sku,
      'price': price,
      'unit': unit,
      'minimum_order_quantity': minimumOrderQuantity,
      'stock_quantity': stockQuantity,
      'image': image,
      'quantity': quantity,
    };
  }
}