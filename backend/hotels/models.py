from django.db import models
from django.conf import settings
from django.db.models import Q


class Hotel(models.Model):

    class HotelType(models.TextChoices):
        CUSTOMER_HOTEL = "CUSTOMER_HOTEL", "Customer Hotel"
        FOOD_PARTNER = "FOOD_PARTNER", "Food Partner"

    class Status(models.TextChoices):
        ACTIVE = "ACTIVE", "Active"
        BLOCKED = "BLOCKED", "Blocked"

    name = models.CharField(max_length=200)
    contact_person = models.CharField(max_length=150)
    phone = models.CharField(max_length=15)
    email = models.EmailField(max_length=191)

    address = models.TextField()
    city = models.CharField(max_length=100)
    state = models.CharField(max_length=100)
    pin_code = models.CharField(max_length=10)

    gst_number = models.CharField(
        max_length=20,
        blank=True,
    )

    property_type = models.CharField(max_length=100)

    hotel_type = models.CharField(
        max_length=20,
        choices=HotelType.choices,
        default=HotelType.CUSTOMER_HOTEL,
    )

    status = models.CharField(
        max_length=10,
        choices=Status.choices,
        default=Status.ACTIVE,
    )

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return self.name


class RestaurantPartnerRequest(models.Model):
    class Status(models.TextChoices):
        PENDING = "PENDING", "Pending"
        APPROVED = "APPROVED", "Approved"
        REJECTED = "REJECTED", "Rejected"

    hotel = models.OneToOneField(
        Hotel,
        on_delete=models.CASCADE,
        related_name="restaurant_partner_request",
    )
    restaurant_name = models.CharField(max_length=200, blank=True)
    restaurant_phone = models.CharField(max_length=15)
    fssai_number = models.CharField(max_length=50)
    description = models.TextField()
    status = models.CharField(
        max_length=10,
        choices=Status.choices,
        default=Status.PENDING,
    )
    requested_at = models.DateTimeField(auto_now_add=True)
    reviewed_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="reviewed_restaurant_partner_requests",
    )
    reviewed_at = models.DateTimeField(null=True, blank=True)
    rejection_reason = models.TextField(blank=True)

    class Meta:
        ordering = ["-requested_at"]
        constraints = [
            models.CheckConstraint(
                condition=Q(status__in=["PENDING", "APPROVED", "REJECTED"]),
                name="valid_restaurant_partner_request_status",
            ),
            models.CheckConstraint(
                condition=(
                    Q(
                        status="PENDING",
                        reviewed_by__isnull=True,
                        reviewed_at__isnull=True,
                    )
                    | Q(
                        status__in=["APPROVED", "REJECTED"],
                        reviewed_by__isnull=False,
                        reviewed_at__isnull=False,
                    )
                ),
                name="restaurant_partner_review_matches_status",
            ),
        ]

    def __str__(self):
        return f"{self.hotel.name} - {self.get_status_display()}"
