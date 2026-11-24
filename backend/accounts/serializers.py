from rest_framework import serializers
from django.contrib.auth import get_user_model
from hotels.models import Hotel, RestaurantPartnerRequest

User = get_user_model()


class UserRegistrationSerializer(serializers.ModelSerializer):
    password = serializers.CharField(
        write_only=True,
        min_length=8,
        style={"input_type": "password"},
    )

    # Hotel/resort details
    hotel_name = serializers.CharField(max_length=200, write_only=True)
    contact_person = serializers.CharField(max_length=150, write_only=True)
    hotel_phone = serializers.CharField(max_length=15, write_only=True)
    hotel_email = serializers.EmailField(max_length=191, write_only=True)
    address = serializers.CharField(write_only=True)
    city = serializers.CharField(max_length=100, write_only=True)
    state = serializers.CharField(max_length=100, write_only=True)
    pin_code = serializers.CharField(max_length=10, write_only=True)
    gst_number = serializers.CharField(
        max_length=20,
        required=False,
        allow_blank=True,
        write_only=True,
    )
    property_type = serializers.CharField(max_length=100, write_only=True)
    partnership_requested = serializers.BooleanField(
        required=False,
        default=False,
        write_only=True,
    )
    restaurant_name = serializers.CharField(
        max_length=200,
        required=False,
        allow_blank=True,
        write_only=True,
    )
    restaurant_phone = serializers.CharField(
        max_length=15,
        required=False,
        allow_blank=True,
        write_only=True,
    )
    fssai_number = serializers.CharField(
        max_length=50,
        required=False,
        allow_blank=True,
        write_only=True,
    )
    restaurant_description = serializers.CharField(
        required=False,
        allow_blank=True,
        write_only=True,
    )

    class Meta:
        model = User
        fields = [
            "id",
            "username",
            "email",
            "phone",
            "password",
            "hotel_name",
            "contact_person",
            "hotel_phone",
            "hotel_email",
            "address",
            "city",
            "state",
            "pin_code",
            "gst_number",
            "property_type",
            "partnership_requested",
            "restaurant_name",
            "restaurant_phone",
            "fssai_number",
            "restaurant_description",
        ]
        read_only_fields = ["id"]

    def validate(self, attrs):
        # Registration is always a customer hotel. Classification changes
        # are deliberately restricted to the protected hotel-management API.
        if self.initial_data.get("hotel_type") == Hotel.HotelType.FOOD_PARTNER:
            raise serializers.ValidationError(
                {"hotel_type": "Food partners must be created by an admin."}
            )
        if attrs.get("partnership_requested", False):
            required_fields = {
                "restaurant_phone": "Restaurant contact number is required.",
                "fssai_number": "FSSAI licence number is required.",
                "restaurant_description": "Restaurant description is required.",
            }
            errors = {
                field: message
                for field, message in required_fields.items()
                if not attrs.get(field, "").strip()
            }
            if errors:
                raise serializers.ValidationError(errors)
        return attrs

    def create(self, validated_data):
        partnership_requested = validated_data.pop(
            "partnership_requested",
            False,
        )
        restaurant_request_data = {
            "restaurant_name": validated_data.pop("restaurant_name", ""),
            "restaurant_phone": validated_data.pop("restaurant_phone", ""),
            "fssai_number": validated_data.pop("fssai_number", ""),
            "description": validated_data.pop("restaurant_description", ""),
        }
        # Extract hotel details before creating the user.
        hotel_data = {
            "name": validated_data.pop("hotel_name"),
            "contact_person": validated_data.pop("contact_person"),
            "phone": validated_data.pop("hotel_phone"),
            "email": validated_data.pop("hotel_email"),
            "address": validated_data.pop("address"),
            "city": validated_data.pop("city"),
            "state": validated_data.pop("state"),
            "pin_code": validated_data.pop("pin_code"),
            "gst_number": validated_data.pop("gst_number", ""),
            "property_type": validated_data.pop("property_type"),
        }

        password = validated_data.pop("password")

        # Create the hotel and customer atomically.
        from django.db import transaction

        with transaction.atomic():
            hotel = Hotel.objects.create(**hotel_data)

            user = User(**validated_data)
            user.set_password(password)
            user.role = User.Role.HOTEL
            user.is_staff = False
            user.is_superuser = False
            user.hotel = hotel
            user.save()

            if partnership_requested:
                RestaurantPartnerRequest.objects.create(
                    hotel=hotel,
                    **restaurant_request_data,
                )

        return user


class UserProfileSerializer(serializers.ModelSerializer):
    class Meta:
        model = User
        fields = [
            "id",
            "username",
            "email",
            "phone",
            "role",
            "is_active",
        ]
        read_only_fields = [
            "id",
            "username",
            "role",
            "is_active",
        ]


class HotelDetailsSerializer(serializers.ModelSerializer):
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
        ]
        read_only_fields = ["id", "hotel_type"]


class ManagedUserSerializer(serializers.ModelSerializer):
    password = serializers.CharField(
        write_only=True,
        min_length=8,
        required=False,
        style={"input_type": "password"},
    )

    class Meta:
        model = User
        fields = [
            "id",
            "username",
            "email",
            "phone",
            "password",
            "role",
            "is_active",
        ]
        read_only_fields = ["id", "is_active"]

    def validate_role(self, value):
        request = self.context.get("request")

        if value not in [User.Role.ADMIN, User.Role.DELIVERY]:
            raise serializers.ValidationError(
                "Only Admin and Delivery accounts can be managed here."
            )

        if request.user.role == User.Role.ADMIN:
            if value != User.Role.DELIVERY:
                raise serializers.ValidationError(
                    "Admins can only manage Delivery accounts."
                )

        return value

    def create(self, validated_data):
        password = validated_data.pop("password", None)

        if not password:
            raise serializers.ValidationError({
                "password": "Password is required when creating a user."
            })

        user = User(**validated_data)
        user.set_password(password)
        user.is_staff = False
        user.is_superuser = False
        user.hotel = None
        user.save()

        return user

    def update(self, instance, validated_data):
        password = validated_data.pop("password", None)

        for attribute, value in validated_data.items():
            setattr(instance, attribute, value)

        if password:
            instance.set_password(password)

        instance.is_staff = False
        instance.is_superuser = False
        instance.hotel = None
        instance.save()

        return instance

    def get_fields(self):
        fields = super().get_fields()

        # Role can be selected during creation,
        # but cannot be changed during updates.
        if self.instance is not None:
            fields["role"].read_only = True

        return fields
