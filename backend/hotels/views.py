from rest_framework import generics
from rest_framework.permissions import IsAuthenticated

from accounts.permissions import IsAdmin
from .models import Hotel
from .serializers import HotelSerializer

from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status


class HotelListCreateView(generics.ListCreateAPIView):
    """
    GET: List hotels.
    POST: Create a hotel.
    """
    queryset = Hotel.objects.all().order_by('-created_at')
    serializer_class = HotelSerializer
    permission_classes = [IsAuthenticated, IsAdmin]


class HotelDetailView(generics.RetrieveUpdateAPIView):
    """
    GET: Retrieve a hotel.
    PUT/PATCH: Update a hotel.
    """
    queryset = Hotel.objects.all()
    serializer_class = HotelSerializer
    permission_classes = [IsAuthenticated, IsAdmin]

class HotelStatusUpdateView(APIView):
    """
    Block or unblock a hotel.
    Only Superadmin and Admin users can perform this action.
    """

    permission_classes = [IsAuthenticated, IsAdmin]

    def patch(self, request, pk):
        try:
            hotel = Hotel.objects.get(pk=pk)
        except Hotel.DoesNotExist:
            return Response(
                {"error": "Hotel not found."},
                status=status.HTTP_404_NOT_FOUND,
            )

        new_status = request.data.get("status")

        if new_status not in [
            Hotel.Status.ACTIVE,
            Hotel.Status.BLOCKED,
        ]:
            return Response(
                {
                    "error": "Invalid status. Use ACTIVE or BLOCKED."
                },
                status=status.HTTP_400_BAD_REQUEST,
            )

        hotel.status = new_status
        hotel.save(update_fields=["status", "updated_at"])

        return Response(
            {
                "message": f"Hotel {new_status.lower()} successfully.",
                "hotel_id": hotel.id,
                "name": hotel.name,
                "status": hotel.status,
            },
            status=status.HTTP_200_OK,
        )