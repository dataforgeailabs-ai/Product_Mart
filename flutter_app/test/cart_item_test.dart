import 'package:flutter_test/flutter_test.dart';
import 'package:hotel_supply_flutter/models/cart_item.dart';

void main() {
  group('CartItem.fromServerJson', () {
    test('parses a product line from the shared cart', () {
      final item = CartItem.fromServerJson({
        'id': 41,
        'item_type': 'PRODUCT',
        'product': 7,
        'product_name': 'Rice',
        'product_sku': 'RICE-1',
        'product_price': '4.50',
        'product_image': null,
        'food_item': null,
        'quantity': 2,
      });

      expect(item.itemType, 'PRODUCT');
      expect(item.productId, 7);
      expect(item.serverCartItemId, 41);
      expect(item.productName, 'Rice');
      expect(item.lineTotal, 9.0);
    });

    test('parses a food line without colliding with its catalog ID', () {
      final item = CartItem.fromServerJson({
        'id': 42,
        'item_type': 'FOOD',
        'product': null,
        'product_name': null,
        'product_sku': null,
        'product_price': null,
        'product_image': null,
        'food_item': 7,
        'food_name': 'Paneer Curry',
        'food_price': '12.00',
        'food_image': '/media/paneer.jpg',
        'quantity': 3,
      });

      expect(item.itemType, 'FOOD');
      expect(item.foodItemId, 7);
      expect(item.serverCartItemId, 42);
      expect(item.productName, 'Paneer Curry');
      expect(item.image, '/media/paneer.jpg');
      expect(item.lineTotal, 36.0);
    });
  });
}
