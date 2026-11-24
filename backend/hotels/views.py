from django.db import transaction
from django.utils import timezone
from rest_framework import generics, status
from rest_framework.exceptions import NotFound, ValidationError
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from accounts.permissions import IsAdmin

from .models import Hotel, RestaurantPartnerRequest
from .serializers import HotelSerializer, RestaurantPartnerRequestSerializer


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


class HotelTypeUpdateView(APIView):
    """Convert a hotel between customer and food-partner classifications."""

    permission_classes = [IsAuthenticated, IsAdmin]

    def patch(self, request, pk):
        try:
            hotel = Hotel.objects.get(pk=pk)
        except Hotel.DoesNotExist as exc:
            raise NotFound("Hotel not found.") from exc

        hotel_type = request.data.get("hotel_type")
        if hotel_type not in Hotel.HotelType.values:
            return Response(
                {"hotel_type": "Use CUSTOMER_HOTEL or FOOD_PARTNER."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        hotel.hotel_type = hotel_type
        hotel.save(update_fields=["hotel_type", "updated_at"])
        return Response(HotelSerializer(hotel).data)


class RestaurantPartnerRequestListView(generics.ListAPIView):
    serializer_class = RestaurantPartnerRequestSerializer
    permission_classes = [IsAuthenticated, IsAdmin]

    def get_queryset(self):
        queryset = RestaurantPartnerRequest.objects.select_related(
            "hotel",
            "reviewed_by",
        )
        requested_status = self.request.query_params.get("status")
        if requested_status:
            if requested_status not in RestaurantPartnerRequest.Status.values:
                raise ValidationError({"status": "Invalid request status."})
            queryset = queryset.filter(status=requested_status)
        return queryset


class RestaurantPartnerRequestDetailView(generics.RetrieveAPIView):
    serializer_class = RestaurantPartnerRequestSerializer
    permission_classes = [IsAuthenticated, IsAdmin]
    queryset = RestaurantPartnerRequest.objects.select_related(
        "hotel",
        "reviewed_by",
    )


class RestaurantPartnerRequestReviewView(APIView):
    permission_classes = [IsAuthenticated, IsAdmin]

    def post(self, request, pk, decision):
        with transaction.atomic():
            try:
                partner_request = (
                    RestaurantPartnerRequest.objects.select_for_update()
                    .select_related("hotel")
                    .get(pk=pk)
                )
            except RestaurantPartnerRequest.DoesNotExist as exc:
                raise NotFound("Restaurant partnership request not found.") from exc

            if partner_request.status != RestaurantPartnerRequest.Status.PENDING:
                raise ValidationError(
                    {"status": "Only pending requests can be reviewed."}
                )

            hotel = Hotel.objects.select_for_update().get(pk=partner_request.hotel_id)
            if decision == "approve":
                if hotel.hotel_type != Hotel.HotelType.CUSTOMER_HOTEL:
                    raise ValidationError(
                        {"hotel": "This hotel is not eligible for approval."}
                    )
                hotel.hotel_type = Hotel.HotelType.FOOD_PARTNER
                hotel.save(update_fields=["hotel_type", "updated_at"])
                partner_request.status = RestaurantPartnerRequest.Status.APPROVED
                partner_request.rejection_reason = ""
            elif decision == "reject":
                reason = str(request.data.get("rejection_reason", "")).strip()
                if not reason:
                    raise ValidationError(
                        {"rejection_reason": "A rejection reason is required."}
                    )
                hotel.hotel_type = Hotel.HotelType.CUSTOMER_HOTEL
                hotel.save(update_fields=["hotel_type", "updated_at"])
                partner_request.status = RestaurantPartnerRequest.Status.REJECTED
                partner_request.rejection_reason = reason
            else:
                raise ValidationError({"decision": "Invalid review decision."})

            partner_request.reviewed_by = request.user
            partner_request.reviewed_at = timezone.now()
            partner_request.save(
                update_fields=[
                    "status",
                    "reviewed_by",
                    "reviewed_at",
                    "rejection_reason",
                ]
            )

        return Response(RestaurantPartnerRequestSerializer(partner_request).data)
