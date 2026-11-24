from decimal import Decimal

from django.urls import reverse
from rest_framework.test import APIClient, APITestCase

from accounts.models import User
from hotels.models import Hotel, RestaurantPartnerRequest

from .models import FoodCategory, FoodItem


class FoodAuthorizationTests(APITestCase):
    def setUp(self):
        self.client = APIClient()
        self.category = FoodCategory.objects.create(name="Breakfast")
        self.customer_hotel = self._hotel("Customer Hotel", "customer@example.com")
        self.partner_hotel = self._hotel(
            "Partner Hotel", "partner@example.com", Hotel.HotelType.FOOD_PARTNER
        )
        self.other_partner_hotel = self._hotel(
            "Other Partner Hotel", "other@example.com", Hotel.HotelType.FOOD_PARTNER
        )
        self.partner = self._user("partner", self.partner_hotel)
        self.customer = self._user("customer", self.customer_hotel)
        self.delivery = User.objects.create_user(
            username="delivery", email="delivery@example.com",
            password="password123", role=User.Role.DELIVERY,
        )
        self.admin = User.objects.create_user(
            username="admin", email="admin@example.com",
            password="password123", role=User.Role.ADMIN,
        )
        self.superadmin = User.objects.create_user(
            username="superadmin", email="superadmin@example.com",
            password="password123", role=User.Role.SUPERADMIN,
        )
        self.own_food = self._food(self.partner_hotel, "Own Food")
        self.other_food = self._food(self.other_partner_hotel, "Other Food")

    def _hotel(self, name, email, hotel_type=Hotel.HotelType.CUSTOMER_HOTEL):
        return Hotel.objects.create(
            name=name, contact_person="Owner", phone="1111111111", email=email,
            address="Address", city="City", state="State", pin_code="123456",
            property_type="Hotel", hotel_type=hotel_type,
        )

    def _user(self, username, hotel):
        return User.objects.create_user(
            username=username, email=f"{username}@example.com",
            password="password123", role=User.Role.HOTEL, hotel=hotel,
        )

    def _food(self, hotel, name):
        return FoodItem.objects.create(
            hotel=hotel, category=self.category, name=name, price=Decimal("10.00")
        )

    def test_management_list_and_detail_cover_admin_roles_and_all_statuses(self):
        unavailable = self._food(self.partner_hotel, "Unavailable")
        unavailable.is_available = False
        unavailable.save(update_fields=["is_available"])
        inactive = self._food(self.partner_hotel, "Inactive")
        inactive.is_active = False
        inactive.save(update_fields=["is_active"])
        blocked_hotel_item = self._food(self.customer_hotel, "Blocked Hotel Item")
        self.customer_hotel.status = Hotel.Status.BLOCKED
        self.customer_hotel.save(update_fields=["status"])

        expected_ids = {
            self.own_food.id,
            self.other_food.id,
            unavailable.id,
            inactive.id,
            blocked_hotel_item.id,
        }
        for user in (self.admin, self.superadmin):
            self.client.force_authenticate(user)
            response = self.client.get(reverse("food-management-item-list"))
            self.assertEqual(response.status_code, 200)
            self.assertEqual({item["id"] for item in response.data}, expected_ids)
            detail = self.client.get(
                reverse("food-management-item-detail", args=[inactive.id])
            )
            self.assertEqual(detail.status_code, 200)
            self.assertFalse(detail.data["is_active"])
            unavailable_detail = self.client.get(
                reverse("food-management-item-detail", args=[unavailable.id])
            )
            self.assertEqual(unavailable_detail.status_code, 200)
            self.assertFalse(unavailable_detail.data["is_available"])

    def test_food_partner_management_reads_all_own_items_only(self):
        unavailable = self._food(self.partner_hotel, "Unavailable")
        unavailable.is_available = False
        unavailable.save(update_fields=["is_available"])
        inactive = self._food(self.partner_hotel, "Inactive")
        inactive.is_active = False
        inactive.save(update_fields=["is_active"])

        self.client.force_authenticate(self.partner)
        response = self.client.get(reverse("food-management-item-list"))
        self.assertEqual(response.status_code, 200)
        self.assertEqual(
            {item["id"] for item in response.data},
            {self.own_food.id, unavailable.id, inactive.id},
        )
        own_inactive = self.client.get(
            reverse("food-management-item-detail", args=[inactive.id])
        )
        self.assertEqual(own_inactive.status_code, 200)
        other_detail = self.client.get(
            reverse("food-management-item-detail", args=[self.other_food.id])
        )
        self.assertEqual(other_detail.status_code, 404)

    def test_customer_hotel_and_delivery_are_denied_management_reads(self):
        for user in (self.customer, self.delivery):
            self.client.force_authenticate(user)
            listing = self.client.get(reverse("food-management-item-list"))
            detail = self.client.get(
                reverse("food-management-item-detail", args=[self.own_food.id])
            )
            self.assertEqual(listing.status_code, 403)
            self.assertEqual(detail.status_code, 403)

    def test_unauthenticated_users_cannot_read_management_items(self):
        listing = self.client.get(reverse("food-management-item-list"))
        detail = self.client.get(
            reverse("food-management-item-detail", args=[self.own_food.id])
        )
        self.assertEqual(listing.status_code, 401)
        self.assertEqual(detail.status_code, 401)

    def _payload(self, name="New Food"):
        return {"category": self.category.pk, "name": name, "price": "12.50", "food_type": "VEG"}

    def test_admin_and_superadmin_can_create_for_any_hotel(self):
        for user in (self.admin, self.superadmin):
            self.client.force_authenticate(user)
            response = self.client.post(
                reverse("food-item-list"),
                {**self._payload(user.username), "hotel": self.other_partner_hotel.pk},
                format="json",
            )
            self.assertEqual(response.status_code, 201)
            self.assertEqual(response.data["hotel"], self.other_partner_hotel.pk)

    def test_admin_can_reassign_food_ownership(self):
        self.client.force_authenticate(self.admin)
        response = self.client.patch(
            reverse("food-item-detail", args=[self.own_food.pk]),
            {"hotel": self.other_partner_hotel.pk}, format="json",
        )
        self.assertEqual(response.status_code, 200)
        self.own_food.refresh_from_db()
        self.assertEqual(self.own_food.hotel_id, self.other_partner_hotel.pk)

    def test_partner_create_is_assigned_to_own_hotel_and_other_is_rejected(self):
        self.client.force_authenticate(self.partner)
        response = self.client.post(reverse("food-item-list"), self._payload(), format="json")
        self.assertEqual(response.status_code, 201)
        self.assertEqual(response.data["hotel"], self.partner_hotel.pk)
        response = self.client.post(
            reverse("food-item-list"),
            {**self._payload("Invalid Food"), "hotel": self.other_partner_hotel.pk},
            format="json",
        )
        self.assertEqual(response.status_code, 403)

    def test_partner_can_update_and_delete_only_own_food(self):
        self.client.force_authenticate(self.partner)
        response = self.client.patch(
            reverse("food-item-detail", args=[self.own_food.pk]),
            {"name": "Updated Food", "hotel": self.other_partner_hotel.pk}, format="json",
        )
        self.assertEqual(response.status_code, 200)
        self.own_food.refresh_from_db()
        self.assertEqual(self.own_food.name, "Updated Food")
        self.assertEqual(self.own_food.hotel_id, self.partner_hotel.pk)
        response = self.client.patch(
            reverse("food-item-detail", args=[self.other_food.pk]), {"name": "Should Fail"}, format="json"
        )
        self.assertEqual(response.status_code, 404)
        response = self.client.delete(reverse("food-item-detail", args=[self.own_food.pk]))
        self.assertEqual(response.status_code, 204)
        self.own_food.refresh_from_db()
        self.assertFalse(self.own_food.is_active)

    def test_customer_and_delivery_cannot_manage_food(self):
        for user in (self.customer, self.delivery):
            self.client.force_authenticate(user)
            response = self.client.post(reverse("food-item-list"), self._payload(), format="json")
            self.assertEqual(response.status_code, 403)
            response = self.client.patch(
                reverse("food-item-detail", args=[self.own_food.pk]), {"name": "Should Fail"}, format="json"
            )
            self.assertEqual(response.status_code, 403)

    def test_partner_cannot_manage_categories(self):
        self.client.force_authenticate(self.partner)
        response = self.client.post(
            reverse("food-category-list"), {"name": "Forbidden"}, format="json"
        )
        self.assertEqual(response.status_code, 403)

    def test_pending_hotel_food_access_starts_only_after_admin_approval(self):
        pending_hotel = self._hotel(
            "Pending Partner Hotel",
            "pending-partner@example.com",
        )
        pending_user = self._user("pending_partner", pending_hotel)
        partner_request = RestaurantPartnerRequest.objects.create(
            hotel=pending_hotel,
            restaurant_phone="8888888888",
            fssai_number="12345678901234",
            description="Pending application.",
        )

        pending_user = User.objects.get(pk=pending_user.pk)
        self.client.force_authenticate(pending_user)
        blocked_create = self.client.post(
            reverse("food-item-list"),
            self._payload("Before Approval"),
            format="json",
        )
        blocked_management_read = self.client.get(
            reverse("food-management-item-list")
        )
        self.assertEqual(blocked_create.status_code, 403)
        self.assertEqual(blocked_management_read.status_code, 403)
        self.assertEqual(
            pending_hotel.hotel_type,
            Hotel.HotelType.CUSTOMER_HOTEL,
        )

        self.client.force_authenticate(self.admin)
        approved = self.client.post(
            f"/api/hotels/restaurant-partner-requests/{partner_request.id}/approve/",
            {},
            format="json",
        )
        self.assertEqual(approved.status_code, 200)

        pending_user = User.objects.get(pk=pending_user.pk)
        self.client.force_authenticate(pending_user)
        created = self.client.post(
            reverse("food-item-list"),
            self._payload("After Approval"),
            format="json",
        )
        self.assertEqual(created.status_code, 201)
        self.assertEqual(created.data["hotel"], pending_hotel.id)
        listing = self.client.get(reverse("food-management-item-list"))
        self.assertEqual(listing.status_code, 200)
        self.assertIn(created.data["id"], {item["id"] for item in listing.data})

        updated = self.client.patch(
            reverse("food-item-detail", args=[created.data["id"]]),
            {"name": "Updated Approved Food"},
            format="json",
        )
        self.assertEqual(updated.status_code, 200)

    def test_admin_category_list_includes_inactive_while_public_list_does_not(self):
        inactive = FoodCategory.objects.create(
            name="Inactive Category",
            is_active=False,
        )

        for user in (self.admin, self.superadmin):
            self.client.force_authenticate(user)
            listing = self.client.get(reverse("food-category-list"))
            self.assertEqual(listing.status_code, 200)
            self.assertEqual(
                {category["id"] for category in listing.data},
                {self.category.id, inactive.id},
            )
            detail = self.client.get(
                reverse("food-category-detail", args=[inactive.id])
            )
            self.assertEqual(detail.status_code, 200)
            self.assertFalse(detail.data["is_active"])

        self.client.force_authenticate(None)
        public_listing = self.client.get(reverse("food-category-list"))
        self.assertEqual(public_listing.status_code, 200)
        self.assertEqual(
            {category["id"] for category in public_listing.data},
            {self.category.id},
        )

    def test_admin_roles_can_create_edit_and_soft_deactivate_categories(self):
        for user in (self.admin, self.superadmin):
            self.client.force_authenticate(user)
            created = self.client.post(
                reverse("food-category-list"),
                {"name": f"Category {user.username}", "description": "Initial"},
                format="json",
            )
            self.assertEqual(created.status_code, 201)
            category_id = created.data["id"]

            updated = self.client.patch(
                reverse("food-category-detail", args=[category_id]),
                {"description": "Updated"},
                format="json",
            )
            self.assertEqual(updated.status_code, 200)
            self.assertEqual(updated.data["description"], "Updated")

            deleted = self.client.delete(
                reverse("food-category-detail", args=[category_id])
            )
            self.assertEqual(deleted.status_code, 204)
            category = FoodCategory.objects.get(pk=category_id)
            self.assertFalse(category.is_active)

    def test_public_food_listing_excludes_unavailable_inactive_and_inactive_hotels(self):
        unavailable = self._food(self.partner_hotel, "Unavailable")
        unavailable.is_available = False
        unavailable.save(update_fields=["is_available"])
        inactive = self._food(self.partner_hotel, "Inactive")
        inactive.is_active = False
        inactive.save(update_fields=["is_active"])
        blocked = self._food(self.customer_hotel, "Blocked Hotel Food")
        self.customer_hotel.status = Hotel.Status.BLOCKED
        self.customer_hotel.save(update_fields=["status"])
        self.assertIsNotNone(blocked)
        response = self.client.get(reverse("food-item-list"))
        self.assertEqual(response.status_code, 200)
        names = {item["name"] for item in response.data}
        self.assertEqual(names, {"Own Food", "Other Food"})
