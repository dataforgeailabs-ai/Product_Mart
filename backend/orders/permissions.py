from rest_framework.permissions import BasePermission


class IsOrderManager(BasePermission):
    """
    Allow only Superadmin and Admin users to manage orders.
    """

    def has_permission(self, request, view):
        return (
            request.user
            and request.user.is_authenticated
            and request.user.role in ["SUPERADMIN", "ADMIN"]
        )


class IsHotelStaff(BasePermission):
    """
    Allow active hotel staff to access hotel ordering features.
    """

    def has_permission(self, request, view):
        user = request.user

        return (
            user
            and user.is_authenticated
            and user.role == "HOTEL"
            and user.hotel is not None
            and user.hotel.status == "ACTIVE"
        )


class IsDeliveryPerson(BasePermission):
    """
    Allow delivery personnel to access delivery operations.
    """

    def has_permission(self, request, view):
        return (
            request.user
            and request.user.is_authenticated
            and request.user.role == "DELIVERY"
        )