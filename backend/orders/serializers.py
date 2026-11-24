from rest_framework import serializers

from .models import (
    Checkout,
    Order,
    OrderItem,
    OrderStatusHistory,
    Payment,
    RefundRequest,
)


class OrderItemSerializer(serializers.ModelSerializer):
    product_name = serializers.SerializerMethodField()
    product_image = serializers.SerializerMethodField()

    food_item_name = serializers.SerializerMethodField()
    food_item_image = serializers.SerializerMethodField()

    class Meta:
        model = OrderItem
        fields = [
            "id",
            "product",
            "product_name",
            "product_image",
            "food_item",
            "food_item_name",
            "food_item_image",
            "quantity",
            "unit_price",
            "line_total",
        ]
        read_only_fields = [
            "id",
            "unit_price",
            "line_total",
        ]

    def get_product_name(self, obj):
        return obj.product.name if obj.product else None

    def get_product_image(self, obj):
        if not obj.product or not obj.product.image:
            return None

        request = self.context.get("request")
        image_url = obj.product.image.url

        return request.build_absolute_uri(image_url) if request else image_url

    def get_food_item_name(self, obj):
        return obj.food_item.name if obj.food_item else None

    def get_food_item_image(self, obj):
        if not obj.food_item or not obj.food_item.image:
            return None

        request = self.context.get("request")
        image_url = obj.food_item.image.url

        return request.build_absolute_uri(image_url) if request else image_url


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
    received_by_username = serializers.CharField(
        source="received_by.username",
        read_only=True,
        allow_null=True,
    )

    confirmed_by_username = serializers.CharField(
        source="confirmed_by.username",
        read_only=True,
        allow_null=True,
    )

    class Meta:
        model = Payment
        fields = [
            "id",
            "checkout",
            "order",
            "method",
            "link_id",
            "payment_id",
            "amount",
            "collected_amount",
            "status",
            "received_by",
            "received_by_username",
            "received_at",
            "confirmed_by",
            "confirmed_by_username",
            "paid_at",
            "created_at",
        ]
        read_only_fields = fields


class RefundRequestSerializer(serializers.ModelSerializer):
    requested_by_username = serializers.CharField(
        source="requested_by.username",
        read_only=True,
    )

    reviewed_by_username = serializers.CharField(
        source="reviewed_by.username",
        read_only=True,
    )

    order_no = serializers.CharField(
        source="order.order_no",
        read_only=True,
    )

    class Meta:
        model = RefundRequest
        fields = [
            "id",
            "checkout",
            "order",
            "order_no",
            "payment",
            "amount",
            "reason",
            "status",
            "requested_by",
            "requested_by_username",
            "reviewed_by",
            "reviewed_by_username",
            "razorpay_refund_id",
            "processed_at",
            "created_at",
            "updated_at",
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

    seller_hotel_name = serializers.CharField(
        source="seller_hotel.name",
        read_only=True,
        allow_null=True,
    )

    placed_by_username = serializers.CharField(
        source="placed_by.username",
        read_only=True,
    )

    checkout_no = serializers.CharField(
        source="checkout.checkout_no",
        read_only=True,
        allow_null=True,
    )

    class Meta:
        model = Order
        fields = [
            "id",
            "order_no",
            "checkout",
            "checkout_no",
            "order_type",
            "hotel",
            "hotel_name",
            "seller_hotel",
            "seller_hotel_name",
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
            "checkout",
            "order_type",
            "hotel",
            "seller_hotel",
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
    payment_method = serializers.ChoiceField(
        choices=[
            ("UPI", "UPI"),
            ("COD", "Cash on Delivery"),
        ]
    )

    notes = serializers.CharField(
        required=False,
        allow_blank=True,
        default="",
    )


class CheckoutDetailSerializer(serializers.ModelSerializer):
    customer_hotel_name = serializers.CharField(
        source="customer_hotel.name",
        read_only=True,
    )

    placed_by_username = serializers.CharField(
        source="placed_by.username",
        read_only=True,
    )

    assigned_delivery_username = serializers.CharField(
        source="assigned_delivery.username",
        read_only=True,
        allow_null=True,
    )

    orders = OrderSerializer(many=True, read_only=True)

    payment = serializers.SerializerMethodField()

    refund_requests = RefundRequestSerializer(
        many=True,
        read_only=True,
    )

    class Meta:
        model = Checkout
        fields = [
            "id",
            "checkout_no",
            "customer_hotel",
            "customer_hotel_name",
            "placed_by",
            "placed_by_username",
            "orders",
            "subtotal",
            "tax",
            "delivery_charge",
            "total",
            "collectable_amount",
            "payment_status",
            "delivery_status",
            "assigned_delivery",
            "assigned_delivery_username",
            "delivered_at",
            "delivery_remarks",
            "payment",
            "refund_requests",
            "created_at",
            "updated_at",
        ]
        read_only_fields = fields

    def get_payment(self, obj):
        try:
            payment = obj.payment
        except Payment.DoesNotExist:
            return None

        return PaymentSerializer(
            payment,
            context=self.context,
        ).data