class AccessKey {
  final String id;
  final String key;
  final bool isActive;
  final String targetGame;
  final int maxUses;
  final int usesCount;
  final String assignedTo;
  final String deviceFingerprint;
  final String createdBy;
  final DateTime createdAt;
  final DateTime? expiresAt;

  AccessKey({
    required this.id,
    required this.key,
    required this.isActive,
    required this.targetGame,
    required this.maxUses,
    required this.usesCount,
    required this.assignedTo,
    required this.deviceFingerprint,
    required this.createdBy,
    required this.createdAt,
    this.expiresAt,
  });

  factory AccessKey.fromJson(Map<String, dynamic> json) {
    return AccessKey(
      id: json['_id'] ?? '',
      key: json['key'] ?? '',
      isActive: json['isActive'] ?? false,
      targetGame: json['targetGame'] ?? '',
      maxUses: json['maxUses'] ?? 1,
      usesCount: json['usesCount'] ?? 0,
      assignedTo: json['assignedTo'] ?? '',
      deviceFingerprint: json['deviceFingerprint'] ?? '',
      createdBy: json['createdBy'] ?? '',
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      expiresAt: json['expiresAt'] != null
          ? DateTime.parse(json['expiresAt'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'key': key,
      'isActive': isActive,
      'targetGame': targetGame,
      'maxUses': maxUses,
      'usesCount': usesCount,
      'assignedTo': assignedTo,
      'deviceFingerprint': deviceFingerprint,
      'createdBy': createdBy,
      'createdAt': createdAt.toIso8601String(),
      'expiresAt': expiresAt?.toIso8601String(),
    };
  }

  bool get isExpired {
    if (expiresAt == null) return false;
    return expiresAt!.isBefore(DateTime.now());
  }
}
