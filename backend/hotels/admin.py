from django.contrib import admin
from .models import Hotel


@admin.register(Hotel)
class HotelAdmin(admin.ModelAdmin):
    list_display = (
        'id',
        'name',
        'contact_person',
        'phone',
        'city',
        'property_type',
        'status',
        'created_at',
    )

    list_filter = (
        'status',
        'property_type',
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