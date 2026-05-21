import 'package:dio/dio.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io';
import 'config_service.dart';

class KeyService {
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

  /// Resolves the current device brand and model to send as audit payload metadata.
  Future<String> _getDeviceMetadata() async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        return '${androidInfo.brand} ${androidInfo.model} (Android ${androidInfo.version.release})';
      }
    } catch (_) {}
    return 'Unknown Device';
  }

  /// Verifies an Access Key with the backend and returns target details.
  Future<Map<String, dynamic>> verifyKey({
    required String backendUrl,
    required String key,
    required String username,
  }) async {
    try {
      final cleanUrl = _sanitizeUrl(backendUrl);
      final metadata = await _getDeviceMetadata();

      final response = await _dio.post(
        '$cleanUrl/api/keys/verify',
        data: {
          'key': key.trim(),
          'username': username.trim(),
          'deviceFingerprint': ConfigService().deviceFingerprint,
        },
        options: Options(
          headers: {
            'X-Device-Info': metadata,
          },
        ),
      );

      if (response.statusCode == 200) {
        return {
          'success': true,
          'targetGame': response.data['targetGame'] ?? 'com.herogame.gplay.lastdayrulessurvival'
        };
      }
    } on DioException catch (e) {
      final errorMsg = e.response?.data != null && e.response?.data['error'] != null
          ? e.response?.data['error']
          : 'Activation key verification failed.';
      return {'success': false, 'error': errorMsg};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
    return {'success': false, 'error': 'Failed to verify key.'};
  }
}
