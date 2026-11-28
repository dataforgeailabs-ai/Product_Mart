from rest_framework import serializers

from .models import FoodCategory, FoodItem
from accounts.models import User


class FoodCategorySerializer(serializers.ModelSerializer):
    subcategories = serializers.SerializerMethodField()

    class Meta:
        model = FoodCategory
        fields = [
            "id",
            "name",
            "description",
            "image",
            "parent_category",
            "subcategories",
            "display_order",
            "is_active",
            "created_at",
            "updated_at",
        ]
        read_only_fields = [
            "id",
            "created_at",
            "updated_at",
        ]

    def get_subcategories(self, obj):
        children = obj.subcategories.filter(is_active=True)

        return FoodCategorySerializer(
            children,
            many=True,
            context=self.context,
        ).data

    def validate_parent_category(self, value):
        if value is None:
            return value

        if not value.is_active:
            if self.instance and value.pk == self.instance.parent_category_id:
                return value
            raise serializers.ValidationError(
                "Cannot assign an inactive parent category."
            )

        if self.instance and value.pk == self.instance.pk:
            raise serializers.ValidationError(
                "A category cannot be its own parent."
            )

        # Walk the proposed parent's ancestors. This prevents arbitrary-depth
        # cycles (including assigning a descendant as this category's parent).
        if self.instance:
            ancestor = value
            seen = set()
            while ancestor is not None:
                if ancestor.pk == self.instance.pk:
                    raise serializers.ValidationError(
                        "A category cannot be assigned beneath one of its descendants."
                    )
                if ancestor.pk in seen:
                    raise serializers.ValidationError(
                        "The selected parent already has a circular relationship."
                    )
                seen.add(ancestor.pk)
                ancestor = ancestor.parent_category

        return value

    def validate_is_active(self, value):
        request = self.context.get("request")
        if request and request.method in ("POST", "PUT", "PATCH"):
            from accounts.models import User
            if request.user.role not in (User.Role.ADMIN, User.Role.SUPERADMIN):
                raise serializers.ValidationError("Only admins can change category status.")
        return value


class FoodItemSerializer(serializers.ModelSerializer):

    hotel_name = serializers.CharField(
        source="hotel.name",
        read_only=True,
    )

    category_name = serializers.CharField(
        source="category.name",
        read_only=True,
    )

    class Meta:
        model = FoodItem
        fields = [
            "id",
            "hotel",
            "hotel_name",
            "category",
            "category_name",
            "name",
            "description",
            "image",
            "price",
            "food_type",
            "preparation_time",
            "serving_size",
            "spice_level",
            "ingredients",
            "allergens",
            "is_available",
            "is_active",
            "created_at",
            "updated_at",
        ]

        read_only_fields = [
            "id",
            "hotel_name",
            "category_name",
            "created_at",
            "updated_at",
        ]

    def get_fields(self):
        fields = super().get_fields()

        request = self.context.get("request")

        # Hotel staff cannot select or change hotel ownership.
        if (
            request
            and request.user.is_authenticated
            and request.user.role == User.Role.HOTEL
        ):
            fields["hotel"].read_only = True

        # Food partners cannot change ownership; admins retain global
        # management and may reassign an item to another hotel.
        if (
            self.instance is not None
            and (
                not request
                or not request.user.is_authenticated
                or request.user.role == User.Role.HOTEL
            )
        ):
            fields["hotel"].read_only = True

        return fields

    def validate_hotel(self, value):
        if value.status != "ACTIVE":
            raise serializers.ValidationError(
                "Cannot add food items to an inactive hotel."
            )

        return value

    def validate_category(self, value):
        if not value.is_active:
            raise serializers.ValidationError(
                "Cannot assign food to an inactive category."
            )

        return value

    def validate_price(self, value):
        if value <= 0:
            raise serializers.ValidationError(
                "Price must be greater than zero."
            )

        return value
