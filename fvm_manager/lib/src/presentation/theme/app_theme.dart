import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

class AppTheme {
  AppTheme._();

  static final light = _build(Brightness.light);
  static final dark = _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final colors =
        ColorScheme.fromSeed(
          seedColor: const Color(0xff3559d9),
          brightness: brightness,
        ).copyWith(
          primary: dark ? const Color(0xffa9beff) : const Color(0xff3559d9),
          onPrimary: dark ? const Color(0xff142967) : Colors.white,
          primaryContainer: dark
              ? const Color(0xff25365e)
              : const Color(0xffeaf0ff),
          onPrimaryContainer: dark
              ? const Color(0xffdce5ff)
              : const Color(0xff2745a8),
          surface: dark ? const Color(0xff1b2435) : const Color(0xffffffff),
          surfaceContainerLowest: dark
              ? const Color(0xff111827)
              : const Color(0xfff4f6fb),
          surfaceContainerLow: dark
              ? const Color(0xff202c40)
              : const Color(0xfff8f9fd),
          surfaceContainer: dark
              ? const Color(0xff27344a)
              : const Color(0xffedf1f8),
          surfaceContainerHigh: dark
              ? const Color(0xff303f57)
              : const Color(0xffe6ebf5),
          surfaceContainerHighest: dark
              ? const Color(0xff3a4b65)
              : const Color(0xffdce3ef),
          onSurface: dark ? const Color(0xffedf2fc) : const Color(0xff202d45),
          onSurfaceVariant: dark
              ? const Color(0xffb5c1d7)
              : const Color(0xff5d6b82),
          outline: dark ? const Color(0xff8191ad) : const Color(0xff8290a8),
          outlineVariant: dark
              ? const Color(0xff394962)
              : const Color(0xffdfe5f0),
          secondary: dark ? const Color(0xff77dfcc) : const Color(0xff087f78),
          onSecondary: dark ? const Color(0xff063c36) : Colors.white,
          secondaryContainer: dark
              ? const Color(0xff173d3b)
              : const Color(0xffe5f6f1),
          onSecondaryContainer: dark
              ? const Color(0xffb2f3e7)
              : const Color(0xff075e57),
          tertiary: dark ? const Color(0xfff2c67e) : const Color(0xffa56314),
          onTertiary: dark ? const Color(0xff382407) : Colors.white,
          tertiaryContainer: dark
              ? const Color(0xff433521)
              : const Color(0xfffff4df),
          onTertiaryContainer: dark
              ? const Color(0xffffdba2)
              : const Color(0xff775019),
          error: dark ? const Color(0xffffa2ab) : const Color(0xffbb3544),
          onError: dark ? const Color(0xff56141e) : Colors.white,
          errorContainer: dark
              ? const Color(0xff43282e)
              : const Color(0xffffecef),
          onErrorContainer: dark
              ? const Color(0xffffcbd1)
              : const Color(0xff942936),
        );
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: colors,
      brightness: brightness,
      fontFamily: switch (defaultTargetPlatform) {
        TargetPlatform.windows => 'Segoe UI',
        TargetPlatform.macOS => '.AppleSystemUIFont',
        _ => 'Roboto',
      },
      fontFamilyFallback: const [
        'Microsoft YaHei',
        'PingFang SC',
        'sans-serif',
      ],
    );
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.md),
    );
    final button = ButtonStyle(
      visualDensity: VisualDensity.standard,
      animationDuration: const Duration(milliseconds: 120),
      overlayColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.pressed)
            ? colors.primary.withValues(alpha: .16)
            : states.contains(WidgetState.focused)
            ? colors.primary.withValues(alpha: .12)
            : states.contains(WidgetState.hovered)
            ? colors.primary.withValues(alpha: .08)
            : null,
      ),
      minimumSize: const WidgetStatePropertyAll(Size(36, 36)),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      ),
      shape: WidgetStatePropertyAll(shape),
      textStyle: WidgetStatePropertyAll(
        TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          letterSpacing: 0,
          fontFamily: base.textTheme.bodyMedium?.fontFamily,
          fontFamilyFallback: const [
            'Microsoft YaHei',
            'PingFang SC',
            'sans-serif',
          ],
        ),
      ),
    );
    return base.copyWith(
      scaffoldBackgroundColor: colors.surfaceContainerLowest,
      visualDensity: VisualDensity.compact,
      textTheme: base.textTheme
          .copyWith(
            headlineSmall: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: colors.onSurface,
            ),
            titleLarge: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: colors.onSurface,
            ),
            titleMedium: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: colors.onSurface,
            ),
            bodyLarge: TextStyle(
              fontSize: 14,
              height: 1.45,
              color: colors.onSurface,
            ),
            bodyMedium: TextStyle(
              fontSize: 13,
              height: 1.45,
              color: colors.onSurface,
            ),
            bodySmall: TextStyle(
              fontSize: 12,
              height: 1.4,
              color: colors.onSurfaceVariant,
            ),
          )
          .apply(
            fontFamily: base.textTheme.bodyMedium?.fontFamily,
            fontFamilyFallback: const [
              'Microsoft YaHei',
              'PingFang SC',
              'sans-serif',
            ],
          )
          .merge(
            const TextTheme(
              displayLarge: TextStyle(letterSpacing: 0),
              displayMedium: TextStyle(letterSpacing: 0),
              displaySmall: TextStyle(letterSpacing: 0),
              headlineLarge: TextStyle(letterSpacing: 0),
              headlineMedium: TextStyle(letterSpacing: 0),
              headlineSmall: TextStyle(letterSpacing: 0),
              titleLarge: TextStyle(letterSpacing: 0),
              titleMedium: TextStyle(letterSpacing: 0),
              titleSmall: TextStyle(letterSpacing: 0),
              bodyLarge: TextStyle(letterSpacing: 0),
              bodyMedium: TextStyle(letterSpacing: 0),
              bodySmall: TextStyle(letterSpacing: 0),
              labelLarge: TextStyle(letterSpacing: 0),
              labelMedium: TextStyle(letterSpacing: 0),
              labelSmall: TextStyle(letterSpacing: 0),
            ),
          ),
      cardTheme: CardThemeData(
        color: colors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.lgAll,
          side: BorderSide(color: colors.outlineVariant),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: button.copyWith(
          overlayColor: WidgetStateProperty.resolveWith(
            (states) =>
                states.contains(WidgetState.hovered) ||
                    states.contains(WidgetState.focused)
                ? colors.onPrimary.withValues(alpha: .12)
                : null,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: button.copyWith(
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.disabled)
                ? colors.onSurface.withValues(alpha: .38)
                : states.contains(WidgetState.focused) ||
                      states.contains(WidgetState.hovered)
                ? colors.primary
                : colors.onSurface,
          ),
          side: WidgetStateProperty.resolveWith(
            (states) => BorderSide(
              color: states.contains(WidgetState.disabled)
                  ? colors.outlineVariant.withValues(alpha: .5)
                  : states.contains(WidgetState.focused)
                  ? colors.primary
                  : colors.outlineVariant,
              width: states.contains(WidgetState.focused) ? 1.5 : 1,
            ),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(style: button),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size(36, 36),
          padding: const EdgeInsets.all(8),
          shape: shape,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.surfaceContainerLow,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
        border: OutlineInputBorder(borderRadius: AppRadius.mdAll),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.mdAll,
          borderSide: BorderSide(color: colors.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.mdAll,
          borderSide: BorderSide(color: colors.primary, width: 1.5),
        ),
        hintStyle: TextStyle(color: colors.onSurfaceVariant, fontSize: 13),
        labelStyle: TextStyle(color: colors.onSurfaceVariant, fontSize: 13),
        floatingLabelStyle: TextStyle(color: colors.primary, fontSize: 12),
      ),
      dividerTheme: DividerThemeData(
        color: colors.outlineVariant,
        thickness: 1,
        space: 1,
      ),
      chipTheme: ChipThemeData(
        shape: shape,
        side: BorderSide(color: colors.outlineVariant),
        backgroundColor: colors.surfaceContainerLow,
        selectedColor: colors.primaryContainer,
        labelStyle: base.textTheme.labelMedium!.copyWith(
          fontSize: 12,
          color: colors.onSurface,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.xlAll),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: colors.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        shape: shape,
        textStyle: TextStyle(fontSize: 13, color: colors.onSurface),
      ),
      dataTableTheme: DataTableThemeData(
        headingRowColor: WidgetStatePropertyAll(colors.surfaceContainerLow),
        headingRowHeight: 40,
        dataRowMinHeight: 44,
        dataRowMaxHeight: 56,
        dividerThickness: 1,
        headingTextStyle: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: colors.onSurfaceVariant,
        ),
      ),
      listTileTheme: const ListTileThemeData(
        dense: true,
        minVerticalPadding: 10,
        contentPadding: EdgeInsets.symmetric(horizontal: 12),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: colors.primary,
        unselectedLabelColor: colors.onSurfaceVariant,
        dividerColor: colors.outlineVariant,
        indicatorSize: TabBarIndicatorSize.tab,
        labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: button.copyWith(
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          ),
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? colors.primaryContainer
                : colors.surface,
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.disabled)
                ? colors.onSurface.withValues(alpha: .38)
                : states.contains(WidgetState.selected)
                ? colors.onPrimaryContainer
                : colors.onSurfaceVariant,
          ),
          side: WidgetStatePropertyAll(
            BorderSide(color: colors.outlineVariant),
          ),
        ),
      ),
      expansionTileTheme: ExpansionTileThemeData(
        backgroundColor: colors.surface,
        collapsedBackgroundColor: colors.surfaceContainerLow,
        iconColor: colors.primary,
        shape: Border(bottom: BorderSide(color: colors.outlineVariant)),
        collapsedShape: Border(
          bottom: BorderSide(color: colors.outlineVariant),
        ),
      ),
      tooltipTheme: const TooltipThemeData(
        waitDuration: Duration(milliseconds: 450),
      ),
    );
  }
}

