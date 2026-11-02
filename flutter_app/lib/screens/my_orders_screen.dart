import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';

class MyOrdersScreen extends StatefulWidget {
  const MyOrdersScreen({super.key});

  @override
  State<MyOrdersScreen> createState() => _MyOrdersScreenState();
}

class _MyOrdersScreenState extends State<MyOrdersScreen> {
  final FlutterSecureStorage _secureStorage =
      const FlutterSecureStorage();

  List<Map<String, dynamic>> _orders = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final accessToken =
          await _secureStorage.read(key: 'access_token');

      if (accessToken == null || accessToken.isEmpty) {
        throw Exception('Please sign in to view your orders.');
      }

      final response = await http.get(
        Uri.parse(ApiConfig.orders),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
      );

      if (response.statusCode == 401) {
        throw Exception(
          'Your session has expired. Please sign in again.',
        );
      }

      if (response.statusCode != 200) {
        throw Exception(
          'Unable to load orders. HTTP ${response.statusCode}',
        );
      }

      final dynamic decoded = jsonDecode(response.body);

      List<dynamic> rawOrders;

      if (decoded is List) {
        rawOrders = decoded;
      } else if (decoded is Map && decoded['results'] is List) {
        rawOrders = decoded['results'] as List;
      } else {
        throw Exception('Invalid orders response from the server.');
      }

      final orders = rawOrders
          .whereType<Map>()
          .map((order) => Map<String, dynamic>.from(order))
          .toList();

      orders.sort((a, b) {
        final dateA = DateTime.tryParse(
          a['created_at']?.toString() ?? '',
        );
        final dateB = DateTime.tryParse(
          b['created_at']?.toString() ?? '',
        );

        if (dateA == null && dateB == null) return 0;
        if (dateA == null) return 1;
        if (dateB == null) return -1;

        return dateB.compareTo(dateA);
      });

      if (!mounted) return;

