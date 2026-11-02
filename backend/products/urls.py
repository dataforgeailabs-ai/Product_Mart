from django.urls import path
from .views import (
    ProductListView,
    ProductDetailView,
    ProductCreateView,
    ProductUpdateView,
    ProductDeleteView,
    ProductCategoryListView,
    ProductCategoryCreateView,
    ProductCategoryUpdateView,
    ProductCategoryDeleteView,
)

urlpatterns = [
    path('', ProductListView.as_view(), name='product-list'),

    path('categories/', ProductCategoryListView.as_view(), name='category-list'),
    path('categories/create/', ProductCategoryCreateView.as_view(), name='category-create'),
    path(
        'categories/update/<int:pk>/',
        ProductCategoryUpdateView.as_view(),
        name='category-update',
    ),
    path(
        'categories/delete/<int:pk>/',
        ProductCategoryDeleteView.as_view(),
        name='category-delete',
    ),

    path('create/', ProductCreateView.as_view(), name='product-create'),
    path('update/<int:pk>/', ProductUpdateView.as_view(), name='product-update'),
    path('delete/<int:pk>/', ProductDeleteView.as_view(), name='product-delete'),

    path('<int:pk>/', ProductDetailView.as_view(), name='product-detail'),
]