class User {
  const User({
    required this.id,
    required this.email,
    required this.displayName,
    required this.createdAt,
  });

  final String id;
  final String email;
  final String displayName;
  final DateTime createdAt;

  /// `created_at` llega con offset (-04:00); se guarda en UTC.
  factory User.fromJson(Map<String, dynamic> json) => User(
    id: json['id'] as String,
    email: json['email'] as String,
    displayName: json['display_name'] as String,
    createdAt: DateTime.parse(json['created_at'] as String).toUtc(),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'email': email,
    'display_name': displayName,
    'created_at': createdAt.toUtc().toIso8601String(),
  };
}
