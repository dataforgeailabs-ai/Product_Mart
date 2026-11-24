import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/restaurant_partner_request.dart';
import 'authenticated_http_client.dart';

class RestaurantPartnershipService {
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
          .map((entry) => '${entry.key}: ${entry.value}')
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
    throw Exception('Invalid restaurant partnership response.');
  }

  Future<List<RestaurantPartnerRequest>> getRequests() async {
    final response = await AuthenticatedHttpClient.instance.get(
      Uri.parse(ApiConfig.restaurantPartnerRequests),
      headers: _headers(),
    );
    _check(response);
    return _list(_decode(response))
        .map(
          (item) => RestaurantPartnerRequest.fromJson(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .toList();
  }

  Future<RestaurantPartnerRequest> getRequest(int id) async {
    final response = await AuthenticatedHttpClient.instance.get(
      Uri.parse('${ApiConfig.restaurantPartnerRequests}$id/'),
      headers: _headers(),
    );
    _check(response);
    return RestaurantPartnerRequest.fromJson(
      Map<String, dynamic>.from(_decode(response) as Map),
    );
  }

  Future<RestaurantPartnerRequest> approve(int id) => _review(
        id,
        'approve/',
        const {},
      );

  Future<RestaurantPartnerRequest> reject(
    int id,
    String rejectionReason,
  ) =>
      _review(id, 'reject/', {'rejection_reason': rejectionReason});

  Future<RestaurantPartnerRequest> _review(
    int id,
    String action,
    Map<String, dynamic> payload,
  ) async {
    final response = await AuthenticatedHttpClient.instance.post(
      Uri.parse('${ApiConfig.restaurantPartnerRequests}$id/$action'),
      headers: _headers(json: true),
      body: jsonEncode(payload),
    );
    _check(response);
    return RestaurantPartnerRequest.fromJson(
      Map<String, dynamic>.from(_decode(response) as Map),
    );
  }
}