      setState(() {
        _orders = orders;
        _isLoading = false;
        _errorMessage = null;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage = e.toString().replaceFirst(
              'Exception: ',
              '',
            );
      });
    }
  }

  String _formatDate(dynamic value) {
    if (value == null) return 'Date unavailable';

    final date = DateTime.tryParse(value.toString());
    if (date == null) return 'Date unavailable';

    final localDate = date.toLocal();

    final day = localDate.day.toString().padLeft(2, '0');
    final month = localDate.month.toString().padLeft(2, '0');
    final year = localDate.year.toString();

    final hour =
        localDate.hour % 12 == 0 ? 12 : localDate.hour % 12;

    final minute = localDate.minute.toString().padLeft(2, '0');
    final period = localDate.hour >= 12 ? 'PM' : 'AM';

    return '$day/$month/$year, $hour:$minute $period';
  }

  double _parseAmount(dynamic value) {
    if (value == null) return 0;
    return double.tryParse(value.toString()) ?? 0;
  }

  String _formatAmount(dynamic value) {
    return _parseAmount(value).toStringAsFixed(2);
  }

  String _formatStatus(String status) {
    switch (status.toUpperCase()) {
      case 'PENDING':
        return 'Pending';
      case 'CONFIRMED':
        return 'Confirmed';
      case 'PACKED':
        return 'Packed';
      case 'OUT_FOR_DELIVERY':
        return 'Out for Delivery';
      case 'DELIVERED':
        return 'Delivered';
      case 'REJECTED':
        return 'Rejected';
      case 'CANCELLED':
        return 'Cancelled';
      default:
        return status.replaceAll('_', ' ');
    }
  }

  Color _statusColor(String status) {
    switch (status.toUpperCase()) {
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
      case 'REJECTED':
      case 'CANCELLED':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Color _paymentColor(String status) {
    switch (status.toUpperCase()) {
      case 'PAID':
        return Colors.green;
      case 'CASH_RECEIVED':
        return Colors.teal;
      case 'PENDING':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  String _formatPaymentStatus(String status) {
    switch (status.toUpperCase()) {
      case 'PAID':
        return 'Paid';
      case 'CASH_RECEIVED':
        return 'Cash Received';
      case 'PENDING':
        return 'Payment Pending';
      default:
        return status.replaceAll('_', ' ');
    }
  }

  int _totalQuantity(Map<String, dynamic> order) {
    final items = order['items'];

    if (items is! List) return 0;

    return items.fold<int>(0, (total, item) {
      if (item is! Map) return total;

      final quantity = int.tryParse(
            item['quantity']?.toString() ?? '',
          ) ??
          0;

      return total + quantity;
    });
  }

  int _itemCount(Map<String, dynamic> order) {
    final items = order['items'];
    if (items is! List) return 0;
    return items.length;
  }

  Widget _buildStatusBadge(
    String status, {
    bool payment = false,
  }) {
    final color =
        payment ? _paymentColor(status) : _statusColor(status);

    final label = payment
        ? _formatPaymentStatus(status)
        : _formatStatus(status);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildOrderCard(Map<String, dynamic> order) {
    final orderNo = order['order_no']?.toString() ?? 'Unknown';
    final status = order['status']?.toString() ?? 'PENDING';
    final paymentStatus =
        order['payment_status']?.toString() ?? 'PENDING';

    final items = order['items'] is List
        ? order['items'] as List
        : <dynamic>[];

    final firstItem = items.isNotEmpty && items.first is Map
        ? Map<String, dynamic>.from(items.first as Map)
        : <String, dynamic>{};

    final firstProductName =
        firstItem['product_name']?.toString() ?? 'Product';

    final remainingItems = items.length - 1;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () async {
          final cancelled = await Navigator.of(context).push<bool>(
            MaterialPageRoute(
              builder: (_) => OrderDetailsScreen(order: order),
            ),
          );

          if (cancelled == true && mounted) {
            await _loadOrders();

            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Order cancelled successfully.'),
                ),
              );
            }
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Order Number',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          orderNo,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _buildStatusBadge(status),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                _formatDate(order['created_at']),
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 13,
                ),
              ),
              const Divider(height: 24),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      width: 60,
                      height: 60,
                      color: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest,
                      child: firstItem['product_image'] != null &&
                              firstItem['product_image'].toString().isNotEmpty
                          ? Image.network(
                              firstItem['product_image'].toString().startsWith('http')
                                  ? firstItem['product_image'].toString()
                                  : '${ApiConfig.baseUrl.replaceFirst('/api', '')}${firstItem['product_image']}',
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return const Icon(
                                  Icons.inventory_2_outlined,
                                  size: 28,
                                  color: Colors.grey,
                                );
                              },
                            )
                          : const Icon(
                              Icons.inventory_2_outlined,
                              size: 28,
                              color: Colors.grey,
                            ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          firstProductName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_totalQuantity(order)} items in '
                          '${_itemCount(order)} product types',
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                          ),
                        ),
                        if (remainingItems > 0) ...[
                          const SizedBox(height: 4),
                          Text(
                            'And $remainingItems more product '
                            '${remainingItems == 1 ? 'type' : 'types'}',
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text(
                        'Total',
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '₹${_formatAmount(order['total'])}',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  _buildStatusBadge(
                    paymentStatus,
                    payment: true,
                  ),
                  const Spacer(),
                  const Text(
                    'View Details',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.arrow_forward_ios,
                    size: 14,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.receipt_long_outlined,
              size: 84,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            const Text(
              'No Orders Yet',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Your orders will appear here after you place an order.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.storefront_outlined),
              label: const Text('Continue Shopping'),
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
        title: const Text('My Orders'),
        actions: [
          IconButton(
            tooltip: 'Refresh orders',
            onPressed: _isLoading ? null : _loadOrders,
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
                          size: 56,
                          color: Colors.red,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: _loadOrders,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Try Again'),
                        ),
                      ],
                    ),
                  ),
                )
              : _orders.isEmpty
                  ? _buildEmptyState()
                  : RefreshIndicator(
                      onRefresh: _loadOrders,
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          Text(
                            '${_orders.length} '
                            '${_orders.length == 1 ? 'Order' : 'Orders'}',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const SizedBox(height: 12),
                          ..._orders.map(_buildOrderCard),
                        ],
                      ),
                    ),
    );
  }
}

class OrderDetailsScreen extends StatelessWidget {
  final Map<String, dynamic> order;

  const OrderDetailsScreen({
    super.key,
    required this.order,
  });

