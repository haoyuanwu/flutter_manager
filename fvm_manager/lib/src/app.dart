import 'package:flutter/material.dart';

import 'presentation/home_page.dart';
import 'presentation/theme/app_theme.dart';

class FvmManagerApp extends StatelessWidget {
  const FvmManagerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Manager',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: AppColors.scaffoldBackground,
        cardTheme: CardThemeData(
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.lgAll,
            side: const BorderSide(color: AppColors.border),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: AppButtonStyles.primary,
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: AppButtonStyles.outline,
        ),
        textButtonTheme: TextButtonThemeData(
          style: AppButtonStyles.text,
        ),
        iconButtonTheme: IconButtonThemeData(
          style: AppButtonStyles.icon,
        ),
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
          isDense: true,
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
        chipTheme: ChipThemeData(
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.smAll,
          ),
        ),
      ),
      home: const HomePage(),
    );
  }
}