class AppPalette {
  AppPalette._(this.colors);
  final ColorScheme colors;
  static AppPalette of(BuildContext context) =>
      AppPalette._(Theme.of(context).colorScheme);
  bool get isDark => colors.brightness == Brightness.dark;
  Color get primary => colors.primary;
  Color get surface => colors.surface;
  Color get surfaceVariant => colors.surfaceContainerLow;
  Color get border => colors.outlineVariant;
  Color get borderLight => colors.outlineVariant.withValues(alpha: .6);
  Color get textPrimary => colors.onSurface;
  Color get textSecondary => colors.onSurfaceVariant;
  Color get textTertiary => colors.onSurfaceVariant;
  Color get violet =>
      isDark ? const Color(0xffc8b5ff) : const Color(0xff7552bf);
  Color get violetContainer =>
      isDark ? const Color(0xff342c50) : const Color(0xfff0eafa);
  // The navigation keeps its own dark surface in both appearance modes.
  Color get sidebarBackground =>
      isDark ? const Color(0xff10192b) : const Color(0xff192641);
  Color get sidebarSelected => const Color(0xff2c4070);
  Color get sidebarIndicator => const Color(0xffa9c4ff);
  Color get sidebarText => const Color(0xffc4cfe3);
  Color get sidebarTextSelected => Colors.white;
  Color get sidebarIcon => const Color(0xffa6b9d8);
  Color get sidebarIconSelected => const Color(0xffb6ceff);
  Color get sidebarGroupTitle => const Color(0xffa1b3d2);
  Color get messageErrorBackground => colors.errorContainer;
  Color get messageErrorBorder => colors.error.withValues(alpha: .4);
  Color get messageErrorText => colors.onErrorContainer;
  Color get messageSuccessBackground => colors.secondaryContainer;
  Color get messageSuccessBorder => colors.secondary.withValues(alpha: .3);
  Color get messageSuccessText => colors.onSecondaryContainer;
  Color get downloadBackground => colors.primaryContainer;
  Color get warningBackground => colors.tertiaryContainer;
  Color get warningText => colors.onTertiaryContainer;
  Color get warningBorder => colors.tertiary.withValues(alpha: .4);
}

