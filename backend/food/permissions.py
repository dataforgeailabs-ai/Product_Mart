from rest_framework.permissions import BasePermission

from accounts.models import User
from hotels.models import Hotel


class CanManageFood(BasePermission):
    """
    Admins manage all food. Food partners manage food owned by their hotel.
    """

    def has_permission(self, request, view):
        user = request.user

        if not user or not user.is_authenticated or not user.is_active:
            return False

        return user.role in [User.Role.SUPERADMIN, User.Role.ADMIN] or (
            user.role == User.Role.HOTEL
            and user.hotel_id is not None
            and user.hotel.hotel_type == Hotel.HotelType.FOOD_PARTNER
        )

    def has_object_permission(self, request, view, obj):
        user = request.user

        if user.role in [User.Role.SUPERADMIN, User.Role.ADMIN]:
            return True

        return bool(
            user
            and user.is_authenticated
            and user.is_active
            and user.role == User.Role.HOTEL
            and user.hotel_id == obj.hotel_id
            and user.hotel.hotel_type == Hotel.HotelType.FOOD_PARTNER
        )
