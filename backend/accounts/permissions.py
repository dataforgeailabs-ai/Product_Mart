from rest_framework.permissions import BasePermission
from .models import User


class IsSuperAdmin(BasePermission):
    """
    Allow access only to active Superadmin users.
    """

    def has_permission(self, request, view):
        user = request.user

        return bool(
            user
            and user.is_authenticated
            and user.is_active
            and user.role == User.Role.SUPERADMIN
        )


class IsAdmin(BasePermission):
    """
    Allow access to active Superadmin and Admin users.
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


class IsDelivery(BasePermission):
    """
    Allow access only to active Delivery users.
    """

    def has_permission(self, request, view):
        user = request.user

        return bool(
            user
            and user.is_authenticated
            and user.is_active
            and user.role == User.Role.DELIVERY
        )


class IsHotelStaff(BasePermission):
    """
    Allow access to active customers belonging to an active hotel.
    """

    def has_permission(self, request, view):
        user = request.user

        if not user or not user.is_authenticated:
            return False

        if not user.is_active:
            return False

        if user.role != User.Role.HOTEL:
            return False

        if not user.hotel_id:
            return False

        return user.hotel.status == "ACTIVE"
