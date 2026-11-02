from django.db import transaction
from rest_framework import generics
from rest_framework.parsers import MultiPartParser, FormParser, JSONParser
from rest_framework.permissions import IsAuthenticated, AllowAny
from rest_framework.response import Response

from .models import Product, ProductCategory, StockHistory
from .serializers import ProductSerializer, ProductCategorySerializer
from .permissions import CanManageProducts


class ProductListView(generics.ListAPIView):
    queryset = Product.objects.filter(is_active=True)
    serializer_class = ProductSerializer
    permission_classes = [AllowAny]


class ProductDetailView(generics.RetrieveAPIView):
    queryset = Product.objects.filter(is_active=True)
    serializer_class = ProductSerializer
    permission_classes = [AllowAny]


class ProductCreateView(generics.CreateAPIView):
    queryset = Product.objects.all()
    serializer_class = ProductSerializer
    permission_classes = [IsAuthenticated, CanManageProducts]
    parser_classes = [MultiPartParser, FormParser, JSONParser]


class ProductUpdateView(generics.UpdateAPIView):
    queryset = Product.objects.all()
    serializer_class = ProductSerializer
    permission_classes = [IsAuthenticated, CanManageProducts]
    parser_classes = [MultiPartParser, FormParser, JSONParser]

    def perform_update(self, serializer):
        with transaction.atomic():
            product = Product.objects.select_for_update().get(
                pk=self.get_object().pk
            )

            old_stock = product.stock_quantity
            updated_product = serializer.save()

            new_stock = updated_product.stock_quantity
            stock_change = new_stock - old_stock

            if stock_change != 0:
                StockHistory.objects.create(
                    product=updated_product,
                    change=stock_change,
                    reason=StockHistory.Reason.MANUAL_ADJUSTMENT,
                    created_by=self.request.user,
                )

class ProductDeleteView(generics.GenericAPIView):
    queryset = Product.objects.all()
    serializer_class = ProductSerializer
    permission_classes = [IsAuthenticated, CanManageProducts]

    def delete(self, request, *args, **kwargs):
        product = self.get_object()
        product.is_active = False
        product.save(update_fields=["is_active", "updated_at"])

        return Response(
            {
                "message": "Product deactivated successfully.",
                "product_id": product.id,
            },
            status=200,
        )


class ProductCategoryListView(generics.ListAPIView):
    queryset = ProductCategory.objects.filter(is_active=True)
    serializer_class = ProductCategorySerializer
    permission_classes = [AllowAny]


class ProductCategoryCreateView(generics.CreateAPIView):
    queryset = ProductCategory.objects.all()
    serializer_class = ProductCategorySerializer
    permission_classes = [IsAuthenticated, CanManageProducts]


class ProductCategoryUpdateView(generics.UpdateAPIView):
    queryset = ProductCategory.objects.all()
    serializer_class = ProductCategorySerializer
    permission_classes = [IsAuthenticated, CanManageProducts]


class ProductCategoryDeleteView(generics.GenericAPIView):
    queryset = ProductCategory.objects.all()
    serializer_class = ProductCategorySerializer
    permission_classes = [IsAuthenticated, CanManageProducts]

    def delete(self, request, *args, **kwargs):
        category = self.get_object()
        category.is_active = False
        category.save(update_fields=["is_active", "updated_at"])

        return Response(
            {
                "message": "Category deactivated successfully.",
                "category_id": category.id,
            },
            status=200,
        )