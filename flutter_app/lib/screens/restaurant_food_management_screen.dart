import 'package:flutter/material.dart';

import '../main.dart' show logoutAndOpenLogin;
import '../models/food_item.dart';
import '../services/food_service.dart';
import 'home_screen.dart';
import 'restaurant_food_form_screen.dart';
import 'food_category_management_screen.dart';

class RestaurantFoodManagementScreen extends StatefulWidget {
  final int? hotelId;

  const RestaurantFoodManagementScreen({super.key, this.hotelId});

  @override
  State<RestaurantFoodManagementScreen> createState() =>
      _RestaurantFoodManagementScreenState();
}

class _RestaurantFoodManagementScreenState
    extends State<RestaurantFoodManagementScreen> {
  final FoodService _service = FoodService();
  List<FoodItem> _items = [];
  bool _isLoading = true;
  String? _error;

  void _goBack() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
      return;
    }

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
      (route) => false,
    );
  }

  Future<void> _confirmLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
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
      ),
    );

    if (confirmed == true && mounted) {
      await logoutAndOpenLogin(context);
    }
  }

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  Future<void> _loadItems() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final allItems = await _service.getFoodItems();
      if (!mounted) return;
      setState(() {
        _items = allItems
            .where((item) => widget.hotelId == null || item.hotel == widget.hotelId)
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _openForm({FoodItem? item}) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => RestaurantFoodFormScreen(
          foodItemId: item?.id,
          adminMode: widget.hotelId == null,
        ),
      ),
    );
    if (!mounted || result != true) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          item == null
              ? 'Food added successfully.'
              : 'Food updated successfully.',
        ),
        backgroundColor: Colors.green,
      ),
    );
    await _loadItems();
  }

  Future<void> _setAvailability(FoodItem item, bool value) async {
    try {
      final updated = await _service.setAvailability(item.id, value);
      if (!mounted) return;
      setState(() {
        _items = _items
            .map((current) => current.id == item.id ? updated : current)
            .toList();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            value ? 'Food is now available.' : 'Food is now unavailable.',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to update availability: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _deactivate(FoodItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Deactivate Food'),
        content: Text('Are you sure you want to deactivate "${item.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Deactivate'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await _service.deactivateFoodItem(item.id);
      if (!mounted) return;
      setState(() => _items.removeWhere((current) => current.id == item.id));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Food deactivated successfully.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to deactivate food: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildItemCard(FoodItem item) {
    final image = item.image;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: image != null && image.isNotEmpty
                      ? Image.network(
                          image,
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, progress) =>
                              progress == null
                              ? child
                              : const Center(
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                          errorBuilder: (context, error, stack) =>
                              const Icon(Icons.restaurant_outlined, size: 30),
                        )
                      : const Icon(Icons.restaurant_outlined, size: 30),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.categoryName,
                        style: const TextStyle(
                          color: Colors.black54,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '₹${item.price.toStringAsFixed(2)}  •  ${item.foodType}',
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Preparation: ${item.preparationTime} min',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (action) {
                    if (action == 'edit') _openForm(item: item);
                    if (action == 'deactivate') _deactivate(item);
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit_outlined),
                          SizedBox(width: 8),
                          Text('Edit'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'deactivate',
                      child: Row(
                        children: [
                          Icon(Icons.block_outlined, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Deactivate'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const Divider(height: 22),
            Row(
              children: [
                Expanded(
                  child: Text('Active: ${item.isActive ? 'Yes' : 'No'}'),
                ),
                const Text('Available'),
                Switch(
                  value: item.isAvailable,
                  onChanged: (value) => _setAvailability(item, value),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<Object?>(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _goBack();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: 'Back',
            onPressed: _goBack,
            icon: const Icon(Icons.arrow_back),
          ),
          title: const Text('Food Management'),
          actions: [
            if (widget.hotelId == null)
              IconButton(
                tooltip: 'Food Categories',
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const FoodCategoryManagementScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.category_outlined),
              ),
            IconButton(
              tooltip: 'Refresh',
              onPressed: _isLoading ? null : _loadItems,
              icon: const Icon(Icons.refresh),
            ),
            IconButton(
              tooltip: 'Log Out',
              onPressed: _confirmLogout,
              icon: const Icon(Icons.logout),
            ),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: _loadItems,
          child: _isLoading
              ? ListView(
                  children: [
                    SizedBox(
                      height: 260,
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  ],
                )
              : _error != null
              ? ListView(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Could not load food items.\n$_error',
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: _loadItems,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  ],
                )
              : _items.isEmpty
              ? ListView(
                  children: const [
                    Padding(
                      padding: EdgeInsets.all(32),
                      child: Column(
                        children: [
                          Icon(
                            Icons.restaurant_menu_outlined,
                            size: 56,
                            color: Colors.grey,
                          ),
                          SizedBox(height: 12),
                          Text(
                            'No food items yet. Add your first food item to get started.',
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ],
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _items.length,
                  itemBuilder: (context, index) =>
                      _buildItemCard(_items[index]),
                ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _openForm(),
          icon: const Icon(Icons.add),
          label: const Text('Add Food'),
        ),
      ),
    );
  }
}
