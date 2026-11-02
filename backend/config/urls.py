from django.contrib import admin
from django.urls import path, include
from django.conf import settings
from django.conf.urls.static import static

from rest_framework_simplejwt.views import (
    TokenObtainPairView,
    TokenRefreshView,
)

urlpatterns = [
    # Django Admin
    path('admin/', admin.site.urls),

    # JWT Authentication
    path('api/token/', TokenObtainPairView.as_view(), name='token_obtain_pair'),
    path('api/token/refresh/', TokenRefreshView.as_view(), name='token_refresh'),

    # User Accounts
    path('api/accounts/', include('accounts.urls')),

    # Core APIs
    path('api/', include('core.urls')),

    # Product APIs
    path('api/products/', include('products.urls')),

    # Hotel APIs
    path('api/hotels/', include('hotels.urls')),

    # Order APIs
    path('api/orders/', include('orders.urls')),

    # Cart APIs
    path('api/cart/', include('cart.urls')),
]

# Serve uploaded media files during development
if settings.DEBUG:
    urlpatterns += static(
        settings.MEDIA_URL,
        document_root=settings.MEDIA_ROOT
    )