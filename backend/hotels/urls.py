from django.urls import path
from .views import (
    HotelListCreateView,
    HotelDetailView,
    HotelStatusUpdateView,
    HotelTypeUpdateView,
    RestaurantPartnerRequestListView,
    RestaurantPartnerRequestDetailView,
    RestaurantPartnerRequestReviewView,
)

urlpatterns = [
    path('', HotelListCreateView.as_view(), name='hotel-list-create'),
    path('<int:pk>/', HotelDetailView.as_view(), name='hotel-detail'),
    path(
        '<int:pk>/status/',
        HotelStatusUpdateView.as_view(),
        name='hotel-status-update',
    ),
    path(
        '<int:pk>/type/',
        HotelTypeUpdateView.as_view(),
        name='hotel-type-update',
    ),
    path(
        'restaurant-partner-requests/',
        RestaurantPartnerRequestListView.as_view(),
        name='restaurant-partner-request-list',
    ),
    path(
        'restaurant-partner-requests/<int:pk>/',
        RestaurantPartnerRequestDetailView.as_view(),
        name='restaurant-partner-request-detail',
    ),
    path(
        'restaurant-partner-requests/<int:pk>/approve/',
        RestaurantPartnerRequestReviewView.as_view(),
        {'decision': 'approve'},
        name='restaurant-partner-request-approve',
    ),
    path(
        'restaurant-partner-requests/<int:pk>/reject/',
        RestaurantPartnerRequestReviewView.as_view(),
        {'decision': 'reject'},
        name='restaurant-partner-request-reject',
    ),
]
