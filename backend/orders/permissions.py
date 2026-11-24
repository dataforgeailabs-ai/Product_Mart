from rest_framework.permissions import BasePermission

from accounts.models import User


class IsOrderManager(BasePermission):
    """
    Allow active Superadmin and Admin users to manage orders.
    """

    def has_permission(self, request, view):
        user = request.user

        return bool(
            user
            and user.is_authenticated
            and user.is_active
            and user.role in [
                User.Role.SUPERADMIN,
                User.Role.ADMIN,
            ]
        )


class IsHotelStaff(BasePermission):
    """
    Allow active hotel users associated with an active hotel
    to access hotel ordering features.
    """

    def has_permission(self, request, view):
        user = request.user

        return bool(
            user
            and user.is_authenticated
            and user.is_active
            and user.role == User.Role.HOTEL
            and user.hotel_id is not None
            and user.hotel.status == "ACTIVE"
        )


class IsDeliveryPerson(BasePermission):
    """
    Allow active delivery personnel to access delivery operations.
    """

    def has_permission(self, request, view):
        user = request.user

        return bool(
            user
            and user.is_authenticated
            and user.is_active
            and user.role == User.Role.DELIVERY
        )
