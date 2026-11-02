import uuid
import hmac
import hashlib

from decimal import Decimal

import razorpay

from django.conf import settings
from django.db import transaction
from django.shortcuts import get_object_or_404
from django.utils import timezone

from rest_framework import generics, status
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from accounts.models import User
from accounts.permissions import IsAdmin, IsDelivery
from cart.models import Cart, CartItem
from hotels.models import Hotel
from products.models import Product, StockHistory

from .models import Order, OrderItem, OrderStatusHistory, Payment
from .serializers import OrderSerializer, CheckoutSerializer
from .permissions import IsOrderManager


class OrderListView(generics.ListAPIView):
    """
    List orders according to the user's role.
    """

    serializer_class = OrderSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        user = self.request.user

        queryset = Order.objects.select_related(
            "hotel",
            "placed_by",
        ).prefetch_related(
            "items__product",
            "status_history__changed_by",
            "payments",
        )

        if user.role in ["SUPERADMIN", "ADMIN"]:
            return queryset

        if (
            user.role == "HOTEL"
            and user.hotel is not None
            and user.hotel.status == "ACTIVE"
        ):
            return queryset.filter(hotel=user.hotel)

        # DELIVERY users can see all orders awaiting delivery.
        if user.role == "DELIVERY" and user.is_active:
            return queryset.filter(
                status=Order.Status.OUT_FOR_DELIVERY
            )

        return queryset.none()


class OrderDetailView(generics.RetrieveAPIView):
    """
    Retrieve an order only when the user is authorized to access it.
    """

    serializer_class = OrderSerializer
    permission_classes = [IsAuthenticated]
    lookup_field = "pk"

    def get_queryset(self):
        user = self.request.user

        queryset = Order.objects.select_related(
            "hotel",
            "placed_by",
        ).prefetch_related(
            "items__product",
            "status_history__changed_by",
            "payments",
        )

        if user.role in ["SUPERADMIN", "ADMIN"]:
            return queryset

        if (
            user.role == "HOTEL"
            and user.hotel is not None
            and user.hotel.status == "ACTIVE"
        ):
            return queryset.filter(hotel=user.hotel)

        # DELIVERY users can access only orders awaiting delivery.
        if user.role == "DELIVERY" and user.is_active:
            return queryset.filter(
                status=Order.Status.OUT_FOR_DELIVERY
            )

        return queryset.none()


