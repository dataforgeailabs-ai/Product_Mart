import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../main.dart' show LoginScreen;
import '../models/product.dart';
import 'cart_screen.dart';
import 'my_orders_screen.dart';
import 'profile_screen.dart';
import '../widgets/brand_logo.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final FlutterSecureStorage _secureStorage =
      const FlutterSecureStorage();

  List<Product> _products = [];
  List<Map<String, dynamic>> _categories = [];

  bool _isLoading = true;
  bool _isAddingToCart = false;
  bool _isCheckingAuth = true;
  bool _isLoggedIn = false;

  String? _errorMessage;
  int? _selectedCategoryId;
  int _cartItemCount = 0;

  @override
  void initState() {
    super.initState();
    _loadCatalog();
    _checkAuthentication();
  }

  Future<Map<String, String>> _getHeaders() async {
    final token = await _secureStorage.read(
      key: 'access_token',
    );

    if (token == null || token.isEmpty) {
      throw Exception('Please sign in to continue.');
    }

    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  Future<void> _loadCatalog() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final responses = await Future.wait([
        http.get(Uri.parse(ApiConfig.products)),
        http.get(Uri.parse(ApiConfig.categories)),
      ]);

      if (responses[0].statusCode != 200) {
        throw Exception(
          'Failed to load products (${responses[0].statusCode}).',
        );
      }

      if (responses[1].statusCode != 200) {
        throw Exception(
          'Failed to load categories (${responses[1].statusCode}).',
        );
      }

      final productData =
          jsonDecode(responses[0].body) as List<dynamic>;

      final categoryData =
          jsonDecode(responses[1].body) as List<dynamic>;

      final products = productData
          .map(
            (item) => Product.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .where((product) => product.isActive)
          .toList();

      final categories = categoryData
          .map((item) => Map<String, dynamic>.from(item as Map))
          .where((category) => category['is_active'] == true)
          .toList();

      if (!mounted) return;

      setState(() {
        _products = products;
        _categories = categories;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _checkAuthentication() async {
    try {
      final token = await _secureStorage.read(
        key: 'access_token',
      );

      if (!mounted) return;

      setState(() {
        _isLoggedIn = token != null && token.isNotEmpty;
        _isCheckingAuth = false;
      });

      if (_isLoggedIn) {
        await _loadCartCount();
      }
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _isLoggedIn = false;
        _isCheckingAuth = false;
        _cartItemCount = 0;
      });
    }
  }

  Future<void> _logout() async {
    try {
      await _secureStorage.delete(key: 'access_token');
      await _secureStorage.delete(key: 'refresh_token');

      if (!mounted) return;

      setState(() {
        _isLoggedIn = false;
        _cartItemCount = 0;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You have been logged out.'),
        ),
      );
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to log out. Please try again.'),
        ),
      );
    }
  }

  Future<void> _openLogin() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const LoginScreen(),
      ),
    );

    if (mounted) {
      await _checkAuthentication();
    }
  }

  Future<void> _loadCartCount() async {
    if (!_isLoggedIn) {
      if (mounted) {
        setState(() {
          _cartItemCount = 0;
        });
      }
      return;
    }

    try {
      final response = await http.get(
        Uri.parse(ApiConfig.cart),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 401) {
        await _handleAuthenticationExpired();
        return;
      }

      if (response.statusCode != 200) {
        throw Exception('Unable to load cart.');
      }

      final data =
          jsonDecode(response.body) as Map<String, dynamic>;

      final totalItems = int.tryParse(
            data['total_items'].toString(),
          ) ??
          0;

      if (!mounted) return;

      setState(() {
        _cartItemCount = totalItems;
      });
    } catch (_) {
      // Keep the current count if the request fails.
    }
  }

  Future<void> _handleAuthenticationExpired() async {
    await _secureStorage.delete(key: 'access_token');
    await _secureStorage.delete(key: 'refresh_token');

    if (!mounted) return;

    setState(() {
      _isLoggedIn = false;
      _cartItemCount = 0;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Your session expired. Please sign in again.'),
      ),
    );
  }

  Future<void> _openProfile() async {
    final canContinue = await _requireLogin();

    if (!canContinue || !mounted) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const ProfileScreen(),
      ),
    );
  }

  Future<bool> _requireLogin() async {
    if (_isCheckingAuth) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please wait while we check your login.'),
        ),
      );
      return false;
    }

    if (_isLoggedIn) {
      return true;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Please sign in to continue.'),
      ),
    );

    await _openLogin();

    return _isLoggedIn;
  }

  Future<void> _addToCart(Product product) async {
    if (_isAddingToCart) return;

    final canContinue = await _requireLogin();

    if (!canContinue || !mounted) return;

    setState(() {
      _isAddingToCart = true;
    });

    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.cart}add/'),
        headers: await _getHeaders(),
        body: jsonEncode({
          'product_id': product.id,
          'quantity': product.minimumOrderQuantity,
        }),
      );

      if (response.statusCode == 401) {
        await _handleAuthenticationExpired();
        return;
      }

      final dynamic decoded = jsonDecode(response.body);

      if (response.statusCode == 200 ||
          response.statusCode == 201) {
        await _loadCartCount();

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${product.name} added to your cart.'),
            action: SnackBarAction(
              label: 'VIEW CART',
              onPressed: _openCart,
            ),
          ),
        );
      } else {
        final message = decoded is Map
            ? (decoded['detail'] ?? 'Unable to add product.')
                .toString()
            : 'Unable to add product.';

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to add product: $e'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isAddingToCart = false;
        });
      }
    }
  }

  Future<void> _openCart() async {
    final canContinue = await _requireLogin();

    if (!canContinue || !mounted) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const CartScreen(),
      ),
    );

    if (mounted) {
      await _loadCartCount();
    }
  }

  Future<void> _openMyOrders() async {
    final canContinue = await _requireLogin();

    if (!canContinue || !mounted) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const MyOrdersScreen(),
      ),
    );
  }

  List<Product> get _filteredProducts {
    if (_selectedCategoryId == null) {
      return _products;
    }

    return _products
        .where(
          (product) => product.category == _selectedCategoryId,
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const BrandLogo(white: true, height: 36),
        actions: [
          if (_isCheckingAuth)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                  ),
                ),
              ),
            )
          else if (_isLoggedIn)
            PopupMenuButton<String>(
              tooltip: 'Account options',
              icon: const Icon(Icons.account_circle_outlined),
              onSelected: (value) {
                if (value == 'profile') {
                  _openProfile();
                } else if (value == 'orders') {
                  _openMyOrders();
                } else if (value == 'logout') {
                  _logout();
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem<String>(
                  value: 'profile',
                  child: ListTile(
                    leading: Icon(Icons.person_outline),
                    title: Text('My Profile'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                PopupMenuItem<String>(
                  value: 'orders',
                  child: ListTile(
                    leading: Icon(Icons.receipt_long_outlined),
                    title: Text('My Orders'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                PopupMenuItem<String>(
                  value: 'logout',
                  child: ListTile(
                    leading: Icon(Icons.logout),
                    title: Text('Logout'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            )
          else
            TextButton.icon(
                onPressed: _openLogin,
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(
                  Icons.login,
                  color: Colors.white,
                ),
                label: const Text(
                  'Login',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          IconButton(
            tooltip: 'Shopping cart',
            onPressed: _openCart,
            icon: Badge(
              label: Text('$_cartItemCount'),
              isLabelVisible: _isLoggedIn && _cartItemCount > 0,
              child: const Icon(Icons.shopping_cart_outlined),
            ),
          ),
          IconButton(
            tooltip: 'Refresh catalog',
            onPressed: _loadCatalog,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? _buildError()
              : RefreshIndicator(
                  onRefresh: _loadCatalog,
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(
                            16,
                            20,
                            16,
                            8,
                          ),
                          child: Text(
                            'Browse Categories',
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: SizedBox(
                          height: 54,
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                            ),
                            children: [
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(
                                  horizontal: 4,
                                ),
                                child: ChoiceChip(
                                  label: const Text('All Products'),
                                  selected:
                                      _selectedCategoryId == null,
                                  onSelected: (_) {
                                    setState(() {
                                      _selectedCategoryId = null;
                                    });
                                  },
                                ),
                              ),
                              ..._categories.map((category) {
                                final id = category['id'] as int;

                                return Padding(
                                  padding:
                                      const EdgeInsets.symmetric(
                                    horizontal: 4,
                                  ),
                                  child: ChoiceChip(
                                    label: Text(
                                      category['name']?.toString() ??
                                          'Category',
                                    ),
                                    selected:
                                        _selectedCategoryId == id,
                                    onSelected: (_) {
                                      setState(() {
                                        _selectedCategoryId = id;
                                      });
                                    },
                                  ),
                                );
                              }),
                            ],
                          ),
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(
                            16,
                            20,
                            16,
                            12,
                          ),
                          child: Text(
                            'Products (${_filteredProducts.length})',
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                        ),
                      ),
                      if (_filteredProducts.isEmpty)
                        const SliverFillRemaining(
                          hasScrollBody: false,
                          child: Center(
                            child: Text('No products available.'),
                          ),
                        )
                      else
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(
                            16,
                            0,
                            16,
                            24,
                          ),
                          sliver: SliverGrid(
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                              childAspectRatio: 0.62,
                            ),
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                final product =
                                    _filteredProducts[index];

                                return _buildProductCard(product);
                              },
                              childCount: _filteredProducts.length,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildProductCard(Product product) {
    final canAddToCart =
        product.stockQuantity >= product.minimumOrderQuantity;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: SizedBox(
              width: double.infinity,
              child: product.image == null || product.image!.isEmpty
                  ? const ColoredBox(
                      color: Color(0xFFF1F3F5),
                      child: Center(
                        child: Icon(
                          Icons.inventory_2_outlined,
                          size: 48,
                          color: Colors.grey,
                        ),
                      ),
                    )
                  : Image.network(
                      product.image!,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return const ColoredBox(
                          color: Color(0xFFF1F3F5),
                          child: Center(
                            child: Icon(
                              Icons.broken_image_outlined,
                              size: 48,
                              color: Colors.grey,
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '₹${product.price.toStringAsFixed(2)} / ${product.unit}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  product.stockQuantity > 0
                      ? 'Stock: ${product.stockQuantity} ${product.unit}'
                      : 'Out of stock',
                  style: TextStyle(
                    fontSize: 12,
                    color: product.stockQuantity > 0
                        ? Colors.green.shade700
                        : Colors.red,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  product.categoryName,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: canAddToCart && !_isAddingToCart
                        ? () => _addToCart(product)
                        : null,
                    icon: const Icon(
                      Icons.add_shopping_cart,
                      size: 18,
                    ),
                    label: const Text(
                      'Add to Cart',
                      maxLines: 1,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_outlined,
              size: 48,
              color: Colors.grey,
            ),
            const SizedBox(height: 12),
            const Text(
              'Unable to load the catalog.',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _loadCatalog,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }
}
