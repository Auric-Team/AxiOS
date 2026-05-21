import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'config_service.dart';

class DownloadService {
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

  /// Downloads the libil2cpp file from the backend and places it into the target directory.
  Future<bool> downloadAndDeploy({
    required String backendUrl,
    required String targetPath,
    required Function(double progress) onProgress,
    required Function(String log) onLog,
  }) async {
    try {
      final cleanUrl = _sanitizeUrl(backendUrl);
      final String downloadEndpoint = '$cleanUrl/api/download/libil2cpp';
      onLog('Initializing download from endpoint: $downloadEndpoint');

      // Resolve a safe temporary file location
      final Directory tempDir = await getTemporaryDirectory();
      final String tempFilePath = '${tempDir.path}/libil2cpp_downloading.so';
      final File tempFile = File(tempFilePath);
      if (await tempFile.exists()) {
        await tempFile.delete();
      }

      onLog('Created temporary download file at: $tempFilePath');
      onLog('Connecting to backend...');

      final Response response = await _dio.download(
        downloadEndpoint,
        tempFilePath,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            final double progress = received / total;
            onProgress(progress);
          } else {
            onProgress(0.0);
          }
        },
      );

      if (response.statusCode != 200) {
        onLog('Error: Server returned status code ${response.statusCode}');
        return false;
      }

      onLog('Download complete (${await tempFile.length()} bytes). Beginning deployment...');

      // Ensure target directory exists
      final Directory destDir = Directory(targetPath);
      if (!await destDir.exists()) {
        onLog('Target directory does not exist. Creating directories recursively...');
        await destDir.create(recursive: true);
      }

      // Copy/move file to target path
      final String finalFilePath = '$targetPath/libil2cpp.so';
      onLog('Deploying payload to: $finalFilePath');
      
      final File finalFile = File(finalFilePath);
      if (await finalFile.exists()) {
        onLog('Existing target file detected. Overwriting libil2cpp.so...');
        try {
          await finalFile.delete();
        } catch (_) {
          // If we can't delete it normally, we will try to overwrite/delete it via root copy
        }
      }

      // Copy temp file to final location
      bool copySuccess = false;
      try {
        await tempFile.copy(finalFilePath);
        copySuccess = true;
      } catch (e) {
        onLog('Standard file copy failed due to Android permission restrictions. Attempting root fallback...');
        copySuccess = await _copyAsRoot(tempFilePath, finalFilePath);
        if (!copySuccess) {
          onLog('Root copy fallback failed or root access is not available.');
          rethrow;
        }
      }
      
      // Clean up temp file
      if (await tempFile.exists()) {
        await tempFile.delete();
      }

      onLog('Success: Payload deployed to $finalFilePath');
      return true;
    } catch (e) {
      onLog('Exception during download/deploy: $e');

      if (e is DioException) {
        onLog('Network Error details: ${e.message}');
        if (e.response != null) {
          onLog('Server response: ${e.response?.data}');
        }
      }
      return false;
    }
  }

  /// Verifies connectivity to the backend status endpoint.
  Future<Map<String, dynamic>?> checkStatus(String backendUrl) async {
    try {
      final cleanUrl = _sanitizeUrl(backendUrl);
      final response = await _dio.get('$cleanUrl/api/status').timeout(
        const Duration(seconds: 5),
      );

      if (response.statusCode == 200) {
        return response.data as Map<String, dynamic>;
      }
    } catch (e) {
      // Ignored print logs to clean up analyzer
    }
    return null;
  }

  /// Sends a User Registration Request
  Future<Map<String, dynamic>> register({
    required String backendUrl,
    required String username,
    required String password,
  }) async {
    try {
      final cleanUrl = _sanitizeUrl(backendUrl);
      final response = await _dio.post(
        '$cleanUrl/api/register',
        data: {
          'username': username,
          'password': password,
          'deviceFingerprint': ConfigService().deviceFingerprint,
        },
      );
      if (response.statusCode == 200) {
        return {'success': true, 'message': response.data['message'] ?? 'Registration complete.'};
      }
    } on DioException catch (e) {
      final msg = e.response?.data != null && e.response?.data['error'] != null
          ? e.response?.data['error']
          : 'Registration connection failed.';
      return {'success': false, 'error': msg};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
    return {'success': false, 'error': 'Unknown error.'};
  }

  /// Sends a User Login Request
  Future<Map<String, dynamic>> login({
    required String backendUrl,
    required String username,
    required String password,
  }) async {
    try {
      final cleanUrl = _sanitizeUrl(backendUrl);
      final response = await _dio.post(
        '$cleanUrl/api/login',
        data: {
          'username': username,
          'password': password,
          'deviceFingerprint': ConfigService().deviceFingerprint,
        },
      );
      if (response.statusCode == 200 && response.data['token'] != null) {
        return {
          'success': true,
          'token': response.data['token'],
          'role': response.data['role'] ?? 'user'
        };
      }
    } on DioException catch (e) {
      final msg = e.response?.data != null && e.response?.data['error'] != null
          ? e.response?.data['error']
          : 'Login connection failed.';
      return {'success': false, 'error': msg};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
    return {'success': false, 'error': 'Invalid response.'};
  }

  /// Verifies if a stored JWT Session Token is still valid.
  Future<Map<String, dynamic>> verifyToken({
    required String backendUrl,
    required String token,
  }) async {
    try {
      final cleanUrl = _sanitizeUrl(backendUrl);
      final response = await _dio.get(
        '$cleanUrl/api/verify',
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
        ),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        return {
          'success': true,
          'username': response.data['username'],
          'role': response.data['role'] ?? 'user'
        };
      }
    } on DioException catch (e) {
      final msg = e.response?.data != null && e.response?.data['error'] != null
          ? e.response?.data['error']
          : 'Token validation failure.';
      return {'success': false, 'error': msg};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
    return {'success': false, 'error': 'Invalid Token Session.'};
  }

  /// Copies a file using root command permissions (`su`).
  Future<bool> _copyAsRoot(String sourcePath, String destPath) async {
    try {
      // 1. Create target directory recursively via root
      final targetDirectory = destPath.substring(0, destPath.lastIndexOf('/'));
      final mkdirResult = await Process.run('su', ['-c', 'mkdir -p "$targetDirectory"']);
      if (mkdirResult.exitCode != 0) {
        return false;
      }

      // 2. Perform the copy operation via root cp
      final cpResult = await Process.run('su', ['-c', 'cp "$sourcePath" "$destPath"']);
      if (cpResult.exitCode == 0) {
        // 3. Set standard readable permissions
        await Process.run('su', ['-c', 'chmod 644 "$destPath"']);
        return true;
      }
    } catch (_) {}
    return false;
  }
}
