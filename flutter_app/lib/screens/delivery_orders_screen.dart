import 'package:flutter/material.dart';

import '../services/order_service.dart';
import 'delivery_order_details_screen.dart';

class DeliveryOrdersScreen extends StatefulWidget {
  const DeliveryOrdersScreen({super.key});

  @override
  State<DeliveryOrdersScreen> createState() => _DeliveryOrdersScreenState();
}

class _DeliveryOrdersScreenState extends State<DeliveryOrdersScreen>
    with SingleTickerProviderStateMixin {
  final OrderService _orderService = OrderService();
  late final TabController _tabController;

  List<Map<String, dynamic>> _checkouts = [];
  bool _isLoading = true;
  String? _errorMessage;
  String _currentStatus = 'OUT_FOR_DELIVERY';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_handleTabChange);
    _loadCheckouts();
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    super.dispose();
  }

  void _handleTabChange() {
    if (_tabController.indexIsChanging) return;
    final status =
        _tabController.index == 0 ? 'OUT_FOR_DELIVERY' : 'DELIVERED';
    if (status != _currentStatus) {
      _currentStatus = status;
      _loadCheckouts();
    }
  }

  Future<void> _loadCheckouts() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final checkouts =
          await _orderService.getMyDeliveries(status: _currentStatus);

      if (!mounted) return;
      setState(() {
        _checkouts = checkouts;
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

  String _formatStatus(String status) =>
      status.replaceAll('_', ' ');

  String _formatDate(dynamic value) {
    if (value == null || value.toString().isEmpty) return 'N/A';
    final date = DateTime.tryParse(value.toString())?.toLocal();
    if (date == null) return 'N/A';
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  String _money(dynamic value) {
    final amount = double.tryParse(value?.toString() ?? '') ?? 0;
    return '₹${amount.toStringAsFixed(2)}';
  }

  Widget _buildCheckoutCard(Map<String, dynamic> checkout) {
    final orders = checkout['orders'] is List
        ? checkout['orders'] as List
        : <dynamic>[];
    final checkoutId = int.tryParse(checkout['id'].toString());
    final checkoutNo = checkout['checkout_no']?.toString() ?? 'Checkout';
    final hotelName =
        checkout['customer_hotel_name']?.toString() ?? 'Hotel';
    final deliveryStatus =
        checkout['delivery_status']?.toString() ?? _currentStatus;
    final paymentStatus =
        checkout['payment_status']?.toString() ?? 'PENDING';
    final payment = checkout['payment'] is Map
        ? Map<String, dynamic>.from(checkout['payment'] as Map)
        : <String, dynamic>{};
    final paymentMethod = payment['method']?.toString() ?? 'N/A';
    final createdAt = checkout['created_at'];
    final deliveredAt = checkout['delivered_at'];

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: checkoutId == null || orders.isEmpty
            ? null
            : () async {
                final delivered = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(
                    builder: (_) => DeliveryOrderDetailsScreen(
                      checkoutId: checkoutId,
                    ),
                  ),
                );

                if (!mounted) return;
                if (delivered == true) await _loadCheckouts();
              },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      checkoutNo,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                  Chip(
                    label: Text(
                      _formatStatus(deliveryStatus),
                      style: const TextStyle(fontSize: 11),
                    ),
                    backgroundColor: deliveryStatus == 'DELIVERED'
                        ? Colors.green.shade100
                        : Colors.orange.shade100,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.hotel_outlined, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      hotelName,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.receipt_long_outlined, size: 18),
                  const SizedBox(width: 8),
                  Text('${orders.length} order(s) in this checkout'),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.calendar_today_outlined, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    _currentStatus == 'DELIVERED'
                        ? 'Delivered: ${_formatDate(deliveredAt)}'
                        : 'Created: ${_formatDate(createdAt)}',
                  ),
                ],
              ),
              const Divider(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total Amount'),
                  Text(
                    _money(checkout['total']),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Payment'),
                  Text(
                    '$paymentMethod • ${_formatStatus(paymentStatus)}',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: paymentStatus == 'PAID' ||
                              paymentStatus == 'CASH_RECEIVED'
                          ? Colors.green
                          : Colors.orange,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'View delivery details  ›',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 12),
              Text(_errorMessage!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _loadCheckouts,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_checkouts.isEmpty) {
      final isHistory = _currentStatus == 'DELIVERED';
      return RefreshIndicator(
        onRefresh: _loadCheckouts,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const SizedBox(height: 150),
            Icon(
              isHistory
                  ? Icons.history
                  : Icons.local_shipping_outlined,
              size: 64,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            Center(
              child: Text(
                isHistory
                    ? 'No completed deliveries yet'
                    : 'No deliveries available',
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadCheckouts,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: _checkouts.length,
        itemBuilder: (context, index) =>
            _buildCheckoutCard(_checkouts[index]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Deliveries'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loadCheckouts,
            icon: const Icon(Icons.refresh),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Active'),
            Tab(text: 'History'),
          ],
        ),
      ),
      body: _buildBody(),
    );
  }
}
