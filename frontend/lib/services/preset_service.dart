import 'package:dio/dio.dart';
import '../config.dart';

class PresetService {
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

  /// Fetches game presets dynamically from the backend server.
  Future<List<PresetGame>> getPresets({
    required String backendUrl,
    required String token,
  }) async {
    try {
      final cleanUrl = _sanitizeUrl(backendUrl);
      final response = await _dio.get(
        '$cleanUrl/api/presets',
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
        ),
      );

      if (response.statusCode == 200 && response.data['presets'] != null) {
        final list = response.data['presets'] as List;
        return list.map((item) {
          return PresetGame(
            package: item['package'] as String,
            name: item['name'] as String,
          );
        }).toList();
      }
    } catch (_) {
      // Ignored print to clean up static analyzer warnings
    }
    // Return empty list on failure
    return [];
  }

  /// Admin-only: Creates a dynamic target game preset.
  Future<bool> createPreset({
    required String backendUrl,
    required String token,
    required String name,
    required String package,
  }) async {
    try {
      final cleanUrl = _sanitizeUrl(backendUrl);
      final response = await _dio.post(
        '$cleanUrl/api/presets',
        data: {
          'name': name.trim(),
          'package': package.trim(),
        },
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
        ),
      );
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Admin-only: Deletes a target game preset.
  Future<bool> deletePreset({
    required String backendUrl,
    required String token,
    required String package,
  }) async {
    try {
      final cleanUrl = _sanitizeUrl(backendUrl);
      final response = await _dio.delete(
        '$cleanUrl/api/presets/${Uri.encodeComponent(package)}',
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
        ),
      );
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
