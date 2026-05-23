import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shizuku_api/shizuku_api.dart';
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
    required String key,
    required String username,
    required Function(double progress, String speed, String eta, String sizeInfo) onProgress,
    required Function(String log) onLog,
  }) async {
    try {
      final cleanUrl = _sanitizeUrl(backendUrl);
      final String downloadEndpoint = '$cleanUrl/api/download/libil2cpp'
          '?key=${Uri.encodeComponent(key)}'
          '&username=${Uri.encodeComponent(username)}'
          '&deviceFingerprint=${Uri.encodeComponent(ConfigService().deviceFingerprint)}';
      onLog('Initializing download from endpoint: $downloadEndpoint');

      // Resolve a safe temporary file location (external for Android to allow Shizuku shell user to access it)
      Directory tempDir = await getTemporaryDirectory();
      if (Platform.isAndroid) {
        try {
          final List<Directory>? extCacheDirs = await getExternalCacheDirectories();
          if (extCacheDirs != null && extCacheDirs.isNotEmpty) {
            tempDir = extCacheDirs.first;
          }
        } catch (_) {
          // Fall back to standard temp dir if external cache is unavailable
        }
      }
      final String tempFilePath = '${tempDir.path}/libil2cpp_downloading.so';
      final File tempFile = File(tempFilePath);
      if (await tempFile.exists()) {
        await tempFile.delete();
      }

      onLog('Created temporary download file at: $tempFilePath');
      onLog('Connecting to backend...');

      final int startTime = DateTime.now().millisecondsSinceEpoch;

      final Response response = await _dio.download(
         downloadEndpoint,
         tempFilePath,
         onReceiveProgress: (received, total) {
           if (total != -1 && total > 0) {
             final double progress = received / total;
             final int now = DateTime.now().millisecondsSinceEpoch;
             final int totalElapsedMs = now - startTime;
             
             // Speed calculation (over the last time interval to keep it smooth)
             double speedBps = 0.0;
             if (totalElapsedMs > 0) {
               speedBps = (received / totalElapsedMs) * 1000; // Bytes per second
             }
             
             final double speedMbps = speedBps / (1024 * 1024);
             final String speedStr = '${speedMbps.toStringAsFixed(2)} MB/s';
             
             // ETA calculation
             String etaStr = '--:--';
             if (speedBps > 0) {
               final double remainingBytes = (total - received).toDouble();
               final double remainingSeconds = remainingBytes / speedBps;
               if (remainingSeconds < 60) {
                 etaStr = '${remainingSeconds.toStringAsFixed(0)}s';
               } else {
                 final int minutes = (remainingSeconds / 60).floor();
                 final int seconds = (remainingSeconds % 60).round();
                 etaStr = '${minutes}m ${seconds}s';
               }
             }
             
             final String sizeInfo = '${(received / (1024 * 1024)).toStringAsFixed(1)} MB / ${(total / (1024 * 1024)).toStringAsFixed(1)} MB';
             onProgress(progress, speedStr, etaStr, sizeInfo);
           } else {
             onProgress(0.0, '0.00 MB/s', '--:--', '0 MB / 0 MB');
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
        copySuccess = await _copyAsRoot(tempFilePath, finalFilePath, onLog: onLog);
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

  /// Copies a file using root command permissions (`su`) or Shizuku fallback.
  Future<bool> _copyAsRoot(String sourcePath, String destPath, {required Function(String log) onLog}) async {
    // 1. Try standard su root execution first
    try {
      final targetDirectory = destPath.substring(0, destPath.lastIndexOf('/'));
      onLog('Root fallback: Attempting to mkdir -p "$targetDirectory" via su');
      final mkdirResult = await Process.run('su', ['-c', 'mkdir -p "$targetDirectory"']);
      if (mkdirResult.exitCode == 0) {
        onLog('Root fallback: su mkdir successful. Copying payload...');
        final cpResult = await Process.run('su', ['-c', 'cp "$sourcePath" "$destPath"']);
        if (cpResult.exitCode == 0) {
          onLog('Root fallback: su cp successful. Adjusting permissions...');
          await Process.run('su', ['-c', 'chmod 644 "$destPath"']);
          return true;
        } else {
          onLog('Root fallback: su cp failed (exit code ${cpResult.exitCode}): ${cpResult.stderr}');
        }
      } else {
        onLog('Root fallback: su mkdir failed (exit code ${mkdirResult.exitCode}): ${mkdirResult.stderr}');
      }
    } catch (e) {
      onLog('Root fallback: su execution failed: $e');
    }

    // 2. Try Shizuku fallback on non-rooted devices
    try {
      final shizuku = ShizukuApi();
      onLog('Shizuku fallback: Checking if Shizuku binder is running...');
      final isRunning = await shizuku.pingBinder() ?? false;
      if (isRunning) {
        onLog('Shizuku fallback: Shizuku binder is active. Checking permission...');
        var hasPermission = await shizuku.checkPermission() ?? false;
        if (!hasPermission) {
          onLog('Shizuku fallback: Requesting Shizuku authorization...');
          hasPermission = await shizuku.requestPermission() ?? false;
        }
        if (hasPermission) {
          onLog('Shizuku fallback: Shizuku permission granted.');
          final targetDirectory = destPath.substring(0, destPath.lastIndexOf('/'));
          
          onLog('Shizuku fallback: Creating target directory...');
          final mkdirOut = await shizuku.runCommand('mkdir -p "$targetDirectory"');
          if (mkdirOut != null && mkdirOut.isNotEmpty) {
            onLog('Shizuku fallback: mkdir output: $mkdirOut');
          }

          onLog('Shizuku fallback: Copying payload from $sourcePath to $destPath...');
          final cpOut = await shizuku.runCommand('cp "$sourcePath" "$destPath"');
          if (cpOut != null && cpOut.isNotEmpty) {
            onLog('Shizuku fallback: cp output: $cpOut');
          }

          onLog('Shizuku fallback: Adjusting file permissions to 644...');
          final chmodOut = await shizuku.runCommand('chmod 644 "$destPath"');
          if (chmodOut != null && chmodOut.isNotEmpty) {
            onLog('Shizuku fallback: chmod output: $chmodOut');
          }

          // Verify file exists in destination path using Shizuku
          final checkResult = await shizuku.runCommand('[ -f "$destPath" ] && echo "exists"');
          onLog('Shizuku fallback: Check path existence output: $checkResult');
          if (checkResult != null && checkResult.contains('exists')) {
            onLog('Shizuku fallback: Success! File exists at destination.');
            return true;
          } else {
            onLog('Shizuku fallback: Error! File does not exist at destination after copy.');
          }
        } else {
          onLog('Shizuku fallback: Shizuku permission was denied by the user.');
        }
      } else {
        onLog('Shizuku fallback: Shizuku binder service is not running.');
      }
    } catch (e) {
      onLog('Shizuku fallback: Exception during Shizuku command execution: $e');
    }

    return false;
  }
}