class CheckoutView(APIView):
    """
    Create a pending order from the authenticated user's cart.
    Stock is validated but not deducted until order confirmation.
    """

    permission_classes = [IsAuthenticated]

    def post(self, request):
        serializer = CheckoutSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        user = request.user

        if user.role != User.Role.HOTEL:
            return Response(
                {"detail": "Only hotel staff can place orders."},
                status=status.HTTP_403_FORBIDDEN,
            )

        if user.hotel_id is None:
            return Response(
                {"detail": "Your account is not associated with a hotel."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        if user.hotel.status != "ACTIVE":
            return Response(
                {"detail": "Your hotel account is not active."},
                status=status.HTTP_403_FORBIDDEN,
            )

        payment_method = serializer.validated_data["payment_method"]
        notes = serializer.validated_data.get("notes", "")

        try:
            with transaction.atomic():
                cart = get_object_or_404(
                    Cart.objects.select_for_update(),
                    user=user,
                )

                cart_items = list(
                    CartItem.objects.filter(cart=cart)
                    .select_related("product")
                    .order_by("product_id")
                )

                if not cart_items:
                    return Response(
                        {"detail": "Your cart is empty."},
                        status=status.HTTP_400_BAD_REQUEST,
                    )

                # Lock product rows and recheck stock.
                product_ids = [item.product_id for item in cart_items]

                locked_products = {
                    product.pk: product
                    for product in Product.objects.select_for_update()
                    .filter(pk__in=product_ids)
                    .order_by("pk")
                }

                subtotal = Decimal("0.00")
                validated_items = []

                for cart_item in cart_items:
                    product = locked_products.get(cart_item.product_id)

                    if product is None or not product.is_active:
                        return Response(
                            {
                                "detail": (
                                    f"Product '{cart_item.product.name}' "
                                    "is no longer available."
                                )
                            },
                            status=status.HTTP_400_BAD_REQUEST,
                        )

                    if cart_item.quantity < product.minimum_order_quantity:
                        return Response(
                            {
                                "detail": (
                                    f"Minimum order quantity for "
                                    f"'{product.name}' is "
                                    f"{product.minimum_order_quantity}."
                                )
                            },
                            status=status.HTTP_400_BAD_REQUEST,
                        )

                    if cart_item.quantity > product.stock_quantity:
                        return Response(
                            {
                                "detail": (
                                    f"Insufficient stock for '{product.name}'. "
                                    f"Available quantity: "
                                    f"{product.stock_quantity}."
                                )
                            },
                            status=status.HTTP_400_BAD_REQUEST,
                        )

                    unit_price = product.price
                    line_total = unit_price * cart_item.quantity
                    subtotal += line_total

                    validated_items.append(
                        {
                            "product": product,
                            "quantity": cart_item.quantity,
                            "unit_price": unit_price,
                            "line_total": line_total,
                        }
                    )

                # Tax and delivery charges remain zero until their
                # business rules are configured.
                tax = Decimal("0.00")
                delivery_charge = Decimal("0.00")
                total = subtotal + tax + delivery_charge

                order = Order.objects.create(
                    order_no=f"ORD-{uuid.uuid4().hex[:12].upper()}",
                    hotel=user.hotel,
                    placed_by=user,
                    subtotal=subtotal,
                    tax=tax,
                    delivery_charge=delivery_charge,
                    total=total,
                    status=Order.Status.PENDING,
                    payment_status=Order.PaymentStatus.PENDING,
                    notes=notes,
                )

                OrderItem.objects.bulk_create(
                    [
                        OrderItem(
                            order=order,
                            product=item["product"],
                            quantity=item["quantity"],
                            unit_price=item["unit_price"],
                            line_total=item["line_total"],
                        )
                        for item in validated_items
                    ]
                )

                OrderStatusHistory.objects.create(
                    order=order,
                    status=Order.Status.PENDING,
                    changed_by=user,
                    remarks="Order placed by hotel staff.",
                )

                Payment.objects.create(
                    order=order,
                    method=payment_method,
                    amount=total,
                    status=Payment.Status.PENDING,
                )

                # Clear the cart only after all order records are created.
                CartItem.objects.filter(cart=cart).delete()

                order = Order.objects.select_related(
                    "hotel",
                    "placed_by",
                ).prefetch_related(
                    "items__product",
                    "status_history__changed_by",
                    "payments",
                ).get(pk=order.pk)

                response_data = OrderSerializer(order).data

            return Response(
                {
                    "message": "Order placed successfully.",
                    "order": response_data,
                },
                status=status.HTTP_201_CREATED,
            )

        except Exception:
            # Unexpected errors are logged by Django. Avoid exposing
            # internal database details in API responses.
            import logging

            logging.getLogger(__name__).exception(
                "Checkout failed for user ID %s",
                user.pk,
            )

            return Response(
                {
                    "detail": (
                        "Unable to place your order. "
                        "Please try again."
                    )
                },
                status=status.HTTP_500_INTERNAL_SERVER_ERROR,
            )

class OrderConfirmationView(APIView):
    """
    Confirm a pending order and deduct its stock atomically.

    Only Admin and Superadmin users can confirm orders.
    UPI orders require verified payment before confirmation.
    COD orders can be confirmed before payment.
    """

    permission_classes = [IsAuthenticated, IsOrderManager]

    def post(self, request, pk):
        try:
            with transaction.atomic():
                order = get_object_or_404(
                    Order.objects.select_for_update(),
                    pk=pk,
                )

                # Only pending orders can be confirmed.
                if order.status != Order.Status.PENDING:
                    return Response(
                        {
                            "detail": (
                                f"Only pending orders can be confirmed. "
                                f"Current status: {order.status}."
                            )
                        },
                        status=status.HTTP_400_BAD_REQUEST,
                    )

                # Lock and validate the order's payment record.
                payments = list(
                    Payment.objects.select_for_update()
                    .filter(order=order)
                    .order_by("pk")
                )

                if len(payments) != 1:
                    return Response(
                        {
                            "detail": (
                                "Order confirmation requires exactly "
                                "one payment record."
                            )
                        },
                        status=status.HTTP_400_BAD_REQUEST,
                    )

                payment = payments[0]

                # UPI payment must be verified before confirmation.
                if payment.method == Payment.Method.UPI:
                    if payment.status != Payment.Status.PAID:
                        return Response(
                            {
                                "detail": (
                                    "UPI payment must be verified before "
                                    "the order can be confirmed."
                                )
                            },
                            status=status.HTTP_400_BAD_REQUEST,
                        )

                # COD can be confirmed while payment is pending.
                elif payment.method == Payment.Method.COD:
                    if payment.status != Payment.Status.PENDING:
                        return Response(
                            {
                                "detail": (
                                    "COD order payment must be pending "
                                    "before confirmation."
                                )
                            },
                            status=status.HTTP_400_BAD_REQUEST,
                        )

                else:
                    return Response(
                        {"detail": "Unsupported payment method."},
                        status=status.HTTP_400_BAD_REQUEST,
                    )

                # Retrieve order items in a consistent order.
                order_items = list(
                    order.items.select_related("product")
                    .order_by("product_id")
                )

                if not order_items:
                    return Response(
                        {
                            "detail": (
                                "Cannot confirm an order without items."
                            )
                        },
                        status=status.HTTP_400_BAD_REQUEST,
                    )

                product_ids = [
                    item.product_id for item in order_items
                ]

                # Lock products to prevent concurrent stock changes.
                locked_products = {
                    product.pk: product
                    for product in Product.objects.select_for_update()
                    .filter(pk__in=product_ids)
                    .order_by("pk")
                }

                # Validate every product before deducting any stock.
                for item in order_items:
                    product = locked_products.get(item.product_id)

                    if product is None or not product.is_active:
                        return Response(
                            {
                                "detail": (
                                    f"Product '{item.product.name}' "
                                    "is no longer available."
                                )
                            },
                            status=status.HTTP_400_BAD_REQUEST,
                        )

                    if product.stock_quantity < item.quantity:
                        return Response(
                            {
                                "detail": (
                                    f"Insufficient stock for "
                                    f"'{product.name}'. "
                                    f"Available: {product.stock_quantity}; "
                                    f"required: {item.quantity}."
                                )
                            },
                            status=status.HTTP_400_BAD_REQUEST,
                        )

                # Deduct stock only after all validations pass.
                for item in order_items:
                    product = locked_products[item.product_id]

                    product.stock_quantity -= item.quantity
                    product.save(
                        update_fields=["stock_quantity"]
                    )

                    StockHistory.objects.create(
                        product=product,
                        change=-item.quantity,
                        reason=StockHistory.Reason.ORDER_CONFIRMED,
                        order=order,
                        created_by=request.user,
                    )

                # Update the order status.
                order.status = Order.Status.CONFIRMED
                order.save(
                    update_fields=["status", "updated_at"]
                )

                OrderStatusHistory.objects.create(
                    order=order,
                    status=Order.Status.CONFIRMED,
                    changed_by=request.user,
                    remarks=(
                        "Order confirmed; stock deducted. "
                        "UPI payment verified."
                        if payment.method == Payment.Method.UPI
                        else "COD order confirmed; stock deducted."
                    ),
                )

            return Response(
                {
                    "message": (
                        "Order confirmed and stock deducted successfully."
                    ),
                    "order_id": order.pk,
                    "order_no": order.order_no,
                    "status": order.status,
                    "payment_method": payment.method,
                    "payment_status": payment.status,
                },
                status=status.HTTP_200_OK,
            )

        except Exception:
            import logging

            logging.getLogger(__name__).exception(
                "Order confirmation failed for order ID %s",
                pk,
            )

            return Response(
                {
                    "detail": (
                        "Unable to confirm the order. Please try again."
                    )
                },
                status=status.HTTP_500_INTERNAL_SERVER_ERROR,
            )


class OrderRejectionView(APIView):
    """
    Reject a pending order without changing product stock.
    Only Admin and Superadmin users can reject orders.
    """

    permission_classes = [IsAuthenticated, IsOrderManager]

    def post(self, request, pk):
        with transaction.atomic():
            order = get_object_or_404(
                Order.objects.select_for_update(),
                pk=pk,
            )

            if order.status != Order.Status.PENDING:
                return Response(
                    {
                        "detail": (
                            "Only pending orders can be rejected. "
                            f"Current status: {order.status}."
                        )
                    },
                    status=status.HTTP_400_BAD_REQUEST,
                )

            remarks = request.data.get(
                "remarks",
                "Order rejected by administrator.",
            )

            order.status = Order.Status.REJECTED
            order.save(update_fields=["status", "updated_at"])

            OrderStatusHistory.objects.create(
                order=order,
                status=Order.Status.REJECTED,
                changed_by=request.user,
                remarks=remarks,
            )

        return Response(
            {
                "message": "Order rejected successfully.",
                "order_id": order.pk,
                "order_no": order.order_no,
                "status": order.status,
            },
            status=status.HTTP_200_OK,
        )


class OrderCancellationView(APIView):
    """
    Cancel a pending or confirmed order.

    Hotel staff can cancel their own hotel's eligible orders.
    Admin and Superadmin can cancel eligible orders for any hotel.

    If the order is CONFIRMED, restore its deducted stock.
    """

    permission_classes = [IsAuthenticated]

    def post(self, request, pk):
        with transaction.atomic():
            order = get_object_or_404(
                Order.objects.select_for_update(),
                pk=pk,
            )

            user = request.user

            # Check permission to cancel this order.
            if user.role in ["SUPERADMIN", "ADMIN"]:
                pass
            elif (
                user.role == "HOTEL"
                and user.hotel_id is not None
                and user.hotel.status == "ACTIVE"
                and order.hotel_id == user.hotel_id
            ):
                pass
            else:
                return Response(
                    {
                        "detail": (
                            "You do not have permission to cancel this order."
                        )
                    },
                    status=status.HTTP_403_FORBIDDEN,
                )

            # Only pending and confirmed orders can be cancelled.
            if order.status not in [
                Order.Status.PENDING,
                Order.Status.CONFIRMED,
            ]:
                return Response(
                    {
                        "detail": (
                            "Only pending or confirmed orders can be cancelled. "
                            f"Current status: {order.status}."
                        )
                    },
                    status=status.HTTP_400_BAD_REQUEST,
                )

            remarks = request.data.get(
                "remarks",
                "Order cancelled by user.",
            )

            # Confirmed orders have already deducted stock.
            if order.status == Order.Status.CONFIRMED:
                order_items = list(
                    order.items.select_related("product")
                    .order_by("product_id")
                )

                product_ids = [item.product_id for item in order_items]

                locked_products = {
                    product.pk: product
                    for product in Product.objects.select_for_update()
                    .filter(pk__in=product_ids)
                    .order_by("pk")
                }

                for item in order_items:
                    product = locked_products.get(item.product_id)

                    if product is None:
                        return Response(
                            {
                                "detail": (
                                    f"Unable to restore stock for "
                                    f"'{item.product.name}'."
                                )
                            },
                            status=status.HTTP_400_BAD_REQUEST,
                        )

                # Restore stock only after all products are available.
                for item in order_items:
                    product = locked_products[item.product_id]
                    product.stock_quantity += item.quantity
                    product.save(update_fields=["stock_quantity"])

                    StockHistory.objects.create(
                        product=product,
                        change=item.quantity,
                        reason=StockHistory.Reason.ORDER_CANCELLED,
                        order=order,
                        created_by=user,
                    )

            order.status = Order.Status.CANCELLED
            order.save(update_fields=["status", "updated_at"])

            OrderStatusHistory.objects.create(
                order=order,
                status=Order.Status.CANCELLED,
                changed_by=user,
                remarks=remarks,
            )

        return Response(
            {
                "message": "Order cancelled successfully.",
                "order_id": order.pk,
                "order_no": order.order_no,
                "status": order.status,
            },
            status=status.HTTP_200_OK,
        )
    

class OrderStatusUpdateView(APIView):
    """
    Update order status through permitted transitions.

    Admin/Superadmin:
        CONFIRMED -> PACKED
        PACKED -> OUT_FOR_DELIVERY

    Delivery person:
        OUT_FOR_DELIVERY -> DELIVERED

    UPI:
        Payment must be PAID before packing, dispatch, or delivery.

    COD:
        Orders can be packed and dispatched before payment.
        Cash is collected and recorded when delivery is completed.
    """

    permission_classes = [IsAuthenticated]

    ALLOWED_TRANSITIONS = {
        Order.Status.CONFIRMED: Order.Status.PACKED,
        Order.Status.PACKED: Order.Status.OUT_FOR_DELIVERY,
        Order.Status.OUT_FOR_DELIVERY: Order.Status.DELIVERED,
    }

    def post(self, request, pk):
        new_status = request.data.get("status")
        remarks = request.data.get("remarks", "")

        if new_status not in Order.Status.values:
            return Response(
                {"detail": "Invalid order status."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        if not isinstance(remarks, str):
            return Response(
                {"detail": "Remarks must be a string."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        with transaction.atomic():
            order = get_object_or_404(
                Order.objects.select_for_update(),
                pk=pk,
            )

            expected_status = self.ALLOWED_TRANSITIONS.get(order.status)

            if expected_status != new_status:
                return Response(
                    {
                        "detail": (
                            f"Invalid transition from {order.status} "
                            f"to {new_status}."
                        )
                    },
                    status=status.HTTP_400_BAD_REQUEST,
                )

            user = request.user

            # Validate permissions for packing and dispatch.
            if new_status in [
                Order.Status.PACKED,
                Order.Status.OUT_FOR_DELIVERY,
            ]:
                if not IsAdmin().has_permission(request, self):
                    return Response(
                        {
                            "detail": (
                                "Only Admin or Superadmin can update "
                                "this order status."
                            )
                        },
                        status=status.HTTP_403_FORBIDDEN,
                    )

            # Validate permissions for delivery.
            elif new_status == Order.Status.DELIVERED:
                if not IsDelivery().has_permission(request, self):
                    return Response(
                        {
                            "detail": (
                                "Only a delivery person can mark an "
                                "order as delivered."
                            )
                        },
                        status=status.HTTP_403_FORBIDDEN,
                    )

            # Lock payment records before checking or updating them.
            payments = list(
                Payment.objects.select_for_update()
                .filter(order=order)
                .order_by("pk")
            )

            if len(payments) != 1:
                return Response(
                    {
                        "detail": (
                            "Order status update requires exactly "
                            "one payment record."
                        )
                    },
                    status=status.HTTP_400_BAD_REQUEST,
                )

            payment = payments[0]

            # UPI must be paid before packing, dispatch, or delivery.
            if payment.method == Payment.Method.UPI:
                if payment.status != Payment.Status.PAID:
                    return Response(
                        {
                            "detail": (
                                "UPI payment must be verified before "
                                "the order can be packed, dispatched, "
                                "or delivered."
                            )
                        },
                        status=status.HTTP_400_BAD_REQUEST,
                    )

            # Handle COD collection when delivery is completed.
            elif payment.method == Payment.Method.COD:
                if new_status == Order.Status.DELIVERED:
                    if payment.status != Payment.Status.PENDING:
                        return Response(
                            {
                                "detail": (
                                    "This COD payment is not pending "
                                    "and cannot be collected again."
                                )
                            },
                            status=status.HTTP_400_BAD_REQUEST,
                        )

                    payment.status = Payment.Status.PAID
                    payment.received_by = user
                    payment.received_at = timezone.now()
                    payment.confirmed_by = None
                    payment.paid_at = payment.received_at

                    payment.save(
                        update_fields=[
                            "status",
                            "received_by",
                            "received_at",
                            "confirmed_by",
                            "paid_at",
                            "updated_at",
                        ]
                    )

                    order.payment_status = Order.PaymentStatus.PAID
                    order.save(
                        update_fields=[
                            "payment_status",
                            "updated_at",
                        ]
                    )

            else:
                return Response(
                    {"detail": "Unsupported payment method."},
                    status=status.HTTP_400_BAD_REQUEST,
                )

            # Record the new order status.
            order.status = new_status
            order.save(update_fields=["status", "updated_at"])

            history_remarks = remarks

            if new_status == Order.Status.DELIVERED:
                if payment.method == Payment.Method.COD:
                    collection_note = "COD cash received and recorded."
                else:
                    collection_note = "UPI payment verified."

                history_remarks = (
                    f"{remarks}\n{collection_note}".strip()
                    if remarks
                    else collection_note
                )

            OrderStatusHistory.objects.create(
                order=order,
                status=new_status,
                changed_by=user,
                remarks=history_remarks,
            )

        return Response(
            {
                "message": "Order status updated successfully.",
                "order_id": order.pk,
                "order_no": order.order_no,
                "status": order.status,
                "payment_status": order.payment_status,
            },
            status=status.HTTP_200_OK,
        )


class UPIPaymentVerificationView(APIView):
    """
    Verify a Razorpay payment before marking a UPI payment as paid.

    Security checks:
    - Only authenticated, active hotel users can verify their own orders.
    - Razorpay payment signatures must be valid.
    - Payment status must be captured.
    - Razorpay Order ID, amount, and currency must match.
    - The payment must belong to the expected order.
    - Duplicate verification of the same payment is handled safely.
    """

    permission_classes = [IsAuthenticated]

    def post(self, request, pk):
        razorpay_order_id = request.data.get("razorpay_order_id")
        razorpay_payment_id = request.data.get("razorpay_payment_id")
        razorpay_signature = request.data.get("razorpay_signature")

        # Validate required fields.
        if not all(
            isinstance(value, str)
            for value in (
                razorpay_order_id,
                razorpay_payment_id,
                razorpay_signature,
            )
        ):
            return Response(
                {
                    "detail": (
                        "razorpay_order_id, razorpay_payment_id, "
                        "and razorpay_signature are required."
                    )
                },
                status=status.HTTP_400_BAD_REQUEST,
            )

        razorpay_order_id = razorpay_order_id.strip()
        razorpay_payment_id = razorpay_payment_id.strip()
        razorpay_signature = razorpay_signature.strip()

        if not all(
            (razorpay_order_id, razorpay_payment_id, razorpay_signature)
        ):
            return Response(
                {
                    "detail": (
                        "Payment verification fields cannot be empty."
                    )
                },
                status=status.HTTP_400_BAD_REQUEST,
            )

        if (
            len(razorpay_order_id) > 255
            or len(razorpay_payment_id) > 255
            or len(razorpay_signature) > 255
        ):
            return Response(
                {"detail": "One or more payment verification fields are invalid."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        # Confirm that Razorpay credentials are configured.
        if (
            not settings.RAZORPAY_KEY_ID
            or not settings.RAZORPAY_KEY_SECRET
        ):
            return Response(
                {"detail": "Razorpay is not configured."},
                status=status.HTTP_503_SERVICE_UNAVAILABLE,
            )

        # Verify the signature and retrieve payment details from Razorpay.
        try:
            client = razorpay.Client(
                auth=(
                    settings.RAZORPAY_KEY_ID,
                    settings.RAZORPAY_KEY_SECRET,
                )
            )

            client.utility.verify_payment_signature(
                {
                    "razorpay_order_id": razorpay_order_id,
                    "razorpay_payment_id": razorpay_payment_id,
                    "razorpay_signature": razorpay_signature,
                }
            )

            razorpay_payment = client.payment.fetch(
                razorpay_payment_id
            )

        except razorpay.errors.SignatureVerificationError:
            return Response(
                {
                    "detail": (
                        "Razorpay payment signature verification failed."
                    )
                },
                status=status.HTTP_400_BAD_REQUEST,
            )

        except Exception:
            return Response(
                {
                    "detail": (
                        "Unable to verify the Razorpay payment. "
                        "Please try again."
                    )
                },
                status=status.HTTP_502_BAD_GATEWAY,
            )

        # Lock the order and payment records before changing their status.
        with transaction.atomic():
            order = get_object_or_404(
                Order.objects.select_for_update(),
                pk=pk,
            )

            # Only active hotel users can verify their own payments.
            if request.user.role != User.Role.HOTEL:
                return Response(
                    {
                        "detail": (
                            "Only hotel users can verify their payments."
                        )
                    },
                    status=status.HTTP_403_FORBIDDEN,
                )

            if not request.user.is_active:
                return Response(
                    {"detail": "Your account is inactive."},
                    status=status.HTTP_403_FORBIDDEN,
                )

            if not hasattr(request.user, "hotel"):
                return Response(
                    {
                        "detail": (
                            "Your account is not linked to a hotel."
                        )
                    },
                    status=status.HTTP_403_FORBIDDEN,
                )

            if order.hotel_id != request.user.hotel.id:
                return Response(
                    {
                        "detail": (
                            "You cannot verify another hotel's payment."
                        )
                    },
                    status=status.HTTP_403_FORBIDDEN,
                )

            if order.status in (
                Order.Status.REJECTED,
                Order.Status.CANCELLED,
            ):
                return Response(
                    {
                        "detail": (
                            "Payment cannot be verified for a "
                            "rejected or cancelled order."
                        )
                    },
                    status=status.HTTP_400_BAD_REQUEST,
                )

            payments = list(
                Payment.objects.select_for_update()
                .filter(order=order)
                .order_by("pk")
            )

            if len(payments) != 1:
                return Response(
                    {
                        "detail": (
                            "Expected exactly one payment record "
                            "for this order."
                        )
                    },
                    status=status.HTTP_400_BAD_REQUEST,
                )

            payment = payments[0]

            if payment.method != Payment.Method.UPI:
                return Response(
                    {
                        "detail": (
                            "Only UPI payments can be verified here."
                        )
                    },
                    status=status.HTTP_400_BAD_REQUEST,
                )

            # Ensure the Razorpay Order ID matches the database record.
            if payment.link_id != razorpay_order_id:
                return Response(
                    {
                        "detail": (
                            "Razorpay Order ID does not match this order."
                        )
                    },
                    status=status.HTTP_400_BAD_REQUEST,
                )

            # Verify that Razorpay associates the payment with this order.
            if razorpay_payment.get("order_id") != razorpay_order_id:
                return Response(
                    {
                        "detail": (
                            "Razorpay payment belongs to a different order."
                        )
                    },
                    status=status.HTTP_400_BAD_REQUEST,
                )

            # Ensure that Razorpay has captured the payment.
            if razorpay_payment.get("status") != "captured":
                return Response(
                    {
                        "detail": (
                            "Payment has not been captured successfully."
                        )
                    },
                    status=status.HTTP_400_BAD_REQUEST,
                )

            # Ensure that the payment amount matches the database amount.
            expected_amount = int(
                payment.amount * Decimal("100")
            )

            if razorpay_payment.get("amount") != expected_amount:
                return Response(
                    {
                        "detail": (
                            "Razorpay payment amount does not match "
                            "the order amount."
                        )
                    },
                    status=status.HTTP_400_BAD_REQUEST,
                )

            # Ensure that the payment currency is INR.
            if razorpay_payment.get("currency") != "INR":
                return Response(
                    {
                        "detail": (
                            "Razorpay payment currency must be INR."
                        )
                    },
                    status=status.HTTP_400_BAD_REQUEST,
                )

            # Handle repeated verification requests safely.
            if payment.status == Payment.Status.PAID:
                if payment.payment_id == razorpay_payment_id:
                    return Response(
                        {
                            "message": (
                                "Payment has already been verified."
                            ),
                            "order_id": order.pk,
                            "order_no": order.order_no,
                            "payment_status": payment.status,
                            "order_payment_status": order.payment_status,
                        },
                        status=status.HTTP_200_OK,
                    )

                return Response(
                    {
                        "detail": (
                            "A different payment is already recorded "
                            "for this order."
                        )
                    },
                    status=status.HTTP_400_BAD_REQUEST,
                )

            if payment.status != Payment.Status.PENDING:
                return Response(
                    {
                        "detail": (
                            "Only pending payments can be verified."
                        )
                    },
                    status=status.HTTP_400_BAD_REQUEST,
                )

            # Record the successfully captured payment.
            payment.payment_id = razorpay_payment_id
            payment.status = Payment.Status.PAID
            payment.confirmed_by = request.user
            payment.paid_at = timezone.now()

            payment.save(
                update_fields=[
                    "payment_id",
                    "status",
                    "confirmed_by",
                    "paid_at",
                    "updated_at",
                ]
            )

            order.payment_status = Order.PaymentStatus.PAID

            order.save(
                update_fields=[
                    "payment_status",
                    "updated_at",
                ]
            )

        return Response(
            {
                "message": "Razorpay payment verified successfully.",
                "order_id": order.pk,
                "order_no": order.order_no,
                "razorpay_order_id": razorpay_order_id,
                "razorpay_payment_id": payment.payment_id,
                "amount": str(payment.amount),
                "currency": "INR",
                "payment_status": payment.status,
                "order_payment_status": order.payment_status,
                "paid_at": payment.paid_at,
            },
            status=status.HTTP_200_OK,
        )

class RazorpayOrderCreateView(APIView):
    """
    Create a Razorpay order for an existing pending UPI payment.
    """

    permission_classes = [IsAuthenticated]

    def post(self, request, pk):
        with transaction.atomic():
            order = get_object_or_404(
                Order.objects.select_for_update(),
                pk=pk,
            )

            # Only hotel users can initiate payment for their own orders.
            if request.user.role != User.Role.HOTEL:
                return Response(
                    {"detail": "Only hotel users can initiate payments."},
                    status=status.HTTP_403_FORBIDDEN,
                )

            if not request.user.is_active:
                return Response(
                    {"detail": "Your account is inactive."},
                    status=status.HTTP_403_FORBIDDEN,
                )

            if not hasattr(request.user, "hotel"):
                return Response(
                    {"detail": "Your account is not linked to a hotel."},
                    status=status.HTTP_403_FORBIDDEN,
                )

            if order.hotel_id != request.user.hotel.id:
                return Response(
                    {"detail": "You cannot pay for another hotel's order."},
                    status=status.HTTP_403_FORBIDDEN,
                )

            if order.status != Order.Status.PENDING:
                return Response(
                    {"detail": "Only pending orders can be paid."},
                    status=status.HTTP_400_BAD_REQUEST,
                )

            payments = list(
                Payment.objects.select_for_update()
                .filter(order=order)
                .order_by("pk")
            )

            if len(payments) != 1:
                return Response(
                    {
                        "detail": (
                            "Expected exactly one payment record "
                            "for this order."
                        )
                    },
                    status=status.HTTP_400_BAD_REQUEST,
                )

            payment = payments[0]

            if payment.method != Payment.Method.UPI:
                return Response(
                    {"detail": "Razorpay is available only for UPI orders."},
                    status=status.HTTP_400_BAD_REQUEST,
                )

            if payment.status != Payment.Status.PENDING:
                return Response(
                    {"detail": "This payment is not pending."},
                    status=status.HTTP_400_BAD_REQUEST,
                )

            if not settings.RAZORPAY_KEY_ID or not settings.RAZORPAY_KEY_SECRET:
                return Response(
                    {"detail": "Razorpay is not configured on the server."},
                    status=status.HTTP_503_SERVICE_UNAVAILABLE,
                )

            # Reuse an existing Razorpay order ID when available.
            if payment.link_id:
                return Response(
                    {
                        "order_id": order.pk,
                        "order_no": order.order_no,
                        "razorpay_order_id": payment.link_id,
                        "razorpay_key_id": settings.RAZORPAY_KEY_ID,
                        "amount": int(payment.amount * Decimal("100")),
                        "currency": "INR",
                    },
                    status=status.HTTP_200_OK,
                )

            try:
                client = razorpay.Client(
                    auth=(
                        settings.RAZORPAY_KEY_ID,
                        settings.RAZORPAY_KEY_SECRET,
                    )
                )

                razorpay_order = client.order.create(
                    {
                        "amount": int(payment.amount * Decimal("100")),
                        "currency": "INR",
                        "receipt": str(order.order_no)[:40],
                        "notes": {
                            "internal_order_id": str(order.pk),
                            "order_no": str(order.order_no),
                        },
                    }
                )

            except Exception:
                return Response(
                    {
                        "detail": (
                            "Unable to create a Razorpay order. "
                            "Please try again."
                        )
                    },
                    status=status.HTTP_502_BAD_GATEWAY,
                )

            payment.link_id = razorpay_order["id"]
            payment.save(update_fields=["link_id", "updated_at"])

        return Response(
            {
                "order_id": order.pk,
                "order_no": order.order_no,
                "razorpay_order_id": razorpay_order["id"],
                "razorpay_key_id": settings.RAZORPAY_KEY_ID,
                "amount": razorpay_order["amount"],
                "currency": razorpay_order["currency"],
            },
            status=status.HTTP_201_CREATED,
        )