import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_manager/src/data/flutter_startup_lock_service.dart';

void main() {
  late Directory root;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('flutter_lock_test_');
    await File('${root.path}/bin/cache/lockfile').create(recursive: true);
    await File('${root.path}/bin/internal/shared.sh').create(recursive: true);
  });
  tearDown(() => root.delete(recursive: true));

  test('finds write lock holders but excludes open files and read locks', () {
    expect(
      FlutterStartupLockService.parsePosixLockOwners('''
p10
f4
lW
p11
f4
l
p12
f5
lr
p13
f7
lw
'''),
      {10, 13},
    );
  });

  test('recognizes recent startup wait output, not old log entries', () {
    const warning =
        'Waiting for another flutter command to release the startup lock...';
    expect(hasFlutterStartupLockWarning(warning), isTrue);
    expect(hasFlutterStartupLockWarning('$warning${'x' * 2100}'), isFalse);
  });

  test('reports unlocked without deleting or truncating lockfile', () async {
    final lock = File('${root.path}/bin/cache/lockfile');
    await lock.writeAsString('preserve');
    final service = FlutterStartupLockService(
      windows: false,
      run: (_, _) async => ProcessResult(0, 1, '', ''),
      recordLockOwner: (_) => null,
    );
    expect((await service.inspect(root.path)).owners, isEmpty);
    expect(await lock.readAsString(), 'preserve');
  });

  test('refuses to remove an unattributed SDK update lock', () async {
    final lock = Directory('${root.path}/bin/cache/.upgrade_lock');
    await lock.create();
    final service = FlutterStartupLockService(
      windows: false,
      run: (_, _) async => ProcessResult(0, 1, '', ''),
      recordLockOwner: (_) => null,
    );
    await expectLater(service.inspect(root.path), throwsException);
    expect(await lock.exists(), isTrue);
  });

  test('does not signal recycled PID or new owners without approval', () async {
    final signals = <int>[];
    final service = FlutterStartupLockService(
      windows: false,
      delay: (_) async {},
      recordLockOwner: (_) => null,
      signal: (pid, _) {
        signals.add(pid);
        return true;
      },
      run: (exe, args) async => exe == 'lsof'
          ? ProcessResult(0, 0, 'p10\nf4\nlW\np20\nf5\nlW\n', '')
          : ProcessResult(0, 0, 'new start identity', ''),
    );
    final result = await service.stop(
      FlutterLockReport(root.path, const [
        FlutterLockOwner(10, 'old start identity'),
      ]),
      force: true,
    );
    expect(signals, isEmpty);
    expect(result.owners.map((owner) => owner.pid), [10, 20]);
  });

  test('normal stop never escalates itself to SIGKILL', () async {
    final signals = <ProcessSignal>[];
    final service = FlutterStartupLockService(
      windows: false,
      delay: (_) async {},
      recordLockOwner: (_) => null,
      signal: (_, signal) {
        signals.add(signal);
        return true;
      },
      run: (exe, args) async => exe == 'lsof'
          ? ProcessResult(0, 0, 'p10\nf4\nlW\n', '')
          : ProcessResult(0, 0, 'same identity', ''),
    );
    final result = await service.stop(
      FlutterLockReport(root.path, const [
        FlutterLockOwner(10, 'same identity'),
      ]),
    );
    expect(signals, [ProcessSignal.sigterm]);
    expect(result.owners, hasLength(1));
  });

  test('inspection errors never signal processes', () async {
    var signals = 0;
    final service = FlutterStartupLockService(
      windows: false,
      recordLockOwner: (_) => null,
      signal: (_, _) {
        signals++;
        return true;
      },
      run: (_, _) async => ProcessResult(0, 1, '', 'permission denied'),
    );
    await expectLater(
      service.stop(
        FlutterLockReport(root.path, const [
          FlutterLockOwner(10, 'same identity'),
        ]),
      ),
      throwsException,
    );
    expect(signals, 0);
  });

  test('window reports survive multi-window channel serialization', () {
    final report = FlutterLockReport(root.path, const [
      FlutterLockOwner(123, 'start dart'),
    ]);
    final decoded = FlutterLockReport.fromJson(
      jsonDecode(jsonEncode(report.toJson())) as Map,
    );
    expect(decoded.sdkPath, root.path);
    expect(decoded.owners.single.pid, 123);
    expect(decoded.owners.single.identity, 'start dart');
  });

  test(
    'Windows uses only confirmed file users and separates graceful/forced stop',
    () async {
      var active = true;
      final commands = <String>[];
      final service = FlutterStartupLockService(
        windows: true,
        delay: (_) async {},
        run: (exe, args) async {
          expect(exe, 'powershell.exe');
          final script = args.last;
          commands.add(script);
          if (script.contains('.Kill()')) active = false;
          if (script.contains('FlutterLockFinder')) {
            return ProcessResult(
              0,
              0,
              active ? '[{"pid":10,"identity":"ticks dart"}]' : '[]',
              '',
            );
          }
          return ProcessResult(0, 0, '', '');
        },
      );
      final report = await service.inspect("C:/SDK's/flutter");
      expect(commands.first, contains("C:/SDK''s/flutter/bin/cache/lockfile"));
      final normal = await service.stop(report);
      expect(normal.owners, hasLength(1));
      expect(
        commands.any((script) => script.contains('.CloseMainWindow()')),
        isTrue,
      );
      expect(commands.any((script) => script.contains('.Kill()')), isFalse);
      expect((await service.stop(normal, force: true)).owners, isEmpty);
    },
  );

  // No real SDK or user processes are touched: only this test's child and file.
  test(
    'a real waiting Flutter process is not mistaken for the lock owner',
    () async {
      final dart =
          '${Platform.environment['FLUTTER_ROOT']}/bin/cache/dart-sdk/bin/dart';
      Future<Process> start(List<String> extra) async {
        final child = await Process.start(dart, [
          'test/support/startup_lock_holder.dart',
          '${root.path}/bin/cache/lockfile',
          ...extra,
        ]);
        addTearDown(() async {
          child.kill(ProcessSignal.sigkill);
          await child.exitCode;
        });
        await child.stdout
            .transform(utf8.decoder)
            .transform(const LineSplitter())
            .first
            .timeout(const Duration(seconds: 10));
        return child;
      }

      final holder = await start([]);
      final waiter = await start(['wait']);
      final report = await FlutterStartupLockService().inspect(root.path);
      expect(report.owners.map((owner) => owner.pid), contains(holder.pid));
      expect(
        report.owners.map((owner) => owner.pid),
        isNot(contains(waiter.pid)),
      );
    },
    skip: Platform.isWindows,
  );

  for (final force in [false, true]) {
    test(
      'releases a real POSIX lock (${force ? 'forced' : 'normal'})',
      () async {
        final flutterRoot = Platform.environment['FLUTTER_ROOT'];
        expect(flutterRoot, isNotNull);
        final dart = '$flutterRoot/bin/cache/dart-sdk/bin/dart';
        final child = await Process.start(dart, [
          'test/support/startup_lock_holder.dart',
          '${root.path}/bin/cache/lockfile',
          if (force) 'ignore-term',
        ]);
        addTearDown(() async {
          child.kill(ProcessSignal.sigkill);
          await child.exitCode;
        });
        await child.stdout
            .transform(utf8.decoder)
            .transform(const LineSplitter())
            .first
            .timeout(const Duration(seconds: 10));
        final service = FlutterStartupLockService(windows: false);
        final report = await service.inspect(root.path);
        expect(report.owners.map((owner) => owner.pid), contains(child.pid));
        if (force) {
          final stillLocked = await service.stop(report);
          expect(
            stillLocked.owners.map((owner) => owner.pid),
            contains(child.pid),
          );
        }
        final result = await service.stop(report, force: force);
        expect(result.owners, isEmpty);
        expect(await File('${root.path}/bin/cache/lockfile').exists(), isTrue);
      },
      skip: Platform.isWindows,
    );
  }
}