  String _formatAmount(dynamic value) {
    final amount = double.tryParse(value?.toString() ?? '') ?? 0;
    return amount.toStringAsFixed(2);
  }

  String _formatDate(dynamic value) {
    if (value == null) return 'Unavailable';

    final date = DateTime.tryParse(value.toString());
    if (date == null) return 'Unavailable';

    final localDate = date.toLocal();

    final day = localDate.day.toString().padLeft(2, '0');
    final month = localDate.month.toString().padLeft(2, '0');
    final year = localDate.year;

    return '$day/$month/$year';
  }

  String _formatDateTime(dynamic value) {
    if (value == null) return 'Unavailable';

    final date = DateTime.tryParse(value.toString());
    if (date == null) return 'Unavailable';

    final localDate = date.toLocal();

    final hour =
        localDate.hour % 12 == 0 ? 12 : localDate.hour % 12;

    final minute = localDate.minute.toString().padLeft(2, '0');
    final period = localDate.hour >= 12 ? 'PM' : 'AM';

    return '${_formatDate(value)}, $hour:$minute $period';
  }

  String _formatStatus(String status) {
    switch (status.toUpperCase()) {
      case 'PENDING':
        return 'Pending';
      case 'CONFIRMED':
        return 'Confirmed';
      case 'PACKED':
        return 'Packed';
      case 'OUT_FOR_DELIVERY':
        return 'Out for Delivery';
      case 'DELIVERED':
        return 'Delivered';
      case 'REJECTED':
        return 'Rejected';
      case 'CANCELLED':
        return 'Cancelled';
      case 'CASH_RECEIVED':
        return 'Cash Received';
      default:
        return status.replaceAll('_', ' ');
    }
  }

