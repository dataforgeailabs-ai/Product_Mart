from rest_framework import serializers
from django.contrib.auth import get_user_model
from hotels.models import Hotel

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
        ]
        read_only_fields = ["id"]

    def create(self, validated_data):
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

        # Create the hotel/resort and user atomically.
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
        ]
        read_only_fields = ["id"]

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
