class FoodCategory {
  final int id;
  final String name;
  final String description;
  final String? image;
  final int? parentCategory;
  final int displayOrder;
  final bool isActive;

  const FoodCategory({
    required this.id,
    required this.name,
    this.description = '',
    required this.image,
    required this.parentCategory,
    this.displayOrder = 0,
    required this.isActive,
  });

  factory FoodCategory.fromJson(Map<String, dynamic> json) {
    return FoodCategory(
      id: (json['id'] as num).toInt(),
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      image: json['image']?.toString(),
      parentCategory: json['parent_category'] == null
          ? null
          : (json['parent_category'] as num).toInt(),
      displayOrder: (json['display_order'] as num?)?.toInt() ?? 0,
      isActive: json['is_active'] == true,
    );
  }
}
