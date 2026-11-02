from rest_framework import serializers
from .models import Product, ProductCategory


class ProductCategorySerializer(serializers.ModelSerializer):
    class Meta:
        model = ProductCategory
        fields = ['id', 'name', 'description', 'is_active']


class ProductSerializer(serializers.ModelSerializer):
    category_details = ProductCategorySerializer(
        source='category',
        read_only=True
    )
    is_low_stock = serializers.SerializerMethodField()

    class Meta:
        model = Product
        fields = [
            'id',
            'category',
            'category_details',
            'name',
            'description',
            'sku',
            'price',
            'stock_quantity',
            'minimum_order_quantity',
            'minimum_stock_level',
            'is_low_stock',
            'unit',
            'image',
            'is_active',
            'created_at',
            'updated_at',
        ]
        read_only_fields = [
            'id',
            'is_low_stock',
            'created_at',
            'updated_at',
        ]

    def validate_minimum_order_quantity(self, value):
        if value < 1:
            raise serializers.ValidationError(
                "Minimum order quantity must be at least 1."
            )
        return value

    def validate_price(self, value):
        if value <= 0:
            raise serializers.ValidationError(
                "Product price must be greater than zero."
            )
        return value

    def get_is_low_stock(self, obj):
        return obj.stock_quantity <= obj.minimum_stock_level