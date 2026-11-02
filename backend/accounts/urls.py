from django.urls import path

from .views import (
    UserRegistrationView,
    CurrentUserView,
    SuperAdminTestView,
    MyHotelDetailsView,
)

urlpatterns = [
    path(
        "register/",
        UserRegistrationView.as_view(),
        name="user-register",
    ),
    path(
        "me/",
        CurrentUserView.as_view(),
        name="current-user",
    ),
    path(
        "superadmin-test/",
        SuperAdminTestView.as_view(),
        name="superadmin-test",
    ),
    path(
        "my-hotel/",
        MyHotelDetailsView.as_view(),
        name="my-hotel-details",
    ),
]