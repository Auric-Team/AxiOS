class AuditLog {
  final String id;
  final String level; // info, warn, error
  final String category; // auth, key, download, upload, system
  final String message;
  final String? ip;
  final String? deviceInfo;
  final DateTime timestamp;

  AuditLog({
    required this.id,
    required this.level,
    required this.category,
    required this.message,
    this.ip,
    this.deviceInfo,
    required this.timestamp,
  });

  factory AuditLog.fromJson(Map<String, dynamic> json) {
    return AuditLog(
      id: json['_id'] ?? '',
      level: json['level'] ?? 'info',
      category: json['category'] ?? 'system',
      message: json['message'] ?? '',
      ip: json['ip'],
      deviceInfo: json['deviceInfo'],
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'level': level,
      'category': category,
      'message': message,
      'ip': ip,
      'deviceInfo': deviceInfo,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}
