import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:razorpay_flutter/razorpay_flutter.dart';

import '../config/api_config.dart';
import '../models/cart_item.dart';

class CheckoutScreen extends StatefulWidget {
  final List<CartItem> items;
  final double cartTotal;

  const CheckoutScreen({
    super.key,
    required this.items,
    required this.cartTotal,
  });

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final FlutterSecureStorage _secureStorage =
      const FlutterSecureStorage();

  final TextEditingController _notesController =
      TextEditingController();

  late final Razorpay _razorpay;

  String _paymentMethod = 'COD';
  bool _isSubmitting = false;
  String? _errorMessage;

  int? _pendingOrderId;
  String? _pendingOrderNo;

  PaymentSuccessResponse? _pendingVerification;

  int get _totalQuantity {
    return widget.items.fold<int>(
      0,
      (total, item) => total + item.quantity,
    );
  }

  @override
  void initState() {
    super.initState();

    _razorpay = Razorpay();

    _razorpay.on(
      Razorpay.EVENT_PAYMENT_SUCCESS,
      _handlePaymentSuccess,
    );

    _razorpay.on(
      Razorpay.EVENT_PAYMENT_ERROR,
      _handlePaymentError,
    );

    _razorpay.on(
      Razorpay.EVENT_EXTERNAL_WALLET,
      _handleExternalWallet,
    );
  }

  @override
  void dispose() {
    _razorpay.clear();
    _notesController.dispose();
    super.dispose();
  }

  Future<String> _getAccessToken() async {
    final token = await _secureStorage.read(
      key: 'access_token',
    );

    if (token == null || token.isEmpty) {
      throw Exception(
        'Please sign in again to place your order.',
      );
    }

    return token;
  }

  Future<Map<String, dynamic>> _postRequest(
    String url,
    String token, {
    Map<String, dynamic>? body,
  }) async {
    final response = await http.post(
      Uri.parse(url),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(body ?? {}),
    );

    dynamic decoded;

    try {
      decoded = jsonDecode(response.body);
    } on FormatException {
      throw Exception(
        'The server returned an invalid response. Please try again.',
      );
    }

    if (decoded is! Map<String, dynamic>) {
      throw Exception('Invalid server response.');
    }

    if (response.statusCode < 200 ||
        response.statusCode >= 300) {
      throw Exception(_getErrorMessage(decoded));
    }

    return decoded;
  }

  String _getErrorMessage(Map<dynamic, dynamic> data) {
    final detail = data['detail'];

    if (detail is String && detail.isNotEmpty) {
      return detail;
    }

    if (detail is List && detail.isNotEmpty) {
      return detail.join('\n');
    }

    return data.entries.map((entry) {
      final value = entry.value;

      if (value is List) {
        return value.join('\n');
      }

      if (value is Map) {
        return value.entries
            .map((item) => '${item.key}: ${item.value}')
            .join('\n');
      }

      return '${entry.key}: $value';
    }).join('\n');
  }

