import 'package:dio/dio.dart';
import '../models/app_user.dart';

class AdminUserService {
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

  /// Fetches all registered users for admin dashboard
  Future<List<AppUser>> fetchUsers({
    required String backendUrl,
    required String token,
  }) async {
    try {
      final cleanUrl = _sanitizeUrl(backendUrl);
      final response = await _dio.get(
        '$cleanUrl/api/users',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      if (response.statusCode == 200 && response.data['users'] != null) {
        final list = response.data['users'] as List;
        return list.map((u) => AppUser.fromJson(u)).toList();
      }
    } catch (_) {}
    return [];
  }

  /// Deletes a registered operator user
  Future<bool> deleteUser({
    required String backendUrl,
    required String token,
    required String userId,
  }) async {
    try {
      final cleanUrl = _sanitizeUrl(backendUrl);
      final response = await _dio.delete(
        '$cleanUrl/api/users/$userId',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Updates user role ('admin' or 'user')
  Future<bool> updateUserRole({
    required String backendUrl,
    required String token,
    required String userId,
    required String role,
  }) async {
    try {
      final cleanUrl = _sanitizeUrl(backendUrl);
      final response = await _dio.patch(
        '$cleanUrl/api/users/$userId/role',
        data: {'role': role},
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
