class CartItem {
  final int productId;
  final int? foodItemId;
  final int? serverCartItemId;
  final String itemType;
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
    this.foodItemId,
    this.serverCartItemId,
    this.itemType = 'PRODUCT',
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
      minimumOrderQuantity: json['minimum_order_quantity'] as int,
      stockQuantity: json['stock_quantity'] as int,
      image: json['image'] as String?,
      quantity: json['quantity'] as int,
      itemType: json['item_type']?.toString() ?? 'PRODUCT',
      foodItemId: json['food_item_id'] == null
          ? null
          : int.tryParse(json['food_item_id'].toString()),
    );
  }

  factory CartItem.fromServerJson(Map<String, dynamic> json) {
    final itemType = json['item_type']?.toString() ?? 'PRODUCT';
    final isFood = itemType == 'FOOD';
    final itemId = int.tryParse(
      (isFood ? json['food_item'] : json['product']).toString(),
    );
    final cartId = int.tryParse(json['id'].toString());
    final quantity = int.tryParse(json['quantity'].toString());
    final price = double.tryParse(
      (isFood ? json['food_price'] : json['product_price']).toString(),
    );

    if (itemId == null || cartId == null || quantity == null || price == null) {
      throw const FormatException('Invalid cart item returned by the server.');
    }

    return CartItem(
      productId: itemId,
      foodItemId: isFood ? itemId : null,
      serverCartItemId: cartId,
      itemType: itemType,
      productName:
          (isFood ? json['food_name'] : json['product_name'])?.toString() ??
          (isFood ? 'Food item' : 'Product'),
      sku: json['product_sku']?.toString() ?? '',
      price: price,
      unit: isFood ? 'item' : 'unit',
      minimumOrderQuantity: 1,
      stockQuantity: 999999,
      image: (isFood ? json['food_image'] : json['product_image'])?.toString(),
      quantity: quantity,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'product_id': productId,
      'food_item_id': foodItemId,
      'item_type': itemType,
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
