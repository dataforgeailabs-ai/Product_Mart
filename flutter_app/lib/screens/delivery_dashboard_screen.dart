import 'package:flutter/material.dart';

import '../main.dart' show secureStorage, LoginScreen;
import 'delivery_orders_screen.dart';

class DeliveryDashboardScreen extends StatelessWidget {
  const DeliveryDashboardScreen({super.key});

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
        title: const Text('Delivery Dashboard'),
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
                    Icons.local_shipping_outlined,
                    size: 48,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Welcome, Delivery Partner',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Manage your assigned deliveries and update delivery progress.',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              leading: const Icon(Icons.assignment_outlined),
              title: const Text('My Deliveries'),
              subtitle: const Text(
                'View orders assigned to you.',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
            Navigator.of(context).push(
               MaterialPageRoute(
                  builder: (_) => const DeliveryOrdersScreen(),
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