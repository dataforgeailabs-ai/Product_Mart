from rest_framework import viewsets
from rest_framework.exceptions import PermissionDenied
from rest_framework.permissions import IsAuthenticated, AllowAny
from rest_framework.decorators import action
from rest_framework.response import Response

from .models import FoodCategory, FoodItem
from .serializers import (
    FoodCategorySerializer,
    FoodItemSerializer,
)
from .permissions import CanManageFood
from accounts.permissions import IsAdmin
from accounts.models import User
from hotels.models import Hotel


class FoodCategoryViewSet(viewsets.ModelViewSet):
    serializer_class = FoodCategorySerializer

    def get_queryset(self):
        queryset = FoodCategory.objects.all()
        user = self.request.user
        if (
            not user.is_authenticated
            or user.role not in [User.Role.SUPERADMIN, User.Role.ADMIN]
        ):
            queryset = queryset.filter(
                is_active=True
            )
        return queryset.select_related("parent_category")

    def get_permissions(self):
        if self.action in [
            "create",
            "update",
            "partial_update",
            "destroy",
            "activate",
            "deactivate",
        ]:
            return [IsAuthenticated(), IsAdmin()]

        return [AllowAny()]

    @action(detail=True, methods=["post"])
    def activate(self, request, pk=None):
        category = self.get_object()
        category.is_active = True
        category.save(update_fields=["is_active", "updated_at"])
        return self._status_response(category)

    @action(detail=True, methods=["post"])
    def deactivate(self, request, pk=None):
        category = self.get_object()
        category.is_active = False
        category.save(update_fields=["is_active", "updated_at"])
        return self._status_response(category)

    def _status_response(self, category):
        return Response(self.get_serializer(category).data)

    def perform_destroy(self, instance):
        instance.is_active = False
        instance.save(update_fields=["is_active"])


class FoodItemViewSet(viewsets.ModelViewSet):
    serializer_class = FoodItemSerializer

    def get_queryset(self):
        queryset = FoodItem.objects.select_related(
            "hotel",
            "category",
        )

        if self.action in [
            "create",
            "update",
            "partial_update",
            "destroy",
        ]:
            user = self.request.user
            if user.role in [User.Role.SUPERADMIN, User.Role.ADMIN]:
                return queryset
            if (
                user.role == User.Role.HOTEL
                and user.hotel_id
                and user.hotel.hotel_type == Hotel.HotelType.FOOD_PARTNER
            ):
                return queryset.filter(hotel_id=user.hotel_id)
            return queryset.none()

        return queryset.filter(
            hotel__status="ACTIVE",
            is_active=True,
            is_available=True,
        )

    def get_permissions(self):
        if self.action in [
            "create",
            "update",
            "partial_update",
            "destroy",
        ]:
            return [IsAuthenticated(), CanManageFood()]

        return [AllowAny()]

    def perform_create(self, serializer):
        user = self.request.user
        if user.role in [User.Role.SUPERADMIN, User.Role.ADMIN]:
            serializer.save()
            return

        supplied_hotel = self.request.data.get("hotel")
        if supplied_hotel not in (None, "", str(user.hotel_id)):
            raise PermissionDenied(
                "Food partners can only create food for their own hotel."
            )

        serializer.save(hotel=user.hotel)

    def perform_destroy(self, instance):
        instance.is_active = False
        instance.save(update_fields=["is_active"])


class FoodItemManagementViewSet(viewsets.ReadOnlyModelViewSet):
    """Authenticated management reads, including unavailable/inactive items."""

    serializer_class = FoodItemSerializer
    permission_classes = [IsAuthenticated, CanManageFood]

    def get_queryset(self):
        queryset = FoodItem.objects.select_related("hotel", "category")
        user = self.request.user

        if user.role in [User.Role.SUPERADMIN, User.Role.ADMIN]:
            return queryset

        if (
            user.role == User.Role.HOTEL
            and user.hotel_id
            and user.hotel.hotel_type == Hotel.HotelType.FOOD_PARTNER
        ):
            return queryset.filter(hotel_id=user.hotel_id)

        return queryset.none()
