from django.contrib import admin
from .models import Hotel, RestaurantPartnerRequest


@admin.register(Hotel)
class HotelAdmin(admin.ModelAdmin):
    list_display = (
        'id',
        'name',
        'contact_person',
        'phone',
        'city',
        'property_type',
        'hotel_type',
        'status',
        'created_at',
    )

    list_filter = (
        'status',
        'property_type',
        'hotel_type',
        'state',
    )

    search_fields = (
        'name',
        'contact_person',
        'phone',
        'email',
        'city',
        'gst_number',
    )

    readonly_fields = (
        'created_at',
        'updated_at',
    )

    ordering = ('-created_at',)


@admin.register(RestaurantPartnerRequest)
class RestaurantPartnerRequestAdmin(admin.ModelAdmin):
    list_display = (
        "hotel",
        "restaurant_name",
        "restaurant_phone",
        "fssai_number",
        "status",
        "requested_at",
        "reviewed_by",
    )
    list_filter = ("status", "requested_at")
    search_fields = (
        "hotel__name",
        "restaurant_name",
        "restaurant_phone",
        "fssai_number",
    )
    readonly_fields = ("requested_at", "reviewed_at", "reviewed_by")
