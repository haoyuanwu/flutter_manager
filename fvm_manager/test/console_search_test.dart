import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_manager/src/presentation/console_search.dart';

void main() {
  test(
    'background search keeps case insensitive non-overlapping ranges',
    () async {
      final worker = ConsoleSearchWorker();
      addTearDown(worker.cancel);
      expect(
        await worker.search('Hello hello HELLO', 'hello', delay: Duration.zero),
        const [
          TextRange(start: 0, end: 5),
          TextRange(start: 6, end: 11),
          TextRange(start: 12, end: 17),
        ],
      );
    },
  );

  test(
    'new input cancels pending debounce and only returns latest results',
    () async {
      final worker = ConsoleSearchWorker();
      addTearDown(worker.cancel);
      final old = worker.search('first second', 'first');
      final latest = worker.search(
        'first second',
        'second',
        delay: Duration.zero,
      );
      expect(await old, isNull);
      expect(await latest, const [TextRange(start: 6, end: 12)]);
    },
  );

  test(
    'cancellation while spawning or running never returns obsolete results',
    () async {
      final worker = ConsoleSearchWorker();
      addTearDown(worker.cancel);
      final old = worker.search('a' * 1000000, 'a', delay: Duration.zero);
      await Future<void>.delayed(const Duration(milliseconds: 1));
      final latest = worker.search('new', 'new', delay: Duration.zero);
      expect(await old, isNull);
      expect(await latest, const [TextRange(start: 0, end: 3)]);
    },
  );

  test('clearing and closing cancel outstanding searches', () async {
    final worker = ConsoleSearchWorker();
    final old = worker.search('text', 'text');
    expect(await worker.search('text', ''), isEmpty);
    expect(await old, isNull);
    final pending = worker.search('text', 'text');
    worker.cancel();
    expect(await pending, isNull);
  });
}
