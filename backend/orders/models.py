from django.db import models
from django.db.models import Q
from django.conf import settings

from hotels.models import Hotel
from products.models import Product
from food.models import FoodItem


class Checkout(models.Model):

    class PaymentStatus(models.TextChoices):
        PENDING = "PENDING", "Pending"
        CASH_RECEIVED = "CASH_RECEIVED", "Cash Received"
        PAID = "PAID", "Paid"
        PARTIALLY_REFUNDED = "PARTIALLY_REFUNDED", "Partially Refunded"
        REFUNDED = "REFUNDED", "Refunded"

    class DeliveryStatus(models.TextChoices):
        PENDING = "PENDING", "Pending"
        READY = "READY", "Ready"
        OUT_FOR_DELIVERY = "OUT_FOR_DELIVERY", "Out for Delivery"
        DELIVERED = "DELIVERED", "Delivered"

    checkout_no = models.CharField(max_length=30, unique=True)

    customer_hotel = models.ForeignKey(
        Hotel,
        on_delete=models.PROTECT,
        related_name="checkouts"
    )

    placed_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.PROTECT,
        related_name="checkouts"
    )

    subtotal = models.DecimalField(max_digits=12, decimal_places=2, default=0)
    tax = models.DecimalField(max_digits=12, decimal_places=2, default=0)
    delivery_charge = models.DecimalField(max_digits=12, decimal_places=2, default=0)
    total = models.DecimalField(max_digits=12, decimal_places=2, default=0)

    # Amount currently expected to be collected for COD.
    # This can decrease if a food order is rejected.
    collectable_amount = models.DecimalField(
        max_digits=12,
        decimal_places=2,
        default=0
    )

    payment_status = models.CharField(
        max_length=25,
        choices=PaymentStatus.choices,
        default=PaymentStatus.PENDING
    )

    delivery_status = models.CharField(
        max_length=25,
        choices=DeliveryStatus.choices,
        default=DeliveryStatus.PENDING
    )

    assigned_delivery = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="assigned_checkouts"
    )

    delivered_at = models.DateTimeField(null=True, blank=True)
    delivery_remarks = models.TextField(blank=True)

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return self.checkout_no


class Order(models.Model):

    class OrderType(models.TextChoices):
        PRODUCT = "PRODUCT", "Product"
        FOOD = "FOOD", "Food"

    class Status(models.TextChoices):
        PENDING = "PENDING", "Pending"
        CONFIRMED = "CONFIRMED", "Confirmed"
        PREPARING = "PREPARING", "Preparing"
        READY = "READY", "Ready"
        PACKED = "PACKED", "Packed"
        OUT_FOR_DELIVERY = "OUT_FOR_DELIVERY", "Out for Delivery"
        DELIVERED = "DELIVERED", "Delivered"
        REJECTED = "REJECTED", "Rejected"
        CANCELLED = "CANCELLED", "Cancelled"

    class PaymentStatus(models.TextChoices):
        PENDING = "PENDING", "Pending"
        CASH_RECEIVED = "CASH_RECEIVED", "Cash Received"
        PAID = "PAID", "Paid"
        PARTIALLY_REFUNDED = "PARTIALLY_REFUNDED", "Partially Refunded"
        REFUNDED = "REFUNDED", "Refunded"

    order_no = models.CharField(max_length=30, unique=True)

    # Nullable for compatibility with existing orders.
    checkout = models.ForeignKey(
        Checkout,
        on_delete=models.PROTECT,
        null=True,
        blank=True,
        related_name="orders"
    )

    order_type = models.CharField(
        max_length=10,
        choices=OrderType.choices,
        default=OrderType.PRODUCT
    )

    # Purchasing resort/customer hotel.
    hotel = models.ForeignKey(
        Hotel,
        on_delete=models.PROTECT,
        related_name="orders"
    )

    # Selling hotel for FOOD orders.
    seller_hotel = models.ForeignKey(
        Hotel,
        on_delete=models.PROTECT,
        null=True,
        blank=True,
        related_name="food_orders"
    )

    placed_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.PROTECT,
        related_name="placed_orders"
    )

    subtotal = models.DecimalField(max_digits=12, decimal_places=2, default=0)
    tax = models.DecimalField(max_digits=12, decimal_places=2, default=0)
    delivery_charge = models.DecimalField(max_digits=12, decimal_places=2, default=0)
    total = models.DecimalField(max_digits=12, decimal_places=2, default=0)

    status = models.CharField(
        max_length=30,
        choices=Status.choices,
        default=Status.PENDING
    )

    payment_status = models.CharField(
        max_length=25,
        choices=PaymentStatus.choices,
        default=PaymentStatus.PENDING
    )

    notes = models.TextField(blank=True)

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return self.order_no


