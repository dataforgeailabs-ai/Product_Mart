import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/product.dart';

class ProductService {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  Future<Map<String, String>> _getHeaders({
    bool authenticated = true,
  }) async {
    final headers = <String, String>{};

    if (authenticated) {
      final token = await _storage.read(key: 'access_token');

      if (token == null || token.isEmpty) {
        throw Exception('Authentication required. Please log in again.');
      }

      headers['Authorization'] = 'Bearer $token';
    }

    return headers;
  }

  dynamic _decodeResponse(http.Response response) {
    if (response.body.isEmpty) return null;

    try {
      return jsonDecode(response.body);
    } catch (_) {
      return response.body;
    }
  }

  String _getErrorMessage(dynamic data) {
    if (data is Map) {
      if (data['detail'] != null) {
        return data['detail'].toString();
      }

      final messages = <String>[];

      data.forEach((key, value) {
        messages.add('$key: ${value is List ? value.join(', ') : value}');
      });

      return messages.join('\n');
    }

    if (data is String && data.isNotEmpty) {
      return data;
    }

    return 'Something went wrong. Please try again.';
  }

  void _checkResponse(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final data = _decodeResponse(response);
      throw Exception(_getErrorMessage(data));
    }
  }

  List<dynamic> _extractList(dynamic data) {
    if (data is List) return data;

    if (data is Map && data['results'] is List) {
      return data['results'];
    }

    throw Exception('Invalid API response format.');
  }

  Future<List<Product>> getProducts() async {
    final response = await http.get(
      Uri.parse(ApiConfig.products),
      headers: await _getHeaders(authenticated: false),
    );

    _checkResponse(response);

    final data = _decodeResponse(response);

    return _extractList(data)
        .map((item) => Product.fromJson(
              Map<String, dynamic>.from(item),
            ))
        .toList();
  }

  Future<Product> getProductDetails(int productId) async {
    final response = await http.get(
      Uri.parse('${ApiConfig.products}$productId/'),
      headers: await _getHeaders(authenticated: false),
    );

    _checkResponse(response);

    return Product.fromJson(
      Map<String, dynamic>.from(_decodeResponse(response)),
    );
  }

  Future<List<Map<String, dynamic>>> getCategories() async {
    final response = await http.get(
      Uri.parse(ApiConfig.categories),
      headers: await _getHeaders(authenticated: false),
    );

    _checkResponse(response);

    final data = _decodeResponse(response);

    return _extractList(data)
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }


Future<Map<String, dynamic>> createCategory({
  required String name,
  required String description,
}) async {
  final response = await http.post(
    Uri.parse('${ApiConfig.categories}create/'),
    headers: {
      ...await _getHeaders(),
      'Content-Type': 'application/json',
    },
    body: jsonEncode({
      'name': name,
      'description': description,
      'is_active': true,
    }),
  );

  _checkResponse(response);

  return Map<String, dynamic>.from(_decodeResponse(response));
}

Future<Map<String, dynamic>> updateCategory({
  required int categoryId,
  required String name,
  required String description,
}) async {
  final response = await http.patch(
    Uri.parse('${ApiConfig.categories}update/$categoryId/'),
    headers: {
      ...await _getHeaders(),
      'Content-Type': 'application/json',
    },
    body: jsonEncode({
      'name': name,
      'description': description,
    }),
  );

  _checkResponse(response);

  return Map<String, dynamic>.from(_decodeResponse(response));
}

Future<void> deleteCategory(int categoryId) async {
  final response = await http.delete(
    Uri.parse('${ApiConfig.categories}delete/$categoryId/'),
    headers: await _getHeaders(),
  );

  _checkResponse(response);
}

  Future<Product> createProduct({
    required int category,
    required String name,
    required String description,
    required String sku,
    required double price,
    required int stockQuantity,
    required int minimumOrderQuantity,
    required int minimumStockLevel,
    required String unit,
    File? image,
  }) async {
    final uri = Uri.parse('${ApiConfig.products}create/');

    if (image == null) {
      final response = await http.post(
        uri,
        headers: {
          ...await _getHeaders(),
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'category': category,
          'name': name,
          'description': description,
          'sku': sku,
          'price': price.toStringAsFixed(2),
          'stock_quantity': stockQuantity,
          'minimum_order_quantity': minimumOrderQuantity,
          'minimum_stock_level': minimumStockLevel,
          'unit': unit,
          'is_active': true,
        }),
      );

      _checkResponse(response);

      return Product.fromJson(
        Map<String, dynamic>.from(_decodeResponse(response)),
      );
    }

    final request = http.MultipartRequest('POST', uri);

    request.headers.addAll(await _getHeaders());

    request.fields.addAll({
      'category': category.toString(),
      'name': name,
      'description': description,
      'sku': sku,
      'price': price.toStringAsFixed(2),
      'stock_quantity': stockQuantity.toString(),
      'minimum_order_quantity': minimumOrderQuantity.toString(),
      'minimum_stock_level': minimumStockLevel.toString(),
      'unit': unit,
      'is_active': 'true',
    });

    request.files.add(
      await http.MultipartFile.fromPath('image', image.path),
    );

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    _checkResponse(response);

    return Product.fromJson(
      Map<String, dynamic>.from(_decodeResponse(response)),
    );
  }

  Future<Product> updateProduct({
    required int productId,
    required int category,
    required String name,
    required String description,
    required String sku,
    required double price,
    required int stockQuantity,
    required int minimumOrderQuantity,
    required int minimumStockLevel,
    required String unit,
    File? image,
  }) async {
    final uri = Uri.parse('${ApiConfig.products}update/$productId/');

    final fields = {
      'category': category.toString(),
      'name': name,
      'description': description,
      'sku': sku,
      'price': price.toStringAsFixed(2),
      'stock_quantity': stockQuantity.toString(),
      'minimum_order_quantity': minimumOrderQuantity.toString(),
      'minimum_stock_level': minimumStockLevel.toString(),
      'unit': unit,
    };

    if (image == null) {
      final response = await http.patch(
        uri,
        headers: {
          ...await _getHeaders(),
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'category': category,
          'name': name,
          'description': description,
          'sku': sku,
          'price': price.toStringAsFixed(2),
          'stock_quantity': stockQuantity,
          'minimum_order_quantity': minimumOrderQuantity,
          'minimum_stock_level': minimumStockLevel,
          'unit': unit,
        }),
      );

      _checkResponse(response);

      return Product.fromJson(
        Map<String, dynamic>.from(_decodeResponse(response)),
      );
    }

    final request = http.MultipartRequest('PATCH', uri);

    request.headers.addAll(await _getHeaders());
    request.fields.addAll(fields);

    request.files.add(
      await http.MultipartFile.fromPath('image', image.path),
    );

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    _checkResponse(response);

    return Product.fromJson(
      Map<String, dynamic>.from(_decodeResponse(response)),
    );
  }

  Future<void> deleteProduct(int productId) async {
    final response = await http.delete(
      Uri.parse('${ApiConfig.products}delete/$productId/'),
      headers: await _getHeaders(),
    );

    _checkResponse(response);
  }
}