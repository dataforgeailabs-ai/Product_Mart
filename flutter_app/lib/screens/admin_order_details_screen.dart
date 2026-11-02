import 'package:flutter/material.dart';

import '../models/order.dart';
import '../services/order_service.dart';

class AdminOrderDetailsScreen extends StatefulWidget {
  final int orderId;

  const AdminOrderDetailsScreen({
    super.key,
    required this.orderId,
  });

  @override
  State<AdminOrderDetailsScreen> createState() =>
      _AdminOrderDetailsScreenState();
}

class _AdminOrderDetailsScreenState
    extends State<AdminOrderDetailsScreen> {
  final OrderService _orderService = OrderService();

  Order? _order;
  bool _isLoading = true;
  bool _isProcessing = false;
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
        _errorMessage =
            e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  String _formatAmount(dynamic amount) {
    final value =
        double.tryParse(amount.toString()) ?? 0.0;

    return '₹${value.toStringAsFixed(2)}';
  }

  String _formatStatus(String status) {
    return status
        .replaceAll('_', ' ')
        .toLowerCase()
        .split(' ')
        .map((word) => word.isEmpty
            ? word
            : '${word[0].toUpperCase()}${word.substring(1)}')
        .join(' ');
  }

  String _formatDate(dynamic value) {
    if (value == null) return 'Not available';

    final date = DateTime.tryParse(value.toString());

    if (date == null) return 'Not available';

    final local = date.toLocal();

    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final year = local.year;

    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');

    return '$day/$month/$year  $hour:$minute';
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'PENDING':
        return Colors.orange;
      case 'CONFIRMED':
        return Colors.blue;
      case 'PACKED':
        return Colors.indigo;
      case 'OUT_FOR_DELIVERY':
        return Colors.purple;
      case 'DELIVERED':
        return Colors.green;
      case 'CANCELLED':
      case 'REJECTED':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  Future<void> _performAction(
    String action, {
    String remarks = '',
  }) async {
    if (_order == null || _isProcessing) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      switch (action) {
        case 'CONFIRM':
          await _orderService.confirmOrder(_order!.id);
          break;

        case 'REJECT':
          await _orderService.rejectOrder(
            _order!.id,
            remarks: remarks,
          );
          break;

        case 'CANCEL':
          await _orderService.cancelOrder(
            _order!.id,
            remarks: remarks,
          );
          break;

        case 'PACKED':
          await _orderService.updateOrderStatus(
            _order!.id,
            'PACKED',
            remarks: remarks,
          );
          break;

        case 'OUT_FOR_DELIVERY':
          await _orderService.updateOrderStatus(
            _order!.id,
            'OUT_FOR_DELIVERY',
            remarks: remarks,
          );
          break;
      }

      await _loadOrder();

      if (!mounted) return;

      _showMessage('Order updated successfully.');
    } catch (e) {
      if (!mounted) return;

      _showMessage(
        e.toString().replaceFirst('Exception: ', ''),
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  Future<void> _showActionDialog({
    required String title,
    required String action,
    required String message,
    bool requireRemarks = false,
  }) async {
    final remarks = await showDialog<String?>(
      context: context,
      builder: (dialogContext) {
        return _OrderActionDialog(
          title: title,
          message: message,
          requireRemarks: requireRemarks,
        );
      },
    );

    if (!mounted || remarks == null) return;

    await _performAction(
      action,
      remarks: remarks,
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(color: Colors.grey.shade700),
            ),
          ),
          Expanded(
            flex: 3,
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

  Widget _buildOrderInformation(Order order) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle(
              'Order Information',
              Icons.receipt_long,
            ),
            _buildInfoRow('Order Number', order.orderNo),
            _buildInfoRow('Hotel', order.hotelName),
            _buildInfoRow(
              'Placed By',
              order.placedByUsername,
            ),
            _buildInfoRow(
              'Order Date',
              _formatDate(order.createdAt),
            ),
            _buildInfoRow(
              'Last Updated',
              _formatDate(order.updatedAt),
            ),
            _buildInfoRow(
              'Order Status',
              _formatStatus(order.status),
            ),
          ],
        ),
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
            _buildSectionTitle(
              'Ordered Products',
              Icons.shopping_bag_outlined,
            ),
            if (order.items.isEmpty)
              const Text('No products found.')
            else
              ...order.items.map((item) {
                final name =
                    item['product_name']?.toString() ??
                        'Unknown Product';

                final quantity =
                    item['quantity']?.toString() ?? '0';

                final unitPrice =
                    _formatAmount(item['unit_price'] ?? 0);

                final lineTotal =
                    _formatAmount(item['line_total'] ?? 0);

                return Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: Colors.grey.shade200,
                      ),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.inventory_2_outlined,
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              '$quantity × $unitPrice',
                              style: TextStyle(
                                color: Colors.grey.shade700,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        lineTotal,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
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

  Widget _buildPriceSummary(Order order) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle(
              'Price Summary',
              Icons.currency_rupee,
            ),
            _buildInfoRow(
              'Subtotal',
              _formatAmount(order.subtotal),
            ),
            _buildInfoRow(
              'Tax',
              _formatAmount(order.tax),
            ),
            _buildInfoRow(
              'Delivery Charge',
              _formatAmount(order.deliveryCharge),
            ),
            const Divider(height: 24),
            _buildInfoRow(
              'Total Amount',
              _formatAmount(order.total),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPayments(Order order) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle(
              'Payment Information',
              Icons.payment,
            ),
            _buildInfoRow(
              'Payment Status',
              _formatStatus(order.paymentStatus),
            ),
            if (order.payments.isEmpty)
              const Text('No payment records found.')
            else
              ...order.payments.map((payment) {
                return Column(
                  children: [
                    const Divider(),
                    _buildInfoRow(
                      'Method',
                      payment['method']?.toString() ?? '-',
                    ),
                    _buildInfoRow(
                      'Amount',
                      _formatAmount(payment['amount'] ?? 0),
                    ),
                    _buildInfoRow(
                      'Payment Status',
                      _formatStatus(
                        payment['status']?.toString() ?? '',
                      ),
                    ),
                    _buildInfoRow(
                      'Payment ID',
                      payment['payment_id']?.toString().isNotEmpty ==
                              true
                          ? payment['payment_id'].toString()
                          : '-',
                    ),
                    _buildInfoRow(
                      'Received By',
                      payment['received_by']?.toString() ?? '-',
                    ),
                    _buildInfoRow(
                      'Received At',
                      _formatDate(payment['received_at']),
                    ),
                    _buildInfoRow(
                      'Paid At',
                      _formatDate(payment['paid_at']),
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
    final history = [...order.statusHistory];

    history.sort((a, b) {
      final dateA = DateTime.tryParse(
            a['changed_at']?.toString() ?? '',
          ) ??
          DateTime(2000);

      final dateB = DateTime.tryParse(
            b['changed_at']?.toString() ?? '',
          ) ??
          DateTime(2000);

      return dateA.compareTo(dateB);
    });

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle(
              'Order Status History',
              Icons.timeline,
            ),
            if (history.isEmpty)
              const Text('No status history available.')
            else
              ...history.map((entry) {
                final status =
                    entry['status']?.toString() ?? '';

                final color = _statusColor(status);

                return Padding(
                  padding: const EdgeInsets.only(bottom: 18),
                  child: Row(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.check_circle,
                        color: color,
                        size: 22,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Text(
                              _formatStatus(status),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: color,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'By: ${entry['changed_by_username'] ?? 'System'}',
                              style: const TextStyle(fontSize: 12),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              entry['remarks']?.toString() ?? '',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _formatDate(entry['changed_at']),
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade600,
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

  Widget _buildAdminActions(Order order) {
    final buttons = <Widget>[];

    if (order.status == 'PENDING') {
      buttons.add(
        FilledButton.icon(
          onPressed: _isProcessing
              ? null
              : () => _showActionDialog(
                    title: 'Confirm Order',
                    action: 'CONFIRM',
                    message:
                        'Are you sure you want to confirm this order? Stock will be deducted.',
                  ),
          icon: const Icon(Icons.check),
          label: const Text('Confirm'),
          style: FilledButton.styleFrom(
            backgroundColor: Colors.green,
          ),
        ),
      );

      buttons.add(
        OutlinedButton.icon(
          onPressed: _isProcessing
              ? null
              : () => _showActionDialog(
                    title: 'Reject Order',
                    action: 'REJECT',
                    message:
                        'Are you sure you want to reject this order?',
                    requireRemarks: true,
                  ),
          icon: const Icon(Icons.close),
          label: const Text('Reject'),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.red,
          ),
        ),
      );
    }

    if (order.status == 'CONFIRMED') {
      buttons.add(
        FilledButton.icon(
          onPressed: _isProcessing
              ? null
              : () => _showActionDialog(
                    title: 'Mark as Packed',
                    action: 'PACKED',
                    message:
                        'Confirm that this order has been packed.',
                    requireRemarks: true,
                  ),
          icon: const Icon(Icons.inventory_2),
          label: const Text('Mark Packed'),
        ),
      );
    }

    if (order.status == 'PACKED') {
      buttons.add(
        FilledButton.icon(
          onPressed: _isProcessing
              ? null
              : () => _showActionDialog(
                    title: 'Dispatch Order',
                    action: 'OUT_FOR_DELIVERY',
                    message:
                        'Confirm that this order is ready for delivery.',
                    requireRemarks: true,
                  ),
          icon: const Icon(Icons.local_shipping),
          label: const Text('Dispatch'),
        ),
      );
    }

    if (order.status == 'PENDING' ||
        order.status == 'CONFIRMED') {
      buttons.add(
        OutlinedButton.icon(
          onPressed: _isProcessing
              ? null
              : () => _showActionDialog(
                    title: 'Cancel Order',
                    action: 'CANCEL',
                    message:
                        'Are you sure you want to cancel this order?',
                    requireRemarks: true,
                  ),
          icon: const Icon(Icons.cancel_outlined),
          label: const Text('Cancel Order'),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.red,
          ),
        ),
      );
    }

    if (buttons.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle(
              'Admin Actions',
              Icons.admin_panel_settings_outlined,
            ),
            if (_isProcessing)
              const LinearProgressIndicator(),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: buttons,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderDetails(Order order) {
    return RefreshIndicator(
      onRefresh: _loadOrder,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(
                    Icons.receipt_long,
                    size: 38,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text(
                          order.orderNo,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          order.hotelName,
                          style: TextStyle(
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: _statusColor(order.status)
                          .withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _formatStatus(order.status),
                      style: TextStyle(
                        color: _statusColor(order.status),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          _buildAdminActions(order),
          _buildOrderInformation(order),
          _buildOrderItems(order),
          _buildPriceSummary(order),
          _buildPayments(order),
          _buildStatusHistory(order),
          if (order.notes.isNotEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    _buildSectionTitle(
                      'Order Notes',
                      Icons.notes,
                    ),
                    Text(order.notes),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Order Details'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _isLoading ? null : _loadOrder,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          color: Colors.red,
                          size: 48,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: _loadOrder,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Try Again'),
                        ),
                      ],
                    ),
                  ),
                )
              : _order == null
                  ? const Center(
                      child: Text('Order not found.'),
                    )
                  : _buildOrderDetails(_order!),
    );
  }
}

class _OrderActionDialog extends StatefulWidget {
  final String title;
  final String message;
  final bool requireRemarks;

  const _OrderActionDialog({
    required this.title,
    required this.message,
    required this.requireRemarks,
  });

  @override
  State<_OrderActionDialog> createState() => _OrderActionDialogState();
}

class _OrderActionDialogState extends State<_OrderActionDialog> {
  late final TextEditingController _remarksController;

  @override
  void initState() {
    super.initState();
    _remarksController = TextEditingController();
  }

  @override
  void dispose() {
    _remarksController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.message),
          if (widget.requireRemarks) ...[
            const SizedBox(height: 16),
            TextField(
              controller: _remarksController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Remarks',
                hintText: 'Enter remarks',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(
            context,
            _remarksController.text.trim(),
          ),
          child: const Text('Continue'),
        ),
      ],
    );
  }
}

