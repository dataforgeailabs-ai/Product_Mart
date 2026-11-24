from rest_framework import serializers

from .models import Cart, CartItem


class CartItemSerializer(serializers.ModelSerializer):
    product_name = serializers.CharField(
        source="product.name",
        read_only=True,
        allow_null=True,
    )

    product_price = serializers.DecimalField(
        source="product.price",
        max_digits=10,
        decimal_places=2,
        read_only=True,
        allow_null=True,
    )

    product_sku = serializers.CharField(
        source="product.sku",
        read_only=True,
        allow_null=True,
    )

    product_image = serializers.ImageField(
        source="product.image",
        read_only=True,
        allow_null=True,
    )

    food_name = serializers.CharField(
        source="food_item.name",
        read_only=True,
        allow_null=True,
    )

    food_price = serializers.DecimalField(
        source="food_item.price",
        max_digits=10,
        decimal_places=2,
        read_only=True,
        allow_null=True,
    )

    food_image = serializers.ImageField(
        source="food_item.image",
        read_only=True,
        allow_null=True,
    )

    line_total = serializers.SerializerMethodField()

    class Meta:
        model = CartItem
        fields = [
            "id",
            "item_type",
            "product",
            "product_name",
            "product_sku",
            "product_price",
            "product_image",
            "food_item",
            "food_name",
            "food_price",
            "food_image",
            "quantity",
            "line_total",
        ]

        read_only_fields = fields

    def get_line_total(self, obj):
        if obj.item_type == "PRODUCT":
            return obj.product.price * obj.quantity

        if obj.item_type == "FOOD":
            return obj.food_item.price * obj.quantity

        return 0


class CartSerializer(serializers.ModelSerializer):
    items = CartItemSerializer(many=True, read_only=True)
    total_items = serializers.SerializerMethodField()
    cart_total = serializers.SerializerMethodField()

    class Meta:
        model = Cart
        fields = [
            "id",
            "items",
            "total_items",
            "cart_total",
            "created_at",
            "updated_at",
        ]

    def get_total_items(self, obj):
        return sum(item.quantity for item in obj.items.all())

    def get_cart_total(self, obj):
        total = 0

        for item in obj.items.all():
            if item.item_type == "PRODUCT":
                total += item.product.price * item.quantity

            elif item.item_type == "FOOD":
                total += item.food_item.price * item.quantity

        return total