  Future<void> _placeOrder() async {
    if (_isSubmitting) return;

    if (widget.items.isEmpty && _pendingOrderId == null) {
      setState(() {
        _errorMessage = 'Your cart is empty.';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final token = await _getAccessToken();

      // Retry verification if Razorpay already reported success.
      if (_pendingVerification != null) {
        await _verifyPayment(token);
        return;
      }

      // Retry payment using the existing pending order.
      if (_paymentMethod == 'UPI' &&
          _pendingOrderId != null) {
        await _startRazorpayPayment(token);
        return;
      }

      // Create a new Django order.
      final response = await _postRequest(
        '${ApiConfig.orders}checkout/',
        token,
        body: {
          'payment_method': _paymentMethod,
          'notes': _notesController.text.trim(),
        },
      );

      final dynamic orderData = response['order'];

      if (orderData is! Map) {
        throw Exception(
          'The server returned an invalid order response.',
        );
      }

      final int? orderId =
          int.tryParse(orderData['id'].toString());

      final String orderNo =
          orderData['order_no']?.toString() ?? '';

      final double orderTotal =
          double.tryParse(orderData['total'].toString()) ??
              widget.cartTotal;

      if (orderId == null || orderNo.isEmpty) {
        throw Exception(
          'The order was created, but its details could not be read.',
        );
      }

      // COD: Keep the existing order placement process.
      if (_paymentMethod == 'COD') {
        await _showOrderSuccess(
          orderNo,
          orderTotal,
        );
        return;
      }

      // UPI: Save the order details for payment retries.
      _pendingOrderId = orderId;
      _pendingOrderNo = orderNo;

      await _startRazorpayPayment(token);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _errorMessage = e.toString().replaceFirst(
              'Exception: ',
              '',
            );
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Future<void> _startRazorpayPayment(String token) async {
    if (_pendingOrderId == null) {
      throw Exception('Order information is missing.');
    }

    final response = await _postRequest(
      '${ApiConfig.orders}${_pendingOrderId!}/create-payment/',
      token,
    );

    final String razorpayOrderId =
        response['razorpay_order_id']?.toString() ?? '';

    final String razorpayKeyId =
        response['razorpay_key_id']?.toString() ?? '';

    final int? amount =
        int.tryParse(response['amount'].toString());

    final String currency =
        response['currency']?.toString() ?? 'INR';

    if (razorpayOrderId.isEmpty ||
        razorpayKeyId.isEmpty ||
        amount == null ||
        amount <= 0) {
      throw Exception(
        'Unable to initialize Razorpay payment.',
      );
    }

    final options = {
      'key': razorpayKeyId,
      'amount': amount,
      'currency': currency,
      'name': 'Misty Go Delivery',
      'order_id': razorpayOrderId,
      'description': 'Order ${_pendingOrderNo ?? ''}',
      'method': {
        'upi': true,
      },
      'theme': {
        'color': '#1565C0',
      },
    };

    _razorpay.open(options);
  }

  void _handlePaymentSuccess(
    PaymentSuccessResponse response,
  ) {
    if (!mounted) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
      _pendingVerification = response;
    });

    _verifyPaymentAfterCallback();
  }

  Future<void> _verifyPaymentAfterCallback() async {
    try {
      final token = await _getAccessToken();
      await _verifyPayment(token);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _errorMessage =
            'Payment was completed, but verification could not be confirmed. '
            'Please retry verification. Do not make another payment.\n\n'
            '${e.toString().replaceFirst('Exception: ', '')}';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Future<void> _verifyPayment(String token) async {
    final payment = _pendingVerification;

    if (payment == null || _pendingOrderId == null) {
      throw Exception(
        'Payment verification information is missing.',
      );
    }

    if (payment.paymentId == null ||
        payment.orderId == null ||
        payment.signature == null) {
      throw Exception(
        'Razorpay returned incomplete payment information.',
      );
    }

    final response = await _postRequest(
      '${ApiConfig.orders}${_pendingOrderId!}/verify-payment/',
      token,
      body: {
        'razorpay_order_id': payment.orderId,
        'razorpay_payment_id': payment.paymentId,
        'razorpay_signature': payment.signature,
      },
    );

    if (response['payment_status'] != 'PAID' &&
        response['order_payment_status'] != 'PAID') {
      throw Exception(
        'Payment verification is not yet complete.',
      );
    }

    if (!mounted) return;

    await _showOrderSuccess(
      _pendingOrderNo ?? '',
      double.tryParse(response['amount'].toString()) ??
          widget.cartTotal,
    );
  }

  void _handlePaymentError(
    PaymentFailureResponse response,
  ) {
    if (!mounted) return;

    setState(() {
      _isSubmitting = false;
      _errorMessage =
          'Payment was not completed. ${response.message ?? 'Please try again.'}';
    });
  }

  void _handleExternalWallet(
    ExternalWalletResponse response,
  ) {
    if (!mounted) return;

    setState(() {
      _errorMessage =
          'Selected wallet: ${response.walletName ?? 'External wallet'}';
    });
  }

  Future<void> _showOrderSuccess(
    String orderNo,
    double orderTotal,
  ) async {
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          icon: const Icon(
            Icons.check_circle_outline,
            color: Colors.green,
            size: 56,
          ),
          title: const Text(
            'Order Placed Successfully',
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Your order has been submitted successfully.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              const Text('Order Number'),
              const SizedBox(height: 4),
              SelectableText(
                orderNo,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Amount: ₹${orderTotal.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Payment method: $_paymentMethod',
              ),
            ],
          ),
          actions: [
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Continue'),
            ),
          ],
        );
      },
    );

    if (!mounted) return;

    Navigator.of(context).pop(orderNo);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Checkout'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Order Summary',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    ...widget.items.map((item) {
                      return Padding(
                        padding: const EdgeInsets.only(
                          bottom: 16,
                        ),
                        child: Row(
                          crossAxisAlignment:
                              CrossAxisAlignment.center,
                          children: [
                            ClipRRect(
                              borderRadius:
                                  BorderRadius.circular(8),
                              child: Container(
                                width: 60,
                                height: 60,
                                color: Colors.grey.shade100,
                                child: item.image != null &&
                                        item.image!.isNotEmpty
                                    ? Image.network(
                                        item.image!.startsWith('http')
                                            ? item.image!
                                            : '${ApiConfig.baseUrl.replaceFirst('/api', '')}${item.image}',
                                        fit: BoxFit.cover,
                                        errorBuilder: (
                                          context,
                                          error,
                                          stackTrace,
                                        ) {
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
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.productName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text('SKU: ${item.sku}'),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${item.quantity} × ₹${item.price.toStringAsFixed(2)}',
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '₹${item.lineTotal.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                    const Divider(),
                    const SizedBox(height: 8),
                    _summaryRow(
                      'Total quantity',
                      '$_totalQuantity',
                    ),
                    const SizedBox(height: 12),
                    _summaryRow(
                      'Order total',
                      '₹${widget.cartTotal.toStringAsFixed(2)}',
                      isTotal: true,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Payment Method',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Card(
              child: RadioGroup<String>(
                groupValue: _paymentMethod,
                onChanged: (String? value) {
                  if (value == null || _isSubmitting) {
                    return;
                  }

                  if (_pendingOrderId != null &&
                      value != 'UPI') {
                    setState(() {
                      _errorMessage =
                          'Please complete or retry your existing UPI payment.';
                    });
                    return;
                  }

                  setState(() {
                    _paymentMethod = value;
                    _errorMessage = null;
                  });
                },
                child: Column(
                  children: [
                    RadioListTile<String>(
                      value: 'COD',
                      enabled: !_isSubmitting &&
                          _pendingOrderId == null,
                      title: const Text('Cash on Delivery'),
                      subtitle: const Text(
                        'Pay when the order is delivered.',
                      ),
                      secondary: const Icon(
                        Icons.payments_outlined,
                      ),
                    ),
                    const Divider(height: 1),
                    RadioListTile<String>(
                      value: 'UPI',
                      enabled: !_isSubmitting,
                      title: const Text('UPI'),
                      subtitle: const Text(
                        'Pay securely using Razorpay.',
                      ),
                      secondary: const Icon(
                        Icons.account_balance_wallet_outlined,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Order Notes (Optional)',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _notesController,
              enabled: !_isSubmitting &&
                  _pendingOrderId == null,
              maxLines: 3,
              maxLength: 500,
              decoration: const InputDecoration(
                hintText:
                    'Add any instructions for your order...',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .errorContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _errorMessage!,
                  style: TextStyle(
                    color: Theme.of(context)
                        .colorScheme
                        .onErrorContainer,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed:
                  _isSubmitting ? null : _placeOrder,
              icon: _isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    )
                  : Icon(
                      _pendingVerification != null
                          ? Icons.verified_outlined
                          : _pendingOrderId != null
                              ? Icons.refresh
                              : Icons.check_circle_outline,
                    ),
              label: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 14,
                ),
                child: Text(
                  _isSubmitting
                      ? 'Processing...'
                      : _pendingVerification != null
                          ? 'Retry Verification'
                          : _pendingOrderId != null
                              ? 'Retry UPI Payment'
                              : 'Place Order · '
                                  '₹${widget.cartTotal.toStringAsFixed(2)}',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Your order will be submitted for confirmation.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryRow(
    String label,
    String value, {
    bool isTotal = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: isTotal
                ? FontWeight.bold
                : FontWeight.normal,
            fontSize: isTotal ? 18 : 14,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: isTotal ? 20 : 14,
          ),
        ),
      ],
    );
  }
}
