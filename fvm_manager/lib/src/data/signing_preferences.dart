import 'dart:convert';
import 'dart:io';

class SigningPreferences {
  const SigningPreferences({
    this.rememberChoice = false,
    this.replaceSource = false,
  });
  final bool rememberChoice;
  final bool replaceSource;
  SigningPreferences copyWith({bool? rememberChoice, bool? replaceSource}) =>
      SigningPreferences(
        rememberChoice: rememberChoice ?? this.rememberChoice,
        replaceSource: replaceSource ?? this.replaceSource,
      );
}

class SigningPreferencesStore {
  SigningPreferencesStore({File? file})
    : file =
          file ??
          File(
            '${Platform.environment[Platform.isWindows ? 'USERPROFILE' : 'HOME'] ?? Directory.systemTemp.path}'
            '${Platform.pathSeparator}.fvm_manager${Platform.pathSeparator}signing_preferences.json',
          );
  final File file;

  SigningPreferences load() {
    try {
      final json = jsonDecode(file.readAsStringSync());
      if (json is Map) {
        return SigningPreferences(
          rememberChoice: json['rememberChoice'] == true,
          replaceSource: json['replaceSource'] == true,
        );
      }
    } on Object {
      /* Missing/corrupt settings always ask, with keep as default. */
    }
    return const SigningPreferences();
  }

  Future<void> save(SigningPreferences value) async {
    await file.parent.create(recursive: true);
    final pending = File('${file.path}.tmp');
    await pending.writeAsString(
      jsonEncode({
        'rememberChoice': value.rememberChoice,
        'replaceSource': value.replaceSource,
      }),
      flush: true,
    );
    await pending.rename(file.path);
  }
}
