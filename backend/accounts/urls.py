from django.urls import path

from .views import (
    UserRegistrationView,
    CurrentUserView,
    SuperAdminTestView,
    MyHotelDetailsView,
    ManagedUserListCreateView,
    ManagedUserDetailView,
    ManagedUserDeactivateView,
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
    path(
    "manage-users/",
    ManagedUserListCreateView.as_view(),
    name="manage-users",
    ),
    path(
        "manage-users/<int:pk>/",
        ManagedUserDetailView.as_view(),
        name="manage-user-detail",
    ),
    path(
        "manage-users/<int:pk>/deactivate/",
        ManagedUserDeactivateView.as_view(),
        name="manage-user-deactivate",
    ),
]