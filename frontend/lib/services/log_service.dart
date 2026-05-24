import 'package:dio/dio.dart';
import '../models/audit_log.dart';

class LogService {
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

  /// Fetches paginated logs from the server
  Future<Map<String, dynamic>> fetchLogs({
    required String backendUrl,
    required String token,
    required int page,
    required int limit,
    required String level,
    required String category,
    required String search,
  }) async {
    try {
      final cleanUrl = _sanitizeUrl(backendUrl);
      final response = await _dio.get(
        '$cleanUrl/api/logs',
        queryParameters: {
          'page': page,
          'limit': limit,
          'level': level,
          'category': category,
          'search': search,
        },
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      if (response.statusCode == 200 && response.data['logs'] != null) {
        final list = response.data['logs'] as List;
        final logs = list.map((l) => AuditLog.fromJson(l)).toList();
        int totalPages = 1;
        if (response.data['pagination'] != null) {
          totalPages = response.data['pagination']['pages'] as int;
        }
        return {
          'success': true,
          'logs': logs,
          'totalPages': totalPages,
        };
      }
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
    return {'success': false, 'error': 'Failed to fetch logs.'};
  }

  /// Deletes all logs on the backend
  Future<bool> clearLogs({
    required String backendUrl,
    required String token,
  }) async {
    try {
      final cleanUrl = _sanitizeUrl(backendUrl);
      final response = await _dio.delete(
        '$cleanUrl/api/logs',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
