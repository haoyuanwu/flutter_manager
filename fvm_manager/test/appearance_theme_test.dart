import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter_manager/src/app.dart';
import 'package:flutter_manager/src/data/appearance_preferences.dart';
import 'package:flutter_manager/src/data/distribution_service.dart';
import 'package:flutter_manager/src/data/build_history_repository.dart';
import 'package:flutter_manager/src/domain/build_history_models.dart';
import 'package:flutter_manager/src/data/apk_install_service.dart';
import 'package:flutter_manager/src/data/apk_signing_service.dart';
import 'package:flutter_manager/src/data/environment_diagnostics_service.dart';
import 'package:flutter_manager/src/data/fvm_service.dart';
import 'package:flutter_manager/src/data/process_runner.dart';
import 'package:flutter_manager/src/data/pub_environment_service.dart';
import 'package:flutter_manager/src/domain/models.dart';
import 'package:flutter_manager/src/domain/project_models.dart';
import 'package:flutter_manager/src/presentation/providers.dart';
import 'package:flutter_manager/src/presentation/mcp_control_server.dart';
import 'package:flutter_manager/src/presentation/widgets/workbench_panel.dart';
import 'package:flutter_manager/src/presentation/widgets/workbench_layout.dart';
import 'package:flutter_manager/src/presentation/theme/app_theme.dart';
import 'package:flutter_manager/src/presentation/theme/theme_controller.dart';

class _Environment extends PubEnvironmentService {
  @override
  Future<List<String>> getSystemPath() async => const [];
  @override
  Future<void> setMcpServerEnabled(bool enabled) async {}
}

class _Controller extends FvmController {
  _Controller(this.path, {this.mcpEnabled = false});
  final String path;
  final bool mcpEnabled;
  @override
  FvmState build() => FvmState(
    fvmInstalled: true,
    mcpServerEnabled: mcpEnabled,
    fvmVersion: '4.1.1',
    latestFvmVersion: '4.1.1',
    globalVersion: '3.47.7',
    installed: [
      InstalledSdk(
        name: '3.47.7',
        flutterVersion: '3.47.7',
        dartVersion: '3.11.0',
        directory: path,
      ),
    ],
    selectedManagedProjectPath: path,
    projectPath: path,
    showMainWindowConsole: true,
    commandLog:
        'Flutter run\nLaunching lib/main.dart on Windows...\nApplication started.\n',
    managedProjects: [
      FlutterProject(
        name: 'flutter_workspace',
        alias: 'Flutter Workspace',
        path: path,
        lastOpened: DateTime(2026),
        hasWindows: true,
        hasAndroid: true,
      ),
    ],
  );
  @override
  Future<void> initialize() async {}
}

class _Diagnostics extends EnvironmentDiagnosticsService {
  _Diagnostics() : super(_Environment(), FvmService(_Environment()));
  @override
  Future<EnvironmentDiagnosticReport> run({
    required FvmState state,
    void Function(List<DiagnosticItem>)? onItemAdded,
  }) async => EnvironmentDiagnosticReport(
    startedAt: DateTime(2026),
    finishedAt: DateTime(2026),
    items: const [
      DiagnosticItem(
        level: EnvironmentDiagnosticLevel.ok,
        category: 'FVM',
        title: 'FVM 可用',
        detail: '4.1.1',
      ),
      DiagnosticItem(
        level: EnvironmentDiagnosticLevel.warning,
        category: '设备',
        title: '未连接设备',
        detail: 'Windows 桌面可用',
      ),
    ],
  );
}

class _Devices extends ApkInstallService {
  _Devices() : super(ProcessRunner(), _Environment());
  @override
  Future<List<AndroidDevice>> listDevices() async => const [];
}

class _Signing extends ApkSigningService {
  _Signing(this.config) : super(ProcessRunner());
  final ApkSigningConfig config;
  @override
  Future<ApkSigningConfig> loadConfig() async => config;
}

class _McpServer extends McpControlServer {
  bool running = false;
  int? port;
  @override
  bool get isRunning => running;
  @override
  int? get activePort => port;
  @override
  Future<void> start({
    required int port,
    required String token,
    required McpToolHandler onToolCall,
  }) async {
    this.port = port;
    running = true;
  }

