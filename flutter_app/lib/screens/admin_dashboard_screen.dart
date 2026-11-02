import 'package:flutter/material.dart';

import '../main.dart' show secureStorage, LoginScreen;
import 'admin_orders_screen.dart';
import 'admin_products_screen.dart';
import 'admin_categories_screen.dart';
import 'admin_hotels_screen.dart';

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  Future<void> _logout(BuildContext context) async {
    await secureStorage.delete(key: 'access_token');
    await secureStorage.delete(key: 'refresh_token');

    if (!context.mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => const LoginScreen(),
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        actions: [
          IconButton(
            tooltip: 'Logout',
            onPressed: () => _logout(context),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.admin_panel_settings_outlined,
                    size: 48,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Welcome, Administrator',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Manage hotel orders and monitor platform operations.',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Order Management
          Card(
            child: ListTile(
              leading: const Icon(Icons.receipt_long_outlined),
              title: const Text('Order Management'),
              subtitle: const Text(
                'View and manage orders from all hotels.',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const AdminOrdersScreen(),
                  ),
                );
              },
            ),
          ),

          // Product Management
          Card(
            child: ListTile(
              leading: const Icon(Icons.inventory_2_outlined),
              title: const Text('Product Management'),
              subtitle: const Text(
                'Add, edit, delete products and manage inventory.',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const AdminProductsScreen(),
                  ),
                );
              },
            ),
          ),
          // Category Management
          Card(
            child: ListTile(
              leading: const Icon(Icons.category_outlined),
              title: const Text('Category Management'),
              subtitle: const Text(
                'Add, edit and delete product categories.',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const AdminCategoriesScreen(),
                  ),
                );
              },
            ),
          ),
          // Hotel Management
          Card(
            child: ListTile(
              leading: const Icon(Icons.hotel_outlined),
              title: const Text('Hotel Management'),
              subtitle: const Text(
                'View, manage, block and reactivate registered hotels.',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const AdminHotelsScreen(),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}