from django.urls import path
from .views import (
    HotelListCreateView,
    HotelDetailView,
    HotelStatusUpdateView,
)

urlpatterns = [
    path('', HotelListCreateView.as_view(), name='hotel-list-create'),
    path('<int:pk>/', HotelDetailView.as_view(), name='hotel-detail'),
    path(
        '<int:pk>/status/',
        HotelStatusUpdateView.as_view(),
        name='hotel-status-update',
    ),
]