import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_manager/src/app.dart';
import 'package:flutter_manager/src/domain/models.dart';
import 'package:flutter_manager/src/domain/project_models.dart';
import 'package:flutter_manager/src/presentation/providers.dart';

class _TestController extends FvmController {
  @override
  FvmState build() => FvmState(
    fvmInstalled: true,
    fvmVersion: '4.1.1',
    latestFvmVersion: '4.1.2',
    globalVersion: '3.44.2',
    installed: const [
      InstalledSdk(
        name: '3.43.0',
        flutterVersion: '3.43.0',
        dartVersion: '3.12.0',
        directory: '/tmp/fvm/versions/3.43.0',
      ),
    ],
    hasFvmUpdate: true,
    hasFlutterUpdate: true,
    activeVersion: '3.44.4',
    downloadProgress: .3,
    downloadReceivedBytes: 10 * 1024 * 1024,
    downloadTotalBytes: 100 * 1024 * 1024,
    downloadBytesPerSecond: 2 * 1024 * 1024,
    downloadPhase: '正在下载',
    selectedManagedProjectPath: '/tmp/demo',
    managedProjects: [
      FlutterProject(
        name: 'demo',
        path: '/tmp/demo',
        lastOpened: DateTime(2026),
        hasAndroid: true,
        androidFlavors: const ['dev', 'prod'],
        androidBuildTypes: const ['debug', 'release'],
      ),
    ],
  );

  @override
  Future<void> initialize() async {}

  @override
  Future<void> ignoreFvmUpdate() async {
    state = state.copyWith(hasFvmUpdate: false);
  }

  @override
  Future<void> ignoreFlutterUpdate() async {
    state = state.copyWith(hasFlutterUpdate: false);
  }
}

void main() {
  testWidgets('shows FVM dashboard status', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 900);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [fvmControllerProvider.overrideWith(_TestController.new)],
        child: const FvmManagerApp(),
      ),
    );

    expect(find.text('Flutter Manager'), findsOneWidget);
    expect(find.text('FVM 4.1.1'), findsOneWidget);
    expect(find.text('3.44.2'), findsOneWidget);
    expect(find.text('更新 FVM'), findsOneWidget);
    expect(find.text('最新版本：4.1.2'), findsOneWidget);
    expect(find.text('打开 FVM 目录'), findsOneWidget);
    expect(find.text('打开 Flutter 目录'), findsOneWidget);
    expect(find.text('10.0 MB / 100.0 MB'), findsOneWidget);
    expect(find.text('2.0 MB/s'), findsOneWidget);
    await tester.tap(find.byTooltip('删除此 Flutter 版本'));
    await tester.pumpAndSettle();
    expect(find.text('确认删除 Flutter 版本？'), findsOneWidget);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(find.text('项目管理'), findsOneWidget);
    expect(find.text('项目 FVM'), findsOneWidget);
    expect(find.byKey(const ValueKey('fvm-update-dot-top')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('flutter-update-dot-nav')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('fvm-update-dot-top')));
    await tester.pump();
    expect(find.byKey(const ValueKey('fvm-update-dot-top')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('flutter-update-dot-nav')));
    await tester.pump();
    expect(find.byKey(const ValueKey('flutter-update-dot-nav')), findsNothing);

    await tester.tap(find.text('项目管理'));
    await tester.pump();
    expect(find.text('添加项目'), findsOneWidget);
    expect(find.text('Android 渠道（可多选）'), findsOneWidget);
    expect(find.text('打开 APK 目录'), findsOneWidget);
    expect(find.text('热重载'), findsOneWidget);
    expect(find.text('热重启'), findsOneWidget);
    expect(find.text('构建后上传 Bugly 符号表'), findsOneWidget);
    expect(find.text('使用自定义 runCommand 工作流'), findsOneWidget);
    await tester.ensureVisible(find.text('dev'));
    await tester.tap(find.text('dev'));
    await tester.pump();
    expect(find.text('已选择 1 个'), findsOneWidget);

    await tester.tap(find.text('项目 FVM'));
    await tester.pump();
    expect(find.text('项目 FVM 配置'), findsOneWidget);
    expect(find.text('选择目录'), findsOneWidget);

    await tester.tap(find.text('环境配置'));
    await tester.pump();
    expect(find.text('选择下载源'), findsOneWidget);
    expect(find.text('测试连通性'), findsOneWidget);
  });
}
