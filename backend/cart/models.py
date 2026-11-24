from django.db import models
from django.db.models import Q
from django.conf import settings

from products.models import Product
from food.models import FoodItem


class Cart(models.Model):
    user = models.OneToOneField(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="cart",
    )

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return f"Cart - {self.user.username}"


class CartItem(models.Model):

    ITEM_TYPE_CHOICES = [
        ("PRODUCT", "Product"),
        ("FOOD", "Food"),
    ]

    cart = models.ForeignKey(
        Cart,
        on_delete=models.CASCADE,
        related_name="items",
    )

    item_type = models.CharField(
        max_length=10,
        choices=ITEM_TYPE_CHOICES,
        default="PRODUCT",
    )

    product = models.ForeignKey(
        Product,
        on_delete=models.PROTECT,
        related_name="cart_items",
        null=True,
        blank=True,
    )

    food_item = models.ForeignKey(
        FoodItem,
        on_delete=models.PROTECT,
        related_name="cart_items",
        null=True,
        blank=True,
    )

    quantity = models.PositiveIntegerField(default=1)

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        constraints = [
            models.CheckConstraint(
                condition=(
                    Q(
                        item_type="PRODUCT",
                        product__isnull=False,
                        food_item__isnull=True,
                    )
                    | Q(
                        item_type="FOOD",
                        product__isnull=True,
                        food_item__isnull=False,
                    )
                ),
                name="cart_item_valid_type_reference",
            ),
        ]

    def __str__(self):
        if self.item_type == "PRODUCT" and self.product:
            return f"{self.product.name} x {self.quantity}"

        if self.item_type == "FOOD" and self.food_item:
            return f"{self.food_item.name} x {self.quantity}"

        return f"Cart Item #{self.pk}"