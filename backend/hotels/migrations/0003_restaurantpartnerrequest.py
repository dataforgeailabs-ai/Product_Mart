from django.conf import settings
from django.db import migrations, models
import django.db.models.deletion


class Migration(migrations.Migration):
    dependencies = [
        ("accounts", "0004_restore_hotel_role"),
        ("hotels", "0002_hotel_hotel_type"),
    ]

    operations = [
        migrations.CreateModel(
            name="RestaurantPartnerRequest",
            fields=[
                (
                    "id",
                    models.BigAutoField(
                        auto_created=True,
                        primary_key=True,
                        serialize=False,
                        verbose_name="ID",
                    ),
                ),
                ("restaurant_name", models.CharField(blank=True, max_length=200)),
                ("restaurant_phone", models.CharField(max_length=15)),
                ("fssai_number", models.CharField(max_length=50)),
                ("description", models.TextField()),
                (
                    "status",
                    models.CharField(
                        choices=[
                            ("PENDING", "Pending"),
                            ("APPROVED", "Approved"),
                            ("REJECTED", "Rejected"),
                        ],
                        default="PENDING",
                        max_length=10,
                    ),
                ),
                ("requested_at", models.DateTimeField(auto_now_add=True)),
                ("reviewed_at", models.DateTimeField(blank=True, null=True)),
                ("rejection_reason", models.TextField(blank=True)),
                (
                    "hotel",
                    models.OneToOneField(
                        on_delete=django.db.models.deletion.CASCADE,
                        related_name="restaurant_partner_request",
                        to="hotels.hotel",
                    ),
                ),
                (
                    "reviewed_by",
                    models.ForeignKey(
                        blank=True,
                        null=True,
                        on_delete=django.db.models.deletion.SET_NULL,
                        related_name="reviewed_restaurant_partner_requests",
                        to=settings.AUTH_USER_MODEL,
                    ),
                ),
            ],
            options={"ordering": ["-requested_at"]},
        ),
        migrations.AddConstraint(
            model_name="restaurantpartnerrequest",
            constraint=models.CheckConstraint(
                condition=models.Q(status__in=["PENDING", "APPROVED", "REJECTED"]),
                name="valid_restaurant_partner_request_status",
            ),
        ),
        migrations.AddConstraint(
            model_name="restaurantpartnerrequest",
            constraint=models.CheckConstraint(
                condition=(
                    models.Q(
                        status="PENDING",
                        reviewed_by__isnull=True,
                        reviewed_at__isnull=True,
                    )
                    | models.Q(
                        status__in=["APPROVED", "REJECTED"],
                        reviewed_by__isnull=False,
                        reviewed_at__isnull=False,
                    )
                ),
                name="restaurant_partner_review_matches_status",
            ),
        ),
    ]
