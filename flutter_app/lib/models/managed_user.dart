class ManagedUser {
  final int id;
  final String username;
  final String email;
  final String phone;
  final String role;
  final bool isActive;

  ManagedUser({
    required this.id,
    required this.username,
    required this.email,
    required this.phone,
    required this.role,
    required this.isActive,
  });

  factory ManagedUser.fromJson(Map<String, dynamic> json) {
    return ManagedUser(
      id: json['id'],
      username: json['username'] ?? '',
      email: json['email'] ?? '',
      phone: json['phone'] ?? '',
      role: json['role'] ?? '',
      isActive: json['is_active'] == true,
    );
  }
}