import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/order.dart';
import 'authenticated_http_client.dart';

class OrderService {
  Map<String, String> _getHeaders() =>
      const {'Content-Type': 'application/json'};

  dynamic _decodeResponse(http.Response response) {
    try {
      return jsonDecode(response.body);
    } catch (_) {
      throw Exception('Invalid response received from the server.');
    }
  }

  String _getErrorMessage(dynamic data) {
    if (data is Map<String, dynamic>) {
      if (data['detail'] != null) {
        return data['detail'].toString();
      }

      return data.entries
          .map((entry) => '${entry.key}: ${entry.value}')
          .join('\n');
    }

    return data.toString();
  }

  Future<List<Order>> getOrders() async {
    final response = await AuthenticatedHttpClient.instance.get(
      Uri.parse(ApiConfig.orders),
      headers: _getHeaders(),
    );

    if (response.statusCode != 200) {
      final data = _decodeResponse(response);
      throw Exception(_getErrorMessage(data));
    }

    final data = _decodeResponse(response);

    if (data is List) {
      return data
          .map((item) => Order.fromJson(
                Map<String, dynamic>.from(item as Map),
              ))
          .toList();
    }

    if (data is Map<String, dynamic> && data['results'] is List) {
      return (data['results'] as List)
          .map((item) => Order.fromJson(
                Map<String, dynamic>.from(item as Map),
              ))
          .toList();
    }

    throw Exception('Unexpected orders response format.');
  }

  Future<Order> getOrderDetails(int orderId) async {
    final response = await AuthenticatedHttpClient.instance.get(
      Uri.parse('${ApiConfig.orders}$orderId/'),
      headers: _getHeaders(),
    );

    final data = _decodeResponse(response);

    if (response.statusCode != 200) {
      throw Exception(_getErrorMessage(data));
    }

    return Order.fromJson(Map<String, dynamic>.from(data as Map));
  }

  // Fetch checkouts assigned to the logged-in delivery user.
  // Use OUT_FOR_DELIVERY for active deliveries and DELIVERED for history.
  Future<List<Map<String, dynamic>>> getMyDeliveries({
    String status = 'OUT_FOR_DELIVERY',
  }) async {
    final uri = Uri.parse(
      '${ApiConfig.orders}checkouts/my-deliveries/',
    ).replace(queryParameters: {'status': status});

    final response = await AuthenticatedHttpClient.instance.get(
      uri,
      headers: _getHeaders(),
    );

    final data = _decodeResponse(response);

    if (response.statusCode != 200) {
      throw Exception(_getErrorMessage(data));
    }

    if (data is Map<String, dynamic> && data['results'] is List) {
      return (data['results'] as List)
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
    }

    throw Exception('Unexpected deliveries response format.');
  }

  // Fetch complete checkout details.
  Future<Map<String, dynamic>> getCheckoutDetails(
    int checkoutId,
  ) async {
    final response = await AuthenticatedHttpClient.instance.get(
      Uri.parse('${ApiConfig.orders}checkouts/$checkoutId/'),
      headers: _getHeaders(),
    );

    final data = _decodeResponse(response);

    if (response.statusCode != 200) {
      throw Exception(_getErrorMessage(data));
    }

    return Map<String, dynamic>.from(data as Map);
  }

  // Assign a delivery person to a checkout.
  Future<void> assignDeliveryPerson(
    int checkoutId,
    int deliveryUserId,
  ) async {
    await _postAction(
      'checkouts/$checkoutId/assign-delivery/',
      body: {
        'delivery_user_id': deliveryUserId,
      },
    );
  }

  // Dispatch checkout or mark it as delivered.
  Future<void> updateCheckoutDeliveryStatus(
    int checkoutId,
    String status, {
    String remarks = '',
  }) async {
    await _postAction(
      'checkouts/$checkoutId/delivery-status/',
      body: {
        'status': status,
        'remarks': remarks,
      },
    );
  }

  Future<void> confirmOrder(int orderId) async {
    await _postAction('$orderId/confirm/');
  }

  Future<void> rejectOrder(int orderId, {String remarks = ''}) async {
    await _postAction(
      '$orderId/reject/',
      body: {'remarks': remarks},
    );
  }

  Future<void> cancelOrder(int orderId, {String remarks = ''}) async {
    await _postAction(
      '$orderId/cancel/',
      body: {'remarks': remarks},
    );
  }

  Future<void> updateOrderStatus(
    int orderId,
    String status, {
    String remarks = '',
  }) async {
    await _postAction(
      '$orderId/status/',
      body: {
        'status': status,
        'remarks': remarks,
      },
    );
  }

  Future<void> _postAction(
    String endpoint, {
    Map<String, dynamic>? body,
  }) async {
    final response = await AuthenticatedHttpClient.instance.post(
      Uri.parse('${ApiConfig.orders}$endpoint'),
      headers: _getHeaders(),
      body: jsonEncode(body ?? {}),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final data = _decodeResponse(response);
      throw Exception(_getErrorMessage(data));
    }
  }
}
