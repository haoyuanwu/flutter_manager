import 'dart:io';
import 'package:flutter/services.dart';

/// Native macOS notification. Notification delivery must never fail a build.
class BuildNotificationService {
  const BuildNotificationService();
  static const channel = MethodChannel('fvm_manager/build_notifications');

  Future<bool> completed({
    required String projectName,
    required String directory,
  }) async {
    if (!Platform.isMacOS) return false;
    try {
      return await channel.invokeMethod<bool>('buildCompleted', {
            'projectName': projectName,
            'directory': directory,
          }) ??
          false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }
}
