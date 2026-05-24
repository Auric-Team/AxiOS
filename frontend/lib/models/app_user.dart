class AppUser {
  final String id;
  final String username;
  final String role;
  final String deviceFingerprint;
  final DateTime createdAt;

  AppUser({
    required this.id,
    required this.username,
    required this.role,
    required this.deviceFingerprint,
    required this.createdAt,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['_id'] ?? '',
      username: json['username'] ?? '',
      role: json['role'] ?? 'user',
      deviceFingerprint: json['deviceFingerprint'] ?? '',
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'username': username,
      'role': role,
      'deviceFingerprint': deviceFingerprint,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
