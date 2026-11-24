from django.contrib import admin
from .models import FoodCategory, FoodItem


@admin.register(FoodCategory)
class FoodCategoryAdmin(admin.ModelAdmin):
    list_display = (
        "id",
        "name",
        "parent_category",
        "display_order",
        "is_active",
    )
    list_filter = ("is_active",)
    search_fields = ("name",)
    ordering = ("display_order", "name")


@admin.register(FoodItem)
class FoodItemAdmin(admin.ModelAdmin):
    list_display = (
        "id",
        "name",
        "hotel",
        "category",
        "price",
        "food_type",
        "is_available",
        "is_active",
    )
    list_filter = (
        "food_type",
        "is_available",
        "is_active",
        "category",
        "hotel",
    )
    search_fields = (
        "name",
        "hotel__name",
        "category__name",
    )
    ordering = ("-created_at",)