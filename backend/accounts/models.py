from django.contrib.auth.models import AbstractUser
from django.db import models


class User(AbstractUser):

    class Role(models.TextChoices):
        SUPERADMIN = "SUPERADMIN", "Superadmin"
        ADMIN = "ADMIN", "Admin"
        DELIVERY = "DELIVERY", "Delivery Person"
        HOTEL = "HOTEL", "Hotel Staff"

    email = models.EmailField(
        max_length=191,
        unique=True,
    )

    phone = models.CharField(
        max_length=15,
        blank=True,
    )

    role = models.CharField(
        max_length=20,
        choices=Role.choices,
        default=Role.HOTEL,
    )

    is_active = models.BooleanField(default=True)

    hotel = models.ForeignKey(
        'hotels.Hotel',
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='users',
    )

    def __str__(self):
        return f"{self.username} ({self.role})"