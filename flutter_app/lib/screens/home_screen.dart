import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../main.dart' show LoginScreen, logoutAndOpenLogin;
import '../models/food_category.dart';
import '../models/food_item.dart';
import '../models/product.dart';
import '../services/authenticated_http_client.dart';
import '../services/food_service.dart';
import '../services/user_service.dart';
import 'cart_screen.dart';
import 'my_orders_screen.dart';
import 'profile_screen.dart';
import '../widgets/brand_logo.dart';
import 'admin_dashboard_screen.dart';
import 'delivery_dashboard_screen.dart';
import 'restaurant_food_management_screen.dart';

class HomeScreen extends StatefulWidget {
  final FoodService? foodService;

  const HomeScreen({super.key, this.foodService});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final FoodService _foodService = widget.foodService ?? FoodService();

  List<Product> _products = [];
  List<FoodItem> _foodItems = [];
  List<FoodCategory> _foodCategories = [];
  List<Map<String, dynamic>> _categories = [];

  bool _isLoading = true;
  bool _isFoodLoading = true;
  bool _isFoodCategoriesLoading = true;
  bool _isAddingToCart = false;
  bool _isCheckingAuth = true;
  bool _isLoggedIn = false;

  String? _errorMessage;
  String? _foodErrorMessage;
  String? _foodCategoriesErrorMessage;
  int? _selectedCategoryId;
  int? _selectedFoodCategoryId;
  int _cartItemCount = 0;
  Map<String, dynamic>? _currentUser;

  bool get _showDashboardMenuItem {
    final role = _currentUser?['role']?.toString();
    if (role == 'SUPERADMIN' || role == 'ADMIN' || role == 'DELIVERY') {
      return true;
    }
    if (role == 'HOTEL') {
      final hotel = _currentUser?['hotel'];
      return hotel is Map && hotel['hotel_type'] == 'FOOD_PARTNER';
    }
    return false;
  }

  @override
  void initState() {
    super.initState();
    _loadCatalog();
    _loadFoodItems();
    _loadFoodCategories();
    _checkAuthentication();
  }

  Map<String, String> _getHeaders() =>
      const {'Content-Type': 'application/json'};

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

  Future<void> _loadFoodItems() async {
    setState(() {
      _isFoodLoading = true;
      _foodErrorMessage = null;
    });

    try {
      final items = await _foodService.getPublicFoodItems();
      if (!mounted) return;
      setState(() {
        _foodItems = items;
        _isFoodLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _foodErrorMessage = e.toString().replaceFirst('Exception: ', '');
        _isFoodLoading = false;
      });
    }
  }

  Future<void> _loadFoodCategories() async {
    setState(() {
      _isFoodCategoriesLoading = true;
      _foodCategoriesErrorMessage = null;
    });

    try {
      final categories = await _foodService.getFoodCategories();
      if (!mounted) return;
      setState(() {
        _foodCategories = categories.where((category) => category.isActive).toList();
        _isFoodCategoriesLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _foodCategoriesErrorMessage =
            e.toString().replaceFirst('Exception: ', '');
        _isFoodCategoriesLoading = false;
      });
    }
  }

  Future<void> _refreshFoodCatalog() async {
    await Future.wait([_loadFoodItems(), _loadFoodCategories()]);
  }

