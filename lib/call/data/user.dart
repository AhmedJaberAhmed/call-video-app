class User {
  final String id;
  final String name;
  final String? email;
  final String? avatarUrl;
  final bool isOnline;

  User({
    required this.id,
    required this.name,
    this.email,
    this.avatarUrl,
    this.isOnline = false,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] ?? '',
      name: json['name'] ?? 'Unknown',
      email: json['email'],
      avatarUrl: json['avatar_url'],
      isOnline: json['is_online'] ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'email': email,
    'avatar_url': avatarUrl,
    'is_online': isOnline,
  };
}

class Contact {
  final String id;
  final String name;
  final String? phone;
  final String? avatarUrl;
  final bool isOnline;

  Contact({
    required this.id,
    required this.name,
    this.phone,
    this.avatarUrl,
    this.isOnline = false,
  });

  factory Contact.fromJson(Map<String, dynamic> json) {
    return Contact(
      id: json['id'] ?? '',
      name: json['name'] ?? 'Unknown',
      phone: json['phone'],
      avatarUrl: json['avatar_url'],
      isOnline: json['is_online'] ?? false,
    );
  }
}