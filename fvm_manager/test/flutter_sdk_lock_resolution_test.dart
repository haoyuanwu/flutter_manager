import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_manager/src/data/fvm_service.dart';
import 'package:flutter_manager/src/data/pub_environment_service.dart';
import 'package:flutter_manager/src/domain/models.dart';

class _Fvm extends FvmService {
  _Fvm(this.sdks) : super(PubEnvironmentService());
  final List<InstalledSdk> sdks;
  @override
  Future<String?> detect({bool allowRepair = true}) async => '4.3.2';
  @override
  Future<List<InstalledSdk>> listInstalled() async => sdks;
}

class _Environment extends PubEnvironmentService {
  _Environment(this.paths);
  final List<String> paths;
  @override
  List<String> get executableSearchPaths => paths;
}

void main() {
  late Directory root;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('sdk_resolution_');
  });
  tearDown(() => root.delete(recursive: true));

  test('FVM config selects its SDK, not an unrelated global SDK', () async {
    final sdk = '${root.path}/versions/stable';
    await File(
      '$sdk/packages/flutter_tools/pubspec.yaml',
    ).create(recursive: true);
    await File('${root.path}/.fvmrc').writeAsString('{"flutter":"stable"}');
    final service = _Fvm([
      InstalledSdk(
        name: 'stable',
        flutterVersion: '3.47.5',
        dartVersion: '3.13.5',
        directory: sdk,
      ),
    ]);
    expect(
      await service.projectFlutterSdkPath(root.path),
      await Directory(sdk).resolveSymbolicLinks(),
    );
  });

  test(
    'unknown configured SDK fails instead of unlocking a different SDK',
    () async {
      await File('${root.path}/.fvmrc').writeAsString('{"flutter":"missing"}');
      await expectLater(
        _Fvm([]).projectFlutterSdkPath(root.path),
        throwsException,
      );
    },
  );

  test('a PATH Flutter symlink resolves to the real SDK', () async {
    final sdk = '${root.path}/sdk';
    await File(
      '$sdk/packages/flutter_tools/pubspec.yaml',
    ).create(recursive: true);
    await File('$sdk/bin/flutter').create(recursive: true);
    final bin = await Directory('${root.path}/links').create();
    await Link('${bin.path}/flutter').create('$sdk/bin/flutter');
    final service = FvmService(_Environment([bin.path]));
    expect(
      await service.projectFlutterSdkPath(root.path),
      await Directory(sdk).resolveSymbolicLinks(),
    );
  }, skip: Platform.isWindows);
}
