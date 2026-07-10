import 'dart:async';
import 'dart:io';

/// Watches a Flutter project's `build/` directory (or project root children
/// when `build/` does not exist) and fires a debounced callback when artifacts
/// may have changed.
///
/// Lifecycle:
/// - At most one active subscription per [projectPath].
/// - Call [watch] to start watching; calling again cancels the previous
///   subscription automatically.
/// - Call [dispose] when the owning widget/page is destroyed or when the app
///   exits.
class BuildDirectoryWatcher {
  BuildDirectoryWatcher();

  static const _debounceDuration = Duration(milliseconds: 750);

  /// Extensions that represent final distribution artifacts or their containers.
  static const _interestingExtensions = <String>{
    'apk',
    'aab',
    'ipa',
    'hap',
    'dmg',
    'pkg',
    'msix',
    'exe',
    'zip',
  };

  StreamSubscription<FileSystemEvent>? _subscription;
  Timer? _debounce;
  String? _projectPath;
  String? _watchedPath;
  bool _disposed = false;

  /// Starts watching [projectPath]. If the `build/` subdirectory exists it is
  /// watched directly; otherwise we watch the project root's immediate
  /// children so that we can switch to `build/` once it is created.
  ///
  /// [onChange] is called (debounced) when a relevant filesystem event is
  /// detected. It should perform a silent re-scan of artifacts.
  void watch(String projectPath, void Function() onChange) {
    if (_disposed) return;
    // Same project — just replace the callback, keep watching.
    if (_projectPath == projectPath && _subscription != null) {
      _onChange = onChange;
      return;
    }
    _stop();
    _projectPath = projectPath;
    _onChange = onChange;
    _startWatching(projectPath);
  }

  void Function() _onChange = () {};

  Future<void> _startWatching(String projectPath) async {
    if (_disposed) return;
    final buildDir = Directory('$projectPath${Platform.pathSeparator}build');
    if (await buildDir.exists()) {
      _subscribe(buildDir.path, recursive: true);
    } else {
      // Watch project root non-recursively; when `build/` is created we
      // switch over.
      _subscribe(projectPath, recursive: false);
    }
  }

  void _subscribe(String path, {required bool recursive}) {
    _cancelSubscription();
    _watchedPath = path;
    final directory = Directory(path);
    try {
      _subscription = directory
          .watch(recursive: recursive)
          .listen(
            _onEvent,
            onError: (Object _) {
              // Directory removed or permission issue — silently stop.
              _cancelSubscription();
            },
            onDone: _cancelSubscription,
            cancelOnError: true,
          );
    } on Object {
      // Platform does not support watching or path is invalid.
      _subscription = null;
    }
  }

  void _onEvent(FileSystemEvent event) {
    if (_disposed) return;

    // When watching the project root (build/ doesn't exist yet), a newly
    // created `build/` directory means we should switch subscriptions.
    if (_watchedPath == _projectPath && event.type == FileSystemEvent.create) {
      final name = event.path.split(Platform.pathSeparator).last;
      if (name == 'build') {
        final buildPath = '$_projectPath${Platform.pathSeparator}build';
        _subscribe(buildPath, recursive: true);
        // Still trigger a refresh after the switch.
        _scheduleRefresh();
        return;
      }
    }

    // Only react to events involving interesting file extensions, directory
    // creation, or deletion.
    if (!_isInterestingEvent(event)) return;

    _scheduleRefresh();
  }

  bool _isInterestingEvent(FileSystemEvent event) {
    // Directory creation or deletion is always interesting.
    if (event is FileSystemCreateEvent || event is FileSystemDeleteEvent) {
      return true;
    }
    // For modify / move events, check the extension.
    final path = event.path;
    final lastSep = path.lastIndexOf(Platform.pathSeparator);
    final fileName = lastSep >= 0 ? path.substring(lastSep + 1) : path;
    final dot = fileName.lastIndexOf('.');
    if (dot < 0) return false;
    final ext = fileName.substring(dot + 1).toLowerCase();
    return _interestingExtensions.contains(ext);
  }

  void _scheduleRefresh() {
    _debounce?.cancel();
    _debounce = Timer(_debounceDuration, () {
      if (!_disposed) _onChange();
    });
  }

  void _cancelSubscription() {
    _subscription?.cancel();
    _subscription = null;
    _watchedPath = null;
  }

  void _stop() {
    _cancelSubscription();
    _debounce?.cancel();
    _debounce = null;
    _projectPath = null;
  }

  /// Whether the watcher currently has an active subscription.
  bool get isActive => _subscription != null;

  /// Stops the current watch subscription and cancels any pending debounce.
  /// The instance can be reused by calling [watch] again.
  void stop() {
    _stop();
    _onChange = () {};
  }

  /// Stops watching and releases all resources. The instance must not be
  /// reused after calling [dispose].
  void dispose() {
    _disposed = true;
    _stop();
    _onChange = () {};
  }
}
