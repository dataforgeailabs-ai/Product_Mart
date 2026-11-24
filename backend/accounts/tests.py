from rest_framework.test import APIClient, APITestCase

from hotels.models import Hotel, RestaurantPartnerRequest


class HotelRegistrationTests(APITestCase):
    def setUp(self):
        self.client = APIClient()
        self.payload = {
            "username": "newhotel", "email": "newhotel@example.com",
            "phone": "9999999999", "password": "password123",
            "hotel_name": "New Hotel", "contact_person": "Owner",
            "hotel_phone": "8888888888", "hotel_email": "hotel@example.com",
            "address": "Address", "city": "City", "state": "State",
            "pin_code": "123456", "property_type": "Hotel",
        }

    def test_registration_defaults_to_customer_hotel_and_hotel_role(self):
        response = self.client.post("/api/accounts/register/", self.payload, format="json")
        self.assertEqual(response.status_code, 201)
        hotel = Hotel.objects.get(name="New Hotel")
        self.assertEqual(hotel.hotel_type, Hotel.HotelType.CUSTOMER_HOTEL)
        self.assertEqual(hotel.users.get().role, "HOTEL")

    def test_public_registration_cannot_assign_food_partner(self):
        response = self.client.post(
            "/api/accounts/register/",
            {**self.payload, "hotel_type": Hotel.HotelType.FOOD_PARTNER}, format="json",
        )
        self.assertEqual(response.status_code, 400)
        self.assertFalse(Hotel.objects.filter(name="New Hotel").exists())

    def test_partnership_unchecked_is_a_normal_customer_hotel_registration(self):
        response = self.client.post(
            "/api/accounts/register/",
            {**self.payload, "partnership_requested": False},
            format="json",
        )
        self.assertEqual(response.status_code, 201)
        hotel = Hotel.objects.get(name="New Hotel")
        self.assertEqual(hotel.hotel_type, Hotel.HotelType.CUSTOMER_HOTEL)
        self.assertFalse(
            RestaurantPartnerRequest.objects.filter(hotel=hotel).exists()
        )

    def test_partnership_registration_creates_pending_request_without_food_access(self):
        response = self.client.post(
            "/api/accounts/register/",
            {
                **self.payload,
                "partnership_requested": True,
                "restaurant_name": "The New Restaurant",
                "restaurant_phone": "7777777777",
                "fssai_number": "12345678901234",
                "restaurant_description": "A restaurant application.",
            },
            format="json",
        )
        self.assertEqual(response.status_code, 201)
        hotel = Hotel.objects.get(name="New Hotel")
        partner_request = RestaurantPartnerRequest.objects.get(hotel=hotel)
        user = hotel.users.get()
        self.assertEqual(user.role, "HOTEL")
        self.assertEqual(hotel.hotel_type, Hotel.HotelType.CUSTOMER_HOTEL)
        self.assertEqual(partner_request.status, "PENDING")
        self.assertEqual(partner_request.restaurant_name, "The New Restaurant")
        self.assertEqual(partner_request.restaurant_phone, "7777777777")
        self.assertEqual(partner_request.fssai_number, "12345678901234")

    def test_partnership_request_requires_contact_license_and_description(self):
        response = self.client.post(
            "/api/accounts/register/",
            {**self.payload, "partnership_requested": True},
            format="json",
        )
        self.assertEqual(response.status_code, 400)
        self.assertFalse(Hotel.objects.filter(name="New Hotel").exists())
