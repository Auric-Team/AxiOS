import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class LauncherService {
  static const _channel = MethodChannel('com.axios.installer/launcher');

  /// Attempts to launch an installed Android application package.
  Future<bool> launchApp(String packageName) async {
    try {
      final bool success = await _channel.invokeMethod('launchApp', {
        'packageName': packageName,
      });
      return success;
    } on PlatformException catch (e) {
      debugPrint('Failed to launch application: ${e.message}');
      return false;
    }
  }
}
