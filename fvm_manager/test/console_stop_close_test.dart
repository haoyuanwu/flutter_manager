import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_manager/src/presentation/pages/console_window_page.dart';

void main() {
  for (final scoped in [false, true]) {
    for (final outcome in ['success', 'failure', 'cancel']) {
      testWidgets(
        'console stop $outcome (${scoped ? 'scoped' : 'global'} channel)',
        (tester) async {
          final messenger =
              TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
          const windows = MethodChannel('mixin.one/desktop_multi_window');
          const channels = MethodChannel(
            'mixin.one/desktop_multi_window/channels',
          );
          final stopped = Completer<void>();
          final events = <String>[];
          final channelName = scoped
              ? 'fvm_manager/console_commands/test-console'
              : 'fvm_manager/console_commands';
          messenger.setMockMethodCallHandler(windows, (call) async {
            if (call.method == 'getWindowDefinition') {
              return {'windowId': 'console-test', 'windowArgument': ''};
            }
            if (call.method == 'window_hide') {
              expect(call.arguments['windowId'], 'console-test');
              events.add('hide');
            }
            return null;
          });
          messenger.setMockMethodCallHandler(channels, (call) async {
            final args = call.arguments as Map;
            if (call.method == 'invokeMethod' &&
                args['method'] == 'stopCommand') {
              expect(args['channel'], channelName);
              expect(args['arguments'], {
                'taskId': 'run::/tmp/demo',
                'waitForExit': true,
              });
              events.add('stop');
              if (outcome == 'failure') {
                throw PlatformException(code: 'STOP_FAILED', message: '仍在运行');
              }
              await stopped.future;
            }
            return null;
          });
          addTearDown(() {
            messenger.setMockMethodCallHandler(windows, null);
            messenger.setMockMethodCallHandler(channels, null);
          });
          await tester.pumpWidget(
            MaterialApp(
              home: ConsoleWindowPage(
                projectTitle: 'demo',
                projectPath: '/tmp/demo',
                initialCommandLog: '',
                initialTasks: const [
                  {'id': 'run::/tmp/demo', 'label': 'Flutter Run'},
                ],
                initialShowQuickCommands: false,
                initialConsoleMode: 'run',
                initialBuildTarget: 'apk',
                initialActionChannelName: channelName,
              ),
            ),
          );
          await tester.pumpAndSettle();
          await tester.tap(find.text('结束运行'));
          await tester.pumpAndSettle();
          if (outcome == 'cancel') {
            await tester.tap(find.text('取消'));
            await tester.pumpAndSettle();
            expect(events, isEmpty);
          } else {
            await tester.tap(find.widgetWithText(FilledButton, '结束运行'));
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 300));
            expect(events, ['stop']);
            if (outcome == 'success') {
              stopped.complete();
              await tester.pumpAndSettle();
              expect(events, ['stop', 'hide']);
            } else {
              expect(find.textContaining('结束命令失败'), findsOneWidget);
              expect(events, ['stop']);
            }
          }
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pumpAndSettle();
        },
      );
    }
  }
}
