import 'dart:convert';
import 'dart:io';

class AppearancePreferences {
  AppearancePreferences({File? file})
    : file =
          file ??
          File(
            '${Platform.environment[Platform.isWindows ? 'USERPROFILE' : 'HOME'] ?? Directory.systemTemp.path}'
            '${Platform.pathSeparator}.fvm_manager${Platform.pathSeparator}appearance.json',
          );

  final File file;

  String load() {
    try {
      final data = jsonDecode(file.readAsStringSync());
      final mode = data is Map ? data['themeMode'] : null;
      return const ['system', 'light', 'dark'].contains(mode)
          ? mode as String
          : 'system';
    } on Object {
      return 'system';
    }
  }

  Future<void> save(String mode) async {
    if (!const ['system', 'light', 'dark'].contains(mode)) {
      throw ArgumentError.value(mode, 'mode');
    }
    await file.parent.create(recursive: true);
    final temporary = File('${file.path}.tmp');
    await temporary.writeAsString(jsonEncode({'themeMode': mode}), flush: true);
    await temporary.rename(file.path);
  }
}
