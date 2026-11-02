from rest_framework.permissions import BasePermission


class CanManageProducts(BasePermission):
    """
    Allow only active Superadmin and Admin users
    to manage products and categories.
    """

    def has_permission(self, request, view):
        user = request.user

        return bool(
            user
            and user.is_authenticated
            and user.is_active
            and user.role in ["SUPERADMIN", "ADMIN"]
        )