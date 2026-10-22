import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/appearance_preferences.dart';

final appearancePreferencesProvider = Provider<AppearancePreferences>(
  (ref) => AppearancePreferences(),
);

final appThemeModeProvider =
    NotifierProvider<AppThemeModeController, ThemeMode>(
      AppThemeModeController.new,
    );

class AppThemeModeController extends Notifier<ThemeMode> {
  Future<void> _pendingSave = Future.value();

  @override
  ThemeMode build() =>
      ThemeMode.values.byName(ref.read(appearancePreferencesProvider).load());

  Future<void> setMode(ThemeMode mode) async {
    final save = _pendingSave.then(
      (_) => ref.read(appearancePreferencesProvider).save(mode.name),
    );
    _pendingSave = save.then((_) {}, onError: (Object error) {});
    await save;
    if (ref.mounted) state = mode;
  }

  void applyFromHost(String mode) {
    state =
        ThemeMode.values.where((value) => value.name == mode).firstOrNull ??
        ThemeMode.system;
  }
}
