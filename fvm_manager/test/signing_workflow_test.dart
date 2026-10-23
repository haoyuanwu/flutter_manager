import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_manager/src/data/apk_signing_service.dart';
import 'package:flutter_manager/src/data/process_runner.dart';
import 'package:flutter_manager/src/data/signing_preferences.dart';
import 'package:flutter_manager/src/presentation/providers.dart';
import 'package:flutter_manager/src/presentation/signing_workflow_dialogs.dart';

class _Runner extends ProcessRunner {
  bool fail = false;
  @override
  Future<ProcessRunResult> run({
    required String executable,
    required List<String> arguments,
    String? taskId,
    String? workingDirectory,
    Map<String, String>? environment,
    bool includeParentEnvironment = true,
    bool runInShell = false,
    Duration? timeout,
  }) async {
    if (arguments.first == 'sign') {
      await File(arguments.last).writeAsBytes([2, 3]);
    }
    return ProcessRunResult(
      exitCode: fail ? 1 : 0,
      stdout: '',
      stderr: fail ? 'failed' : '',
    );
  }
}

class _Service extends ApkSigningService {
  _Service(super.runner);
  @override
  Future<String?> findApkSigner() async => '/fake/apksigner';
  @override
  Future<ApkInfo> extractApkInfo(String path) async =>
      ApkInfo(path: path, name: path.split(Platform.pathSeparator).last);
}

void main() {
  late Directory root;
  late SigningPreferencesStore store;
  setUp(() {
    root = Directory.systemTemp.createTempSync('signing-workflow-test-');
    store = SigningPreferencesStore(
      file: File('${root.path}/preferences.json'),
    );
  });
  tearDown(() async => root.delete(recursive: true));

  test(
    'preferences default to ask and keep, persist and recover corrupt data',
    () async {
      expect(store.load().rememberChoice, false);
      expect(store.load().replaceSource, false);
      await store.save(
        const SigningPreferences(rememberChoice: true, replaceSource: true),
      );
      final restored = SigningPreferencesStore(file: store.file).load();
      expect(restored.rememberChoice, true);
      expect(restored.replaceSource, true);
      await store.file.writeAsString('{broken');
      expect(store.load().rememberChoice, false);
      expect(store.load().replaceSource, false);
    },
  );

  test(
    'signing to source directory with same name never mutates input before consent',
    () async {
      final source = File('${root.path}/app.apk');
      await source.writeAsBytes([1]);
      final result = await _Service(_Runner()).signApk(
        apkPath: source.path,
        jksPath: 'key.jks',
        password: 'test',
        keyAlias: 'key',
        outputDir: root.path,
        outputNameSuffix: '',
      );
      expect(result.success, true);
      expect(result.outputPath, isNot(source.path));
      expect(await source.readAsBytes(), [1]);
      expect(await File(result.outputPath).readAsBytes(), [2, 3]);
    },
  );

  test(
    'replacement writes signed APK and keeps recoverable original and independent output',
    () async {
      final source = File('${root.path}/app.apk');
      final output = File('${root.path}/signed.apk');
      await source.writeAsBytes([1]);
      await output.writeAsBytes([2, 3]);
      final result = await _Service(_Runner()).replaceOriginal(
        SignedApkInfo(
          originalPath: source.path,
          outputPath: output.path,
          outputName: 'signed.apk',
        ),
      );
      expect(result.sourceReplacementError, isNull);
      expect(result.outputPath, source.path);
      expect(await source.readAsBytes(), [2, 3]);
      expect(await File(result.sourceBackupPath!).readAsBytes(), [1]);
      expect(await output.readAsBytes(), [2, 3]);
    },
  );

  test('missing output and same-file result never damage original', () async {
    final source = File('${root.path}/app.apk');
    await source.writeAsBytes([1]);
    for (final output in [source.path, '${root.path}/missing.apk']) {
      final result = await _Service(_Runner()).replaceOriginal(
        SignedApkInfo(
          originalPath: source.path,
          outputPath: output,
          outputName: 'app.apk',
        ),
      );
      expect(result.sourceReplacementError, isNotNull);
      expect(await source.readAsBytes(), [1]);
    }
  });

  test('failed signing never asks to replace or modifies source', () async {
    final source = File('${root.path}/app.apk');
    await source.writeAsBytes([1]);
    final container = ProviderContainer(
      overrides: [
        apkSigningServiceProvider.overrideWithValue(
          _Service(_Runner()..fail = true),
        ),
      ],
    );
    addTearDown(container.dispose);
    final controller = container.read(apkSigningControllerProvider.notifier);
    controller.addUnsignedApks([ApkInfo(path: source.path, name: 'app.apk')]);
    var asked = false;
    await controller.signSelectedApks(
      jksPath: 'key',
      password: 'test',
      keyAlias: 'key',
      outputDir: root.path,
      selectedPaths: [source.path],
      chooseSourceHandling: (_) async {
        asked = true;
        return true;
      },
    );
    expect(asked, false);
    expect(await source.readAsBytes(), [1]);
    expect(
      container.read(apkSigningControllerProvider).signingInProgress,
      false,
    );
  });

  test(
    'successful batch waits for decision, then updates result path after replacement',
    () async {
      final source = File('${root.path}/app.apk');
      await source.writeAsBytes([1]);
      final container = ProviderContainer(
        overrides: [
          apkSigningServiceProvider.overrideWithValue(_Service(_Runner())),
        ],
      );
      addTearDown(container.dispose);
      final controller = container.read(apkSigningControllerProvider.notifier);
      controller.addUnsignedApks([ApkInfo(path: source.path, name: 'app.apk')]);
      await controller.signSelectedApks(
        jksPath: 'key',
        password: 'test',
        keyAlias: 'key',
        outputDir: root.path,
        selectedPaths: [source.path],
        chooseSourceHandling: (count) async {
          expect(count, 1);
          expect(await source.readAsBytes(), [1]);
          return true;
        },
      );
      expect(await source.readAsBytes(), [2, 3]);
      expect(
        container
            .read(apkSigningControllerProvider)
            .signedApks
            .single
            .outputPath,
        source.path,
      );
    },
  );

  testWidgets(
    'remembered dialog choice skips future prompts and can be re-enabled',
    (tester) async {
      final results = <bool>[];
      await tester.pumpWidget(
        ProviderScope(
          overrides: [signingPreferencesStoreProvider.overrideWithValue(store)],
          child: MaterialApp(
            home: Consumer(
              builder: (context, ref, _) => Scaffold(
                body: TextButton(
                  onPressed: () async => results.add(
                    await confirmSigningSourceHandling(context, ref, 1),
                  ),
                  child: const Text('finish'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('finish'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('remember-signing-source-choice')),
      );
      await tester.tap(find.byKey(const ValueKey('replace-signing-source')));
      // File-backed preference writes complete outside the test clock.
      for (var i = 0; i < 20 && results.isEmpty; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pump();
      }
      expect(results, [true]);
      expect(store.load().replaceSource, true);
      expect(store.load().rememberChoice, true);
      await tester.tap(find.text('finish'));
      await tester.pumpAndSettle();
      expect(results, [true, true]);
      expect(find.byType(AlertDialog), findsNothing);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(Scaffold)),
      );
      await tester.runAsync(
        () => container
            .read(signingPreferencesProvider.notifier)
            .update(rememberChoice: false),
      );
      await tester.tap(find.text('finish'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      Navigator.of(tester.element(find.byType(AlertDialog))).pop();
      await tester.pumpAndSettle();
      expect(results.last, false);
    },
  );
}
