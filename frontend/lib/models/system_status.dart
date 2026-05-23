class SystemConfig {
  final String uploadDir;
  final bool mockBinaryEnabled;
  final String logLevel;
  final String dbStatus;

  SystemConfig({
    required this.uploadDir,
    required this.mockBinaryEnabled,
    required this.logLevel,
    required this.dbStatus,
  });

  factory SystemConfig.fromJson(Map<String, dynamic> json) {
    return SystemConfig(
      uploadDir: json['uploadDir'] ?? '',
      mockBinaryEnabled: json['mockBinaryEnabled'] ?? false,
      logLevel: json['logLevel'] ?? 'info',
      dbStatus: json['dbStatus'] ?? 'disconnected',
    );
  }
}

class SystemHardwareInfo {
  final String platform;
  final String release;
  final int uptime;
  final int totalMemory;
  final int freeMemory;
  final double memoryUsagePercentage;
  final String cpuModel;
  final int cpuCores;
  final List<double> loadAverage;

  SystemHardwareInfo({
    required this.platform,
    required this.release,
    required this.uptime,
    required this.totalMemory,
    required this.freeMemory,
    required this.memoryUsagePercentage,
    required this.cpuModel,
    required this.cpuCores,
    required this.loadAverage,
  });

  factory SystemHardwareInfo.fromJson(Map<String, dynamic> json) {
    var rawLoad = json['loadAverage'];
    List<double> parsedLoad = [0.0, 0.0, 0.0];
    if (rawLoad is List) {
      for (int i = 0; i < rawLoad.length && i < 3; i++) {
        parsedLoad[i] = (rawLoad[i] as num).toDouble();
      }
    }

    return SystemHardwareInfo(
      platform: json['platform'] ?? 'unknown',
      release: json['release'] ?? '',
      uptime: json['uptime'] is int ? json['uptime'] : (json['uptime'] as num?)?.toInt() ?? 0,
      totalMemory: json['totalMemory'] is int ? json['totalMemory'] : (json['totalMemory'] as num?)?.toInt() ?? 0,
      freeMemory: json['freeMemory'] is int ? json['freeMemory'] : (json['freeMemory'] as num?)?.toInt() ?? 0,
      memoryUsagePercentage: (json['memoryUsagePercentage'] as num?)?.toDouble() ?? 0.0,
      cpuModel: json['cpuModel'] ?? 'Unknown CPU',
      cpuCores: json['cpuCores'] is int ? json['cpuCores'] : (json['cpuCores'] as num?)?.toInt() ?? 1,
      loadAverage: parsedLoad,
    );
  }
}

class SystemStatus {
  final String status;
  final String message;
  final SystemConfig config;
  final SystemHardwareInfo system;
  final bool binaryExists;
  final int binarySize;
  final String timestamp;

  SystemStatus({
    required this.status,
    required this.message,
    required this.config,
    required this.system,
    required this.binaryExists,
    required this.binarySize,
    required this.timestamp,
  });

  factory SystemStatus.fromJson(Map<String, dynamic> json) {
    return SystemStatus(
      status: json['status'] ?? 'offline',
      message: json['message'] ?? '',
      config: SystemConfig.fromJson(json['config'] ?? {}),
      system: SystemHardwareInfo.fromJson(json['system'] ?? {}),
      binaryExists: json['binaryExists'] ?? false,
      binarySize: json['binarySize'] is int ? json['binarySize'] : (json['binarySize'] as num?)?.toInt() ?? 0,
      timestamp: json['timestamp'] ?? '',
    );
  }
}
