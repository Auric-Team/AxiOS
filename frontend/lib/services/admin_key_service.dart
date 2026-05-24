import 'package:dio/dio.dart';
import '../models/access_key.dart';

class AdminKeyService {
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

  /// Fetches all keys for admin dashboard
  Future<List<AccessKey>> fetchKeys({
    required String backendUrl,
    required String token,
  }) async {
    try {
      final cleanUrl = _sanitizeUrl(backendUrl);
      final response = await _dio.get(
        '$cleanUrl/api/keys',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      if (response.statusCode == 200 && response.data['keys'] != null) {
        final list = response.data['keys'] as List;
        return list.map((k) => AccessKey.fromJson(k)).toList();
      }
    } catch (_) {}
    return [];
  }

  /// Generates new keys
  Future<bool> generateKeys({
    required String backendUrl,
    required String token,
    String? prefix,
    required int count,
    required int maxUses,
    int? expiresInHours,
    String? assignedTo,
    required String targetGame,
  }) async {
    try {
      final cleanUrl = _sanitizeUrl(backendUrl);
      final response = await _dio.post(
        '$cleanUrl/api/keys/generate',
        data: {
          'prefix': prefix?.isEmpty == true ? null : prefix,
          'count': count,
          'maxUses': maxUses,
          'expiresInHours': expiresInHours,
          'assignedTo': assignedTo?.isEmpty == true ? null : assignedTo,
          'targetGame': targetGame,
        },
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Deletes a key
  Future<bool> deleteKey({
    required String backendUrl,
    required String token,
    required String keyId,
  }) async {
    try {
      final cleanUrl = _sanitizeUrl(backendUrl);
      final response = await _dio.delete(
        '$cleanUrl/api/keys/$keyId',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Resets a key's device fingerprint
  Future<bool> resetFingerprint({
    required String backendUrl,
    required String token,
    required String keyId,
  }) async {
    try {
      final cleanUrl = _sanitizeUrl(backendUrl);
      final response = await _dio.patch(
        '$cleanUrl/api/keys/$keyId/reset-fingerprint',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Toggles key status (active/inactive)
  Future<bool> toggleKeyStatus({
    required String backendUrl,
    required String token,
    required String keyId,
  }) async {
    try {
      final cleanUrl = _sanitizeUrl(backendUrl);
      final response = await _dio.patch(
        '$cleanUrl/api/keys/$keyId/status',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Deactivates all keys
  Future<Map<String, dynamic>> deactivateAll({
    required String backendUrl,
    required String token,
  }) async {
    try {
      final cleanUrl = _sanitizeUrl(backendUrl);
      final response = await _dio.patch(
        '$cleanUrl/api/keys/deactivate-all',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      if (response.statusCode == 200) {
        return {'success': true, 'message': response.data['message']};
      }
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
    return {'success': false, 'error': 'Unknown error.'};
  }

  /// Prunes expired/disabled keys
  Future<Map<String, dynamic>> pruneKeys({
    required String backendUrl,
    required String token,
  }) async {
    try {
      final cleanUrl = _sanitizeUrl(backendUrl);
      final response = await _dio.delete(
        '$cleanUrl/api/keys/prune-inactive',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      if (response.statusCode == 200) {
        return {'success': true, 'message': response.data['message']};
      }
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
    return {'success': false, 'error': 'Unknown error.'};
  }
}
