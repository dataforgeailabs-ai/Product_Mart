from rest_framework import serializers
from .models import Hotel, RestaurantPartnerRequest


class HotelSerializer(serializers.ModelSerializer):
    class Meta:
        model = Hotel
        fields = [
            "id",
            "name",
            "contact_person",
            "phone",
            "email",
            "address",
            "city",
            "state",
            "pin_code",
            "gst_number",
            "property_type",
            "hotel_type",
            "status",
            "created_at",
            "updated_at",
        ]
        read_only_fields = [
            "id",
            "status",
            "hotel_type",
            "created_at",
            "updated_at",
        ]


class RestaurantPartnerRequestSerializer(serializers.ModelSerializer):
    hotel_name = serializers.CharField(source="hotel.name", read_only=True)
    hotel_contact_person = serializers.CharField(
        source="hotel.contact_person",
        read_only=True,
    )
    hotel_phone = serializers.CharField(source="hotel.phone", read_only=True)
    hotel_email = serializers.EmailField(source="hotel.email", read_only=True)
    reviewed_by_name = serializers.CharField(
        source="reviewed_by.username",
        read_only=True,
        allow_null=True,
    )

    class Meta:
        model = RestaurantPartnerRequest
        fields = [
            "id",
            "hotel",
            "hotel_name",
            "hotel_contact_person",
            "hotel_phone",
            "hotel_email",
            "restaurant_name",
            "restaurant_phone",
            "fssai_number",
            "description",
            "status",
            "requested_at",
            "reviewed_by",
            "reviewed_by_name",
            "reviewed_at",
            "rejection_reason",
        ]
        read_only_fields = fields
