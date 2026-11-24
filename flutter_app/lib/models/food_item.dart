class FoodItem {
  final int id;
  final int hotel;
  final String hotelName;
  final int category;
  final String categoryName;
  final String name;
  final String description;
  final String? image;
  final double price;
  final String foodType;
  final int preparationTime;
  final String servingSize;
  final String spiceLevel;
  final String ingredients;
  final String allergens;
  final bool isAvailable;
  final bool isActive;

  const FoodItem({
    required this.id,
    required this.hotel,
    required this.hotelName,
    required this.category,
    required this.categoryName,
    required this.name,
    required this.description,
    required this.image,
    required this.price,
    required this.foodType,
    required this.preparationTime,
    required this.servingSize,
    required this.spiceLevel,
    required this.ingredients,
    required this.allergens,
    required this.isAvailable,
    required this.isActive,
  });

  factory FoodItem.fromJson(Map<String, dynamic> json) => FoodItem(
    id: (json['id'] as num).toInt(),
    hotel: (json['hotel'] as num).toInt(),
    hotelName: json['hotel_name']?.toString() ?? '',
    category: (json['category'] as num).toInt(),
    categoryName: json['category_name']?.toString() ?? '',
    name: json['name']?.toString() ?? '',
    description: json['description']?.toString() ?? '',
    image: json['image']?.toString(),
    price: double.parse(json['price'].toString()),
    foodType: json['food_type']?.toString() ?? 'VEG',
    preparationTime: (json['preparation_time'] as num).toInt(),
    servingSize: json['serving_size']?.toString() ?? '',
    spiceLevel: json['spice_level']?.toString() ?? '',
    ingredients: json['ingredients']?.toString() ?? '',
    allergens: json['allergens']?.toString() ?? '',
    isAvailable: json['is_available'] == true,
    isActive: json['is_active'] == true,
  );
}
