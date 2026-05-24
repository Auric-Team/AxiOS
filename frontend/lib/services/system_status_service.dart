import 'package:dio/dio.dart';
import '../models/system_status.dart';

class SystemStatusService {
  final Dio _dio = Dio();

  String _sanitizeUrl(String backendUrl) {
    String cleanUrl = backendUrl.trim();
    if (!cleanUrl.startsWith('http://') && !cleanUrl.startsWith('https://')) {
      cleanUrl = 'http://$cleanUrl';
    }
    if (cleanUrl.endsWith('/')) {
      cleanUrl = cleanUrl.substring(0, cleanUrl.length - 1);
    }
    return cleanUrl;
  }

  /// Fetches system status details
  Future<SystemStatus?> fetchStatus({required String backendUrl}) async {
    try {
      final cleanUrl = _sanitizeUrl(backendUrl);
      final response = await _dio.get('$cleanUrl/api/status');
      if (response.statusCode == 200) {
        return SystemStatus.fromJson(response.data);
      }
    } catch (_) {}
    return null;
  }

  /// Uploads binary payload targeting a specific game package
  Future<bool> uploadPayload({
    required String backendUrl,
    required String token,
    required String filePath,
    String? targetGame,
    required Function(double progress) onProgress,
  }) async {
    try {
      final cleanUrl = _sanitizeUrl(backendUrl);
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(filePath, filename: 'libil2cpp.so'),
      });

      final String queryParam = targetGame != null && targetGame.trim().isNotEmpty
          ? '?targetGame=${Uri.encodeComponent(targetGame.trim())}'
          : '';

      final response = await _dio.post(
        '$cleanUrl/api/upload$queryParam',
        data: formData,
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
          connectTimeout: const Duration(minutes: 5),
          sendTimeout: const Duration(minutes: 15),
          receiveTimeout: const Duration(minutes: 15),
        ),
        onSendProgress: (sent, total) {
          if (total > 0) {
            onProgress(sent / total);
          }
        },
      );

      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
