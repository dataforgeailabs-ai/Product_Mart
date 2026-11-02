import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';

class HotelService {
  final FlutterSecureStorage _storage =
      const FlutterSecureStorage();

  Future<Map<String, String>> _getHeaders() async {
    final token = await _storage.read(key: 'access_token');

    if (token == null || token.isEmpty) {
      throw Exception('Authentication required. Please log in again.');
    }

    return {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };
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

  List<dynamic> _extractList(dynamic data) {
    if (data is List) return data;

    if (data is Map && data['results'] is List) {
      return data['results'];
    }

    throw Exception('Invalid hotel API response.');
  }

  Future<List<Map<String, dynamic>>> getHotels() async {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/hotels/'),
      headers: await _getHeaders(),
    );

    _checkResponse(response);

    return _extractList(_decodeResponse(response))
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Future<Map<String, dynamic>> getHotelDetails(
    int hotelId,
  ) async {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/hotels/$hotelId/'),
      headers: await _getHeaders(),
    );

    _checkResponse(response);

    return Map<String, dynamic>.from(
      _decodeResponse(response),
    );
  }

  Future<void> updateHotelStatus({
    required int hotelId,
    required String status,
  }) async {
    final response = await http.patch(
      Uri.parse('${ApiConfig.baseUrl}/hotels/$hotelId/status/'),
      headers: await _getHeaders(),
      body: jsonEncode({
        'status': status,
      }),
    );

    _checkResponse(response);
  }
}