import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/cart_item.dart';
import '../models/product.dart';

class CartService {
  static const String _cartKey = 'guest_cart';

  Future<List<CartItem>> getItems() async {
    final prefs = await SharedPreferences.getInstance();
    final String? cartJson = prefs.getString(_cartKey);

    if (cartJson == null || cartJson.isEmpty) {
      return [];
    }

    try {
      final List<dynamic> decoded = jsonDecode(cartJson) as List<dynamic>;

      return decoded
          .map(
            (item) => CartItem.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList();
    } catch (_) {
      await prefs.remove(_cartKey);
      return [];
    }
  }

  Future<void> _saveItems(List<CartItem> items) async {
    final prefs = await SharedPreferences.getInstance();

    final String cartJson = jsonEncode(
      items.map((item) => item.toJson()).toList(),
    );

    await prefs.setString(_cartKey, cartJson);
  }

  Future<String?> addProduct(Product product) async {
    if (product.stockQuantity < product.minimumOrderQuantity) {
      return 'This product does not have enough stock to order.';
    }

    final List<CartItem> items = await getItems();

    final int index = items.indexWhere(
      (item) => item.productId == product.id,
    );

    if (index != -1) {
      final CartItem existingItem = items[index];
      final int newQuantity = existingItem.quantity + 1;

      if (newQuantity < product.minimumOrderQuantity) {
        return 'Minimum order quantity is '
            '${product.minimumOrderQuantity} ${product.unit}.';
      }

      if (newQuantity > product.stockQuantity) {
        return 'Not enough stock available.';
      }

      existingItem.quantity = newQuantity;
    } else {
      items.add(
        CartItem(
          productId: product.id,
          productName: product.name,
          sku: product.sku,
          price: product.price,
          unit: product.unit,
          minimumOrderQuantity: product.minimumOrderQuantity,
          stockQuantity: product.stockQuantity,
          image: product.image,
          quantity: product.minimumOrderQuantity,
        ),
      );
    }

    await _saveItems(items);
    return null;
  }

  Future<String?> updateQuantity(int productId, int quantity) async {
    final List<CartItem> items = await getItems();

    final int index = items.indexWhere(
      (item) => item.productId == productId,
    );

    if (index == -1) {
      return 'Product not found in cart.';
    }

    final CartItem item = items[index];

    if (quantity < item.minimumOrderQuantity) {
      return 'Minimum order quantity is '
          '${item.minimumOrderQuantity} ${item.unit}.';
    }

    if (quantity > item.stockQuantity) {
      return 'Only ${item.stockQuantity} ${item.unit} available.';
    }

    item.quantity = quantity;

    await _saveItems(items);
    return null;
  }

  Future<void> removeProduct(int productId) async {
    final List<CartItem> items = await getItems();

    items.removeWhere((item) => item.productId == productId);

    await _saveItems(items);
  }

  Future<void> clearCart() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cartKey);
  }

  Future<int> getTotalItems() async {
    final List<CartItem> items = await getItems();

    return items.fold<int>(
      0,
      (total, item) => total + item.quantity,
    );
  }

  Future<double> getCartTotal() async {
    final List<CartItem> items = await getItems();

    return items.fold<double>(
      0,
      (total, item) => total + item.lineTotal,
    );
  }
}