import 'dart:io';
import 'package:dio/dio.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_manager/src/data/flutter_device_monitor.dart';
import 'package:flutter_manager/src/data/flutter_project_creation_service.dart';
import 'package:flutter_manager/src/data/fvm_service.dart';
import 'package:flutter_manager/src/data/local_project_service.dart';
import 'package:flutter_manager/src/data/process_runner.dart';
import 'package:flutter_manager/src/data/project_repository.dart';
import 'package:flutter_manager/src/data/pub_environment_service.dart';
import 'package:flutter_manager/src/data/pub_package_service.dart';
import 'package:flutter_manager/src/domain/models.dart';
import 'package:flutter_manager/src/domain/project_creation_options.dart';
import 'package:flutter_manager/src/domain/project_models.dart';
import 'package:flutter_manager/src/domain/project_dependency.dart';
import 'package:flutter_manager/src/presentation/create_project_dialog.dart';
import 'package:flutter_manager/src/presentation/providers.dart';

class _Controller extends FvmController {
  @override
  FvmState build() => const FvmState();
}

class _Repository extends ProjectRepository {
  List<FlutterProject> saved = [];
  bool fail = false;
  @override
  Future<void> save(List<FlutterProject> projects) async {
    if (fail) throw Exception('Cannot save project list');
    saved = projects;
  }
}

class _Monitor extends FlutterDeviceMonitor {
  _Monitor() : super(FvmService(PubEnvironmentService()));
  @override
  Future<void> start({
    required String projectPath,
    required void Function(List<Map<String, String>>) onDevices,
    required void Function(Object) onError,
  }) async => onDevices([]);
}

class _Creator extends FlutterProjectCreationService {
  _Creator()
    : super(
        FvmService(PubEnvironmentService()),
        ProcessRunner(),
        LocalProjectService(),
      );
  ProjectCreationOptions? received;
  int calls = 0;
  @override
  Future<FlutterProject> create(
    ProjectCreationOptions options, {
    required void Function(String) onOutput,
  }) async {
    calls++;
    received = options;
    onOutput('Project created.\n');
    return FlutterProject(
      name: options.name,
      path: options.projectPath,
      lastOpened: DateTime.now(),
      hasWindows: true,
    );
  }
}

class _Packages extends PubPackageService {
  _Packages() : super(Dio());
  int calls = 0;
  bool fail = false;
  @override
  Future<List<PubPackage>> search(
    String query, {
    CancelToken? cancelToken,
  }) async {
    calls++;
    if (fail) throw Exception('Network unavailable');
    return const [
      PubPackage(
        name: 'dio',
        version: '5.9.0',
        description: 'HTTP client',
        downloadCount30Days: 1234567,
      ),
      PubPackage(name: 'http', version: '1.2.0', description: 'HTTP package'),
    ];
  }
}