/// 应用颜色常量
class AppColors {
  AppColors._();

  // 主色调
  static const Color primary = Color(0xff0071bd);
  static const Color primaryLight = Color(0xff55c2ff);
  static const Color primaryDark = Color(0xff065f80);

  // 背景色
  static const Color scaffoldBackground = Color(0xfff5f7fa);
  static const Color surface = Colors.white;
  static const Color surfaceVariant = Color(0xfff8fafc);

  // 侧边栏
  static const Color sidebarBackground = Color(0xff101820);
  static const Color sidebarBackgroundLight = Color(0xff16202a);
  static const Color sidebarSelected = Color(0xff203342);
  static const Color sidebarIndicator = Color(0xff55c2ff);
  static const Color sidebarText = Colors.white70;
  static const Color sidebarTextSelected = Colors.white;
  static const Color sidebarIcon = Colors.white60;
  static const Color sidebarIconSelected = Color(0xff55c2ff);
  static const Color sidebarDivider = Colors.white24;
  static const Color sidebarGroupTitle = Colors.white38;

  // 边框
  static const Color border = Color(0xffe1e6eb);
  static const Color borderLight = Color(0xffedf0f4);

  // 文字
  static const Color textPrimary = Color(0xff1a1a1a);
  static const Color textSecondary = Colors.black54;
  static const Color textTertiary = Colors.black38;
  static const Color textOnDark = Colors.white;
  static const Color textOnDarkSecondary = Colors.white70;

