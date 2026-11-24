from rest_framework.test import APIClient, APITestCase

from accounts.models import User

from .models import Hotel, RestaurantPartnerRequest


class HotelTypeAuthorizationTests(APITestCase):
    def setUp(self):
        self.client = APIClient()
        self.hotel = Hotel.objects.create(
            name="Hotel", contact_person="Owner", phone="1111111111",
            email="hotel@example.com", address="Address", city="City",
            state="State", pin_code="123456", property_type="Hotel",
        )
        self.admin = User.objects.create_user(
            username="admin", email="admin@example.com", password="password123",
            role=User.Role.ADMIN,
        )
        self.hotel_user = User.objects.create_user(
            username="hoteluser", email="hoteluser@example.com", password="password123",
            role=User.Role.HOTEL, hotel=self.hotel,
        )

    def test_only_admin_can_convert_hotel_type(self):
        self.client.force_authenticate(self.hotel_user)
        response = self.client.patch(
            f"/api/hotels/{self.hotel.pk}/type/",
            {"hotel_type": Hotel.HotelType.FOOD_PARTNER}, format="json",
        )
        self.assertEqual(response.status_code, 403)
        self.client.force_authenticate(self.admin)
        response = self.client.patch(
            f"/api/hotels/{self.hotel.pk}/type/",
            {"hotel_type": Hotel.HotelType.FOOD_PARTNER}, format="json",
        )
        self.assertEqual(response.status_code, 200)
        self.hotel.refresh_from_db()
        self.assertEqual(self.hotel.hotel_type, Hotel.HotelType.FOOD_PARTNER)

    def test_regular_hotel_update_cannot_change_hotel_type(self):
        self.client.force_authenticate(self.admin)
        response = self.client.patch(
            f"/api/hotels/{self.hotel.pk}/",
            {"name": "Renamed", "hotel_type": Hotel.HotelType.FOOD_PARTNER}, format="json",
        )
        self.assertEqual(response.status_code, 200)
        self.hotel.refresh_from_db()
        self.assertEqual(self.hotel.hotel_type, Hotel.HotelType.CUSTOMER_HOTEL)


class RestaurantPartnerRequestWorkflowTests(APITestCase):
    def setUp(self):
        self.client = APIClient()
        self.hotel = self._create_hotel("Pending Hotel", "pending@example.com")
        self.partner_request = RestaurantPartnerRequest.objects.create(
            hotel=self.hotel,
            restaurant_name="Pending Restaurant",
            restaurant_phone="8888888888",
            fssai_number="12345678901234",
            description="Restaurant description.",
        )
        self.admin = User.objects.create_user(
            username="review-admin",
            email="review-admin@example.com",
            password="password123",
            role=User.Role.ADMIN,
        )
        self.superadmin = User.objects.create_user(
            username="review-superadmin",
            email="review-superadmin@example.com",
            password="password123",
            role=User.Role.SUPERADMIN,
        )
        self.hotel_user = User.objects.create_user(
            username="request-hotel-user",
            email="request-hotel-user@example.com",
            password="password123",
            role=User.Role.HOTEL,
            hotel=self.hotel,
        )
        self.delivery = User.objects.create_user(
            username="request-delivery",
            email="request-delivery@example.com",
            password="password123",
            role=User.Role.DELIVERY,
        )

    def _create_hotel(self, name, email):
        return Hotel.objects.create(
            name=name,
            contact_person="Owner",
            phone="9999999999",
            email=email,
            address="Address",
            city="City",
            state="State",
            pin_code="123456",
            property_type="Hotel",
        )

    def _detail_url(self, request_id=None):
        return f"/api/hotels/restaurant-partner-requests/{request_id or self.partner_request.id}/"

    def test_admin_roles_can_list_pending_requests_and_retrieve_details(self):
        for reviewer in (self.admin, self.superadmin):
            self.client.force_authenticate(reviewer)
            listing = self.client.get("/api/hotels/restaurant-partner-requests/")
            detail = self.client.get(self._detail_url())
            self.assertEqual(listing.status_code, 200)
            self.assertEqual(detail.status_code, 200)
            self.assertEqual(detail.data["hotel_name"], "Pending Hotel")
            self.assertEqual(detail.data["restaurant_name"], "Pending Restaurant")
            self.assertEqual(detail.data["status"], "PENDING")

    def test_approval_promotes_hotel_and_cannot_be_repeated(self):
        self.client.force_authenticate(self.admin)
        response = self.client.post(
            f"{self._detail_url().rstrip('/')}/approve/",
            {},
            format="json",
        )
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.data["status"], "APPROVED")
        self.assertEqual(response.data["reviewed_by"], self.admin.id)
        self.assertIsNotNone(response.data["reviewed_at"])
        self.hotel.refresh_from_db()
        self.assertEqual(self.hotel.hotel_type, Hotel.HotelType.FOOD_PARTNER)

        duplicate = self.client.post(
            f"{self._detail_url().rstrip('/')}/approve/",
            {},
            format="json",
        )
        self.assertEqual(duplicate.status_code, 400)

    def test_rejection_keeps_customer_hotel_and_requires_reason(self):
        self.client.force_authenticate(self.superadmin)
        url = f"{self._detail_url().rstrip('/')}/reject/"
        missing_reason = self.client.post(url, {}, format="json")
        self.assertEqual(missing_reason.status_code, 400)

        response = self.client.post(
            url,
            {"rejection_reason": "Please provide a valid licence."},
            format="json",
        )
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.data["status"], "REJECTED")
        self.assertEqual(
            response.data["rejection_reason"],
            "Please provide a valid licence.",
        )
        self.hotel.refresh_from_db()
        self.assertEqual(self.hotel.hotel_type, Hotel.HotelType.CUSTOMER_HOTEL)

    def test_hotel_and_delivery_roles_cannot_review_requests(self):
        url = f"{self._detail_url().rstrip('/')}/approve/"
        for user in (self.hotel_user, self.delivery):
            self.client.force_authenticate(user)
            response = self.client.post(url, {}, format="json")
            self.assertEqual(response.status_code, 403)

    def test_public_users_cannot_read_or_review_requests(self):
        self.client.force_authenticate(None)
        listing = self.client.get("/api/hotels/restaurant-partner-requests/")
        review = self.client.post(
            f"{self._detail_url().rstrip('/')}/approve/",
            {},
            format="json",
        )
        self.assertEqual(listing.status_code, 401)
        self.assertEqual(review.status_code, 401)