class OrderItem(models.Model):

    order = models.ForeignKey(
        Order,
        on_delete=models.CASCADE,
        related_name="items"
    )

    product = models.ForeignKey(
        Product,
        on_delete=models.PROTECT,
        null=True,
        blank=True,
        related_name="order_items"
    )

    food_item = models.ForeignKey(
        FoodItem,
        on_delete=models.PROTECT,
        null=True,
        blank=True,
        related_name="order_items"
    )

    quantity = models.PositiveIntegerField()

    unit_price = models.DecimalField(max_digits=10, decimal_places=2)

    line_total = models.DecimalField(max_digits=12, decimal_places=2)

    class Meta:
        constraints = [
            models.CheckConstraint(
                condition=(
                    Q(product__isnull=False, food_item__isnull=True)
                    | Q(product__isnull=True, food_item__isnull=False)
                ),
                name="order_item_product_or_food"
            )
        ]

    def __str__(self):
        item_name = self.product.name if self.product else self.food_item.name
        return f"{item_name} - {self.quantity}"


class OrderStatusHistory(models.Model):

    order = models.ForeignKey(
        Order,
        on_delete=models.CASCADE,
        related_name="status_history"
    )

    status = models.CharField(
        max_length=30,
        choices=Order.Status.choices
    )

    changed_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.PROTECT
    )

    remarks = models.TextField(blank=True)

    changed_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["changed_at"]

    def __str__(self):
        return f"{self.order.order_no} - {self.status}"


class Payment(models.Model):

    class Method(models.TextChoices):
        UPI = "UPI", "UPI"
        COD = "COD", "Cash on Delivery"

    class Status(models.TextChoices):
        PENDING = "PENDING", "Pending"
        CASH_RECEIVED = "CASH_RECEIVED", "Cash Received"
        PAID = "PAID", "Paid"
        PARTIALLY_REFUNDED = "PARTIALLY_REFUNDED", "Partially Refunded"
        REFUNDED = "REFUNDED", "Refunded"

    # New payments are linked to a checkout.
    # One checkout can have one payment.
    checkout = models.OneToOneField(
        Checkout,
        on_delete=models.PROTECT,
        null=True,
        blank=True,
        related_name="payment"
    )

    # Retained for existing payment records.
    order = models.ForeignKey(
        Order,
        on_delete=models.PROTECT,
        null=True,
        blank=True,
        related_name="payments"
    )

    method = models.CharField(max_length=10, choices=Method.choices)

    link_id = models.CharField(max_length=255, blank=True)

    payment_id = models.CharField(max_length=255, blank=True)

    amount = models.DecimalField(max_digits=12, decimal_places=2)

    # Actual amount collected for COD.
    collected_amount = models.DecimalField(
        max_digits=12,
        decimal_places=2,
        null=True,
        blank=True
    )

    status = models.CharField(
        max_length=25,
        choices=Status.choices,
        default=Status.PENDING
    )

    received_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.PROTECT,
        null=True,
        blank=True,
        related_name="cash_payments_received"
    )

    received_at = models.DateTimeField(null=True, blank=True)

    confirmed_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.PROTECT,
        null=True,
        blank=True,
        related_name="payments_confirmed"
    )

    paid_at = models.DateTimeField(null=True, blank=True)

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        if self.checkout:
            return self.checkout.checkout_no

        if self.order:
            return self.order.order_no

        return f"Payment #{self.pk}"


class RefundRequest(models.Model):

    class Status(models.TextChoices):
        PENDING = "PENDING", "Pending Approval"
        APPROVED = "APPROVED", "Approved"
        REJECTED = "REJECTED", "Rejected"
        PROCESSING = "PROCESSING", "Processing"
        PROCESSED = "PROCESSED", "Processed"
        FAILED = "FAILED", "Failed"

    checkout = models.ForeignKey(
        Checkout,
        on_delete=models.PROTECT,
        related_name="refund_requests"
    )

    # One refund request per rejected food order.
    order = models.OneToOneField(
        Order,
        on_delete=models.PROTECT,
        related_name="refund_request"
    )

    payment = models.ForeignKey(
        Payment,
        on_delete=models.PROTECT,
        related_name="refund_requests"
    )

    amount = models.DecimalField(max_digits=12, decimal_places=2)

    reason = models.TextField()

    status = models.CharField(
        max_length=20,
        choices=Status.choices,
        default=Status.PENDING
    )

    requested_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.PROTECT,
        related_name="refund_requests_created"
    )

    reviewed_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.PROTECT,
        null=True,
        blank=True,
        related_name="refund_requests_reviewed"
    )

    razorpay_refund_id = models.CharField(max_length=255, blank=True)

    processed_at = models.DateTimeField(null=True, blank=True)

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return f"Refund for {self.order.order_no}"