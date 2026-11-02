class Order {
  final int id;
  final String orderNo;
  final int hotel;
  final String hotelName;
  final int placedBy;
  final String placedByUsername;
  final List<Map<String, dynamic>> items;
  final double subtotal;
  final double tax;
  final double deliveryCharge;
  final double total;
  final String status;
  final String paymentStatus;
  final List<Map<String, dynamic>> statusHistory;
  final List<Map<String, dynamic>> payments;
  final String notes;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Order({
    required this.id,
    required this.orderNo,
    required this.hotel,
    required this.hotelName,
    required this.placedBy,
    required this.placedByUsername,
    required this.items,
    required this.subtotal,
    required this.tax,
    required this.deliveryCharge,
    required this.total,
    required this.status,
    required this.paymentStatus,
    required this.statusHistory,
    required this.payments,
    required this.notes,
    this.createdAt,
    this.updatedAt,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    return Order(
      id: int.tryParse(json['id'].toString()) ?? 0,
      orderNo: json['order_no']?.toString() ?? '',
      hotel: int.tryParse(json['hotel'].toString()) ?? 0,
      hotelName: json['hotel_name']?.toString() ?? '',
      placedBy: int.tryParse(json['placed_by'].toString()) ?? 0,
      placedByUsername:
          json['placed_by_username']?.toString() ?? '',
      items: (json['items'] as List<dynamic>? ?? [])
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList(),
      subtotal: _toDouble(json['subtotal']),
      tax: _toDouble(json['tax']),
      deliveryCharge: _toDouble(json['delivery_charge']),
      total: _toDouble(json['total']),
      status: json['status']?.toString() ?? '',
      paymentStatus: json['payment_status']?.toString() ?? '',
      statusHistory:
          (json['status_history'] as List<dynamic>? ?? [])
              .map((item) => Map<String, dynamic>.from(item as Map))
              .toList(),
      payments: (json['payments'] as List<dynamic>? ?? [])
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList(),
      notes: json['notes']?.toString() ?? '',
      createdAt: DateTime.tryParse(
        json['created_at']?.toString() ?? '',
      ),
      updatedAt: DateTime.tryParse(
        json['updated_at']?.toString() ?? '',
      ),
    );
  }

  static double _toDouble(dynamic value) {
    return double.tryParse(value?.toString() ?? '') ?? 0.0;
  }
}