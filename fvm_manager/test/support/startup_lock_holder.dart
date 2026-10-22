import 'dart:async';
import 'dart:io';

// Only used with a temporary SDK in the startup-lock integration tests.
Future<void> main(List<String> args) async {
  final file = await File(args.first).open(mode: FileMode.append);
  if (args.contains('wait')) stdout.writeln('waiting');
  await file.lock(
    args.contains('wait') ? FileLock.blockingExclusive : FileLock.exclusive,
  );
  if (args.contains('ignore-term')) {
    ProcessSignal.sigterm.watch().listen((_) {});
  }
  stdout.writeln('locked');
  await Future<void>.delayed(const Duration(minutes: 1));
  await file.close();
}
