import 'package:flutter/material.dart';

import '../main.dart' show logoutAndOpenLogin;
import '../services/order_service.dart';
import 'delivery_orders_screen.dart';

class DeliveryDashboardScreen extends StatefulWidget {
  const DeliveryDashboardScreen({super.key});

  @override
  State<DeliveryDashboardScreen> createState() =>
      _DeliveryDashboardScreenState();
}

class _DeliveryDashboardScreenState extends State<DeliveryDashboardScreen> {
  final OrderService _orderService = OrderService();

  bool _isLoading = true;
  String? _error;

  int _outForDelivery = 0;
  int _completedDeliveries = 0;

  int get _totalAssigned => _outForDelivery + _completedDeliveries;

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  Future<void> _loadDashboard() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        _orderService.getMyDeliveries(status: 'OUT_FOR_DELIVERY'),
        _orderService.getMyDeliveries(status: 'DELIVERED'),
      ]);

      if (!mounted) return;

      setState(() {
        _outForDelivery = results[0].length;
        _completedDeliveries = results[1].length;
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

  Future<void> _logout(BuildContext context) async {
    await logoutAndOpenLogin(context);
  }

  void _openDeliveries() {
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (_) => const DeliveryOrdersScreen(),
          ),
        )
        .then((_) => _loadDashboard());
  }

  Widget _buildStatCard({
    required BuildContext context,
    required String title,
    required int value,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: color.withValues(alpha: 0.12),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value.toString(),
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    title,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Delivery Dashboard'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _isLoading ? null : _loadDashboard,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'Logout',
            onPressed: () => _logout(context),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadDashboard,
        child: ListView(
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
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Delivery Summary',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                if (_isLoading)
                  const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (_error != null) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Could not load delivery statistics.',
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _error!,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: _loadDashboard,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ] else ...[
              _buildStatCard(
                context: context,
                title: 'Total Assigned',
                value: _isLoading ? 0 : _totalAssigned,
                icon: Icons.assignment_outlined,
                color: Theme.of(context).colorScheme.primary,
              ),
              _buildStatCard(
                context: context,
                title: 'Active Deliveries',
                value: _isLoading ? 0 : _outForDelivery,
                icon: Icons.local_shipping_outlined,
                color: Colors.orange,
              ),
              _buildStatCard(
                context: context,
                title: 'Completed Deliveries',
                value: _isLoading ? 0 : _completedDeliveries,
                icon: Icons.check_circle_outline,
                color: Colors.green,
              ),
            ],
            const SizedBox(height: 16),
            Card(
              child: ListTile(
                leading: const CircleAvatar(
                  child: Icon(Icons.assignment_outlined),
                ),
                title: const Text('My Deliveries'),
                subtitle: const Text(
                  'View active deliveries and completed delivery history.',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: _openDeliveries,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
