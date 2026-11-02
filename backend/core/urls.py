from django.urls import path

from .views import HealthCheckView, HotelStaffTestView

urlpatterns = [
path('health/', HealthCheckView.as_view(), name='health-check'),
path(
'hotel-staff-test/',
HotelStaffTestView.as_view(),
name='hotel-staff-test',
),
]
