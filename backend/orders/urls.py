from django.urls import path

from .views import (
    OrderListView,
    OrderDetailView,
    CheckoutView,
    CheckoutDetailView,
    CheckoutMyDeliveriesView,
    OrderConfirmationView,
    OrderRejectionView,
    OrderCancellationView,
    OrderStatusUpdateView,
    RefundRequestListView,
    RefundApprovalView,
    CheckoutDeliveryAssignmentView,
    CheckoutDeliveryStatusView,
    UPIPaymentVerificationView,
    RazorpayOrderCreateView,
    CheckoutReadyForDispatchView,
)

urlpatterns = [
    # Orders
    path("", OrderListView.as_view(), name="order-list"),
    path("<int:pk>/", OrderDetailView.as_view(), name="order-detail"),
    path("<int:pk>/confirm/", OrderConfirmationView.as_view(), name="order-confirm"),
    path("<int:pk>/reject/", OrderRejectionView.as_view(), name="order-reject"),
    path("<int:pk>/cancel/", OrderCancellationView.as_view(), name="order-cancel"),
    path("<int:pk>/status/", OrderStatusUpdateView.as_view(), name="order-status-update"),

    # Checkout
    path("checkout/", CheckoutView.as_view(), name="order-checkout"),
    path("checkouts/<int:pk>/", CheckoutDetailView.as_view(), name="checkout-detail"),

    # Checkout Payment
    path(
        "checkouts/<int:pk>/create-payment/",
        RazorpayOrderCreateView.as_view(),
        name="razorpay-order-create",
    ),
    path(
        "checkouts/<int:pk>/verify-payment/",
        UPIPaymentVerificationView.as_view(),
        name="upi-payment-verification",
    ),

    # Delivery
    path(
        "checkouts/<int:pk>/assign-delivery/",
        CheckoutDeliveryAssignmentView.as_view(),
        name="checkout-assign-delivery",
    ),
    path(
        "checkouts/<int:pk>/delivery-status/",
        CheckoutDeliveryStatusView.as_view(),
        name="checkout-delivery-status",
    ),

    # Refunds
    path("refunds/", RefundRequestListView.as_view(), name="refund-list"),
    path(
        "refunds/<int:pk>/approve/",
        RefundApprovalView.as_view(),
        name="refund-approval",
    ),

    path(
        "checkouts/my-deliveries/",
        CheckoutMyDeliveriesView.as_view(),
        name="my-deliveries",
    ),

    path(
        "checkouts/ready-for-dispatch/",
        CheckoutReadyForDispatchView.as_view(),
        name="checkout-ready-for-dispatch",
    ),
]