class ApiConfig {
  static const String baseUrl = 'https://api.mistygo.in/api';
  static const String login = '$baseUrl/token/';
  static const String refreshToken = '$baseUrl/token/refresh/';
  static const String register = '$baseUrl/accounts/register/';
  static const String currentUser = '$baseUrl/accounts/me/';

  static const String products = '$baseUrl/products/';
  static const String categories = '$baseUrl/products/categories/';
  static const String foodItems = '$baseUrl/food/items/';
  static const String foodCategories = '$baseUrl/food/categories/';
  static const String foodManagementItems = '$baseUrl/food/manage/items/';

  static const String myHotel = '$baseUrl/accounts/my-hotel/';
  static const String cart = '$baseUrl/cart/';
  static const String orders = '$baseUrl/orders/';
  static const String manageUsers = '$baseUrl/accounts/manage-users/';
  static const String restaurantPartnerRequests = '$baseUrl/hotels/restaurant-partner-requests/';
}
