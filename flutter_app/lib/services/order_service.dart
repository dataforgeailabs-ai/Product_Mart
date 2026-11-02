import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/order.dart';

class OrderService {
  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  Future<Map<String, String>> _getHeaders() async {
    final accessToken = await _storage.read(key: 'access_token');

    if (accessToken == null || accessToken.isEmpty) {
      throw Exception('Authentication required. Please sign in again.');
    }

    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $accessToken',
    };
  }

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
    final response = await http.get(
      Uri.parse(ApiConfig.orders),
      headers: await _getHeaders(),
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

    // Supports Django REST Framework paginated responses.
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
    final response = await http.get(
      Uri.parse('${ApiConfig.orders}$orderId/'),
      headers: await _getHeaders(),
    );

    final data = _decodeResponse(response);

    if (response.statusCode != 200) {
      throw Exception(_getErrorMessage(data));
    }

    return Order.fromJson(Map<String, dynamic>.from(data as Map));
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
    final response = await http.post(
      Uri.parse('${ApiConfig.orders}$endpoint'),
      headers: await _getHeaders(),
      body: jsonEncode(body ?? {}),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final data = _decodeResponse(response);
      throw Exception(_getErrorMessage(data));
    }
  }
}