from django.db import transaction
from django.shortcuts import get_object_or_404

from rest_framework import status
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from products.models import Product
from .models import Cart, CartItem
from .serializers import CartSerializer


class CartView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        cart, _ = Cart.objects.get_or_create(user=request.user)
        serializer = CartSerializer(cart)
        return Response(serializer.data)


class AddToCartView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        product_id = request.data.get("product_id")
        quantity = request.data.get("quantity", 1)

        try:
            quantity = int(quantity)
        except (TypeError, ValueError):
            return Response(
                {"detail": "Quantity must be a valid integer."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        if quantity < 1:
            return Response(
                {"detail": "Quantity must be at least 1."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        product = get_object_or_404(
            Product,
            pk=product_id,
            is_active=True,
        )

        if quantity < product.minimum_order_quantity:
            return Response(
                {
                    "detail": (
                        f"Minimum order quantity for this product is "
                        f"{product.minimum_order_quantity}."
                    )
                },
                status=status.HTTP_400_BAD_REQUEST,
            )

        if quantity > product.stock_quantity:
            return Response(
                {"detail": "Requested quantity exceeds available stock."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        cart, _ = Cart.objects.get_or_create(user=request.user)

        with transaction.atomic():
            cart_item, created = CartItem.objects.get_or_create(
                cart=cart,
                product=product,
                defaults={"quantity": quantity},
            )

            if not created:
                new_quantity = cart_item.quantity + quantity

                if new_quantity < product.minimum_order_quantity:
                    return Response(
                        {
                            "detail": (
                                f"Minimum order quantity for this product is "
                                f"{product.minimum_order_quantity}."
                            )
                        },
                        status=status.HTTP_400_BAD_REQUEST,
                    )

                if new_quantity > product.stock_quantity:
                    return Response(
                        {
                            "detail": (
                                "Combined cart quantity exceeds available stock."
                            )
                        },
                        status=status.HTTP_400_BAD_REQUEST,
                    )

                cart_item.quantity = new_quantity
                cart_item.save(update_fields=["quantity", "updated_at"])

        cart.refresh_from_db()

        return Response(
            {
                "message": "Product added to cart successfully.",
                "cart": CartSerializer(cart).data,
            },
            status=status.HTTP_200_OK,
        )


class UpdateCartItemView(APIView):
    permission_classes = [IsAuthenticated]

    def patch(self, request, item_id):
        quantity = request.data.get("quantity")

        try:
            quantity = int(quantity)
        except (TypeError, ValueError):
            return Response(
                {"detail": "Quantity must be a valid integer."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        if quantity < 1:
            return Response(
                {"detail": "Quantity must be at least 1."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        cart, _ = Cart.objects.get_or_create(user=request.user)

        cart_item = get_object_or_404(
            CartItem.objects.select_related("product"),
            pk=item_id,
            cart=cart,
        )

        product = cart_item.product

        if not product.is_active:
            return Response(
                {"detail": "This product is no longer available."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        if quantity < product.minimum_order_quantity:
            return Response(
                {
                    "detail": (
                        f"Minimum order quantity for this product is "
                        f"{product.minimum_order_quantity}."
                    )
                },
                status=status.HTTP_400_BAD_REQUEST,
            )

        if quantity > product.stock_quantity:
            return Response(
                {"detail": "Requested quantity exceeds available stock."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        cart_item.quantity = quantity
        cart_item.save(update_fields=["quantity", "updated_at"])

        cart.refresh_from_db()

        return Response(
            {
                "message": "Cart quantity updated successfully.",
                "cart": CartSerializer(cart).data,
            }
        )


class RemoveCartItemView(APIView):
    permission_classes = [IsAuthenticated]

    def delete(self, request, item_id):
        cart, _ = Cart.objects.get_or_create(user=request.user)

        cart_item = get_object_or_404(
            CartItem,
            pk=item_id,
            cart=cart,
        )

        cart_item.delete()

        cart.refresh_from_db()

        return Response(
            {
                "message": "Product removed from cart successfully.",
                "cart": CartSerializer(cart).data,
            },
            status=status.HTTP_200_OK,
        )