from django.contrib import admin
from .models import Product, ProductCategory, StockHistory


@admin.register(Product)
class ProductAdmin(admin.ModelAdmin):
    list_display = (
        'id',
        'name',
        'category',
        'sku',
        'price',
        'stock_quantity',
        'unit',
        'is_active',
        'created_at',
    )

    search_fields = ('name', 'sku')
    list_filter = ('is_active', 'unit', 'category')
    ordering = ('-created_at',)


@admin.register(ProductCategory)
class ProductCategoryAdmin(admin.ModelAdmin):
    list_display = (
        'id',
        'name',
        'is_active',
        'created_at',
    )

    search_fields = ('name',)
    list_filter = ('is_active',)
    ordering = ('name',)

from .models import StockHistory


@admin.register(StockHistory)
class StockHistoryAdmin(admin.ModelAdmin):
    list_display = (
        "product",
        "change",
        "reason",
        "order",
        "created_by",
        "created_at",
    )

    list_filter = ("reason", "created_at")
    search_fields = (
        "product__name",
        "product__sku",
        "order__order_no",
        "created_by__username",
    )

    readonly_fields = ("created_at",)