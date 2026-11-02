from rest_framework import generics
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from .serializers import (
    UserRegistrationSerializer,
    UserProfileSerializer,
    HotelDetailsSerializer,
)
from .permissions import IsSuperAdmin, IsHotelStaff


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