  Color _statusColor(String status) {
    switch (status.toUpperCase()) {
      case 'PENDING':
        return Colors.orange;
      case 'CONFIRMED':
        return Colors.blue;
      case 'PACKED':
        return Colors.indigo;
      case 'OUT_FOR_DELIVERY':
        return Colors.purple;
      case 'DELIVERED':
      case 'PAID':
        return Colors.green;
      case 'CASH_RECEIVED':
        return Colors.teal;
      case 'REJECTED':
      case 'CANCELLED':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Widget _buildBadge(String status) {
    final color = _statusColor(status);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        _formatStatus(status),
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildAmountRow(
    String label,
    dynamic value, {
    bool bold = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight:
                  bold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            '₹${_formatAmount(value)}',
            style: TextStyle(
              fontWeight:
                  bold ? FontWeight.bold : FontWeight.normal,
              fontSize: bold ? 18 : 14,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _cancelOrder(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cancel Order?'),
        content: const Text(
          'Are you sure you want to cancel this order? '
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(false),
            child: const Text('Keep Order'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(true),
            child: const Text('Cancel Order'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    try {
      const storage = FlutterSecureStorage();

      final accessToken =
          await storage.read(key: 'access_token');

      if (accessToken == null || accessToken.isEmpty) {
        throw Exception(
          'Please sign in again to cancel this order.',
        );
      }

      final orderId = order['id'];

      if (orderId == null) {
        throw Exception(
          'Order ID is missing. Please refresh your orders.',
        );
      }

      final response = await http.post(
        Uri.parse('${ApiConfig.orders}$orderId/cancel/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode({
          'remarks': 'Cancelled by hotel staff from the mobile app.',
        }),
      );

      if (!context.mounted) return;

      if (response.statusCode == 200) {
        Navigator.of(context).pop(true);
        return;
      }

      String message =
          'Unable to cancel the order. HTTP ${response.statusCode}.';

      try {
        final decoded = jsonDecode(response.body);

        if (decoded is Map) {
          message = (
            decoded['detail'] ??
            decoded['message'] ??
            message
          ).toString();
        }
      } catch (_) {
        // Use the fallback message if the response is not JSON.
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (e) {
      if (!context.mounted) return;

      final message =
          e.toString().replaceFirst('Exception: ', '');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final orderNo = order['order_no']?.toString() ?? 'Unknown';
    final status = order['status']?.toString() ?? 'PENDING';

    final paymentStatus =
        order['payment_status']?.toString() ?? 'PENDING';

    final items = order['items'] is List
        ? order['items'] as List
        : <dynamic>[];

    final payments = order['payments'] is List
        ? order['payments'] as List
        : <dynamic>[];

    final history = order['status_history'] is List
        ? order['status_history'] as List
        : <dynamic>[];

    final firstPayment =
        payments.isNotEmpty && payments.first is Map
            ? Map<String, dynamic>.from(payments.first as Map)
            : <String, dynamic>{};

    final paymentMethod =
        firstPayment['method']?.toString() ?? 'Not specified';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Order Details'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Order Number',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 6),
                  SelectableText(
                    orderNo,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Placed on ${_formatDateTime(order['created_at'])}',
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildBadge(status),
                      _buildBadge(paymentStatus),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Products (${items.length})',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: items.isEmpty
                  ? const Text('No product details available.')
                  : Column(
                      children: [
                        for (int index = 0;
                            index < items.length;
                            index++) ...[
                          if (index > 0) const Divider(height: 24),
                          if (items[index] is Map)
                            _buildProductRow(
                              Map<String, dynamic>.from(
                                items[index] as Map,
                              ),
                            ),
                        ],
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Payment Summary',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildAmountRow('Subtotal', order['subtotal']),
                  _buildAmountRow('Tax', order['tax']),
                  _buildAmountRow(
                    'Delivery Charge',
                    order['delivery_charge'],
                  ),
                  const Divider(height: 24),
                  _buildAmountRow(
                    'Total',
                    order['total'],
                    bold: true,
                  ),
                  const Divider(height: 24),
                  _detailRow('Payment Method', paymentMethod),
                  const SizedBox(height: 8),
                  _detailRow(
                    'Payment Status',
                    _formatStatus(paymentStatus),
                  ),
                  if (firstPayment['payment_id'] != null &&
                      firstPayment['payment_id']
                          .toString()
                          .isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _detailRow(
                      'Payment Reference',
                      firstPayment['payment_id'].toString(),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if ((order['notes']?.toString() ?? '').isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              'Order Notes',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(order['notes'].toString()),
              ),
            ),
          ],
          const SizedBox(height: 24),
          Text(
            'Order Timeline',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          if (history.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('No order history available.'),
              ),
            )
          else
            ...history.map((entry) {
              if (entry is! Map) {
                return const SizedBox.shrink();
              }

              final event = Map<String, dynamic>.from(entry);

              final eventStatus =
                  event['status']?.toString() ?? 'UNKNOWN';

              final remarks = event['remarks']?.toString() ?? '';

              final changedBy =
                  event['changed_by_username']?.toString() ?? '';

              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor:
                        _statusColor(eventStatus).withValues(alpha: 0.12),
                    child: Icon(
                      Icons.check_circle_outline,
                      color: _statusColor(eventStatus),
                    ),
                  ),
                  title: Text(
                    _formatStatus(eventStatus),
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (remarks.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(remarks),
                      ],
                      if (changedBy.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text('Updated by: $changedBy'),
                      ],
                      const SizedBox(height: 4),
                      Text(
                        _formatDateTime(event['changed_at']),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                  isThreeLine: true,
                ),
              );
            }),
          if (status.toUpperCase() == 'PENDING' ||
              status.toUpperCase() == 'CONFIRMED') ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _cancelOrder(context),
                icon: const Icon(Icons.cancel_outlined),
                label: const Text('Cancel Order'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildProductRow(Map<String, dynamic> item) {
    final name = item['product_name']?.toString() ?? 'Product';
    final image = item['product_image']?.toString();

    final quantity = int.tryParse(
          item['quantity']?.toString() ?? '',
        ) ??
        0;

    final imageUrl = image == null || image.isEmpty
        ? null
        : image.startsWith('http')
            ? image
            : '${ApiConfig.baseUrl.replaceFirst('/api', '')}$image';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: 80,
            height: 80,
            color: Colors.grey.shade100,
            child: imageUrl != null
                ? Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return const Icon(
                        Icons.inventory_2_outlined,
                        size: 32,
                        color: Colors.grey,
                      );
                    },
                  )
                : const Icon(
                    Icons.inventory_2_outlined,
                    size: 32,
                    color: Colors.grey,
                  ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '$quantity × ₹${_formatAmount(item['unit_price'])}',
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '₹${_formatAmount(item['line_total'])}',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _detailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.grey),
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
    );
  }
}