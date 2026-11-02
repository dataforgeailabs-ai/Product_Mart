from rest_framework import serializers
from .models import Order, OrderItem, OrderStatusHistory, Payment
from django.db import models

class OrderItemSerializer(serializers.ModelSerializer):
    product_name = serializers.CharField(
        source="product.name",
        read_only=True,
    )

    product_image = serializers.ImageField(
    source="product.image",
    read_only=True,
)

    class Meta:
        model = OrderItem
        fields = [
            "id",
            "product",
            "product_name",
            "product_image",
            "quantity",
            "unit_price",
            "line_total",
        ]
        read_only_fields = [
            "id",
            "unit_price",
            "line_total",
        ]


class OrderStatusHistorySerializer(serializers.ModelSerializer):
    changed_by_username = serializers.CharField(
        source="changed_by.username",
        read_only=True,
    )

    class Meta:
        model = OrderStatusHistory
        fields = [
            "id",
            "status",
            "changed_by",
            "changed_by_username",
            "remarks",
            "changed_at",
        ]
        read_only_fields = fields


class PaymentSerializer(serializers.ModelSerializer):
    class Meta:
        model = Payment
        fields = [
            "id",
            "method",
            "link_id",
            "payment_id",
            "amount",
            "status",
            "received_by",
            "received_at",
            "confirmed_by",
            "paid_at",
            "created_at",
        ]
        read_only_fields = fields


class OrderSerializer(serializers.ModelSerializer):
    items = OrderItemSerializer(many=True, read_only=True)
    status_history = OrderStatusHistorySerializer(
        many=True,
        read_only=True,
    )
    payments = PaymentSerializer(many=True, read_only=True)
    hotel_name = serializers.CharField(
        source="hotel.name",
        read_only=True,
    )
    placed_by_username = serializers.CharField(
        source="placed_by.username",
        read_only=True,
    )

    class Meta:
        model = Order
        fields = [
            "id",
            "order_no",
            "hotel",
            "hotel_name",
            "placed_by",
            "placed_by_username",
            "items",
            "subtotal",
            "tax",
            "delivery_charge",
            "total",
            "status",
            "payment_status",
            "status_history",
            "payments",
            "notes",
            "created_at",
            "updated_at",
        ]
        read_only_fields = [
            "id",
            "order_no",
            "hotel",
            "placed_by",
            "subtotal",
            "tax",
            "delivery_charge",
            "total",
            "status",
            "payment_status",
            "items",
            "status_history",
            "payments",
            "created_at",
            "updated_at",
        ]


class CheckoutSerializer(serializers.Serializer):
    class PaymentMethod(models.TextChoices):
        UPI = "UPI", "UPI"
        COD = "COD", "Cash on Delivery"

    payment_method = serializers.ChoiceField(
        choices=PaymentMethod.choices
    )

    notes = serializers.CharField(
        required=False,
        allow_blank=True,
        default="",
    )