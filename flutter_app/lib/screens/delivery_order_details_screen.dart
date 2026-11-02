import 'package:flutter/material.dart';

import '../models/order.dart';
import '../services/order_service.dart';

class DeliveryOrderDetailsScreen extends StatefulWidget {
  final int orderId;

  const DeliveryOrderDetailsScreen({
    super.key,
    required this.orderId,
  });

  @override
  State<DeliveryOrderDetailsScreen> createState() =>
      _DeliveryOrderDetailsScreenState();
}

class _DeliveryOrderDetailsScreenState
    extends State<DeliveryOrderDetailsScreen> {
  final OrderService _orderService = OrderService();

  Order? _order;
  bool _isLoading = true;
  bool _isDelivering = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadOrder();
  }

  Future<void> _loadOrder() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final order =
          await _orderService.getOrderDetails(widget.orderId);

      if (!mounted) return;

      setState(() {
        _order = order;
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

  String _formatStatus(String status) {
    return status.replaceAll('_', ' ');
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'N/A';

    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  String _formatDateTime(dynamic value) {
    if (value == null) return 'N/A';

    final date = DateTime.tryParse(value.toString());

    if (date == null) return value.toString();

    return '${_formatDate(date)} '
        '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _markAsDelivered() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Confirm Delivery'),
          content: const Text(
            'Are you sure this order has been delivered successfully?',
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, true),
              child: const Text('Confirm Delivery'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    setState(() {
      _isDelivering = true;
    });

    try {
      await _orderService.updateOrderStatus(
        widget.orderId,
        'DELIVERED',
        remarks: 'Order successfully delivered.',
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Order marked as delivered successfully.'),
          backgroundColor: Colors.green,
        ),
      );

      // Do not fetch the order again. Delivery users can only
      // access orders with OUT_FOR_DELIVERY status.
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isDelivering = false;
      });

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
              style: const TextStyle(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderItems(Order order) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle('Order Items'),
            ...order.items.map((item) {
              final productName =
                  item['product_name']?.toString() ?? 'Product';

              final quantity =
                  item['quantity']?.toString() ?? '0';

              final unitPrice =
                  double.tryParse(item['unit_price'].toString()) ?? 0;

              final lineTotal =
                  double.tryParse(item['line_total'].toString()) ?? 0;

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            productName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Text(
                          '₹${lineTotal.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '$quantity × ₹${unitPrice.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: Colors.black54,
                        ),
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

  Widget _buildPaymentDetails(Order order) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle('Payment Information'),
            _infoRow(
              'Payment Status',
              _formatStatus(order.paymentStatus),
            ),
            if (order.payments.isNotEmpty)
              ...order.payments.map((payment) {
                return Column(
                  children: [
                    const Divider(),
                    _infoRow(
                      'Method',
                      payment['method']?.toString() ?? 'N/A',
                    ),
                    _infoRow(
                      'Amount',
                      '₹${payment['amount'] ?? '0'}',
                    ),
                    _infoRow(
                      'Payment Status',
                      _formatStatus(
                        payment['status']?.toString() ?? 'PENDING',
                      ),
                    ),
                    if (payment['received_by'] != null)
                      _infoRow(
                        'Received By',
                        payment['received_by'].toString(),
                      ),
                    if (payment['received_at'] != null)
                      _infoRow(
                        'Received At',
                        _formatDateTime(payment['received_at']),
                      ),
                  ],
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusHistory(Order order) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle('Order Status History'),
            if (order.statusHistory.isEmpty)
              const Text('No status history available.')
            else
              ...order.statusHistory.map((history) {
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
                                history['status']?.toString() ?? '',
                              ),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (history['changed_by_username'] != null)
                              Text(
                                'By: ${history['changed_by_username']}',
                                style: const TextStyle(
                                  color: Colors.black54,
                                ),
                              ),
                            if (history['remarks'] != null &&
                                history['remarks'].toString().isNotEmpty)
                              Text(
                                history['remarks'].toString(),
                              ),
                            if (history['changed_at'] != null)
                              Text(
                                _formatDateTime(history['changed_at']),
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

  Widget _buildContent(Order order) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  order.orderNo,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                _infoRow('Hotel', order.hotelName),
                _infoRow('Order Date', _formatDate(order.createdAt)),
                _infoRow(
                  'Order Status',
                  _formatStatus(order.status),
                ),
                _infoRow('Placed By', order.placedByUsername),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        _buildOrderItems(order),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionTitle('Price Summary'),
                _infoRow(
                  'Subtotal',
                  '₹${order.subtotal.toStringAsFixed(2)}',
                ),
                _infoRow(
                  'Tax',
                  '₹${order.tax.toStringAsFixed(2)}',
                ),
                _infoRow(
                  'Delivery Charge',
                  '₹${order.deliveryCharge.toStringAsFixed(2)}',
                ),
                const Divider(),
                _infoRow(
                  'Total Amount',
                  '₹${order.total.toStringAsFixed(2)}',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        _buildPaymentDetails(order),
        const SizedBox(height: 12),
        _buildStatusHistory(order),
        if (order.notes.isNotEmpty) ...[
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionTitle('Order Notes'),
                  Text(order.notes),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 20),
        if (order.status == 'OUT_FOR_DELIVERY')
          SizedBox(
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _isDelivering ? null : _markAsDelivered,
              icon: _isDelivering
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.check_circle_outline),
              label: Text(
                _isDelivering
                    ? 'Updating...'
                    : 'Mark as Delivered',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        const SizedBox(height: 20),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Delivery Details'),
      ),
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
                          onPressed: _loadOrder,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : _order == null
                  ? const Center(child: Text('Order not found.'))
                  : _buildContent(_order!),
    );
  }
}