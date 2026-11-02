import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/cart_item.dart';
import 'cart_service.dart';

class CartSyncService {
  CartSyncService({
    FlutterSecureStorage? storage,
    CartService? cartService,
    http.Client? client,
  })  : _storage = storage ?? const FlutterSecureStorage(),
        _cartService = cartService ?? CartService(),
        _client = client ?? http.Client();

  final FlutterSecureStorage _storage;
  final CartService _cartService;
  final http.Client _client;

  Future<Map<String, String>> _getHeaders() async {
    final accessToken = await _storage.read(key: 'access_token');

    if (accessToken == null || accessToken.isEmpty) {
      throw Exception('Please sign in to synchronize your cart.');
    }

    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $accessToken',
    };
  }

  Future<Map<String, dynamic>> _getServerCart() async {
    final response = await _client.get(
      Uri.parse(ApiConfig.cart),
      headers: await _getHeaders(),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Unable to load your server cart. '
        'HTTP ${response.statusCode}: ${response.body}',
      );
    }

    final decoded = jsonDecode(response.body);

    if (decoded is! Map<String, dynamic>) {
      throw Exception('Unexpected cart response from the server.');
    }

    return decoded;
  }

  Future<void> synchronizeGuestCart() async {
    final List<CartItem> guestItems = await _cartService.getItems();

    if (guestItems.isEmpty) {
      return;
    }

    final headers = await _getHeaders();
    final serverCart = await _getServerCart();
    final serverItems = serverCart['items'];

    if (serverItems is! List) {
      throw Exception('The server returned an invalid cart.');
    }

    final Map<int, Map<String, dynamic>> serverItemsByProductId = {};

    for (final item in serverItems) {
      if (item is! Map) {
        throw Exception('The server returned an invalid cart item.');
      }

      final serverItem = Map<String, dynamic>.from(item);
      final productId = int.tryParse(
        serverItem['product'].toString(),
      );

      if (productId == null) {
        throw Exception('A server cart item has an invalid product ID.');
      }

      serverItemsByProductId[productId] = serverItem;
    }

    final List<String> errors = [];

    for (final guestItem in guestItems) {
      try {
        final serverItem =
            serverItemsByProductId[guestItem.productId];

        if (serverItem == null) {
          final response = await _client.post(
            Uri.parse('${ApiConfig.cart}add/'),
            headers: headers,
            body: jsonEncode({
              'product_id': guestItem.productId,
              'quantity': guestItem.quantity,
            }),
          );

          if (response.statusCode != 200) {
            errors.add(
              '${guestItem.productName}: '
              '${_extractError(response.body)}',
            );
          }

          continue;
        }

        final serverItemId = int.tryParse(
          serverItem['id'].toString(),
        );

        final serverQuantity = int.tryParse(
          serverItem['quantity'].toString(),
        );

        if (serverItemId == null || serverQuantity == null) {
          errors.add(
            '${guestItem.productName}: invalid server cart item.',
          );
          continue;
        }

        // Keep the server quantity unchanged when the product
        // already exists, preventing accidental duplicate additions.
        final response = await _client.patch(
          Uri.parse(
            '${ApiConfig.cart}items/$serverItemId/update/',
          ),
          headers: headers,
          body: jsonEncode({
            'quantity': serverQuantity,
          }),
        );

        if (response.statusCode != 200) {
          errors.add(
            '${guestItem.productName}: '
            '${_extractError(response.body)}',
          );
        }
      } catch (e) {
        errors.add('${guestItem.productName}: $e');
      }
    }

    if (errors.isNotEmpty) {
      throw Exception(
        'Some guest cart items could not be synchronized:\n'
        '${errors.join('\n')}',
      );
    }

    await _cartService.clearCart();
  }

  String _extractError(String body) {
    try {
      final decoded = jsonDecode(body);

      if (decoded is Map<String, dynamic>) {
        return (decoded['detail'] ??
                decoded['message'] ??
                decoded.toString())
            .toString();
      }
    } catch (_) {
      // Use the response body when it is not JSON.
    }

    return body.isEmpty ? 'Request failed.' : body;
  }
}