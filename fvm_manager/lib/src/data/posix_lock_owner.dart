import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

final class _DarwinFlock extends Struct {
  @Int64()
  external int start;
  @Int64()
  external int length;
  @Int32()
  external int pid;
  @Int16()
  external int type;
  @Int16()
  external int whence;
}

final class _LinuxFlock extends Struct {
  @Int16()
  external int type;
  @Int16()
  external int whence;
  @Int64()
  external int start;
  @Int64()
  external int length;
  @Int32()
  external int pid;
}

/// F_GETLK queries the kernel without acquiring/releasing a lock. macOS lsof
/// does not expose Dart's POSIX record-lock ownership, and open file handles
/// include waiting processes, so those handles are not safe kill targets.
int? posixRecordLockOwner(String path) {
  if (!Platform.isMacOS && !Platform.isLinux) {
    throw UnsupportedError('当前平台不支持安全查询 POSIX 锁');
  }
  final libc = DynamicLibrary.process();
  final open = libc
      .lookupFunction<
        Int32 Function(Pointer<Utf8>, Int32, VarArgs<()>),
        int Function(Pointer<Utf8>, int)
      >('open');
  final close = libc.lookupFunction<Int32 Function(Int32), int Function(int)>(
    'close',
  );
  final fcntl = libc
      .lookupFunction<
        Int32 Function(Int32, Int32, VarArgs<(Pointer<Void>,)>),
        int Function(int, int, Pointer<Void>)
      >('fcntl');
  final filename = path.toNativeUtf8();
  // O_RDONLY; this function never modifies the file.
  final fd = open(filename, 0);
  calloc.free(filename);
  if (fd < 0) throw FileSystemException('无法打开启动锁文件以查询占用者', path);
  final darwin = Platform.isMacOS;
  final lock = darwin
      ? calloc<_DarwinFlock>().cast<Void>()
      : calloc<_LinuxFlock>().cast<Void>();
  try {
    if (darwin) {
      lock.cast<_DarwinFlock>().ref.type = 3; // Darwin F_WRLCK
    } else {
      lock.cast<_LinuxFlock>().ref.type = 1; // Linux F_WRLCK
    }
    // start=0, length=0, whence=SEEK_SET: query the whole file.
    if (fcntl(fd, darwin ? 7 : 5, lock) != 0) {
      throw FileSystemException('系统无法查询启动锁持有者', path);
    }
    final lockType = darwin
        ? lock.cast<_DarwinFlock>().ref.type
        : lock.cast<_LinuxFlock>().ref.type;
    if (lockType == 2) return null; // Darwin and Linux F_UNLCK
    final pid = darwin
        ? lock.cast<_DarwinFlock>().ref.pid
        : lock.cast<_LinuxFlock>().ref.pid;
    if (pid <= 0) throw FileSystemException('无法安全确定启动锁持有者', path);
    return pid;
  } finally {
    calloc.free(lock);
    close(fd);
  }
}