  @override
  Future<void> stop() async => running = false;
}

class _Artifacts extends DistributionService {
  @override
  Future<List<DistributionArtifact>> scanArtifacts(
    String projectPath, {
    bool deduplicate = true,
  }) async => const [];
}

class _History extends BuildHistoryRepository {
  @override
  Future<BuildHistorySnapshot> load({bool tolerateErrors = true}) async =>
      const BuildHistorySnapshot();
}

void desktopTest(String description, WidgetTesterCallback callback) =>
    testWidgets(
      description,
      callback,
      variant: TargetPlatformVariant.only(TargetPlatform.windows),
    );

void main() {
  late Directory root;
  late AppearancePreferences preferences;
  const writePreviews = bool.fromEnvironment('WRITE_THEME_PREVIEWS');
  final previewKey = GlobalKey();
  setUpAll(() async {
    if (writePreviews && Platform.isWindows) {
      final font = File(r'C:\Windows\Fonts\msyh.ttc');
      if (font.existsSync()) {
        for (final name in ['Roboto', 'Segoe UI']) {
          await (FontLoader(
            name,
          )..addFont(font.readAsBytes().then(ByteData.sublistView))).load();
        }
      }
      await (FontLoader(
        'MaterialIcons',
      )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
      final mono = File(r'C:\Windows\Fonts\consola.ttf');
      if (mono.existsSync()) {
        for (final name in ['monospace', 'Menlo']) {
          await (FontLoader(
            name,
          )..addFont(mono.readAsBytes().then(ByteData.sublistView))).load();
        }
      }
    }
  });
  setUp(() {
    root = Directory.systemTemp.createTempSync('appearance_');
    preferences = AppearancePreferences(
      file: File('${root.path}/appearance.json'),
    );
  });
  tearDown(() async {
    await root.delete(recursive: true);
  });

  Future<void> open(
    WidgetTester tester, {
    Size size = const Size(1440, 1000),
    bool mcpEnabled = false,
    ApkSigningConfig signingConfig = const ApkSigningConfig(),
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appearancePreferencesProvider.overrideWithValue(preferences),
          fvmControllerProvider.overrideWith(
            () => _Controller(root.path, mcpEnabled: mcpEnabled),
          ),
          mcpControlServerProvider.overrideWithValue(_McpServer()),
          pubEnvironmentServiceProvider.overrideWithValue(_Environment()),
          environmentDiagnosticsServiceProvider.overrideWithValue(
            _Diagnostics(),
          ),
          apkInstallServiceProvider.overrideWithValue(_Devices()),
          apkSigningServiceProvider.overrideWithValue(_Signing(signingConfig)),
          distributionServiceProvider.overrideWithValue(_Artifacts()),
          buildHistoryRepositoryProvider.overrideWithValue(_History()),
          projectIconProvider.overrideWith((ref, path) async => null),
          packageInfoProvider.overrideWith(
            (ref) async => PackageInfo(
              appName: 'Flutter Manager',
              packageName: 'flutter_manager',
              version: '1.2.7',
              buildNumber: '13',
            ),
          ),
        ],
        child: RepaintBoundary(key: previewKey, child: const FvmManagerApp()),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> navigate(WidgetTester tester, String title) async {
    final navigation = find.byKey(const ValueKey('sidebar-navigation-list'));
    final scroll = find
        .descendant(of: navigation, matching: find.byType(Scrollable))
        .first;
    tester.state<ScrollableState>(scroll).position.jumpTo(0);
    await tester.pumpAndSettle();
    final item = find.descendant(of: navigation, matching: find.text(title));
    await tester.scrollUntilVisible(item, 120, scrollable: scroll);
    await tester.pumpAndSettle();
    await tester.tap(item);
    await tester.pumpAndSettle();
  }

  Future<void> screenshot(WidgetTester tester, String name) async {
    if (!writePreviews) return;
    final boundary =
        previewKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
    await tester.runAsync(() async {
      final picture = await boundary.toImage();
      final bytes = (await picture.toByteData(format: ui.ImageByteFormat.png))!;
      final file = File('build/theme-previews/$name.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes.buffer.asUint8List());
      picture.dispose();
    });
  }

  Future<void> waitForSave(WidgetTester tester, String mode) async {
    for (var attempt = 0; attempt < 50; attempt++) {
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(FvmManagerApp)),
      );
      if (preferences.load() == mode &&
          container.read(appThemeModeProvider).name == mode) {
        break;
      }
    }
    await tester.pumpAndSettle();
  }

  test(
    'appearance defaults safely and persists every supported mode',
    () async {
      expect(preferences.load(), 'system');
      for (final mode in ['dark', 'light', 'system']) {
        await preferences.save(mode);
        expect(AppearancePreferences(file: preferences.file).load(), mode);
      }
      preferences.file.writeAsStringSync('{broken');
      expect(preferences.load(), 'system');
      preferences.file.writeAsStringSync('{"themeMode":"unsupported"}');
      expect(preferences.load(), 'system');
    },
  );

  test(
    'theme controller serializes quick changes and does not overwrite settings on host sync',
    () async {
      final container = ProviderContainer(
        overrides: [
          appearancePreferencesProvider.overrideWithValue(preferences),
        ],
      );
      addTearDown(container.dispose);
      expect(container.read(appThemeModeProvider), ThemeMode.system);
      final controller = container.read(appThemeModeProvider.notifier);
      await Future.wait([
        controller.setMode(ThemeMode.dark),
        controller.setMode(ThemeMode.light),
        controller.setMode(ThemeMode.system),
      ]);
      expect(preferences.load(), 'system');
      expect(container.read(appThemeModeProvider), ThemeMode.system);
      controller.applyFromHost('dark');
      expect(container.read(appThemeModeProvider), ThemeMode.dark);
      expect(preferences.load(), 'system');
    },
  );

  desktopTest(
    'system appearance responds live and explicit settings survive restart',
    (tester) async {
      final dispatcher = tester.binding.platformDispatcher;
      dispatcher.platformBrightnessTestValue = Brightness.light;
      addTearDown(dispatcher.clearPlatformBrightnessTestValue);
      await open(tester);
      expect(
        tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
        ThemeMode.system,
      );
      dispatcher.platformBrightnessTestValue = Brightness.dark;
      await tester.pumpAndSettle();
      expect(
        Theme.of(tester.element(find.byType(Scaffold).first)).brightness,
        Brightness.dark,
      );
      await navigate(tester, '设置');
      await tester.tap(find.text('浅色'));
      await waitForSave(tester, 'light');
      expect(preferences.load(), 'light');
      expect(
        Theme.of(tester.element(find.byType(Scaffold).first)).brightness,
        Brightness.light,
      );
      await tester.pumpWidget(const SizedBox());
      await open(tester);
      expect(
        tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
        ThemeMode.light,
      );
      await navigate(tester, '设置');
      await tester.tap(find.text('跟随系统'));
      await waitForSave(tester, 'system');
      expect(
        Theme.of(tester.element(find.byType(Scaffold).first)).brightness,
        Brightness.dark,
      );
      dispatcher.platformBrightnessTestValue = Brightness.light;
      await tester.pumpAndSettle();
      expect(
        Theme.of(tester.element(find.byType(Scaffold).first)).brightness,
        Brightness.light,
      );
    },
  );

  for (final brightness in Brightness.values) {
    for (final size in [
      const Size(1440, 1000),
      const Size(960, 720),
      const Size(960, 640),
      const Size(1280, 800),
      const Size(1920, 1080),
    ]) {
      desktopTest('all workbench pages fit ${brightness.name} $size', (
        tester,
      ) async {
        tester.binding.platformDispatcher.platformBrightnessTestValue =
            brightness;
        addTearDown(
          tester.binding.platformDispatcher.clearPlatformBrightnessTestValue,
        );
        await open(tester, size: size);
        for (final page in [
          '概览',
          'Flutter 版本',
          '项目管理',
          '产物中心',
          'APK 签名',
          'APK 安装',
          '应用签名',
          '环境诊断',
          '环境配置',
          'MCP 服务',
          '设置',
          '请我喝个茶',
        ]) {
          await navigate(tester, page);
          expect(
            tester.takeException(),
            isNull,
            reason: '$page ${brightness.name} $size',
          );
          expect(
            Theme.of(tester.element(find.byType(Scaffold).first)).brightness,
            brightness,
          );
          final header = find.byType(WorkbenchPageHeader);
          expect(header, findsOneWidget);
          final headerBounds = tester.getRect(header);
          expect(headerBounds.left, closeTo(245, 1));
          expect(headerBounds.top, closeTo(80, 1));
          expect(headerBounds.right, lessThanOrEqualTo(size.width - 24));
          await screenshot(
            tester,
            '${brightness.name}-${size.width.toInt()}x${size.height.toInt()}-$page',
          );
        }
      });
    }
  }

  desktopTest(
    'overview metrics fill aligned columns and actions anchor right',
    (tester) async {
      for (final size in [const Size(1440, 1000), const Size(960, 720)]) {
        await tester.pumpWidget(const SizedBox());
        await open(tester, size: size);
        final bounds = [
          for (var index = 0; index < 3; index++)
            tester.getRect(find.byKey(ValueKey('overview-metric-$index'))),
        ];
        expect(bounds[0].width, closeTo(bounds[1].width, .1));
        expect(bounds[0].left, closeTo(245, 1));
        expect(bounds[2].right, closeTo(size.width - 24, 1));
        if (size.width > 1000) {
          expect(bounds.map((rect) => rect.top).toSet(), hasLength(1));
          final action = find.widgetWithText(OutlinedButton, '打开 Flutter 目录');
          expect(tester.getRect(action).right, closeTo(size.width - 24, 1));
        } else {
          expect(bounds[0].top, bounds[1].top);
          expect(bounds[2].left, bounds[0].left);
          expect(bounds[2].top, greaterThan(bounds[0].bottom));
        }
      }
    },
  );

  desktopTest(
    'project starts at its details and compact signing stays usable',
    (tester) async {
      await open(tester, size: const Size(960, 640));
      await navigate(tester, '项目管理');
      final details = find.byKey(PageStorageKey('project-detail-${root.path}'));
      final scroll = find
          .descendant(of: details, matching: find.byType(Scrollable))
          .first;
      expect(tester.state<ScrollableState>(scroll).position.pixels, 0);
      expect(find.text('Flutter Workspace').hitTestable(), findsWidgets);
      await navigate(tester, 'APK 签名');
      final panels = find.byType(WorkbenchPanel);
      expect(tester.getSize(panels.at(1)).height, greaterThanOrEqualTo(320));
      expect(tester.getSize(panels.at(2)).height, greaterThanOrEqualTo(320));
      await tester.ensureVisible(find.text('已签名'));
      await tester.pumpAndSettle();
      expect(find.text('已签名').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  desktopTest('signing handles long Windows paths and saved credential menus', (
    tester,
  ) async {
    final alias = List.filled(12, 'release_key').join('_');
    final fileName = '${List.filled(12, 'release').join('_')}.jks';
    await open(
      tester,
      size: const Size(960, 640),
      signingConfig: ApkSigningConfig(
        jksPath: 'C:\\Users\\Developer\\signing\\$fileName',
        keyAlias: alias,
        keyAliasHistory: [alias],
        password: 'example_password',
        passwordHistory: const ['example_password'],
      ),
    );
    await navigate(tester, 'APK 签名');
    expect(tester.takeException(), isNull);
    final button = find.widgetWithText(OutlinedButton, fileName);
    expect(button, findsOneWidget);
    expect(tester.getRect(button).right, lessThanOrEqualTo(936));
    await screenshot(tester, 'light-960x640-signing-long-path');
  });

  test('both palettes provide legible text and small component radii', () {
    for (final theme in [AppTheme.light, AppTheme.dark]) {
      final colors = theme.colorScheme;
      final ratio =
          (colors.onSurface.computeLuminance() + .05) /
          (colors.surface.computeLuminance() + .05);
      expect(ratio > 1 ? ratio : 1 / ratio, greaterThan(7));
      final shape = theme.cardTheme.shape as RoundedRectangleBorder;
      expect(shape.borderRadius, BorderRadius.circular(6));
    }
  });

  desktopTest('restored theme reaches native chrome on the first frame', (
    tester,
  ) async {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    const channel = MethodChannel('fvm_manager/appearance');
    final calls = <Map>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'setTheme');
      calls.add(call.arguments as Map);
      return null;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    await tester.runAsync(() => preferences.save('dark'));
    await open(tester);
    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
      ThemeMode.dark,
    );
    expect(calls.last, {'mode': 'dark', 'dark': true});
    await navigate(tester, '设置');
    await tester.tap(find.text('浅色'));
    await waitForSave(tester, 'light');
    expect(calls.last, {'mode': 'light', 'dark': false});
  });

  desktopTest('sidebar has no scrollbar but remains scrollable', (
    tester,
  ) async {
    await open(tester, size: const Size(960, 640));
    final navigation = find.byKey(const ValueKey('sidebar-navigation-list'));
    expect(
      find.ancestor(
        of: navigation,
        matching: find.byWidgetPredicate((widget) => widget is RawScrollbar),
      ),
      findsNothing,
    );
    final scroll = find
        .descendant(of: navigation, matching: find.byType(Scrollable))
        .first;
    final position = tester.state<ScrollableState>(scroll).position;
    expect(position.maxScrollExtent, greaterThan(0));
    await tester.drag(navigation, const Offset(0, -300));
    await tester.pumpAndSettle();
    expect(position.pixels, greaterThan(0));
    await navigate(tester, '设置');
    expect(find.byKey(const ValueKey('theme-mode-selector')), findsOneWidget);
  });

  desktopTest('project search filters and clears without changing selection', (
    tester,
  ) async {
    await open(tester);
    await navigate(tester, '项目管理');
    final search = find.byKey(const ValueKey('managed-project-search'));
    await tester.enterText(search, 'does_not_match');
    await tester.pump();
    expect(find.text('没有匹配的项目'), findsOneWidget);
    expect(find.byKey(ValueKey(root.path)), findsNothing);
    await tester.tap(find.byTooltip('清空搜索'));
    await tester.pumpAndSettle();
    expect(find.byKey(ValueKey(root.path)), findsOneWidget);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(FvmManagerApp)),
    );
    expect(
      container.read(fvmControllerProvider).selectedManagedProjectPath,
      root.path,
    );
  });

  desktopTest('quick theme menu persists the selected appearance', (
    tester,
  ) async {
    await open(tester);
    await tester.tap(find.byKey(const ValueKey('quick-theme-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('深色'));
    await waitForSave(tester, 'dark');
    expect(preferences.load(), 'dark');
    expect(
      Theme.of(tester.element(find.byType(Scaffold).first)).brightness,
      Brightness.dark,
    );
  });

  desktopTest(
    'MCP bind error remains visible and retry restores actual running state',
    (tester) async {
      await open(tester, mcpEnabled: true);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(FvmManagerApp)),
      );
      container
          .read(mcpServerRuntimeProvider.notifier)
          .update(const McpServerRuntime(error: '端口 17891 已被占用，本窗口未能启动 MCP。'));
      await navigate(tester, 'MCP 服务');
      expect(find.byKey(const ValueKey('mcp-service-error')), findsOneWidget);
      expect(find.textContaining('未启动'), findsWidgets);
      await tester.tap(find.byKey(const ValueKey('retry-mcp-service')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('mcp-service-error')), findsNothing);
      expect(find.textContaining('运行中 · 127.0.0.1:17891'), findsOneWidget);
    },
  );

  desktopTest('tool panel highlights keyboard focus without shifting bounds', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(
          body: SizedBox(width: 400, child: WorkbenchPanel(child: TextField())),
        ),
      ),
    );
    final panel = find.byType(WorkbenchPanel);
    final original = tester.getRect(panel);
    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();
    final decoration =
        tester
                .widget<AnimatedContainer>(
                  find
                      .descendant(
                        of: panel,
                        matching: find.byType(AnimatedContainer),
                      )
                      .first,
                )
                .decoration
            as BoxDecoration;
    expect(
      (decoration.border! as Border).top.color,
      AppTheme.light.colorScheme.primary,
    );
    expect(tester.getRect(panel), original);
  });
}
