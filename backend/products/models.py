from django.db import models
from django.core.validators import MinValueValidator
from django.conf import settings


class ProductCategory(models.Model):
    name = models.CharField(max_length=100, unique=True)
    description = models.TextField(blank=True)
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return self.name


class Product(models.Model):
    category = models.ForeignKey(
        ProductCategory,
        on_delete=models.PROTECT,
        related_name='products',
        null=True,
        blank=True,
    )

    name = models.CharField(max_length=200)
    description = models.TextField(blank=True)
    sku = models.CharField(max_length=100, unique=True)
    price = models.DecimalField(
        max_digits=10,
        decimal_places=2,
        validators=[MinValueValidator(0.01)],
    )
    stock_quantity = models.PositiveIntegerField(default=0)
    minimum_order_quantity = models.PositiveIntegerField(
        default=1,
        validators=[MinValueValidator(1)],
    )
    minimum_stock_level = models.PositiveIntegerField(default=0)
    unit = models.CharField(max_length=50, default="piece")

    image = models.ImageField(
        upload_to="products/",
        blank=True,
        null=True,
    )

    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return f"{self.name} ({self.sku})"

class StockHistory(models.Model):

    class Reason(models.TextChoices):
        PURCHASE = "PURCHASE", "Purchase"
        ORDER_CONFIRMED = "ORDER_CONFIRMED", "Order Confirmed"
        ORDER_CANCELLED = "ORDER_CANCELLED", "Order Cancelled"
        ORDER_REJECTED = "ORDER_REJECTED", "Order Rejected"
        MANUAL_ADJUSTMENT = "MANUAL_ADJUSTMENT", "Manual Adjustment"

    product = models.ForeignKey(
        Product,
        on_delete=models.PROTECT,
        related_name="stock_history",
    )

    change = models.IntegerField(
        help_text="Positive for stock added, negative for stock removed."
    )

    reason = models.CharField(
        max_length=30,
        choices=Reason.choices,
    )

    order = models.ForeignKey(
        "orders.Order",
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="stock_history",
    )

    created_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.PROTECT,
        related_name="stock_changes",
    )

    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["-created_at"]

    def __str__(self):
        return f"{self.product.name}: {self.change} ({self.reason})"