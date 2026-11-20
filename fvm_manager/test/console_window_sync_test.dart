import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_manager/src/presentation/console_window_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('late console engine recovers live logs after startup retries', (
    tester,
  ) async {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    const windows = MethodChannel('mixin.one/desktop_multi_window');
    const channels = MethodChannel('mixin.one/desktop_multi_window/channels');
    final service = ConsoleWindowService.instance;
    const key = 'run::/tmp/late-console';
    var registered = false;
    var shown = false;
    final received = <String>[];
    messenger.setMockMethodCallHandler(windows, (call) async {
      if (call.method == 'createWindow') return 'late-engine';
      if (call.method == 'window_show') shown = true;
      return null;
    });
    messenger.setMockMethodCallHandler(channels, (call) async {
      final args = call.arguments as Map;
      if (call.method == 'invokeMethod' && args['method'] == 'consoleSync') {
        if (!registered) throw PlatformException(code: 'CHANNEL_UNREGISTERED');
        received.add(args['arguments']['commandLog'] as String);
      }
      return null;
    });
    addTearDown(() async {
      await service.close(key);
      messenger.setMockMethodCallHandler(windows, null);
      messenger.setMockMethodCallHandler(channels, null);
    });
    var opened = false;
    unawaited(
      service
          .openOrFocus(
            windowKey: key,
            projectPath: '/tmp/late-console',
            projectTitle: 'demo',
            commandLog: r'$ flutter run',
            tasks: const [],
            showQuickCommands: true,
            consoleMode: 'run',
            buildTarget: 'apk',
          )
          .then((_) => opened = true),
    );
    await tester.pump();
    service.markReady('/tmp/late-console', windowId: 'late-engine');
    await tester.pump();
    expect(
      shown,
      isTrue,
      reason: 'tab-keyed ready must not wait for 5s timeout',
    );
    for (var i = 0; i < 13; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(opened, isTrue);
    registered = true;
    await service.sync(
      windowKey: key,
      projectPath: '/tmp/late-console',
      projectTitle: 'demo',
      commandLog: 'Launching lib/main.dart\nI/flutter: live output\n',
      tasks: const [],
      showQuickCommands: true,
      consoleMode: 'run',
      buildTarget: 'apk',
    );
    expect(received.last, contains('I/flutter: live output'));
  });
}
