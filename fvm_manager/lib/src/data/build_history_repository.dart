import 'dart:convert';
import 'dart:io';

import '../domain/build_history_models.dart';

class BuildHistoryRepository {
  BuildHistoryRepository({this._storageFile});

  static const schemaVersion = 1;
  static const maxSessions = 500;

  final File? _storageFile;
  Future<void> _mutationQueue = Future.value();

  Future<BuildHistorySnapshot> load({bool tolerateErrors = true}) async {
    final file = _file;
    if (!await file.exists()) return const BuildHistorySnapshot();
    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map<String, dynamic>) {
        return const BuildHistorySnapshot();
      }
      final sessions =
          (decoded['sessions'] as List<dynamic>? ?? const [])
              .whereType<Map<String, dynamic>>()
              .map(BuildSession.fromMap)
              .where((session) => session.id.isNotEmpty)
              .toList()
            ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
      final artifacts = (decoded['artifacts'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(BuildArtifactRecord.fromMap)
          .where((artifact) => artifact.id.isNotEmpty)
          .map(
            (artifact) => BuildArtifactRecord(
              id: artifact.id,
              buildSessionId: artifact.buildSessionId,
              projectPath: artifact.projectPath,
              path: artifact.path,
              name: artifact.name,
              type: artifact.type,
              platform: artifact.platform,
              size: artifact.size,
              modified: artifact.modified,
              exists: File(artifact.path).existsSync(),
              source: artifact.source,
              fingerprint: artifact.fingerprint,
            ),
          )
          .toList();
      return BuildHistorySnapshot(sessions: sessions, artifacts: artifacts);
    } on Object {
      if (!tolerateErrors) rethrow;
      return const BuildHistorySnapshot();
    }
  }

  Future<void> startSession(BuildSession session) async {
    await _mutate(
      (snapshot) => BuildHistorySnapshot(
        sessions: [
          session,
          ...snapshot.sessions.where((item) => item.id != session.id),
        ],
        artifacts: snapshot.artifacts,
      ),
    );
  }

  Future<void> recoverInterruptedSessions() async {
    await _mutate(
      (snapshot) => BuildHistorySnapshot(
        sessions: snapshot.sessions
            .map(
              (session) => session.status == BuildSessionStatus.running
                  ? session.copyWith(status: BuildSessionStatus.interrupted)
                  : session,
            )
            .toList(growable: false),
        artifacts: snapshot.artifacts,
      ),
    );
  }

  Future<void> completeSession({
    required String sessionId,
    required BuildSessionStatus status,
    required DateTime finishedAt,
    required int? exitCode,
    required List<BuildArtifactRecord> artifacts,
  }) async {
    await _mutate((snapshot) {
      final sessions = snapshot.sessions
          .map(
            (session) => session.id == sessionId
                ? session.copyWith(
                    finishedAt: finishedAt,
                    status: status,
                    exitCode: exitCode,
                    artifactIds: artifacts.map((item) => item.id).toList(),
                  )
                : session,
          )
          .toList();
      final mergedArtifacts = [
        ...artifacts,
        ...snapshot.artifacts.where(
          (artifact) => artifact.buildSessionId != sessionId,
        ),
      ];
      return _trim(
        BuildHistorySnapshot(sessions: sessions, artifacts: mergedArtifacts),
      );
    });
  }

  BuildHistorySnapshot _trim(BuildHistorySnapshot snapshot) {
    final sessions = [...snapshot.sessions]
      ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
    final keptSessions = sessions.take(maxSessions).toList(growable: false);
    final ids = keptSessions.map((session) => session.id).toSet();
    return BuildHistorySnapshot(
      sessions: keptSessions,
      artifacts: snapshot.artifacts
          .where((artifact) => ids.contains(artifact.buildSessionId))
          .toList(growable: false),
    );
  }

  Future<void> _mutate(
    BuildHistorySnapshot Function(BuildHistorySnapshot snapshot) update,
  ) {
    Future<void> run() async {
      final snapshot = await load(tolerateErrors: false);
      await _write(update(snapshot));
    }

    _mutationQueue = _mutationQueue.then((_) => run(), onError: (_) => run());
    return _mutationQueue;
  }

  Future<void> _write(BuildHistorySnapshot snapshot) async {
    final file = _file;
    await file.parent.create(recursive: true);
    final temporary = File('${file.path}.tmp');
    await temporary.writeAsString(
      jsonEncode({
        'schemaVersion': schemaVersion,
        'sessions': snapshot.sessions
            .map((session) => session.toMap())
            .toList(),
        'artifacts': snapshot.artifacts
            .map((artifact) => artifact.toMap())
            .toList(),
      }),
      flush: true,
    );
    try {
      await temporary.rename(file.path);
    } on FileSystemException {
      final backup = File('${file.path}.bak');
      if (await backup.exists()) await backup.delete();
      if (await file.exists()) await file.rename(backup.path);
      try {
        await temporary.rename(file.path);
        if (await backup.exists()) await backup.delete();
      } on Object {
        if (!await file.exists() && await backup.exists()) {
          await backup.rename(file.path);
        }
        rethrow;
      }
    }
  }

  File get _file {
    if (_storageFile case final file?) return file;
    final home =
        Platform.environment[Platform.isWindows ? 'USERPROFILE' : 'HOME'];
    if (home == null) throw Exception('无法确定用户目录');
    return File(
      '$home${Platform.pathSeparator}.fvm_manager${Platform.pathSeparator}'
      'build_history.json',
    );
  }
}
