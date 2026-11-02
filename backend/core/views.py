from rest_framework.permissions import AllowAny
from rest_framework.response import Response
from rest_framework.views import APIView
from accounts.permissions import IsHotelStaff


class HealthCheckView(APIView):
    permission_classes = [AllowAny]
    authentication_classes = []

    def get(self, request):
        return Response({
            "status": "success",
            "message": "Hotel Supply Platform API is running."
        })

class HotelStaffTestView(APIView):
    permission_classes = [IsHotelStaff]

    def get(self, request):
        return Response({
            "status": "success",
            "message": "Hotel staff access verified.",
            "username": request.user.username,
            "hotel_id": request.user.hotel_id,
            "hotel_name": request.user.hotel.name,
        })