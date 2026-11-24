import 'dart:convert';

import 'package:http/http.dart' as http;
import '../models/managed_user.dart';
import '../config/api_config.dart';
import 'authenticated_http_client.dart';

class UserService {
  Map<String, String> _getHeaders() =>
      const {'Content-Type': 'application/json'};

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

      if (data['error'] != null) {
        return data['error'].toString();
      }

      final messages = <String>[];

      data.forEach((key, value) {
        messages.add(
          '$key: ${value is List ? value.join(', ') : value}',
        );
      });

      return messages.join('\n');
    }

    if (data is String && data.isNotEmpty) {
      return data;
    }

    return 'Something went wrong. Please try again.';
  }

  void _checkResponse(http.Response response) {
    if (response.statusCode < 200 ||
        response.statusCode >= 300) {
      throw Exception(
        _getErrorMessage(_decodeResponse(response)),
      );
    }
  }

  // Get logged-in user details and role.
  Future<Map<String, dynamic>> getCurrentUser() async {
    final response = await AuthenticatedHttpClient.instance.get(
      Uri.parse(ApiConfig.currentUser),
      headers: _getHeaders(),
    );

    _checkResponse(response);

    return Map<String, dynamic>.from(
      _decodeResponse(response),
    );
  }

  // Get all users accessible to the logged-in administrator.
  Future<List<Map<String, dynamic>>> getUsers() async {
    final response = await AuthenticatedHttpClient.instance.get(
      Uri.parse(ApiConfig.manageUsers),
      headers: _getHeaders(),
    );

    _checkResponse(response);

    final data = _decodeResponse(response);

    List<dynamic> results;

    if (data is List) {
      results = data;
    } else if (data is Map && data['results'] is List) {
      results = data['results'];
    } else {
      throw Exception('Invalid user API response.');
    }

    return results
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  // Create an Admin or Delivery account.
  Future<Map<String, dynamic>> createUser({
    required String username,
    required String email,
    required String phone,
    required String password,
    required String role,
  }) async {
    final response = await AuthenticatedHttpClient.instance.post(
      Uri.parse(ApiConfig.manageUsers),
      headers: _getHeaders(),
      body: jsonEncode({
        'username': username,
        'email': email,
        'phone': phone,
        'password': password,
        'role': role,
      }),
    );

    _checkResponse(response);

    return Map<String, dynamic>.from(
      _decodeResponse(response),
    );
  }

  // Update an existing user's details.
  Future<Map<String, dynamic>> updateUser({
    required int userId,
    required String username,
    required String email,
    required String phone,
    String? password,
  }) async {
    final body = <String, dynamic>{
      'username': username,
      'email': email,
      'phone': phone,
    };

    if (password != null && password.isNotEmpty) {
      body['password'] = password;
    }

    final response = await AuthenticatedHttpClient.instance.patch(
      Uri.parse('${ApiConfig.manageUsers}$userId/'),
      headers: _getHeaders(),
      body: jsonEncode(body),
    );

    _checkResponse(response);

    return Map<String, dynamic>.from(
      _decodeResponse(response),
    );
  }

  // Deactivate a user account.
  Future<Map<String, dynamic>> deactivateUser(
    int userId,
  ) async {
    final response = await AuthenticatedHttpClient.instance.patch(
      Uri.parse(
        '${ApiConfig.manageUsers}$userId/deactivate/',
      ),
      headers: _getHeaders(),
    );

    _checkResponse(response);

    return Map<String, dynamic>.from(
      _decodeResponse(response),
    );
  }

    // Get active delivery personnel only.
  Future<List<ManagedUser>> getDeliveryUsers() async {
    final users = await getUsers();

    return users
        .map((user) => ManagedUser.fromJson(user))
        .where(
          (user) => user.role == 'DELIVERY' && user.isActive,
        )
        .toList();
  }
}