  Future<void> _checkAuthentication() async {
    try {
      final token = await secureStorage.read(
        key: 'access_token',
      );

      if (!mounted) return;

      setState(() {
        _isLoggedIn = token != null && token.isNotEmpty;
        _isCheckingAuth = false;
      });

      if (_isLoggedIn) {
        try {
          final user = await UserService().getCurrentUser();
          if (mounted) {
            setState(() {
              _currentUser = user;
            });
          }
        } catch (_) {
          if (mounted) {
            setState(() {
              _currentUser = null;
            });
          }
        }
        await _loadCartCount();
      }
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _isLoggedIn = false;
        _isCheckingAuth = false;
        _cartItemCount = 0;
        _currentUser = null;
      });
    }
  }

  Future<void> _confirmLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Log Out'),
          content: const Text('Are you sure you want to log out?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Log Out'),
            ),
          ],
        );
      },
    );

    if (confirmed == true && mounted) {
      await logoutAndOpenLogin(context);
    }
  }

  Future<void> _openDashboard() async {
    final canContinue = await _requireLogin();
    if (!canContinue || !mounted) return;

    final user = _currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to determine your dashboard.')),
      );
      return;
    }

    final role = user['role']?.toString();
    Widget? dashboard;

    switch (role) {
      case 'SUPERADMIN':
      case 'ADMIN':
        dashboard = const AdminDashboardScreen();
        break;
      case 'DELIVERY':
        dashboard = const DeliveryDashboardScreen();
        break;
      case 'HOTEL':
        final hotel = user['hotel'];
        final hotelType = hotel is Map ? hotel['hotel_type']?.toString() : null;
        if (hotelType == 'FOOD_PARTNER' &&
            hotel is Map &&
            hotel['id'] is num) {
          dashboard = RestaurantFoodManagementScreen(
            hotelId: (hotel['id'] as num).toInt(),
          );
        } else if (hotelType == 'CUSTOMER_HOTEL') {
          // Product Listing is the existing Customer Hotel dashboard.
          return;
        }
        break;
    }

    if (dashboard == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No dashboard is available for this account.')),
      );
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => dashboard!,
      ),
    );
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
      final response = await AuthenticatedHttpClient.instance.get(
        Uri.parse(ApiConfig.cart),
        headers: _getHeaders(),
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
      final response = await AuthenticatedHttpClient.instance.post(
        Uri.parse('${ApiConfig.cart}add/'),
        headers: _getHeaders(),
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

  Future<void> _addFoodToCart(FoodItem foodItem) async {
    if (_isAddingToCart) return;

    final canContinue = await _requireLogin();
    if (!canContinue || !mounted) return;

    setState(() => _isAddingToCart = true);
    try {
      final response = await AuthenticatedHttpClient.instance.post(
        Uri.parse('${ApiConfig.cart}add/'),
        headers: _getHeaders(),
        body: jsonEncode({
          'food_item_id': foodItem.id,
          'quantity': 1,
        }),
      );

      if (response.statusCode == 401) {
        await _handleAuthenticationExpired();
        return;
      }

      final dynamic decoded = jsonDecode(response.body);
      if (response.statusCode == 200 || response.statusCode == 201) {
        await _loadCartCount();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${foodItem.name} added to your cart.')),
        );
      } else {
        final message = decoded is Map
            ? (decoded['detail'] ?? 'Unable to add food item.').toString()
            : 'Unable to add food item.';
        throw Exception(message);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to add food item: ${e.toString().replaceFirst('Exception: ', '')}'),
        ),
      );
    } finally {
      if (mounted) setState(() => _isAddingToCart = false);
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

  List<FoodItem> get _filteredFoodItems {
    if (_selectedFoodCategoryId == null) return _foodItems;
    return _foodItems
        .where((item) => item.category == _selectedFoodCategoryId)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
      appBar: AppBar(
        title: const BrandLogo(white: true, height: 36),
        bottom: const TabBar(
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          indicatorWeight: 3.5,
          labelStyle: TextStyle(fontWeight: FontWeight.w600),
          tabs: [
            Tab(text: 'Products'),
            Tab(text: 'Food Items'),
          ],
        ),
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
                } else if (value == 'dashboard') {
                  _openDashboard();
                } else if (value == 'orders') {
                  _openMyOrders();
                } else if (value == 'logout') {
                  _confirmLogout();
                }
              },
              itemBuilder: (context) => [
                if (_showDashboardMenuItem)
                  const PopupMenuItem<String>(
                    value: 'dashboard',
                    child: ListTile(
                      leading: Icon(Icons.dashboard_outlined),
                      title: Text('My Dashboard'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                const PopupMenuItem<String>(
                  value: 'profile',
                  child: ListTile(
                    leading: Icon(Icons.person_outline),
                    title: Text('My Profile'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const PopupMenuItem<String>(
                  value: 'orders',
                  child: ListTile(
                    leading: Icon(Icons.receipt_long_outlined),
                    title: Text('My Orders'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const PopupMenuItem<String>(
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
            onPressed: () {
              _loadCatalog();
              _refreshFoodCatalog();
            },
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: TabBarView(
        children: [
        _isLoading
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
        _buildFoodTab(),
        ],
      ),
      ),
    );
  }

  Widget _buildFoodTab() {
    return Column(
      children: [
        _buildFoodCategorySection(),
        Expanded(child: _buildFoodItemsContent()),
      ],
    );
  }

  Widget _buildFoodCategorySection() {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Browse Food Categories',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ChoiceChip(
                    label: const Text('All Food'),
                    selected: _selectedFoodCategoryId == null,
                    onSelected: (_) => setState(() {
                      _selectedFoodCategoryId = null;
                    }),
                  ),
                ),
                if (_isFoodCategoriesLoading)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: SizedBox(
                      width: 22,
                      child: Center(
                        child: SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    ),
                  )
                else if (_foodCategoriesErrorMessage != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: TextButton.icon(
                      onPressed: _loadFoodCategories,
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('Retry categories'),
                    ),
                  )
                else if (_foodCategories.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Center(
                      child: Text(
                        'No food categories available.',
                        style: TextStyle(color: Colors.grey.shade700),
                      ),
                    ),
                  )
                else
                  ..._foodCategories.map((category) => Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: ChoiceChip(
                          label: Text(category.name),
                          selected: _selectedFoodCategoryId == category.id,
                          onSelected: (_) => setState(() {
                            _selectedFoodCategoryId = category.id;
                          }),
                        ),
                      )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFoodItemsContent() {
    if (_isFoodLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_foodErrorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_outlined, size: 48, color: Colors.grey),
              const SizedBox(height: 12),
              const Text('Unable to load food items.'),
              const SizedBox(height: 8),
              Text(_foodErrorMessage!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _loadFoodItems,
                icon: const Icon(Icons.refresh),
                label: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    final items = _filteredFoodItems;
    if (items.isEmpty) {
      final message = _selectedFoodCategoryId == null
          ? 'No food items available.'
          : 'No available food items in this category.';
      return RefreshIndicator(
        onRefresh: _refreshFoodCatalog,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const SizedBox(height: 100),
            Center(child: Text(message)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refreshFoodCatalog,
      child: GridView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: items.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.55,
        ),
        itemBuilder: (context, index) => _buildFoodCard(items[index]),
      ),
    );
  }

  Widget _buildFoodCard(FoodItem item) {
    final typeColor = switch (item.foodType) {
      'NON_VEG' => Colors.red.shade700,
      'VEGAN' => Colors.teal.shade700,
      _ => Colors.green.shade700,
    };
    final typeLabel = switch (item.foodType) {
      'NON_VEG' => 'NON-VEG',
      'VEGAN' => 'VEGAN',
      _ => 'VEG',
    };

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: SizedBox(width: double.infinity, child: _buildCatalogImage(item.image)),
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    Icon(Icons.storefront_outlined, size: 14, color: Colors.grey.shade700),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        item.hotelName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  item.categoryName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        '₹${item.price.toStringAsFixed(2)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    _buildFoodTypeBadge(typeLabel, typeColor),
                  ],
                ),
                const SizedBox(height: 5),
                _buildAvailabilityBadge(item.isAvailable),
                const SizedBox(height: 7),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: item.isAvailable && !_isAddingToCart
                        ? () => _addFoodToCart(item)
                        : null,
                    icon: const Icon(Icons.add_shopping_cart, size: 18),
                    label: const Text('Add to Cart', maxLines: 1),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFoodTypeBadge(String label, Color color) {
    final icon = label == 'VEGAN' ? Icons.eco_outlined : Icons.circle;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvailabilityBadge(bool isAvailable) {
    final color = isAvailable ? Colors.green.shade700 : Colors.orange.shade800;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isAvailable ? Icons.check_circle_outline : Icons.schedule_outlined,
            size: 13,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            isAvailable ? 'Available' : 'Unavailable',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCatalogImage(String? imageUrl) {
    const placeholder = ColoredBox(
      color: Color(0xFFF1F3F5),
      child: Center(
        child: Icon(Icons.image_outlined, size: 48, color: Colors.grey),
      ),
    );

    if (imageUrl == null || imageUrl.isEmpty) return placeholder;
    return Image.network(
      imageUrl,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => placeholder,
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
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _buildCatalogImage(product.image),
                  if (product.stockQuantity == 0)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red.shade700,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'Out of Stock',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                ],
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
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(
                      product.stockQuantity > 0
                          ? Icons.inventory_2_outlined
                          : Icons.remove_shopping_cart_outlined,
                      size: 15,
                      color: product.stockQuantity > 0
                          ? Colors.green.shade700
                          : Colors.red.shade700,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        product.stockQuantity > 0
                            ? 'Stock: ${product.stockQuantity} ${product.unit}'
                            : 'Out of stock',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: product.stockQuantity > 0
                              ? Colors.green.shade700
                              : Colors.red.shade700,
                        ),
                      ),
                    ),
                  ],
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
