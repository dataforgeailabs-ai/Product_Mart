from django.db import transaction
from django.shortcuts import get_object_or_404

from rest_framework import status
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from products.models import Product
from food.models import FoodItem

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
        food_item_id = request.data.get("food_item_id")
        quantity = request.data.get("quantity", 1)

        if bool(product_id) == bool(food_item_id):
            return Response(
                {
                    "detail": (
                        "Provide either product_id or food_item_id, "
                        "not both."
                    )
                },
                status=status.HTTP_400_BAD_REQUEST,
            )

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

        with transaction.atomic():

            if product_id:
                product = get_object_or_404(
                    Product,
                    pk=product_id,
                    is_active=True,
                )

                if quantity < product.minimum_order_quantity:
                    return Response(
                        {
                            "detail": (
                                f"Minimum order quantity is "
                                f"{product.minimum_order_quantity}."
                            )
                        },
                        status=status.HTTP_400_BAD_REQUEST,
                    )

                cart_item = CartItem.objects.filter(
                    cart=cart,
                    item_type="PRODUCT",
                    product=product,
                ).first()

                new_quantity = quantity

                if cart_item:
                    new_quantity += cart_item.quantity

                if new_quantity > product.stock_quantity:
                    return Response(
                        {
                            "detail": (
                                "Requested quantity exceeds available stock."
                            )
                        },
                        status=status.HTTP_400_BAD_REQUEST,
                    )

                if cart_item:
                    cart_item.quantity = new_quantity
                    cart_item.save(
                        update_fields=["quantity", "updated_at"]
                    )
                else:
                    CartItem.objects.create(
                        cart=cart,
                        item_type="PRODUCT",
                        product=product,
                        quantity=quantity,
                    )

                message = "Product added to cart successfully."

            else:
                food_item = get_object_or_404(
                    FoodItem,
                    pk=food_item_id,
                    is_active=True,
                    is_available=True,
                    hotel__status="ACTIVE",
                )

                cart_item = CartItem.objects.filter(
                    cart=cart,
                    item_type="FOOD",
                    food_item=food_item,
                ).first()

                new_quantity = quantity

                if cart_item:
                    new_quantity += cart_item.quantity

                    cart_item.quantity = new_quantity
                    cart_item.save(
                        update_fields=["quantity", "updated_at"]
                    )
                else:
                    CartItem.objects.create(
                        cart=cart,
                        item_type="FOOD",
                        food_item=food_item,
                        quantity=quantity,
                    )

                message = "Food item added to cart successfully."

        cart.refresh_from_db()

        return Response(
            {
                "message": message,
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
            CartItem.objects.select_related(
                "product",
                "food_item",
                "food_item__hotel",
            ),
            pk=item_id,
            cart=cart,
        )

        if cart_item.item_type == "PRODUCT":
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
                            f"Minimum order quantity is "
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

        elif cart_item.item_type == "FOOD":
            food_item = cart_item.food_item

            if (
                not food_item.is_active
                or not food_item.is_available
                or food_item.hotel.status != "ACTIVE"
            ):
                return Response(
                    {"detail": "This food item is no longer available."},
                    status=status.HTTP_400_BAD_REQUEST,
                )

        cart_item.quantity = quantity
        cart_item.save(update_fields=["quantity", "updated_at"])

        cart.refresh_from_db()

        return Response(
            {
                "message": "Cart quantity updated successfully.",
                "cart": CartSerializer(cart).data,
            },
            status=status.HTTP_200_OK,
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

        item_type = cart_item.item_type

        cart_item.delete()

        cart.refresh_from_db()

        return Response(
            {
                "message": (
                    f"{item_type.title()} item removed from cart successfully."
                ),
                "cart": CartSerializer(cart).data,
            },
            status=status.HTTP_200_OK,
        )