void main() {
  late Directory root;
  late _Creator creator;
  late _Repository repository;
  late _Packages packages;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('project_dialog_');
    creator = _Creator();
    repository = _Repository();
    packages = _Packages();
  });
  tearDown(() => root.delete(recursive: true));

  Future<void> open(WidgetTester tester, Size size) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          fvmControllerProvider.overrideWith(_Controller.new),
          flutterProjectCreationServiceProvider.overrideWithValue(creator),
          pubPackageServiceProvider.overrideWithValue(packages),
          projectRepositoryProvider.overrideWithValue(repository),
          flutterDeviceMonitorProvider.overrideWithValue(_Monitor()),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () =>
                    showCreateProjectDialog(context, const FvmState()),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('create-project-parent')),
      root.path,
    );
  }

  testWidgets(
    'prefills options and automatically persists and selects the created project',
    (tester) async {
      await open(tester, const Size(1200, 900));
      expect(
        tester
            .widgetList<TextFormField>(find.byType(TextFormField))
            .map((field) => field.controller?.text),
        contains('com.example'),
      );
      expect(find.text('A new Flutter project.'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('create-project-name')),
        'my_app',
      );
      expect(
        tester
            .widget<TextFormField>(
              find.byKey(const ValueKey('create-project-folder')),
            )
            .controller!
            .text,
        'my_app',
      );
      await tester.tap(find.byKey(const ValueKey('create-project-submit')));
      await tester.pumpAndSettle();
      expect(find.byType(CreateProjectDialog), findsNothing);
      expect(creator.received!.name, 'my_app');
      expect(creator.received!.dependencies, isEmpty);
      expect(packages.calls, 0);
      expect(repository.saved.single.path, creator.received!.projectPath);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(MaterialApp)),
      );
      expect(
        container.read(fvmControllerProvider).selectedManagedProjectPath,
        creator.received!.projectPath,
      );
    },
  );

  testWidgets('invalid fields do not launch Flutter', (tester) async {
    await open(tester, const Size(960, 700));
    await tester.enterText(
      find.byKey(const ValueKey('create-project-name')),
      'Invalid Name',
    );
    await tester.tap(find.byKey(const ValueKey('create-project-submit')));
    await tester.pumpAndSettle();
    expect(creator.calls, 0);
    expect(find.text('以小写字母开头，仅使用小写字母、数字和下划线'), findsOneWidget);
  });

  testWidgets(
    'failed import can retry without recreating or overwriting the project',
    (tester) async {
      repository.fail = true;
      await open(tester, const Size(1200, 900));
      await tester.tap(find.byKey(const ValueKey('create-project-submit')));
      await tester.pumpAndSettle();
      expect(find.text('加入项目管理'), findsOneWidget);
      expect(creator.calls, 1);
      repository.fail = false;
      await tester.tap(find.byKey(const ValueKey('create-project-submit')));
      await tester.pumpAndSettle();
      expect(creator.calls, 1);
      expect(repository.saved, hasLength(1));
    },
  );

  testWidgets('search adds a package as a development dependency', (
    tester,
  ) async {
    await open(tester, const Size(1200, 1000));
    await tester.tap(find.byKey(const ValueKey('create-project-next')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const ValueKey('pub-package-search')),
    );
    await tester.enterText(
      find.byKey(const ValueKey('pub-package-search')),
      'dio',
    );
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('开发依赖'));
    await tester.tap(find.text('开发依赖'));
    await tester.ensureVisible(
      find.byKey(const ValueKey('add-pub-package-dio')),
    );
    await tester.tap(find.byKey(const ValueKey('add-pub-package-dio')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('create-project-submit')));
    await tester.pumpAndSettle();
    expect(creator.received!.dependencies.single.name, 'dio');
    expect(creator.received!.dependencies.single.constraint, '^5.9.0');
    expect(creator.received!.dependencies.single.development, isTrue);
  });

  testWidgets(
    'selected dependencies can be skipped even with an invalid constraint',
    (tester) async {
      await open(tester, const Size(420, 840));
      await tester.tap(find.byKey(const ValueKey('create-project-next')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const ValueKey('pub-package-search')),
      );
      await tester.enterText(
        find.byKey(const ValueKey('pub-package-search')),
        'dio',
      );
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const ValueKey('add-pub-package-dio')),
      );
      await tester.tap(find.byKey(const ValueKey('add-pub-package-dio')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const ValueKey('pub-package-version-dio')),
      );
      await tester.enterText(
        find.byKey(const ValueKey('pub-package-version-dio')),
        'invalid',
      );
      await tester.pump();
      await tester.tap(find.text('跳过依赖，直接创建'));
      await tester.pumpAndSettle();
      expect(creator.received!.dependencies, isEmpty);
    },
  );

  testWidgets('search failure does not block direct creation', (tester) async {
    packages.fail = true;
    await open(tester, const Size(960, 800));
    await tester.tap(find.byKey(const ValueKey('create-project-next')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const ValueKey('pub-package-search')),
    );
    await tester.enterText(
      find.byKey(const ValueKey('pub-package-search')),
      'dio',
    );
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expect(find.text('无法搜索 pub.dev，请检查网络后重试'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('create-project-submit')));
    await tester.pumpAndSettle();
    expect(creator.received!.dependencies, isEmpty);
  });

  testWidgets('compact form and advanced options fit narrow windows', (
    tester,
  ) async {
    await open(tester, const Size(420, 740));
    await tester.ensureVisible(find.text('高级设置'));
    await tester.tap(find.text('高级设置'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('离线获取依赖'));
    expect(find.text('下一步：添加依赖'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('steps retain configuration, search and selected dependencies', (
    tester,
  ) async {
    await open(tester, const Size(960, 800));
    await tester.enterText(
      find.byKey(const ValueKey('create-project-name')),
      'retained_app',
    );
    await tester.tap(find.byKey(const ValueKey('create-project-next')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('create-project-name')), findsNothing);
    await tester.enterText(
      find.byKey(const ValueKey('pub-package-search')),
      'dio',
    );
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('add-pub-package-dio')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('create-project-back')));
    await tester.pumpAndSettle();
    expect(find.text('retained_app'), findsWidgets);
    expect(find.byKey(const ValueKey('pub-package-search')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('create-project-next')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('pub-package-search')))
          .controller!
          .text,
      'dio',
    );
    expect(find.text('已选择 1 个依赖'), findsOneWidget);
    expect(packages.calls, 1);
    await tester.tap(find.byKey(const ValueKey('create-project-submit')));
    await tester.pumpAndSettle();
    expect(creator.received!.name, 'retained_app');
    expect(creator.received!.dependencies.single.name, 'dio');
  });

  testWidgets('invalid configuration cannot advance to dependencies', (
    tester,
  ) async {
    await open(tester, const Size(960, 800));
    await tester.enterText(
      find.byKey(const ValueKey('create-project-name')),
      'Invalid Name',
    );
    await tester.tap(find.byKey(const ValueKey('create-project-next')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('pub-package-search')), findsNothing);
    expect(creator.calls, 0);
    expect(packages.calls, 0);
  });

  testWidgets(
    'dependency downloads are shown and removal preserves other edited versions',
    (tester) async {
      await open(tester, const Size(1200, 1000));
      await tester.tap(find.byKey(const ValueKey('create-project-next')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('pub-package-search')),
        'http',
      );
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      expect(find.text('近 30 天下载：1234567'), findsOneWidget);
      expect(find.text('近 30 天下载：暂无数据'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('add-pub-package-dio')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('add-pub-package-http')));
      await tester.pumpAndSettle();
      final version = find.byKey(const ValueKey('pub-package-version-http'));
      await tester.ensureVisible(version);
      await tester.enterText(version, '^1.1.0');
      await tester.pump();
      final remove = find.byKey(const ValueKey('remove-pub-package-dio'));
      await tester.ensureVisible(remove);
      await tester.tap(remove);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('pub-package-version-dio')),
        findsNothing,
      );
      expect(find.text('已选择 1 个依赖'), findsOneWidget);
      expect(
        find.descendant(of: version, matching: find.text('^1.1.0')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('create-project-submit')));
      await tester.pumpAndSettle();
      expect(creator.received!.dependencies.single.name, 'http');
      expect(creator.received!.dependencies.single.constraint, '^1.1.0');
    },
  );

  testWidgets(
    'selected search result can be removed and added again in narrow windows',
    (tester) async {
      await open(tester, const Size(420, 840));
      await tester.tap(find.byKey(const ValueKey('create-project-next')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('pub-package-search')),
        'dio',
      );
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      final add = find.byKey(const ValueKey('add-pub-package-dio'));
      await tester.tap(add);
      await tester.pumpAndSettle();
      expect(find.text('近 30 天下载：1234567'), findsNWidgets(2));
      final remove = find.byKey(
        const ValueKey('remove-pub-package-result-dio'),
      );
      await tester.ensureVisible(remove);
      await tester.tap(remove);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('pub-package-version-dio')),
        findsNothing,
      );
      await tester.tap(add);
      await tester.pumpAndSettle();
      expect(find.text('已选择 1 个依赖'), findsOneWidget);
      final selectedRemove = find.byKey(
        const ValueKey('remove-pub-package-dio'),
      );
      await tester.ensureVisible(selectedRemove);
      await tester.tap(selectedRemove);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('create-project-submit')));
      await tester.pumpAndSettle();
      expect(creator.received!.dependencies, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );
}
