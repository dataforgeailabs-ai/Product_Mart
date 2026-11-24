import uuid
import logging
from decimal import Decimal

import razorpay

from django.conf import settings
from django.db import transaction
from django.db.models import Prefetch
from django.shortcuts import get_object_or_404
from django.utils import timezone

from rest_framework import generics, status
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from accounts.models import User
from cart.models import Cart, CartItem
from food.models import FoodItem
from products.models import Product, StockHistory

from .models import (
    Checkout,
    Order,
    OrderItem,
    OrderStatusHistory,
    Payment,
    RefundRequest,
)

from .serializers import (
    OrderSerializer,
    CheckoutSerializer,
    CheckoutDetailSerializer,
    RefundRequestSerializer,
)

from .permissions import IsOrderManager


logger = logging.getLogger(__name__)


def razorpay_client():
    return razorpay.Client(
        auth=(
            settings.RAZORPAY_KEY_ID,
            settings.RAZORPAY_KEY_SECRET,
        )
    )


def order_queryset():
    return (
        Order.objects
        .select_related(
            "hotel",
            "seller_hotel",
            "placed_by",
            "checkout",
        )
        .prefetch_related(
            "items__product",
            "items__food_item",
            "status_history__changed_by",
            "payments",
        )
    )


def checkout_queryset():
    return (
        Checkout.objects
        .select_related(
            "customer_hotel",
            "placed_by",
            "assigned_delivery",
            "payment",
        )
        .prefetch_related(
            "orders__items__product",
            "orders__items__food_item",
            "orders__status_history__changed_by",
            "refund_requests",
        )
    )


def is_order_manager(user):
    return (
        user.is_authenticated
        and user.is_active
        and user.role in [
            User.Role.SUPERADMIN,
            User.Role.ADMIN,
        ]
    )


def is_customer(user):
    return (
        user.is_authenticated
        and user.is_active
        and user.role == User.Role.HOTEL
        and user.hotel_id is not None
        and user.hotel.status == "ACTIVE"
    )


def add_order_history(order, user, remarks=""):
    OrderStatusHistory.objects.create(
        order=order,
        status=order.status,
        changed_by=user,
        remarks=remarks,
    )


def update_checkout_readiness(checkout, user):
    """
    Checkout becomes READY when every non-rejected order
    has reached its preparation/packing completion state.
    """

    orders = list(checkout.orders.all())

    active_orders = [
        order for order in orders
        if order.status not in [
            Order.Status.REJECTED,
            Order.Status.CANCELLED,
        ]
    ]

    if not active_orders:
        return

    for order in active_orders:
        if order.order_type == Order.OrderType.PRODUCT:
            if order.status != Order.Status.PACKED:
                return

        elif order.order_type == Order.OrderType.FOOD:
            if order.status != Order.Status.READY:
                return

    checkout.delivery_status = Checkout.DeliveryStatus.READY
    checkout.save(update_fields=[
        "delivery_status",
        "updated_at",
    ])


# =========================================================
# ORDER LIST
# =========================================================

class OrderListView(generics.ListAPIView):

    serializer_class = OrderSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        user = self.request.user
        queryset = order_queryset()

        if is_order_manager(user):
            return queryset

        if is_customer(user):
            return queryset.filter(hotel_id=user.hotel_id)

        if (
            user.role == User.Role.DELIVERY
            and user.is_active
        ):
            return queryset.filter(
                checkout__assigned_delivery=user,
                checkout__delivery_status=(
                    Checkout.DeliveryStatus.OUT_FOR_DELIVERY
                ),
            )

        return queryset.none()


# =========================================================
# ORDER DETAIL
# =========================================================

class OrderDetailView(generics.RetrieveAPIView):

    serializer_class = OrderSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        user = self.request.user
        queryset = order_queryset()

        if is_order_manager(user):
            return queryset

        if is_customer(user):
            return queryset.filter(hotel_id=user.hotel_id)

        if user.role == User.Role.DELIVERY and user.is_active:
            return queryset.filter(
                checkout__assigned_delivery=user,
                checkout__delivery_status=(
                    Checkout.DeliveryStatus.OUT_FOR_DELIVERY
                ),
            )

        return queryset.none()


# =========================================================
# CHECKOUT
# =========================================================