  // 状态
  static const Color success = Color(0xff10b981);
  static const Color warning = Color(0xfff59e0b);
  static const Color error = Color(0xffef4444);
  static const Color info = Color(0xff3b82f6);

  // 控制台
  static const Color consoleBackground = Color(0xff17191c);
  static const Color consoleSurface = Color(0xff262a30);
  static const Color consoleText = Color(0xffc9d1d9);
  static const Color consoleBorder = Colors.white24;
  static const Color consoleSearchHighlight = Color(0xfffff3a3);
  static const Color consoleSearchHighlightCurrent = Color(0xffffc857);

  // 消息栏
  static const Color messageSuccessBackground = Color(0xfff0f9ff);
  static const Color messageSuccessBorder = Color(0xffbae6fd);
  static const Color messageSuccessText = Color(0xff075985);
  static const Color messageErrorBackground = Color(0xfffff1f2);
  static const Color messageErrorBorder = Color(0xffffcdd2);
  static const Color messageErrorText = Color(0xffb91c1c);

  // 下载状态栏
  static const Color downloadBackground = Color(0xffeef7fb);
}

/// 间距常量
class AppSpacing {
  AppSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;

  // 页面边距
  static const EdgeInsets pagePadding = EdgeInsets.all(xl);
  static const EdgeInsets pagePaddingHorizontal = EdgeInsets.symmetric(
    horizontal: xl,
  );

  // 卡片边距
  static const EdgeInsets cardPadding = EdgeInsets.all(xl);
  static const EdgeInsets cardPaddingSmall = EdgeInsets.all(lg);

  // 列表项间距
  static const double listItemGap = sm;
  static const double sectionGap = xl;
  static const double cardGap = lg;
}

/// 圆角常量
class AppRadius {
  AppRadius._();

  static const double sm = 4;
  static const double md = 8;
  static const double lg = 12;
  static const double xl = 16;
  static const double full = 999;

  static BorderRadius get smAll => BorderRadius.circular(sm);
  static BorderRadius get mdAll => BorderRadius.circular(md);
  static BorderRadius get lgAll => BorderRadius.circular(lg);
  static BorderRadius get xlAll => BorderRadius.circular(xl);
  static BorderRadius get fullAll => BorderRadius.circular(full);
}

/// 文字样式
class AppTextStyles {
  AppTextStyles._();

  // 标题
  static const TextStyle h1 = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w700,
  );

  static const TextStyle h2 = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w700,
  );

  static const TextStyle h3 = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w700,
  );

  static const TextStyle h4 = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w700,
  );

  // 正文
  static const TextStyle bodyLarge = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w400,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
  );

  static const TextStyle bodySmall = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w400,
  );

  // 辅助文字
  static const TextStyle caption = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
  );

  static const TextStyle captionSmall = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w400,
  );

  // 标签
  static const TextStyle label = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w600,
  );

  static const TextStyle labelSmall = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w600,
  );

  // 按钮
  static const TextStyle buttonLarge = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
  );

  static const TextStyle buttonMedium = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w600,
  );

  // 代码
  static const TextStyle code = TextStyle(
    fontFamily: 'monospace',
    fontSize: 12,
    color: AppColors.consoleText,
  );

  // 侧边栏
  static const TextStyle sidebarTitle = TextStyle(fontWeight: FontWeight.w700);

  static const TextStyle sidebarItem = TextStyle(fontSize: 13);

  static const TextStyle sidebarItemSmall = TextStyle(fontSize: 12);

  static const TextStyle sidebarGroup = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
  );

  static const TextStyle sidebarShortcut = TextStyle(fontSize: 11);

  // 控制台
  static const TextStyle consoleTitle = TextStyle(
    color: Colors.white,
    fontWeight: FontWeight.w700,
  );

  static const TextStyle consoleInput = TextStyle(color: Colors.white);
}

/// 按钮样式
class AppButtonStyles {
  AppButtonStyles._();

