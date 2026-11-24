import 'package:flutter/material.dart';

import '../services/order_service.dart';

class DeliveryOrderDetailsScreen extends StatefulWidget {
  final int checkoutId;

  const DeliveryOrderDetailsScreen({
    super.key,
    required this.checkoutId,
  });

  @override
  State<DeliveryOrderDetailsScreen> createState() =>
      _DeliveryOrderDetailsScreenState();
}

class _DeliveryOrderDetailsScreenState
    extends State<DeliveryOrderDetailsScreen> {
  final OrderService _orderService = OrderService();

  Map<String, dynamic>? _checkout;
  bool _isLoading = true;
  bool _isDelivering = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadCheckout();
  }

  Future<void> _loadCheckout() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final checkout =
          await _orderService.getCheckoutDetails(widget.checkoutId);

      if (!mounted) return;

      setState(() {
        _checkout = checkout;
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

  String _formatStatus(String value) =>
      value.replaceAll('_', ' ');

  String _formatDateTime(dynamic value) {
    if (value == null || value.toString().isEmpty) return 'N/A';

    final date = DateTime.tryParse(value.toString())?.toLocal();
    if (date == null) return value.toString();

    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year} '
        '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
  }

  String _money(dynamic value) {
    final amount = double.tryParse(value?.toString() ?? '') ?? 0;
    return '₹${amount.toStringAsFixed(2)}';
  }

  List<Map<String, dynamic>> get _orders {
    final raw = _checkout?['orders'];
    if (raw is! List) return [];

    return raw
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Future<void> _markAsDelivered() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Confirm Delivery'),
        content: const Text(
          'Confirm that the complete checkout has been delivered successfully?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Confirm Delivery'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isDelivering = true);

    try {
      await _orderService.updateCheckoutDeliveryStatus(
        widget.checkoutId,
        'DELIVERED',
        remarks: 'Checkout successfully delivered.',
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Checkout marked as delivered successfully.'),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;

      setState(() => _isDelivering = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update delivery: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: Colors.black54),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckoutSummary(Map<String, dynamic> checkout) {
    final payment = checkout['payment'] is Map
        ? Map<String, dynamic>.from(checkout['payment'] as Map)
        : <String, dynamic>{};

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              checkout['checkout_no']?.toString() ?? 'Checkout',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            _infoRow(
              'Customer Hotel',
              checkout['customer_hotel_name']?.toString() ?? 'N/A',
            ),
            _infoRow(
              'Placed By',
              checkout['placed_by_username']?.toString() ?? 'N/A',
            ),
            _infoRow(
              'Checkout Date',
              _formatDateTime(checkout['created_at']),
            ),
            _infoRow(
              'Delivery Status',
              _formatStatus(
                checkout['delivery_status']?.toString() ?? 'PENDING',
              ),
            ),
            _infoRow(
              'Assigned Delivery Partner',
              checkout['assigned_delivery_username']?.toString() ?? 'N/A',
            ),
            if (checkout['delivered_at'] != null)
              _infoRow(
                'Delivered At',
                _formatDateTime(checkout['delivered_at']),
              ),
            if ((checkout['delivery_remarks'] ?? '')
                .toString()
                .isNotEmpty)
              _infoRow(
                'Delivery Remarks',
                checkout['delivery_remarks'].toString(),
              ),
            const Divider(height: 24),
            _infoRow('Total Amount', _money(checkout['total'])),
            _infoRow(
              'Collectable Amount',
              _money(checkout['collectable_amount']),
            ),
            _infoRow(
              'Payment Method',
              payment['method']?.toString() ?? 'N/A',
            ),
            _infoRow(
              'Payment Status',
              _formatStatus(
                checkout['payment_status']?.toString() ?? 'PENDING',
              ),
            ),
            if (payment['collected_amount'] != null)
              _infoRow(
                'Collected Amount',
                _money(payment['collected_amount']),
              ),
            if (payment['received_by'] != null)
                _infoRow(
                  'Received By',
                  payment['received_by_username']?.toString() ??
                      payment['received_by'].toString(),
                ),
            if (payment['received_at'] != null)
              _infoRow(
                'Received At',
                _formatDateTime(payment['received_at']),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderItems(Map<String, dynamic> order) {
    final items = order['items'] is List
        ? order['items'] as List
        : <dynamic>[];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle('Items'),
            if (items.isEmpty)
              const Text('No items found for this order.')
            else
              ...items.whereType<Map>().map((rawItem) {
                final item = Map<String, dynamic>.from(rawItem);
                final itemName = item['product_name']?.toString() ??
                    item['food_item_name']?.toString() ??
                    'Item';
                final quantity = item['quantity']?.toString() ?? '0';

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              itemName,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                          Text(
                            _money(item['line_total']),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '$quantity × ${_money(item['unit_price'])}',
                          style: const TextStyle(color: Colors.black54),
                        ),
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderHistory(Map<String, dynamic> order) {
    final history = order['status_history'] is List
        ? order['status_history'] as List
        : <dynamic>[];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle('Individual Order Status History'),
            Text(
              order['order_no']?.toString() ?? 'Order',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            if (history.isEmpty)
              const Text('No status history available.')
            else
              ...history.whereType<Map>().map((rawEntry) {
                final entry = Map<String, dynamic>.from(rawEntry);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.check_circle,
                        color: Colors.green,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _formatStatus(
                                entry['status']?.toString() ?? '',
                              ),
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            if (entry['changed_by_username'] != null)
                              Text(
                                'By: ${entry['changed_by_username']}',
                                style: const TextStyle(color: Colors.black54),
                              ),
                            if ((entry['remarks'] ?? '')
                                .toString()
                                .isNotEmpty)
                              Text(entry['remarks'].toString()),
                            Text(
                              _formatDateTime(entry['changed_at']),
                              style: const TextStyle(
                                color: Colors.black54,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    final checkout = _checkout!;
    final orders = _orders;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildCheckoutSummary(checkout),
        const SizedBox(height: 12),
        Text(
          'Individual Orders (${orders.length})',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        if (orders.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('No individual orders found in this checkout.'),
            ),
          )
        else
          ...orders.map((order) {
            return Column(
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          order['order_no']?.toString() ?? 'Order',
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _infoRow(
                          'Order Type',
                          order['order_type']?.toString() ?? 'N/A',
                        ),
                        _infoRow(
                          'Seller Hotel',
                          order['seller_hotel_name']?.toString() ?? 'Platform',
                        ),
                        _infoRow(
                          'Order Status',
                          _formatStatus(
                            order['status']?.toString() ?? 'N/A',
                          ),
                        ),
                        _infoRow(
                          'Payment Status',
                          _formatStatus(
                            order['payment_status']?.toString() ?? 'N/A',
                          ),
                        ),
                        _infoRow('Order Total', _money(order['total'])),
                        const Divider(height: 24),
                        _buildOrderItems(order),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                _buildOrderHistory(order),
                const SizedBox(height: 12),
              ],
            );
          }),
        if (checkout['delivery_status'] == 'OUT_FOR_DELIVERY') ...[
          const SizedBox(height: 8),
          SizedBox(
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _isDelivering ? null : _markAsDelivered,
              icon: _isDelivering
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2)
                    )
                  : const Icon(Icons.check_circle_outline),
              label: Text(
                _isDelivering ? 'Updating...' : 'Mark as Delivered',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
        const SizedBox(height: 20),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Delivery Details')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          size: 48,
                          color: Colors.red,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loadCheckout,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : _checkout == null
                  ? const Center(child: Text('Checkout not found.'))
                  : _buildContent(),
    );
  }
}
