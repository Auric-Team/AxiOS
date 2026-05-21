import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';

class DetectionService {
  static const String androidDataRoot = '/storage/emulated/0/Android/data';

  /// Requests the best possible storage permissions depending on Android version.
  Future<bool> requestStoragePermission() async {
    if (!Platform.isAndroid) return true;

    // Check Android SDK level
    final androidInfo = await DeviceInfoPlugin().androidInfo;
    final sdkInt = androidInfo.version.sdkInt;

    if (sdkInt >= 30) {
      // Android 11+ requires MANAGE_EXTERNAL_STORAGE for broad path access
      var status = await Permission.manageExternalStorage.status;
      if (!status.isGranted) {
        status = await Permission.manageExternalStorage.request();
      }
      return status.isGranted;
    } else {
      // Android 10 and below require standard storage permissions
      var readStatus = await Permission.storage.status;
      if (!readStatus.isGranted) {
        readStatus = await Permission.storage.request();
      }
      return readStatus.isGranted;
    }
  }

  /// Detects whether the game package directory exists on device storage.
  /// If it exists, returns the full path. If not, returns path anyway to create it.
  Future<String?> detectGameDirectory(String packageName) async {
    if (!Platform.isAndroid) {
      return '/mock/storage/Android/data/$packageName';
    }

    final targetPath = '$androidDataRoot/$packageName';
    try {
      final dataDir = Directory(targetPath);
      // Even if the directory is empty or not yet visible in direct listing, we try to access it
      if (await dataDir.exists()) {
        return targetPath;
      }
      
      // Attempt to create it. If we can, it means the permission is operational.
      await dataDir.create(recursive: true);
      return targetPath;
    } catch (e) {
      debugPrint('Game directory detection error: $e');
      // If we cannot verify or create, we fall back to returning the path so user can attempt deploy
      return targetPath;
    }
  }
}
