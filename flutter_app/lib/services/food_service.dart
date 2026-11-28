import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/food_category.dart';
import '../models/food_item.dart';
import 'authenticated_http_client.dart';

class FoodService {
  Map<String, String> _headers({bool json = false}) => {
        if (json) 'Content-Type': 'application/json',
      };

  dynamic _decode(http.Response response) {
    if (response.body.isEmpty) return null;
    try {
      return jsonDecode(response.body);
    } catch (_) {
      return response.body;
    }
  }

  String _message(dynamic data) {
    if (data is Map) {
      if (data['detail'] != null) return data['detail'].toString();
      if (data['error'] != null) return data['error'].toString();
      return data.entries
          .map((entry) {
            final value = entry.value;
            return '${entry.key}: ${value is List ? value.join(', ') : value}';
          })
          .join('\n');
    }
    if (data is String && data.isNotEmpty) return data;
    return 'Something went wrong. Please try again.';
  }

  void _check(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(_message(_decode(response)));
    }
  }

  List<dynamic> _list(dynamic data) {
    if (data is List) return data;
    if (data is Map && data['results'] is List) return data['results'];
    throw Exception('Invalid food API response format.');
  }

  Future<List<FoodItem>> getFoodItems() async {
    final response = await AuthenticatedHttpClient.instance.get(
      Uri.parse(ApiConfig.foodManagementItems),
      headers: _headers(),
    );
    _check(response);
    return _list(_decode(response))
        .map(
          (item) => FoodItem.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList();
  }

  Future<List<FoodItem>> getPublicFoodItems() async {
    final response = await http.get(Uri.parse(ApiConfig.foodItems));
    _check(response);
    return _list(_decode(response))
        .map(
          (item) => FoodItem.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .where((item) => item.isActive && item.isAvailable)
        .toList();
  }

  Future<FoodItem> getFoodItem(int id) async {
    final response = await AuthenticatedHttpClient.instance.get(
      Uri.parse('${ApiConfig.foodManagementItems}$id/'),
      headers: _headers(),
    );
    _check(response);
    return FoodItem.fromJson(
      Map<String, dynamic>.from(_decode(response) as Map),
    );
  }

  Future<List<FoodCategory>> getFoodCategories() async {
    final response = await http.get(Uri.parse(ApiConfig.foodCategories));
    return _parseFoodCategories(response);
  }

  Future<List<FoodCategory>> getManagedFoodCategories() async {
    final response = await AuthenticatedHttpClient.instance.get(
      Uri.parse(ApiConfig.foodCategories),
      headers: _headers(),
    );
    _check(response);
    return _parseFoodCategories(response);
  }

  List<FoodCategory> _parseFoodCategories(http.Response response) {
    _check(response);
    return _list(_decode(response))
        .map(
          (item) =>
              FoodCategory.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList();
  }

  Future<FoodCategory> getFoodCategory(int id) async {
    final response = await AuthenticatedHttpClient.instance.get(
      Uri.parse('${ApiConfig.foodCategories}$id/'),
      headers: _headers(),
    );
    _check(response);
    return FoodCategory.fromJson(
      Map<String, dynamic>.from(_decode(response) as Map),
    );
  }

  Future<FoodCategory> createFoodCategory({
    required Map<String, dynamic> fields,
    File? image,
  }) => _saveCategory(
    uri: Uri.parse(ApiConfig.foodCategories),
    method: 'POST',
    fields: fields,
    image: image,
  );

  Future<FoodCategory> updateFoodCategory({
    required int id,
    required Map<String, dynamic> fields,
    File? image,
  }) => _saveCategory(
    uri: Uri.parse('${ApiConfig.foodCategories}$id/'),
    method: 'PATCH',
    fields: fields,
    image: image,
  );

  Future<FoodCategory> setFoodCategoryActive(int id, bool active) async {
    final response = await AuthenticatedHttpClient.instance.post(
      Uri.parse('${ApiConfig.foodCategories}$id/${active ? 'activate' : 'deactivate'}/'),
      headers: _headers(),
    );
    _check(response);
    return FoodCategory.fromJson(Map<String, dynamic>.from(_decode(response) as Map));
  }

  Future<FoodCategory> _saveCategory({
    required Uri uri,
    required String method,
    required Map<String, dynamic> fields,
    File? image,
  }) async => FoodCategory.fromJson(
    Map<String, dynamic>.from(
      await _write(
        uri: uri,
        method: method,
        fields: fields,
        image: image,
        encodeNullMultipartFieldsAsEmpty: true,
      ) as Map,
    ),
  );

  Future<FoodItem> createFoodItem({
    required Map<String, dynamic> fields,
    File? image,
  }) => _save(
    uri: Uri.parse(ApiConfig.foodItems),
    method: 'POST',
    fields: fields,
    image: image,
  );

  Future<FoodItem> updateFoodItem({
    required int id,
    required Map<String, dynamic> fields,
    File? image,
  }) => _save(
    uri: Uri.parse('${ApiConfig.foodItems}$id/'),
    method: 'PATCH',
    fields: fields,
    image: image,
  );

  Future<FoodItem> _save({
    required Uri uri,
    required String method,
    required Map<String, dynamic> fields,
    File? image,
  }) async => FoodItem.fromJson(
    Map<String, dynamic>.from(
      await _write(
        uri: uri,
        method: method,
        fields: fields,
        image: image,
      ) as Map,
    ),
  );

  Future<dynamic> _write({
    required Uri uri,
    required String method,
    required Map<String, dynamic> fields,
    File? image,
    bool encodeNullMultipartFieldsAsEmpty = false,
  }) async {
    if (image == null) {
      final request = http.Request(method, uri)
        ..headers.addAll(_headers(json: true))
        ..body = jsonEncode(fields);
      final streamed = await AuthenticatedHttpClient.instance.send(request);
      final response = await http.Response.fromStream(streamed);
      _check(response);
      return _decode(response);
    }

    final request = http.MultipartRequest(method, uri)
      ..headers.addAll(_headers());
    fields.forEach((key, value) {
      if (value != null || encodeNullMultipartFieldsAsEmpty) {
        request.fields[key] = value?.toString() ?? '';
      }
    });
    request.files.add(await http.MultipartFile.fromPath('image', image.path));
    final streamed = await AuthenticatedHttpClient.instance.send(request);
    final response = await http.Response.fromStream(streamed);
    _check(response);
    return _decode(response);
  }

  Future<FoodItem> setAvailability(int id, bool isAvailable) async {
    final response = await AuthenticatedHttpClient.instance.patch(
      Uri.parse('${ApiConfig.foodItems}$id/'),
      headers: _headers(json: true),
      body: jsonEncode({'is_available': isAvailable}),
    );
    _check(response);
    return FoodItem.fromJson(
      Map<String, dynamic>.from(_decode(response) as Map),
    );
  }

  Future<void> deactivateFoodItem(int id) async {
    final response = await AuthenticatedHttpClient.instance.delete(
      Uri.parse('${ApiConfig.foodItems}$id/'),
      headers: _headers(),
    );
    _check(response);
  }
}
