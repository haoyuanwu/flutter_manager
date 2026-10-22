import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_manager/src/data/flutter_startup_lock_service.dart';
import 'package:flutter_manager/src/presentation/widgets/flutter_startup_lock_button.dart';

void main() {
  const locked = FlutterLockReport('/SDK/flutter', [
    FlutterLockOwner(10, 'start dart'),
  ]);
  const unlocked = FlutterLockReport('/SDK/flutter', []);

  Future<void> open(
    WidgetTester tester, {
    Future<FlutterLockReport> Function()? inspect,
    required Future<FlutterLockReport> Function(FlutterLockReport, bool) stop,
    Future<void> Function()? rerun,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FlutterStartupLockButton(
            inspect: inspect ?? () async => locked,
            stop: stop,
            rerun: rerun ?? () async {},
          ),
        ),
      ),
    );
    await tester.tap(find.text('解除启动锁'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('continue waiting never stops anything', (tester) async {
    var stops = 0;
    await open(
      tester,
      stop: (_, _) async {
        stops++;
        return unlocked;
      },
    );
    expect(find.text('/SDK/flutter'), findsOneWidget);
    expect(find.textContaining('PID 10'), findsOneWidget);
    await tester.tap(find.text('继续等待'));
    await tester.pumpAndSettle();
    expect(stops, 0);
  });

  testWidgets('normal stop does not retry automatically', (tester) async {
    final forces = <bool>[];
    var reruns = 0;
    await open(
      tester,
      stop: (_, force) async {
        forces.add(force);
        return unlocked;
      },
      rerun: () async {
        reruns++;
      },
    );
    await tester.tap(find.text('尝试正常停止'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('当前未检测到启动锁占用'), findsOneWidget);
    expect(forces, [false]);
    expect(reruns, 0);
    await tester.tap(find.text('重新运行'));
    await tester.pumpAndSettle();
    expect(reruns, 1);
  });

  testWidgets('force requires a separate confirmation after normal stop', (
    tester,
  ) async {
    final forces = <bool>[];
    await open(
      tester,
      stop: (_, force) async {
        forces.add(force);
        return force ? unlocked : locked;
      },
    );
    expect(find.text('强制结束并解锁'), findsNothing);
    await tester.tap(find.text('尝试正常停止'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(forces, [false]);
    await tester.tap(find.text('强制结束并解锁'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(forces, [false, true]);
    await tester.tap(find.text('完成'));
    await tester.pumpAndSettle();
  });

  testWidgets('failure is visible and never offers retry as success', (
    tester,
  ) async {
    await open(
      tester,
      inspect: () async => throw Exception('无权限'),
      stop: (_, _) async => unlocked,
    );
    expect(find.text('未能解除启动锁'), findsOneWidget);
    expect(find.textContaining('无权限'), findsOneWidget);
    expect(find.text('重新运行'), findsNothing);
    await tester.tap(find.text('知道了'));
    await tester.pumpAndSettle();
    expect(find.text('解除启动锁'), findsOneWidget);
  });

  testWidgets('console output changing does not dispose an active recovery', (
    tester,
  ) async {
    final visible = ValueNotifier(true);
    addTearDown(visible.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ValueListenableBuilder<bool>(
            valueListenable: visible,
            builder: (_, show, _) => FlutterStartupLockButton(
              compact: true,
              visible: show,
              inspect: () async => locked,
              stop: (_, _) async {
                visible.value = false;
                return unlocked;
              },
              rerun: () async {},
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byTooltip('解除 Flutter 启动锁'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('尝试正常停止'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('当前未检测到启动锁占用'), findsOneWidget);
    await tester.tap(find.text('完成'));
    await tester.pumpAndSettle();
    expect(find.byType(IconButton), findsNothing);
  });
}