class CheckoutView(APIView):

    permission_classes = [IsAuthenticated]

    def post(self, request):

        serializer = CheckoutSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        user = request.user

        if not is_customer(user):
            return Response(
                {"detail": "Only active customer accounts can place orders."},
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
                    CartItem.objects
                    .filter(cart=cart)
                    .select_related(
                        "product",
                        "food_item",
                        "food_item__hotel",
                    )
                    .order_by("pk")
                )

                if not cart_items:
                    return Response(
                        {"detail": "Your cart is empty."},
                        status=status.HTTP_400_BAD_REQUEST,
                    )

                product_ids = [
                    item.product_id
                    for item in cart_items
                    if item.item_type == "PRODUCT"
                ]

                food_ids = [
                    item.food_item_id
                    for item in cart_items
                    if item.item_type == "FOOD"
                ]

                products = {
                    product.pk: product
                    for product in Product.objects
                    .select_for_update()
                    .filter(pk__in=product_ids)
                    .order_by("pk")
                }

                food_items = {
                    food.pk: food
                    for food in FoodItem.objects
                    .select_for_update()
                    .select_related("hotel")
                    .filter(pk__in=food_ids)
                    .order_by("pk")
                }

                product_lines = []
                food_groups = {}

                subtotal = Decimal("0.00")

                for cart_item in cart_items:

                    quantity = cart_item.quantity

                    if cart_item.item_type == "PRODUCT":

                        product = products.get(cart_item.product_id)

                        if product is None or not product.is_active:
                            return Response(
                                {"detail": "A product is unavailable."},
                                status=status.HTTP_400_BAD_REQUEST,
                            )

                        if quantity < product.minimum_order_quantity:
                            return Response(
                                {
                                    "detail": (
                                        f"Minimum quantity for {product.name} "
                                        f"is {product.minimum_order_quantity}."
                                    )
                                },
                                status=status.HTTP_400_BAD_REQUEST,
                            )

                        if quantity > product.stock_quantity:
                            return Response(
                                {
                                    "detail": (
                                        f"Insufficient stock for {product.name}."
                                    )
                                },
                                status=status.HTTP_400_BAD_REQUEST,
                            )

                        line_total = product.price * quantity

                        product_lines.append({
                            "product": product,
                            "quantity": quantity,
                            "unit_price": product.price,
                            "line_total": line_total,
                        })

                    elif cart_item.item_type == "FOOD":

                        food = food_items.get(cart_item.food_item_id)

                        if (
                            food is None
                            or not food.is_active
                            or not food.is_available
                        ):
                            return Response(
                                {"detail": "A food item is unavailable."},
                                status=status.HTTP_400_BAD_REQUEST,
                            )

                        if food.hotel.status != "ACTIVE":
                            return Response(
                                {
                                    "detail": (
                                        f"The seller of {food.name} "
                                        "is currently inactive."
                                    )
                                },
                                status=status.HTTP_400_BAD_REQUEST,
                            )

                        line_total = food.price * quantity

                        food_groups.setdefault(
                            food.hotel_id,
                            {
                                "hotel": food.hotel,
                                "items": [],
                            },
                        )["items"].append({
                            "food_item": food,
                            "quantity": quantity,
                            "unit_price": food.price,
                            "line_total": line_total,
                        })

                    else:
                        return Response(
                            {"detail": "Invalid cart item type."},
                            status=status.HTTP_400_BAD_REQUEST,
                        )

                    subtotal += line_total

                tax = Decimal("0.00")
                delivery_charge = Decimal("0.00")
                total = subtotal + tax + delivery_charge

                checkout = Checkout.objects.create(
                    checkout_no=f"CHK-{uuid.uuid4().hex[:12].upper()}",
                    customer_hotel=user.hotel,
                    placed_by=user,
                    subtotal=subtotal,
                    tax=tax,
                    delivery_charge=delivery_charge,
                    total=total,
                    collectable_amount=total,
                    payment_status=Checkout.PaymentStatus.PENDING,
                    delivery_status=Checkout.DeliveryStatus.PENDING,
                )

                # PRODUCT ORDER

                if product_lines:

                    product_total = sum(
                        (item["line_total"] for item in product_lines),
                        Decimal("0.00"),
                    )

                    product_order = Order.objects.create(
                        order_no=f"ORD-{uuid.uuid4().hex[:12].upper()}",
                        checkout=checkout,
                        order_type=Order.OrderType.PRODUCT,
                        hotel=user.hotel,
                        placed_by=user,
                        subtotal=product_total,
                        total=product_total,
                        status=Order.Status.PENDING,
                        payment_status=Order.PaymentStatus.PENDING,
                        notes=notes,
                    )

                    OrderItem.objects.bulk_create([
                        OrderItem(
                            order=product_order,
                            product=item["product"],
                            quantity=item["quantity"],
                            unit_price=item["unit_price"],
                            line_total=item["line_total"],
                        )
                        for item in product_lines
                    ])

                    add_order_history(
                        product_order,
                        user,
                        "Product order created.",
                    )

                # FOOD ORDERS

                for group in food_groups.values():

                    seller = group["hotel"]
                    lines = group["items"]

                    food_total = sum(
                        (item["line_total"] for item in lines),
                        Decimal("0.00"),
                    )

                    food_order = Order.objects.create(
                        order_no=f"ORD-{uuid.uuid4().hex[:12].upper()}",
                        checkout=checkout,
                        order_type=Order.OrderType.FOOD,
                        hotel=user.hotel,
                        seller_hotel=seller,
                        placed_by=user,
                        subtotal=food_total,
                        total=food_total,
                        status=Order.Status.PENDING,
                        payment_status=Order.PaymentStatus.PENDING,
                        notes=notes,
                    )

                    OrderItem.objects.bulk_create([
                        OrderItem(
                            order=food_order,
                            food_item=item["food_item"],
                            quantity=item["quantity"],
                            unit_price=item["unit_price"],
                            line_total=item["line_total"],
                        )
                        for item in lines
                    ])

                    add_order_history(
                        food_order,
                        user,
                        f"Food order created for {seller.name}.",
                    )

                Payment.objects.create(
                    checkout=checkout,
                    method=payment_method,
                    amount=total,
                    status=Payment.Status.PENDING,
                )

                CartItem.objects.filter(cart=cart).delete()

                checkout = checkout_queryset().get(pk=checkout.pk)

                response_data = CheckoutDetailSerializer(
                    checkout,
                    context={"request": request},
                ).data

            return Response(
                {
                    "message": "Checkout created successfully.",
                    "checkout": response_data,
                },
                status=status.HTTP_201_CREATED,
            )

        except Exception:
            logger.exception("Checkout failed for user %s", user.pk)

            return Response(
                {"detail": "Unable to create checkout."},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR,
            )


# =========================================================
# CHECKOUT DETAIL
# =========================================================

class CheckoutDetailView(generics.RetrieveAPIView):

    serializer_class = CheckoutDetailSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        user = self.request.user
        queryset = checkout_queryset()

        if is_order_manager(user):
            return queryset

        if is_customer(user):
            return queryset.filter(customer_hotel_id=user.hotel_id)

        if user.role == User.Role.DELIVERY and user.is_active:
            return queryset.filter(assigned_delivery=user)

        return queryset.none()

