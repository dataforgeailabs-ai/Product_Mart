class ApiConfig {
  //static const String baseUrl = 'http://10.235.167.106:8000/api';
  
  static const String baseUrl = 'http://3.6.214.93/api';
  static const String login = '$baseUrl/token/';
  static const String refreshToken = '$baseUrl/token/refresh/';
  static const String register = '$baseUrl/accounts/register/';
  static const String currentUser = '$baseUrl/accounts/me/';

  static const String products = '$baseUrl/products/';
  static const String categories = '$baseUrl/products/categories/';

  static const String myHotel = '$baseUrl/accounts/my-hotel/';
  static const String cart = '$baseUrl/cart/';
  static const String orders = '$baseUrl/orders/';
}