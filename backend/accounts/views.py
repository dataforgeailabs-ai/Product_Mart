from rest_framework import generics, status
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from .serializers import (
    UserRegistrationSerializer,
    UserProfileSerializer,
    HotelDetailsSerializer,
    ManagedUserSerializer,
)
from django.contrib.auth import get_user_model
from .permissions import IsSuperAdmin, IsAdmin, IsHotelStaff

User = get_user_model()

class UserRegistrationView(generics.CreateAPIView):
    serializer_class = UserRegistrationSerializer
    permission_classes = [AllowAny]


class CurrentUserView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        user = request.user

        hotel_details = None

        if user.hotel_id:
            hotel_details = {
                "id": user.hotel.id,
                "name": user.hotel.name,
                "status": user.hotel.status,
            }

        return Response({
            "id": user.id,
            "username": user.username,
            "email": user.email,
            "phone": user.phone,
            "role": user.role,
            "is_active": user.is_active,
            "hotel": hotel_details,
        })

    def patch(self, request):
        serializer = UserProfileSerializer(
            request.user,
            data=request.data,
            partial=True,
        )

        serializer.is_valid(raise_exception=True)
        serializer.save()

        return Response({
            "message": "Account profile updated successfully.",
            "user": serializer.data,
        })


class SuperAdminTestView(APIView):
    permission_classes = [IsAuthenticated, IsSuperAdmin]

    def get(self, request):
        return Response({
            "message": "Superadmin access granted.",
            "username": request.user.username,
            "role": request.user.role,
        })


class MyHotelDetailsView(APIView):
    permission_classes = [IsAuthenticated, IsHotelStaff]

    def get(self, request):
        serializer = HotelDetailsSerializer(request.user.hotel)
        return Response(serializer.data)

    def patch(self, request):
        serializer = HotelDetailsSerializer(
            request.user.hotel,
            data=request.data,
            partial=True,
        )

        serializer.is_valid(raise_exception=True)
        serializer.save()

        return Response({
            "message": "Hotel profile updated successfully.",
            "hotel": serializer.data,
        })

class ManagedUserListCreateView(generics.ListCreateAPIView):
    serializer_class = ManagedUserSerializer
    permission_classes = [IsAuthenticated, IsAdmin]

    def get_queryset(self):
        user = self.request.user

        if user.role == User.Role.SUPERADMIN:
            return User.objects.filter(
                role__in=[
                    User.Role.ADMIN,
                    User.Role.DELIVERY,
                ]
            ).order_by("-date_joined")

        return User.objects.filter(
            role=User.Role.DELIVERY
        ).order_by("-date_joined")

    def perform_create(self, serializer):
        serializer.save()


class ManagedUserDetailView(generics.RetrieveUpdateAPIView):
    serializer_class = ManagedUserSerializer
    permission_classes = [IsAuthenticated, IsAdmin]
    http_method_names = ["get", "put", "patch", "head", "options"]

    def get_queryset(self):
        user = self.request.user

        if user.role == User.Role.SUPERADMIN:
            return User.objects.filter(
                role__in=[
                    User.Role.ADMIN,
                    User.Role.DELIVERY,
                ]
            )

        return User.objects.filter(
            role=User.Role.DELIVERY
        )

    def perform_update(self, serializer):
        serializer.save()


class ManagedUserDeactivateView(APIView):
    permission_classes = [IsAuthenticated, IsAdmin]

    def patch(self, request, pk):

        if pk == request.user.pk:
            return Response(
                {"error": "You cannot deactivate your own account."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        user = self.get_object(pk)

        if user is None:
            return Response(
                {"error": "User not found."},
                status=status.HTTP_404_NOT_FOUND,
            )

        if not user.is_active:
            return Response(
                {"message": "User is already inactive."},
                status=status.HTTP_200_OK,
            )

        user.is_active = False
        user.save(update_fields=["is_active"])

        return Response({
            "message": "User deactivated successfully.",
            "user_id": user.id,
        })

    def get_object(self, pk):
        current_user = self.request.user

        queryset = User.objects.filter(
            pk=pk,
            role__in=(
                [User.Role.ADMIN, User.Role.DELIVERY]
                if current_user.role == User.Role.SUPERADMIN
                else [User.Role.DELIVERY]
            ),
        )

        return queryset.first()