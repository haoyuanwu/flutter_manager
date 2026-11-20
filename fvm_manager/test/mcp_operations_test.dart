import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_manager/src/presentation/mcp_operations.dart';

void main() {
  test(
    'operation acceptance is separate from completion and mutation is single-flight',
    () async {
      final jobs = McpOperations();
      final gate = Completer<Map<String, dynamic>>();
      final accepted = jobs.start('upload', '/a', () => gate.future);
      expect(accepted['status'], 'running');
      expect(
        () => jobs.start('upload', '/b', () async => {}),
        throwsStateError,
      );
      gate.complete({'downloadUrl': 'https://example.com/app'});
      await Future<void>.delayed(const Duration(milliseconds: 5));
      final complete = jobs.get(accepted['operationId'] as String);
      expect(complete['status'], 'success');
      expect(
        (complete['result'] as Map)['downloadUrl'],
        'https://example.com/app',
      );
      expect(jobs.busy, isFalse);
      expect(accepted['status'], 'running');
    },
  );
  test('stopped build is cancelled rather than reported as success', () async {
    final jobs = McpOperations();
    final gate = Completer<Map<String, dynamic>>();
    final accepted = jobs.start('build', '/a', () => gate.future);
    jobs.requestCancellation('build', '/b');
    expect(
      jobs.get(accepted['operationId'] as String)['cancelRequested'],
      isNull,
    );
    jobs.requestCancellation('build', '/a');
    gate.complete({'stopped': true});
    await Future<void>.delayed(const Duration(milliseconds: 5));
    expect(jobs.get(accepted['operationId'] as String)['status'], 'cancelled');
  });
  test('failures are retained, redacted and release the lock', () async {
    final jobs = McpOperations();
    final accepted = jobs.start(
      'upload',
      '/a',
      () async => throw StateError('secret'),
      describeError: (_) => 'safe failure',
    );
    await Future<void>.delayed(const Duration(milliseconds: 5));
    final job = jobs.get(accepted['operationId'] as String);
    expect(job['status'], 'failed');
    expect(job['error'], 'safe failure');
    expect(jobs.busy, isFalse);
    expect(() => jobs.get('missing'), throwsArgumentError);
  });
}
