import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/cart_item.dart';
import '../services/cart_service.dart';
import 'checkout_screen.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final CartService _cartService = CartService();
  final FlutterSecureStorage _secureStorage =
      const FlutterSecureStorage();

  List<CartItem> _items = [];
  final Map<int, int> _serverItemIds = {};

  bool _isLoading = true;
  bool _isUpdating = false;
  bool _isLoggedIn = false;
  String? _error;

  double get _cartTotal {
    return _items.fold<double>(
      0,
      (total, item) => total + item.lineTotal,
    );
  }

  int get _totalItems {
    return _items.fold<int>(
      0,
      (total, item) => total + item.quantity,
    );
  }

  @override
  void initState() {
    super.initState();
    _loadCart();
  }

  Future<Map<String, String>> _getHeaders() async {
    final accessToken = await _secureStorage.read(
      key: 'access_token',
    );

    if (accessToken == null || accessToken.isEmpty) {
      throw Exception('Please sign in to access your server cart.');
    }

    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $accessToken',
    };
  }

  Future<void> _loadCart() async {
    try {
      final accessToken = await _secureStorage.read(
        key: 'access_token',
      );

      if (accessToken == null || accessToken.isEmpty) {
        final guestItems = await _cartService.getItems();

        if (!mounted) return;

        setState(() {
          _isLoggedIn = false;
          _items = guestItems;
          _serverItemIds.clear();
          _isLoading = false;
          _error = null;
        });

        return;
      }

      final response = await http.get(
        Uri.parse(ApiConfig.cart),
        headers: await _getHeaders(),
      );

      if (response.statusCode != 200) {
        throw Exception(
          'Unable to load server cart. '
          'HTTP ${response.statusCode}: ${response.body}',
        );
      }

      final decoded = jsonDecode(response.body);

      if (decoded is! Map<String, dynamic>) {
        throw Exception('Invalid cart response from the server.');
      }

      final rawItems = decoded['items'];

      if (rawItems is! List) {
        throw Exception('Invalid cart items returned by the server.');
      }

      final List<CartItem> serverItems = [];
      final Map<int, int> itemIds = {};

      for (final rawItem in rawItems) {
        if (rawItem is! Map) {
          continue;
        }

        final item = Map<String, dynamic>.from(rawItem);

        final productId = int.tryParse(
          item['product'].toString(),
        );

        final cartItemId = int.tryParse(
          item['id'].toString(),
        );

        final quantity = int.tryParse(
          item['quantity'].toString(),
        );

        if (productId == null ||
            cartItemId == null ||
            quantity == null) {
          continue;
        }

        final price = double.tryParse(
          item['product_price'].toString(),
        );

        if (price == null) {
          continue;
        }

        serverItems.add(
          CartItem(
            productId: productId,
            productName:
                item['product_name']?.toString() ?? 'Product',
            sku: item['product_sku']?.toString() ?? '',
            price: price,
            unit: 'unit',
            minimumOrderQuantity: 1,
            stockQuantity: 999999,
            image: item['product_image']?.toString(),
            quantity: quantity,
          ),
        );

        itemIds[productId] = cartItemId;
      }

      if (!mounted) return;

      setState(() {
        _isLoggedIn = true;
        _items = serverItems;
        _serverItemIds
          ..clear()
          ..addAll(itemIds);
        _isLoading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _changeQuantity(
    CartItem item,
    int quantity,
  ) async {
    if (_isUpdating) return;

    setState(() {
      _isUpdating = true;
    });

    try {
      String? message;

      if (_isLoggedIn) {
        final cartItemId = _serverItemIds[item.productId];

        if (cartItemId == null) {
          throw Exception('Server cart item ID not found.');
        }

        final response = await http.patch(
          Uri.parse(
            '${ApiConfig.cart}items/$cartItemId/update/',
          ),
          headers: await _getHeaders(),
          body: jsonEncode({
            'quantity': quantity,
          }),
        );

        if (response.statusCode != 200) {
          final decoded = jsonDecode(response.body);

          message = decoded is Map
              ? (decoded['detail'] ?? 'Unable to update quantity.')
                  .toString()
              : 'Unable to update quantity.';

          throw Exception(message);
        }
      } else {
        message = await _cartService.updateQuantity(
          item.productId,
          quantity,
        );

        if (message != null) {
          throw Exception(message);
        }
      }

      await _loadCart();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString().replaceFirst('Exception: ', ''),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isUpdating = false;
        });
      }
    }
  }

  Future<void> _removeItem(CartItem item) async {
    if (_isUpdating) return;

    setState(() {
      _isUpdating = true;
    });

    try {
      if (_isLoggedIn) {
        final cartItemId = _serverItemIds[item.productId];

        if (cartItemId == null) {
          throw Exception('Server cart item ID not found.');
        }

        final response = await http.delete(
          Uri.parse(
            '${ApiConfig.cart}items/$cartItemId/remove/',
          ),
          headers: await _getHeaders(),
        );

        if (response.statusCode != 200) {
          throw Exception(
            'Unable to remove product. '
            'HTTP ${response.statusCode}',
          );
        }
      } else {
        await _cartService.removeProduct(item.productId);
      }

      await _loadCart();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${item.productName} removed from cart.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString().replaceFirst('Exception: ', ''),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isUpdating = false;
        });
      }
    }
  }

  Future<void> _proceedToCheckout() async {
    if (_isUpdating) return;

    if (!_isLoggedIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please sign in to proceed to checkout.',
          ),
        ),
      );
      return;
    }

    if (_items.isEmpty) return;

    final orderNo = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (context) => CheckoutScreen(
          items: List<CartItem>.from(_items),
          cartTotal: _cartTotal,
        ),
      ),
    );

    if (!mounted || orderNo == null) return;

    await _loadCart();

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Order $orderNo placed successfully.',
        ),
      ),
    );
  }

  Future<void> _clearCart() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear cart?'),
        content: const Text(
          'This will remove all products from your cart.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear Cart'),
          ),
        ],
      ),
    );

    if (confirm != true || _isUpdating) return;

    setState(() {
      _isUpdating = true;
    });

    try {
      if (_isLoggedIn) {
        for (final item in List<CartItem>.from(_items)) {
          final cartItemId = _serverItemIds[item.productId];

          if (cartItemId == null) continue;

          final response = await http.delete(
            Uri.parse(
              '${ApiConfig.cart}items/$cartItemId/remove/',
            ),
            headers: await _getHeaders(),
          );

          if (response.statusCode != 200) {
            throw Exception(
              'Unable to clear the entire cart. '
              'Some products may remain.',
            );
          }
        }
      } else {
        await _cartService.clearCart();
      }

      await _loadCart();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString().replaceFirst('Exception: ', ''),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isUpdating = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('My Cart ($_totalItems)'),
        actions: [
          if (_items.isNotEmpty)
            IconButton(
              tooltip: 'Clear cart',
              onPressed: _isUpdating ? null : _clearCart,
              icon: const Icon(Icons.delete_sweep_outlined),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: () {
                            setState(() {
                              _isLoading = true;
                            });

                            _loadCart();
                          },
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : _items.isEmpty
                  ? _buildEmptyCart()
                  : _buildCartContents(),
    );
  }

  Widget _buildEmptyCart() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.shopping_cart_outlined,
              size: 80,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            const Text(
              'Your cart is empty',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Add products from the catalog to get started.',
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.storefront_outlined),
              label: const Text('Continue Shopping'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCartContents() {
    return Column(
      children: [
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadCart,
            child: ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: _items.length,
              separatorBuilder: (context, index) =>
                  const SizedBox(height: 8),
              itemBuilder: (context, index) {
                return _buildCartItem(_items[index]);
              },
            ),
          ),
        ),
        _buildCartSummary(),
      ],
    );
  }

  Widget _buildCartItem(CartItem item) {
  return Card(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: 76,
              height: 76,
              color: Colors.grey.shade100,
              child: item.image != null && item.image!.isNotEmpty
                  ? Image.network(
                      item.image!.startsWith('http')
                          ? item.image!
                          : '${ApiConfig.baseUrl.replaceFirst('/api', '')}${item.image}',
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return const Icon(
                          Icons.inventory_2_outlined,
                          size: 32,
                          color: Colors.grey,
                        );
                      },
                    )
                  : const Icon(
                      Icons.inventory_2_outlined,
                      size: 32,
                      color: Colors.grey,
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.productName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text('SKU: ${item.sku}'),
                const SizedBox(height: 4),
                Text(
                  '₹${item.price.toStringAsFixed(2)} / ${item.unit}',
                ),
                const SizedBox(height: 4),
                Text(
                  'Subtotal: ₹${item.lineTotal.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    IconButton(
                      onPressed: _isUpdating || item.quantity <= 1
                          ? null
                          : () => _changeQuantity(
                                item,
                                item.quantity - 1,
                              ),
                      icon: const Icon(
                        Icons.remove_circle_outline,
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                    Text(
                      '${item.quantity}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      onPressed: _isUpdating
                          ? null
                          : () => _changeQuantity(
                                item,
                                item.quantity + 1,
                              ),
                      icon: const Icon(
                        Icons.add_circle_outline,
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                    const Spacer(),
                    IconButton(
                      tooltip: 'Remove product',
                      onPressed: _isUpdating
                          ? null
                          : () => _removeItem(item),
                      icon: const Icon(
                        Icons.delete_outline,
                        color: Colors.red,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

  Widget _buildCartSummary() {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 8,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Total quantity: $_totalItems'),
                const Text('Subtotal'),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Cart Total',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '₹${_cartTotal.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _isUpdating ? null : _proceedToCheckout,
                icon: const Icon(
                  Icons.shopping_bag_outlined,
                ),
                label: const Text('Proceed to Checkout'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}