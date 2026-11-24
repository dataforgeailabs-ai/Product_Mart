from rest_framework.routers import DefaultRouter
from .views import (
    FoodCategoryViewSet,
    FoodItemManagementViewSet,
    FoodItemViewSet,
)

router = DefaultRouter()

router.register(
    "categories",
    FoodCategoryViewSet,
    basename="food-category",
)

router.register(
    "items",
    FoodItemViewSet,
    basename="food-item",
)

router.register(
    "manage/items",
    FoodItemManagementViewSet,
    basename="food-management-item",
)

urlpatterns = router.urls
