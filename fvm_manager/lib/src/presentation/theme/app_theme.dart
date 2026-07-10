import 'package:flutter/material.dart';

/// 应用颜色常量
class AppColors {
  AppColors._();

  // 主色调
  static const Color primary = Color(0xff087ea4);
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
  static const Color consoleBackground = Color(0xff101820);
  static const Color consoleSurface = Color(0xff1b2733);
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
  static const EdgeInsets pagePaddingHorizontal = EdgeInsets.symmetric(horizontal: xl);

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

  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
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
    fontSize: 28,
    fontWeight: FontWeight.w800,
    color: AppColors.textPrimary,
  );

  static const TextStyle h2 = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
  );

  static const TextStyle h3 = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
  );

  static const TextStyle h4 = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
  );

  // 正文
  static const TextStyle bodyLarge = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
  );

  static const TextStyle bodySmall = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
  );

  // 辅助文字
  static const TextStyle caption = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
  );

  static const TextStyle captionSmall = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w400,
    color: AppColors.textTertiary,
  );

  // 标签
  static const TextStyle label = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  static const TextStyle labelSmall = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    color: AppColors.textSecondary,
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
  static const TextStyle sidebarTitle = TextStyle(
    color: Colors.white,
    fontWeight: FontWeight.w700,
  );

  static const TextStyle sidebarItem = TextStyle(
    color: AppColors.sidebarText,
    fontSize: 13,
  );

  static const TextStyle sidebarItemSmall = TextStyle(
    color: AppColors.sidebarText,
    fontSize: 12,
  );

  static const TextStyle sidebarGroup = TextStyle(
    color: AppColors.sidebarGroupTitle,
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.8,
  );

  static const TextStyle sidebarShortcut = TextStyle(
    color: Colors.white24,
    fontSize: 11,
  );

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
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
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

  static BoxDecoration get metricDecoration => BoxDecoration(
    gradient: const LinearGradient(
      colors: [Colors.white, AppColors.surfaceVariant],
    ),
    borderRadius: AppRadius.lgAll,
    border: Border.all(color: AppColors.border),
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
  }) =>
      InputDecoration(
        labelText: labelText,
        hintText: hintText,
        prefixIcon: prefixIcon,
        suffixIcon: suffixIcon,
        border: const OutlineInputBorder(),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      );

  static InputDecoration searchInput({
    required String hintText,
  }) =>
      InputDecoration(
        hintText: hintText,
        hintStyle: const TextStyle(color: Colors.white54),
        prefixIcon: const Icon(Icons.search, color: Colors.white70),
        filled: true,
        fillColor: AppColors.consoleSurface,
        border: const OutlineInputBorder(),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
