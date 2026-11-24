from django.db import models
from django.core.validators import MinValueValidator
from decimal import Decimal


class FoodCategory(models.Model):
    name = models.CharField(max_length=100, unique=True)
    description = models.TextField(blank=True)

    image = models.ImageField(
        upload_to="food/categories/",
        blank=True,
        null=True,
    )

    parent_category = models.ForeignKey(
        "self",
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="subcategories",
    )

    display_order = models.PositiveIntegerField(default=0)
    is_active = models.BooleanField(default=True)

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ["display_order", "name"]
        verbose_name_plural = "Food Categories"

    def __str__(self):
        return self.name


class FoodItem(models.Model):

    class FoodType(models.TextChoices):
        VEG = "VEG", "Vegetarian"
        NON_VEG = "NON_VEG", "Non-Vegetarian"
        VEGAN = "VEGAN", "Vegan"

    class SpiceLevel(models.TextChoices):
        MILD = "MILD", "Mild"
        MEDIUM = "MEDIUM", "Medium"
        HOT = "HOT", "Hot"

    hotel = models.ForeignKey(
        "hotels.Hotel",
        on_delete=models.CASCADE,
        related_name="food_items",
    )

    category = models.ForeignKey(
        FoodCategory,
        on_delete=models.PROTECT,
        related_name="food_items",
    )

    name = models.CharField(max_length=200)
    description = models.TextField(blank=True)

    image = models.ImageField(
        upload_to="food/items/",
        blank=True,
        null=True,
    )

    price = models.DecimalField(
        max_digits=10,
        decimal_places=2,
        validators=[MinValueValidator(Decimal("0.01"))],
    )

    food_type = models.CharField(
        max_length=10,
        choices=FoodType.choices,
        default=FoodType.VEG,
    )

    preparation_time = models.PositiveIntegerField(
        default=15,
        help_text="Preparation time in minutes.",
    )

    serving_size = models.CharField(
        max_length=50,
        blank=True,
    )

    spice_level = models.CharField(
        max_length=10,
        choices=SpiceLevel.choices,
        blank=True,
    )

    ingredients = models.TextField(blank=True)
    allergens = models.TextField(blank=True)

    is_available = models.BooleanField(default=True)
    is_active = models.BooleanField(default=True)

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ["-created_at"]
        indexes = [
            models.Index(fields=["hotel", "category"]),
            models.Index(fields=["is_available", "is_active"]),
        ]

    def __str__(self):
        return f"{self.name} - {self.hotel.name}"