class RestaurantPartnerRequest {
  final int id;
  final int hotel;
  final String hotelName;
  final String hotelContactPerson;
  final String hotelPhone;
  final String hotelEmail;
  final String restaurantName;
  final String restaurantPhone;
  final String fssaiNumber;
  final String description;
  final String status;
  final DateTime? requestedAt;
  final int? reviewedBy;
  final String? reviewedByName;
  final DateTime? reviewedAt;
  final String rejectionReason;

  const RestaurantPartnerRequest({
    required this.id,
    required this.hotel,
    required this.hotelName,
    required this.hotelContactPerson,
    required this.hotelPhone,
    required this.hotelEmail,
    required this.restaurantName,
    required this.restaurantPhone,
    required this.fssaiNumber,
    required this.description,
    required this.status,
    required this.requestedAt,
    required this.reviewedBy,
    required this.reviewedByName,
    required this.reviewedAt,
    required this.rejectionReason,
  });

  factory RestaurantPartnerRequest.fromJson(Map<String, dynamic> json) =>
      RestaurantPartnerRequest(
        id: (json['id'] as num).toInt(),
        hotel: (json['hotel'] as num).toInt(),
        hotelName: json['hotel_name']?.toString() ?? '',
        hotelContactPerson: json['hotel_contact_person']?.toString() ?? '',
        hotelPhone: json['hotel_phone']?.toString() ?? '',
        hotelEmail: json['hotel_email']?.toString() ?? '',
        restaurantName: json['restaurant_name']?.toString() ?? '',
        restaurantPhone: json['restaurant_phone']?.toString() ?? '',
        fssaiNumber: json['fssai_number']?.toString() ?? '',
        description: json['description']?.toString() ?? '',
        status: json['status']?.toString() ?? 'PENDING',
        requestedAt: DateTime.tryParse(json['requested_at']?.toString() ?? ''),
        reviewedBy: json['reviewed_by'] == null
            ? null
            : (json['reviewed_by'] as num).toInt(),
        reviewedByName: json['reviewed_by_name']?.toString(),
        reviewedAt: DateTime.tryParse(json['reviewed_at']?.toString() ?? ''),
        rejectionReason: json['rejection_reason']?.toString() ?? '',
      );
}