class CheckoutMyDeliveriesView(APIView):

    permission_classes = [IsAuthenticated]

    def get(self, request):

        user = request.user

        if (
            user.role != User.Role.DELIVERY
            or not user.is_active
        ):
            return Response(
                {"detail": "Only active delivery users can access this endpoint."},
                status=status.HTTP_403_FORBIDDEN,
            )

        delivery_status = request.query_params.get(
            "status",
            Checkout.DeliveryStatus.OUT_FOR_DELIVERY,
        )

        allowed_statuses = [
            Checkout.DeliveryStatus.OUT_FOR_DELIVERY,
            Checkout.DeliveryStatus.DELIVERED,
        ]

        if delivery_status not in allowed_statuses:
            return Response(
                {"detail": "Invalid delivery status filter."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        checkouts = checkout_queryset().filter(
            assigned_delivery=user,
            delivery_status=delivery_status,
        ).order_by("-created_at")

        serializer = CheckoutDetailSerializer(
            checkouts,
            many=True,
            context={"request": request},
        )

        return Response(
            {
                "count": checkouts.count(),
                "results": serializer.data,
            },
            status=status.HTTP_200_OK,
        )


# =========================================================
# ORDER CONFIRMATION
# =========================================================

class OrderConfirmationView(APIView):

    permission_classes = [IsAuthenticated, IsOrderManager]

    def post(self, request, pk):

        try:
            with transaction.atomic():

                order = get_object_or_404(
                    Order.objects.select_for_update(),
                    pk=pk,
                )

                if order.status != Order.Status.PENDING:
                    return Response(
                        {"detail": "Only pending orders can be confirmed."},
                        status=status.HTTP_400_BAD_REQUEST,
                    )

                if order.checkout_id:
                    payment = get_object_or_404(
                        Payment.objects.select_for_update(),
                        checkout_id=order.checkout_id,
                    )
                else:
                    payment = get_object_or_404(
                        Payment.objects.select_for_update(),
                        order=order,
                    )

                if payment.method == Payment.Method.UPI:
                    if payment.status != Payment.Status.PAID:
                        return Response(
                            {"detail": "UPI payment has not been verified."},
                            status=status.HTTP_400_BAD_REQUEST,
                        )

                elif payment.method == Payment.Method.COD:
                    if payment.status != Payment.Status.PENDING:
                        return Response(
                            {"detail": "COD payment is not pending."},
                            status=status.HTTP_400_BAD_REQUEST,
                        )

                items = list(
                    order.items.select_related(
                        "product",
                        "food_item",
                        "food_item__hotel",
                    ).order_by("pk")
                )

                if not items:
                    return Response(
                        {"detail": "Order has no items."},
                        status=status.HTTP_400_BAD_REQUEST,
                    )

                if order.order_type == Order.OrderType.PRODUCT:

                    product_ids = [
                        item.product_id for item in items
                    ]

                    if any(product_id is None for product_id in product_ids):
                        return Response(
                            {"detail": "Invalid product order items."},
                            status=status.HTTP_400_BAD_REQUEST,
                        )

                    products = {
                        product.pk: product
                        for product in Product.objects
                        .select_for_update()
                        .filter(pk__in=product_ids)
                        .order_by("pk")
                    }

                    for item in items:

                        product = products.get(item.product_id)

                        if product is None or not product.is_active:
                            return Response(
                                {
                                    "detail": (
                                        f"Product {item.product_id} "
                                        "is unavailable."
                                    )
                                },
                                status=status.HTTP_400_BAD_REQUEST,
                            )

                        if product.stock_quantity < item.quantity:
                            return Response(
                                {
                                    "detail": (
                                        f"Insufficient stock for {product.name}."
                                    )
                                },
                                status=status.HTTP_400_BAD_REQUEST,
                            )

                    for item in items:

                        product = products[item.product_id]
                        product.stock_quantity -= item.quantity

                        product.save(update_fields=["stock_quantity"])

                        StockHistory.objects.create(
                            product=product,
                            change=-item.quantity,
                            reason=StockHistory.Reason.ORDER_CONFIRMED,
                            order=order,
                            created_by=request.user,
                        )

                elif order.order_type == Order.OrderType.FOOD:

                    food_ids = [
                        item.food_item_id for item in items
                    ]

                    if any(food_id is None for food_id in food_ids):
                        return Response(
                            {"detail": "Invalid food order items."},
                            status=status.HTTP_400_BAD_REQUEST,
                        )

                    foods = {
                        food.pk: food
                        for food in FoodItem.objects
                        .select_for_update()
                        .select_related("hotel")
                        .filter(pk__in=food_ids)
                        .order_by("pk")
                    }

                    for item in items:

                        food = foods.get(item.food_item_id)

                        if (
                            food is None
                            or not food.is_active
                            or not food.is_available
                        ):
                            return Response(
                                {
                                    "detail": (
                                        f"Food item {item.food_item_id} "
                                        "is unavailable."
                                    )
                                },
                                status=status.HTTP_400_BAD_REQUEST,
                            )

                        if food.hotel.status != "ACTIVE":
                            return Response(
                                {"detail": "Food seller is inactive."},
                                status=status.HTTP_400_BAD_REQUEST,
                            )

                        if (
                            order.seller_hotel_id
                            and food.hotel_id != order.seller_hotel_id
                        ):
                            return Response(
                                {"detail": "Food seller does not match order."},
                                status=status.HTTP_400_BAD_REQUEST,
                            )

                else:
                    return Response(
                        {"detail": "Unsupported order type."},
                        status=status.HTTP_400_BAD_REQUEST,
                    )

                order.status = Order.Status.CONFIRMED
                order.payment_status = (
                    Order.PaymentStatus.PAID
                    if payment.status == Payment.Status.PAID
                    else Order.PaymentStatus.PENDING
                )

                order.save(update_fields=[
                    "status",
                    "payment_status",
                    "updated_at",
                ])

                add_order_history(
                    order,
                    request.user,
                    "Order confirmed.",
                )

            return Response(
                {
                    "message": "Order confirmed successfully.",
                    "order_id": order.pk,
                    "order_no": order.order_no,
                    "status": order.status,
                },
                status=status.HTTP_200_OK,
            )

        except Exception:
            logger.exception("Order confirmation failed: %s", pk)

            return Response(
                {"detail": "Unable to confirm order."},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR,
            )


# =========================================================
# ORDER REJECTION AND REFUND REQUEST
# =========================================================

class OrderRejectionView(APIView):

    permission_classes = [IsAuthenticated, IsOrderManager]

    def post(self, request, pk):

        try:
            with transaction.atomic():

                order = get_object_or_404(
                    Order.objects.select_for_update(),
                    pk=pk,
                )

                if order.status != Order.Status.PENDING:
                    return Response(
                        {"detail": "Only pending orders can be rejected."},
                        status=status.HTTP_400_BAD_REQUEST,
                    )

                checkout = None
                payment = None

                if order.checkout_id:

                    checkout = Checkout.objects.select_for_update().get(
                        pk=order.checkout_id
                    )

                    payment = Payment.objects.select_for_update().get(
                        checkout=checkout
                    )

                else:

                    payment = Payment.objects.filter(
                        order=order
                    ).first()

                remarks = request.data.get(
                    "remarks",
                    "Order rejected by administrator.",
                )

                # Mark order as rejected
                order.status = Order.Status.REJECTED

                order.save(
                    update_fields=["status", "updated_at"]
                )

                # Record order history
                add_order_history(
                    order,
                    request.user,
                    remarks,
                )

                refund_request = None

                # Handle payment adjustments
                if checkout and payment:

                    if order.order_type == Order.OrderType.FOOD:

                        # UPI refund request
                        if payment.method == Payment.Method.UPI:

                            if payment.status == Payment.Status.PAID:

                                refund_request = RefundRequest.objects.create(
                                    checkout=checkout,
                                    order=order,
                                    payment=payment,
                                    amount=order.total,
                                    reason=remarks,
                                    requested_by=request.user,
                                )

                        # COD collectable amount adjustment
                        elif payment.method == Payment.Method.COD:

                            if (
                                payment.status == Payment.Status.PENDING
                                and checkout.payment_status
                                != Checkout.PaymentStatus.CASH_RECEIVED
                            ):

                                checkout.collectable_amount = max(
                                    Decimal("0.00"),
                                    checkout.collectable_amount - order.total,
                                )

                                checkout.save(
                                    update_fields=[
                                        "collectable_amount",
                                        "updated_at",
                                    ]
                                )

                # Recalculate checkout readiness
                if checkout:

                    update_checkout_readiness(
                        checkout,
                        request.user,
                    )

                return Response(
                    {
                        "message": "Order rejected successfully.",
                        "order_id": order.pk,
                        "refund_request": (
                            RefundRequestSerializer(refund_request).data
                            if refund_request
                            else None
                        ),
                    },
                    status=status.HTTP_200_OK,
                )

        except Exception:
            logger.exception(
                "Order rejection failed: %s",
                pk,
            )

            return Response(
                {"detail": "Unable to reject order."},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR,
            )


# =========================================================
# REFUND REQUEST LIST
# =========================================================

class RefundRequestListView(generics.ListAPIView):

    serializer_class = RefundRequestSerializer
    permission_classes = [IsAuthenticated, IsOrderManager]

    queryset = RefundRequest.objects.select_related(
        "checkout",
        "order",
        "payment",
        "requested_by",
        "reviewed_by",
    ).all()


# =========================================================
# REFUND APPROVAL AND RAZORPAY REFUND
# =========================================================

class RefundApprovalView(APIView):

    permission_classes = [IsAuthenticated, IsOrderManager]

    def post(self, request, pk):

        try:
            with transaction.atomic():

                refund = get_object_or_404(
                    RefundRequest.objects.select_for_update().select_related(
                        "payment",
                        "checkout",
                        "order",
                    ),
                    pk=pk,
                )

                if refund.status != RefundRequest.Status.PENDING:
                    return Response(
                        {"detail": "Refund is not awaiting approval."},
                        status=status.HTTP_400_BAD_REQUEST,
                    )

                # Reject refund request
                if request.data.get("approved") is not True:

                    refund.status = RefundRequest.Status.REJECTED
                    refund.reviewed_by = request.user

                    refund.save(update_fields=[
                        "status",
                        "reviewed_by",
                        "updated_at",
                    ])

                    return Response(
                        {"message": "Refund request rejected."},
                        status=status.HTTP_200_OK,
                    )

                checkout = Checkout.objects.select_for_update().get(
                    pk=refund.checkout_id
                )

                payment = Payment.objects.select_for_update().get(
                    checkout=checkout
                )

                if payment.method != Payment.Method.UPI:
                    return Response(
                        {"detail": "Only UPI payments can be refunded."},
                        status=status.HTTP_400_BAD_REQUEST,
                    )

                if payment.status not in [
                    Payment.Status.PAID,
                    Payment.Status.PARTIALLY_REFUNDED,
                ]:
                    return Response(
                        {"detail": "Payment is not eligible for refund."},
                        status=status.HTTP_400_BAD_REQUEST,
                    )

                if not payment.payment_id:
                    return Response(
                        {"detail": "Razorpay payment ID is missing."},
                        status=status.HTTP_400_BAD_REQUEST,
                    )

                if refund.amount <= Decimal("0.00"):
                    return Response(
                        {"detail": "Invalid refund amount."},
                        status=status.HTTP_400_BAD_REQUEST,
                    )

                # Calculate already processed and reserved refunds
                existing_refunds = RefundRequest.objects.filter(
                    checkout=checkout,
                    status__in=[
                        RefundRequest.Status.PROCESSED,
                        RefundRequest.Status.PROCESSING,
                    ],
                ).exclude(pk=refund.pk)

                reserved_amount = sum(
                    (item.amount for item in existing_refunds),
                    Decimal("0.00"),
                )

                remaining_amount = checkout.total - reserved_amount

                if refund.amount > remaining_amount:
                    return Response(
                        {
                            "detail": (
                                "Refund amount exceeds the remaining "
                                "refundable checkout balance."
                            )
                        },
                        status=status.HTTP_400_BAD_REQUEST,
                    )

                # Mark refund as processing before contacting Razorpay
                refund.status = RefundRequest.Status.PROCESSING
                refund.reviewed_by = request.user

                refund.save(update_fields=[
                    "status",
                    "reviewed_by",
                    "updated_at",
                ])

                payment_id = payment.payment_id
                amount_paise = int(refund.amount * 100)

            # Call Razorpay outside the database transaction
            result = razorpay_client().payment.refund(
                payment_id,
                {
                    "amount": amount_paise,
                    "notes": {
                        "refund_request_id": str(refund.pk),
                        "order_no": refund.order.order_no,
                    },
                },
            )

            razorpay_refund_status = result.get("status")
            razorpay_refund_id = result.get("id")

            with transaction.atomic():

                refund = RefundRequest.objects.select_for_update().get(
                    pk=pk
                )

                refund.razorpay_refund_id = razorpay_refund_id or ""

                if razorpay_refund_status == "processed":

                    refund.status = RefundRequest.Status.PROCESSED
                    refund.processed_at = timezone.now()

                elif razorpay_refund_status == "pending":

                    refund.status = RefundRequest.Status.PROCESSING

                else:

                    logger.warning(
                        "Unexpected Razorpay refund status for request %s: %s",
                        pk,
                        razorpay_refund_status,
                    )

                    refund.status = RefundRequest.Status.PROCESSING

                refund.save(update_fields=[
                    "razorpay_refund_id",
                    "status",
                    "processed_at",
                    "updated_at",
                ])

                checkout = Checkout.objects.select_for_update().get(
                    pk=refund.checkout_id
                )

                payment = Payment.objects.select_for_update().get(
                    checkout=checkout
                )

                # Only processed refunds count as completed refunds
                completed_refunds = RefundRequest.objects.filter(
                    checkout=checkout,
                    status=RefundRequest.Status.PROCESSED,
                )

                refunded_total = sum(
                    (item.amount for item in completed_refunds),
                    Decimal("0.00"),
                )

                if refunded_total >= checkout.total:
                    checkout.payment_status = (
                        Checkout.PaymentStatus.REFUNDED
                    )

                    payment.status = Payment.Status.REFUNDED

                elif refunded_total > 0:
                    checkout.payment_status = (
                        Checkout.PaymentStatus.PARTIALLY_REFUNDED
                    )

                    payment.status = Payment.Status.PARTIALLY_REFUNDED

                checkout.save(update_fields=[
                    "payment_status",
                    "updated_at",
                ])

                payment.save(update_fields=[
                    "status",
                    "updated_at",
                ])

                # Update the individual order payment status
                if refund.status == RefundRequest.Status.PROCESSED:

                    if refund.amount >= refund.order.total:
                        refund.order.payment_status = (
                            Order.PaymentStatus.REFUNDED
                        )
                    else:
                        refund.order.payment_status = (
                            Order.PaymentStatus.PARTIALLY_REFUNDED
                        )

                    refund.order.save(update_fields=[
                        "payment_status",
                        "updated_at",
                    ])

            if razorpay_refund_status == "processed":

                return Response(
                    {
                        "message": "Refund processed successfully.",
                        "refund_id": razorpay_refund_id,
                        "status": refund.status,
                    },
                    status=status.HTTP_200_OK,
                )

            return Response(
                {
                    "message": (
                        "Refund submitted to Razorpay. "
                        "Final processing is still pending."
                    ),
                    "refund_id": razorpay_refund_id,
                    "status": refund.status,
                },
                status=status.HTTP_202_ACCEPTED,
            )

        except Exception:

            logger.exception(
                "Refund processing failed: %s",
                pk,
            )

            # Keep PROCESSING because a network failure may occur
            # after Razorpay has already accepted the refund.
            # Verify the Razorpay dashboard before retrying.

            return Response(
                {
                    "detail": (
                        "Unable to confirm refund processing. "
                        "Check the Razorpay dashboard before retrying."
                    )
                },
                status=status.HTTP_502_BAD_GATEWAY,
            )


# =========================================================
# CHECKOUT DELIVERY ASSIGNMENT
# =========================================================

class CheckoutDeliveryAssignmentView(APIView):

    permission_classes = [IsAuthenticated, IsOrderManager]

    def post(self, request, pk):

        delivery_user_id = request.data.get("delivery_user_id")

        if not delivery_user_id:
            return Response(
                {"detail": "delivery_user_id is required."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        with transaction.atomic():

            checkout = get_object_or_404(
                Checkout.objects.select_for_update(),
                pk=pk,
            )

            if checkout.delivery_status != Checkout.DeliveryStatus.READY:
                return Response(
                    {"detail": "Checkout is not ready for delivery."},
                    status=status.HTTP_400_BAD_REQUEST,
                )

            delivery_user = get_object_or_404(
                User,
                pk=delivery_user_id,
                role=User.Role.DELIVERY,
                is_active=True,
            )

            checkout.assigned_delivery = delivery_user

            checkout.save(update_fields=[
                "assigned_delivery",
                "updated_at",
            ])

        return Response(
            {
                "message": "Delivery person assigned.",
                "checkout_id": checkout.pk,
                "delivery_person": delivery_user.username,
            },
            status=status.HTTP_200_OK,
        )


# =========================================================
# CHECKOUT DELIVERY STATUS
# =========================================================

class CheckoutDeliveryStatusView(APIView):

    permission_classes = [IsAuthenticated]

    def post(self, request, pk):

        new_status = request.data.get("status")

        with transaction.atomic():

            checkout = get_object_or_404(
                Checkout.objects.select_for_update(),
                pk=pk,
            )

            user = request.user

            if new_status == Checkout.DeliveryStatus.OUT_FOR_DELIVERY:

                if not is_order_manager(user):
                    return Response(
                        {"detail": "Only administrators can dispatch orders."},
                        status=status.HTTP_403_FORBIDDEN,
                    )

                if checkout.delivery_status != Checkout.DeliveryStatus.READY:
                    return Response(
                        {"detail": "Checkout is not ready for dispatch."},
                        status=status.HTTP_400_BAD_REQUEST,
                    )

                if checkout.assigned_delivery_id is None:
                    return Response(
                        {"detail": "Assign a delivery person first."},
                        status=status.HTTP_400_BAD_REQUEST,
                    )

                checkout.delivery_status = (
                    Checkout.DeliveryStatus.OUT_FOR_DELIVERY
                )

                checkout.save(update_fields=[
                    "delivery_status",
                    "updated_at",
                ])

                checkout.orders.exclude(
                    status__in=[
                        Order.Status.REJECTED,
                        Order.Status.CANCELLED,
                    ]
                ).update(
                    status=Order.Status.OUT_FOR_DELIVERY,
                    updated_at=timezone.now(),
                )

                for order in checkout.orders.exclude(
                    status__in=[
                        Order.Status.REJECTED,
                        Order.Status.CANCELLED,
                    ]
                ):
                    add_order_history(
                        order,
                        user,
                        "Checkout dispatched for delivery.",
                    )

            elif new_status == Checkout.DeliveryStatus.DELIVERED:

                if (
                    user.role != User.Role.DELIVERY
                    or checkout.assigned_delivery_id != user.pk
                ):
                    return Response(
                        {"detail": "You are not assigned to this delivery."},
                        status=status.HTTP_403_FORBIDDEN,
                    )

                if (
                    checkout.delivery_status
                    != Checkout.DeliveryStatus.OUT_FOR_DELIVERY
                ):
                    return Response(
                        {"detail": "Checkout is not out for delivery."},
                        status=status.HTTP_400_BAD_REQUEST,
                    )

                payment = Payment.objects.select_for_update().get(
                    checkout=checkout
                )

                if payment.method == Payment.Method.COD:

                    if payment.status != Payment.Status.PENDING:
                        return Response(
                            {"detail": "COD payment is not pending."},
                            status=status.HTTP_400_BAD_REQUEST,
                        )

                    payment.status = Payment.Status.CASH_RECEIVED
                    payment.collected_amount = checkout.collectable_amount
                    payment.received_by = user
                    payment.received_at = timezone.now()
                    payment.confirmed_by = user
                    payment.paid_at = timezone.now()

                    payment.save()

                    checkout.payment_status = (
                        Checkout.PaymentStatus.CASH_RECEIVED
                    )

                checkout.delivery_status = Checkout.DeliveryStatus.DELIVERED
                checkout.delivered_at = timezone.now()
                checkout.delivery_remarks = request.data.get("remarks", "")

                checkout.save(update_fields=[
                    "delivery_status",
                    "delivered_at",
                    "delivery_remarks",
                    "payment_status",
                    "updated_at",
                ])

                checkout.orders.exclude(
                    status__in=[
                        Order.Status.REJECTED,
                        Order.Status.CANCELLED,
                    ]
                ).update(
                    status=Order.Status.DELIVERED,
                    updated_at=timezone.now(),
                )

                for order in checkout.orders.exclude(
                    status__in=[
                        Order.Status.REJECTED,
                        Order.Status.CANCELLED,
                    ]
                ):
                    if payment.method == Payment.Method.COD:
                        order.payment_status = (
                            Order.PaymentStatus.CASH_RECEIVED
                        )
                        order.save(update_fields=["payment_status"])

                    add_order_history(
                        order,
                        user,
                        "Order delivered.",
                    )

            else:
                return Response(
                    {"detail": "Invalid checkout delivery status."},
                    status=status.HTTP_400_BAD_REQUEST,
                )

        return Response(
            {
                "message": "Checkout delivery updated.",
                "checkout_id": checkout.pk,
                "delivery_status": checkout.delivery_status,
            },
            status=status.HTTP_200_OK,
        )


# =========================================================
# RAZORPAY ORDER CREATION - CHECKOUT
# =========================================================

class RazorpayOrderCreateView(APIView):

    permission_classes = [IsAuthenticated]

    def post(self, request, pk):

        try:
            with transaction.atomic():

                checkout = get_object_or_404(
                    Checkout.objects.select_for_update(),
                    pk=pk,
                )

                if not is_customer(request.user):
                    return Response(
                        {"detail": "Only customer accounts can pay."},
                        status=status.HTTP_403_FORBIDDEN,
                    )

                if checkout.placed_by_id != request.user.pk:
                    return Response(
                        {"detail": "You cannot pay for this checkout."},
                        status=status.HTTP_403_FORBIDDEN,
                    )

                payment = Payment.objects.select_for_update().get(
                    checkout=checkout
                )

                if payment.method != Payment.Method.UPI:
                    return Response(
                        {"detail": "This checkout does not use UPI."},
                        status=status.HTTP_400_BAD_REQUEST,
                    )

                if payment.status == Payment.Status.PAID:
                    return Response(
                        {"detail": "Payment is already completed."},
                        status=status.HTTP_400_BAD_REQUEST,
                    )

                if payment.link_id:
                    return Response(
                        {
                            "message": "Razorpay order already created.",
                            "razorpay_order_id": payment.link_id,
                            "amount": int(payment.amount * 100),
                            "currency": "INR",
                            "key": settings.RAZORPAY_KEY_ID,
                        },
                        status=status.HTTP_200_OK,
                    )

                razorpay_order = razorpay_client().order.create({
                    "amount": int(payment.amount * 100),
                    "currency": "INR",
                    "receipt": checkout.checkout_no,
                    "notes": {
                        "checkout_id": str(checkout.pk),
                        "checkout_no": checkout.checkout_no,
                    },
                })

                payment.link_id = razorpay_order["id"]
                payment.save(update_fields=["link_id", "updated_at"])

            return Response(
                {
                    "message": "Razorpay order created.",
                    "razorpay_order_id": razorpay_order["id"],
                    "amount": razorpay_order["amount"],
                    "currency": razorpay_order["currency"],
                    "key": settings.RAZORPAY_KEY_ID,
                },
                status=status.HTTP_201_CREATED,
            )

        except Exception:
            logger.exception("Razorpay order creation failed: %s", pk)

            return Response(
                {"detail": "Unable to create Razorpay order."},
                status=status.HTTP_502_BAD_GATEWAY,
            )


# =========================================================
# UPI PAYMENT VERIFICATION - CHECKOUT
# =========================================================

class UPIPaymentVerificationView(APIView):

    permission_classes = [IsAuthenticated]

    def post(self, request, pk):

        razorpay_order_id = request.data.get("razorpay_order_id")
        razorpay_payment_id = request.data.get("razorpay_payment_id")
        razorpay_signature = request.data.get("razorpay_signature")

        if not all([
            razorpay_order_id,
            razorpay_payment_id,
            razorpay_signature,
        ]):
            return Response(
                {"detail": "Missing Razorpay verification parameters."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        try:
            with transaction.atomic():

                checkout = get_object_or_404(
                    Checkout.objects.select_for_update(),
                    pk=pk,
                )

                if not is_customer(request.user):
                    return Response(
                        {"detail": "Only customer accounts can verify payment."},
                        status=status.HTTP_403_FORBIDDEN,
                    )

                if checkout.placed_by_id != request.user.pk:
                    return Response(
                        {"detail": "You cannot verify this checkout."},
                        status=status.HTTP_403_FORBIDDEN,
                    )

                payment = Payment.objects.select_for_update().get(
                    checkout=checkout
                )

                if payment.status == Payment.Status.PAID:
                    if payment.payment_id == razorpay_payment_id:
                        return Response(
                            {"message": "Payment already verified."},
                            status=status.HTTP_200_OK,
                        )

                    return Response(
                        {"detail": "This checkout is already paid."},
                        status=status.HTTP_400_BAD_REQUEST,
                    )

                if payment.link_id != razorpay_order_id:
                    return Response(
                        {"detail": "Razorpay order ID mismatch."},
                        status=status.HTTP_400_BAD_REQUEST,
                    )

                client = razorpay_client()

                client.utility.verify_payment_signature({
                    "razorpay_order_id": razorpay_order_id,
                    "razorpay_payment_id": razorpay_payment_id,
                    "razorpay_signature": razorpay_signature,
                })

                razorpay_payment = client.payment.fetch(
                    razorpay_payment_id
                )

                if razorpay_payment.get("status") != "captured":
                    return Response(
                        {"detail": "Payment has not been captured."},
                        status=status.HTTP_400_BAD_REQUEST,
                    )

                if int(razorpay_payment.get("amount", 0)) != int(
                    payment.amount * 100
                ):
                    return Response(
                        {"detail": "Payment amount mismatch."},
                        status=status.HTTP_400_BAD_REQUEST,
                    )

                if razorpay_payment.get("currency") != "INR":
                    return Response(
                        {"detail": "Invalid payment currency."},
                        status=status.HTTP_400_BAD_REQUEST,
                    )

                payment.payment_id = razorpay_payment_id
                payment.status = Payment.Status.PAID
                payment.paid_at = timezone.now()

                payment.save(update_fields=[
                    "payment_id",
                    "status",
                    "paid_at",
                    "updated_at",
                ])

                checkout.payment_status = Checkout.PaymentStatus.PAID
                checkout.save(update_fields=[
                    "payment_status",
                    "updated_at",
                ])

                checkout.orders.exclude(
                    status__in=[
                        Order.Status.REJECTED,
                        Order.Status.CANCELLED,
                    ]
                ).update(
                    payment_status=Order.PaymentStatus.PAID,
                    updated_at=timezone.now(),
                )

            return Response(
                {
                    "message": "Payment verified successfully.",
                    "checkout_id": checkout.pk,
                    "payment_id": razorpay_payment_id,
                    "payment_status": payment.status,
                },
                status=status.HTTP_200_OK,
            )

        except razorpay.errors.SignatureVerificationError:
            return Response(
                {"detail": "Invalid Razorpay payment signature."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        except Exception:
            logger.exception("Payment verification failed: %s", pk)

            return Response(
                {"detail": "Payment verification failed."},
                status=status.HTTP_502_BAD_GATEWAY,
            )


class OrderCancellationView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request, pk):
        with transaction.atomic():
            order = get_object_or_404(
                Order.objects.select_for_update(),
                pk=pk,
            )

            user = request.user
            manager = is_order_manager(user)

            customer = (
                is_customer(user)
                and order.hotel_id == user.hotel_id
            )

            if not manager and not customer:
                return Response(
                    {"detail": "You cannot cancel this order."},
                    status=status.HTTP_403_FORBIDDEN,
                )

            if order.status not in [
                Order.Status.PENDING,
                Order.Status.CONFIRMED,
            ]:
                return Response(
                    {
                        "detail": (
                            "Only pending or confirmed orders "
                            "can be cancelled."
                        )
                    },
                    status=status.HTTP_400_BAD_REQUEST,
                )

            checkout = None
            payment = None

            if order.checkout_id:
                checkout = Checkout.objects.select_for_update().get(
                    pk=order.checkout_id
                )

                payment = Payment.objects.select_for_update().filter(
                    checkout=checkout
                ).first()

                if payment is None:
                    return Response(
                        {"detail": "Checkout payment record not found."},
                        status=status.HTTP_400_BAD_REQUEST,
                    )
            else:
                payment = Payment.objects.select_for_update().filter(
                    order=order
                ).first()

            # Validate payment before modifying stock or order
            if payment:
                if (
                    payment.method == Payment.Method.COD
                    and payment.status == Payment.Status.CASH_RECEIVED
                ):
                    return Response(
                        {"detail": "COD payment has already been collected."},
                        status=status.HTTP_400_BAD_REQUEST,
                    )

                if (
                    payment.method == Payment.Method.UPI
                    and payment.status == Payment.Status.PAID
                ):
                    if checkout is None:
                        return Response(
                            {
                                "detail": (
                                    "Refund processing for legacy orders "
                                    "is not supported through checkout refunds."
                                )
                            },
                            status=status.HTTP_400_BAD_REQUEST,
                        )

                    if RefundRequest.objects.filter(order=order).exists():
                        return Response(
                            {
                                "detail": (
                                    "A refund request already exists "
                                    "for this order."
                                )
                            },
                            status=status.HTTP_400_BAD_REQUEST,
                        )

            # Restore product stock if order was confirmed
            if (
                order.status == Order.Status.CONFIRMED
                and order.order_type == Order.OrderType.PRODUCT
            ):
                items = list(
                    order.items.select_related("product").order_by("pk")
                )

                product_ids = [
                    item.product_id for item in items
                ]

                products = {
                    product.pk: product
                    for product in Product.objects
                    .select_for_update()
                    .filter(pk__in=product_ids)
                    .order_by("pk")
                }

                for item in items:
                    product = products.get(item.product_id)

                    if product is None:
                        continue

                    product.stock_quantity += item.quantity

                    product.save(
                        update_fields=["stock_quantity"]
                    )

                    StockHistory.objects.create(
                        product=product,
                        change=item.quantity,
                        reason=StockHistory.Reason.ORDER_CANCELLED,
                        order=order,
                        created_by=user,
                    )

            refund_request = None

            # Create ADMIN approval request for paid UPI orders
            if (
                checkout
                and payment
                and payment.method == Payment.Method.UPI
                and payment.status == Payment.Status.PAID
            ):
                refund_request = RefundRequest.objects.create(
                    checkout=checkout,
                    order=order,
                    payment=payment,
                    amount=order.total,
                    reason=request.data.get(
                        "remarks",
                        "Order cancelled.",
                    ),
                    requested_by=user,
                )

            # Reduce COD collection amount
            elif (
                checkout
                and payment
                and payment.method == Payment.Method.COD
                and payment.status == Payment.Status.PENDING
            ):
                checkout.collectable_amount = max(
                    Decimal("0.00"),
                    checkout.collectable_amount - order.total,
                )

                checkout.save(
                    update_fields=[
                        "collectable_amount",
                        "updated_at",
                    ]
                )

            # Cancel order
            order.status = Order.Status.CANCELLED

            order.save(
                update_fields=["status", "updated_at"]
            )

            add_order_history(
                order,
                user,
                request.data.get(
                    "remarks",
                    "Order cancelled.",
                ),
            )

            if checkout:
                update_checkout_readiness(checkout, user)

        return Response(
            {
                "message": "Order cancelled successfully.",
                "order_id": order.pk,
                "status": order.status,
                "refund_request": (
                    RefundRequestSerializer(refund_request).data
                    if refund_request
                    else None
                ),
            },
            status=status.HTTP_200_OK,
        )


class OrderStatusUpdateView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request, pk):
        with transaction.atomic():
            order = get_object_or_404(
                Order.objects.select_for_update().select_related(
                    "checkout"
                ),
                pk=pk,
            )

            user = request.user
            new_status = request.data.get("status")

            if not is_order_manager(user):
                return Response(
                    {
                        "detail": (
                            "Only administrators can update "
                            "preparation status."
                        )
                    },
                    status=status.HTTP_403_FORBIDDEN,
                )

            if order.status in [
                Order.Status.REJECTED,
                Order.Status.CANCELLED,
                Order.Status.DELIVERED,
            ]:
                return Response(
                    {"detail": "This order can no longer be updated."},
                    status=status.HTTP_400_BAD_REQUEST,
                )

            if order.order_type == Order.OrderType.PRODUCT:
                allowed = {
                    Order.Status.CONFIRMED: Order.Status.PACKED,
                }

            elif order.order_type == Order.OrderType.FOOD:
                allowed = {
                    Order.Status.CONFIRMED: Order.Status.PREPARING,
                    Order.Status.PREPARING: Order.Status.READY,
                }

            else:
                return Response(
                    {"detail": "Unsupported order type."},
                    status=status.HTTP_400_BAD_REQUEST,
                )

            expected_status = allowed.get(order.status)

            if new_status != expected_status:
                return Response(
                    {
                        "detail": (
                            f"Invalid status transition. "
                            f"Expected: {expected_status}."
                        )
                    },
                    status=status.HTTP_400_BAD_REQUEST,
                )

            order.status = new_status

            order.save(
                update_fields=["status", "updated_at"]
            )

            add_order_history(
                order,
                user,
                request.data.get("remarks", ""),
            )

            if order.checkout_id:
                checkout = Checkout.objects.select_for_update().get(
                    pk=order.checkout_id
                )

                update_checkout_readiness(
                    checkout,
                    user,
                )

        return Response(
            {
                "message": "Order status updated.",
                "order_id": order.pk,
                "status": order.status,
            },
            status=status.HTTP_200_OK,
        )

class CheckoutReadyForDispatchView(APIView):

    permission_classes = [IsAuthenticated, IsOrderManager]

    def get(self, request):

        checkouts = checkout_queryset().filter(
            delivery_status=Checkout.DeliveryStatus.READY
        ).order_by("-created_at")

        serializer = CheckoutDetailSerializer(
            checkouts,
            many=True,
            context={"request": request},
        )

        return Response(
            {
                "count": checkouts.count(),
                "results": serializer.data,
            },
            status=status.HTTP_200_OK,
        )
