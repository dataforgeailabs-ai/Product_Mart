import 'package:flutter/material.dart';

import '../main.dart' show logoutAndOpenLogin;
import 'admin_orders_screen.dart';
import 'admin_products_screen.dart';
import 'admin_categories_screen.dart';
import 'admin_hotels_screen.dart';
import 'admin_users_screen.dart';
import 'restaurant_food_management_screen.dart';
import 'admin_restaurant_partner_requests_screen.dart';

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  Future<void> _logout(BuildContext context) async {
    await logoutAndOpenLogin(context);
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
          Card(
            child: ListTile(
              leading: const Icon(Icons.restaurant_menu_outlined),
              title: const Text('Food Management'),
              subtitle: const Text(
                'Manage restaurant food items and categories.',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const RestaurantFoodManagementScreen(),
                  ),
                );
              },
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.fact_check_outlined),
              title: const Text('Restaurant Partnership Requests'),
              subtitle: const Text(
                'Review applications to join Misty Go as a restaurant.',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        const AdminRestaurantPartnerRequestsScreen(),
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
          // User Management
          Card(
            child: ListTile(
              leading: const Icon(Icons.manage_accounts_outlined),
              title: const Text('User Management'),
              subtitle: const Text(
                'Manage administrators and delivery personnel.',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const AdminUsersScreen(),
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
