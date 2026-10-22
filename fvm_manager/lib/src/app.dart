import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'presentation/home_page.dart';
import 'presentation/theme/app_theme.dart';
import 'presentation/theme/theme_controller.dart';
import 'presentation/theme/window_appearance.dart';
import 'presentation/console_window_service.dart';

class FvmManagerApp extends ConsumerWidget {
  const FvmManagerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(appThemeModeProvider);
    ConsoleWindowService.instance.themeMode = mode.name;
    ref.listen(appThemeModeProvider, (_, next) {
      unawaited(ConsoleWindowService.instance.syncThemeMode(next.name));
    });
    return MaterialApp(
      title: 'Flutter Manager',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: mode,
      builder: (context, child) => WindowAppearance(mode: mode, child: child!),
      home: const HomePage(),
    );
  }
}