  // 主要按钮
  static ButtonStyle get primary => FilledButton.styleFrom(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    textStyle: AppTextStyles.buttonLarge,
    shape: RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
  );

  // 次要按钮（tonal）
  static ButtonStyle get secondary => FilledButton.styleFrom(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    textStyle: AppTextStyles.buttonMedium,
    shape: RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
  );

  // 轮廓按钮
  static ButtonStyle get outline => OutlinedButton.styleFrom(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    textStyle: AppTextStyles.buttonMedium,
    shape: RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
  );

  // 文字按钮
  static ButtonStyle get text => TextButton.styleFrom(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    textStyle: AppTextStyles.buttonMedium,
  );

  // 图标按钮
  static ButtonStyle get icon => IconButton.styleFrom(
    minimumSize: const Size(36, 36),
    padding: const EdgeInsets.all(8),
  );

  // 小型按钮
  static ButtonStyle get smallOutline => OutlinedButton.styleFrom(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    textStyle: AppTextStyles.bodySmall,
    shape: RoundedRectangleBorder(borderRadius: AppRadius.smAll),
  );

  // 危险按钮
  static ButtonStyle get danger => FilledButton.styleFrom(
    backgroundColor: AppColors.error,
    foregroundColor: Colors.white,
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
    textStyle: AppTextStyles.buttonLarge,
    shape: RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
  );

  // 菜单项按钮
  static ButtonStyle get menuItem => TextButton.styleFrom(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    alignment: Alignment.centerLeft,
  );
}

/// 卡片样式
class AppCardStyles {
  AppCardStyles._();

  static BoxDecoration get defaultDecoration => BoxDecoration(
    color: AppColors.surface,
    borderRadius: AppRadius.lgAll,
    border: Border.all(color: AppColors.border),
  );

  static BoxDecoration get selectedDecoration => BoxDecoration(
    color: AppColors.primary.withValues(alpha: 0.05),
    borderRadius: AppRadius.lgAll,
    border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
  );

  static BoxDecoration get darkDecoration => BoxDecoration(
    color: AppColors.consoleBackground,
    borderRadius: AppRadius.lgAll,
  );

  static BoxDecoration metricDecoration(BuildContext context) => BoxDecoration(
    color: AppPalette.of(context).surface,
    borderRadius: AppRadius.lgAll,
    border: Border.all(color: AppPalette.of(context).border),
  );
}

/// 输入框装饰
class AppInputDecorations {
  AppInputDecorations._();

  static InputDecoration defaultInput({
    required String labelText,
    String? hintText,
    Widget? prefixIcon,
    Widget? suffixIcon,
  }) => InputDecoration(
    labelText: labelText,
    hintText: hintText,
    prefixIcon: prefixIcon,
    suffixIcon: suffixIcon,
    border: const OutlineInputBorder(),
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
  );

  static InputDecoration searchInput({required String hintText}) =>
      InputDecoration(
        hintText: hintText,
        hintStyle: const TextStyle(color: Colors.white54),
        prefixIcon: const Icon(Icons.search, color: Colors.white70),
        filled: true,
        fillColor: AppColors.consoleSurface,
        border: const OutlineInputBorder(),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
      );
}

/// 动画常量
class AppAnimations {
  AppAnimations._();

  static const Duration fast = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 200);
  static const Duration slow = Duration(milliseconds: 300);

  static const Curve defaultCurve = Curves.easeOutCubic;
}

/// 阴影
class AppShadows {
  AppShadows._();

  static List<BoxShadow> get sm => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.05),
      blurRadius: 4,
      offset: const Offset(0, 2),
    ),
  ];

  static List<BoxShadow> get md => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.1),
      blurRadius: 8,
      offset: const Offset(0, 4),
    ),
  ];

  static List<BoxShadow> get lg => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.15),
      blurRadius: 16,
      offset: const Offset(0, 8),
    ),
  ];
}

/// 响应式断点
class AppBreakpoints {
  AppBreakpoints._();

  static const double mobile = 600;
  static const double tablet = 900;
  static const double desktop = 1200;
  static const double largeDesktop = 1600;

  static bool isMobile(BuildContext context) =>
      MediaQuery.of(context).size.width < mobile;

  static bool isTablet(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= mobile && width < desktop;
  }

  static bool isDesktop(BuildContext context) =>
      MediaQuery.of(context).size.width >= desktop;

  static bool isLargeDesktop(BuildContext context) =>
      MediaQuery.of(context).size.width >= largeDesktop;
}
