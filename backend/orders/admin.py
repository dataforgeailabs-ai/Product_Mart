from django.contrib import admin
from .models import Order, OrderItem, OrderStatusHistory, Payment


class OrderItemInline(admin.TabularInline):
    model = OrderItem
    extra = 0
    readonly_fields = ("unit_price", "line_total")


class OrderStatusHistoryInline(admin.TabularInline):
    model = OrderStatusHistory
    extra = 0
    readonly_fields = ("status", "changed_by", "remarks", "changed_at")
    can_delete = False


class PaymentInline(admin.TabularInline):
    model = Payment
    extra = 0
    readonly_fields = ("created_at", "updated_at")


@admin.register(Order)
class OrderAdmin(admin.ModelAdmin):
    list_display = (
        "order_no",
        "hotel",
        "total",
        "status",
        "payment_status",
        "created_at",
    )

    list_filter = ("status", "payment_status", "created_at")
    search_fields = ("order_no", "hotel__name")
    readonly_fields = ("created_at", "updated_at")

    inlines = [
        OrderItemInline,
        OrderStatusHistoryInline,
        PaymentInline,
    ]


@admin.register(OrderItem)
class OrderItemAdmin(admin.ModelAdmin):
    list_display = ("order", "product", "quantity", "unit_price", "line_total")
    search_fields = ("order__order_no", "product__name")


@admin.register(OrderStatusHistory)
class OrderStatusHistoryAdmin(admin.ModelAdmin):
    list_display = ("order", "status", "changed_by", "changed_at")
    list_filter = ("status", "changed_at")
    search_fields = ("order__order_no", "changed_by__username")
    readonly_fields = ("changed_at",)


@admin.register(Payment)
class PaymentAdmin(admin.ModelAdmin):
    list_display = ("order", "method", "amount", "status", "created_at")
    list_filter = ("method", "status", "created_at")
    search_fields = ("order__order_no", "payment_id", "link_id")
    readonly_fields = ("created_at", "updated_at")