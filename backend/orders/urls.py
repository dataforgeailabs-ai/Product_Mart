from django.urls import path

from .views import (
    OrderListView,
    OrderDetailView,
    CheckoutView,
    OrderConfirmationView,
    OrderRejectionView,
    OrderCancellationView,
    OrderStatusUpdateView,
    UPIPaymentVerificationView,
    RazorpayOrderCreateView,
)

urlpatterns = [
    path("", OrderListView.as_view(), name="order-list"),
    path("checkout/", CheckoutView.as_view(), name="order-checkout"),

    path(
        "<int:pk>/create-payment/",
        RazorpayOrderCreateView.as_view(),
        name="razorpay-order-create",
    ),

    path(
        "<int:pk>/confirm/",
        OrderConfirmationView.as_view(),
        name="order-confirm",
    ),
    path(
        "<int:pk>/reject/",
        OrderRejectionView.as_view(),
        name="order-reject",
    ),
    path(
        "<int:pk>/cancel/",
        OrderCancellationView.as_view(),
        name="order-cancel",
    ),
    path(
        "<int:pk>/verify-payment/",
        UPIPaymentVerificationView.as_view(),
        name="upi-payment-verification",
    ),
    path(
        "<int:pk>/status/",
        OrderStatusUpdateView.as_view(),
        name="order-status-update",
    ),
    path("<int:pk>/", OrderDetailView.as_view(), name="order-detail"),
]