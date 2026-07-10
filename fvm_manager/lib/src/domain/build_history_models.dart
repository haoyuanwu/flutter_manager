enum BuildSessionStatus { running, success, failed, stopped, interrupted }

class BuildSession {
  const BuildSession({
    required this.id,
    required this.projectPath,
    required this.taskId,
    required this.label,
    required this.commands,
    required this.target,
    required this.mode,
    required this.flavors,
    required this.startedAt,
    required this.status,
    this.finishedAt,
    this.flutterVersion,
    this.exitCode,
    this.artifactIds = const [],
  });

  final String id;
  final String projectPath;
  final String taskId;
  final String label;
  final List<String> commands;
  final String target;
  final String mode;
  final List<String> flavors;
  final DateTime startedAt;
  final DateTime? finishedAt;
  final String? flutterVersion;
  final BuildSessionStatus status;
  final int? exitCode;
  final List<String> artifactIds;

  BuildSession copyWith({
    DateTime? finishedAt,
    BuildSessionStatus? status,
    int? exitCode,
    List<String>? artifactIds,
  }) => BuildSession(
    id: id,
    projectPath: projectPath,
    taskId: taskId,
    label: label,
    commands: commands,
    target: target,
    mode: mode,
    flavors: flavors,
    startedAt: startedAt,
    finishedAt: finishedAt ?? this.finishedAt,
    flutterVersion: flutterVersion,
    status: status ?? this.status,
    exitCode: exitCode ?? this.exitCode,
    artifactIds: artifactIds ?? this.artifactIds,
  );

  factory BuildSession.fromMap(Map<String, dynamic> map) => BuildSession(
    id: map['id'] as String? ?? '',
    projectPath: map['projectPath'] as String? ?? '',
    taskId: map['taskId'] as String? ?? '',
    label: map['label'] as String? ?? '',
    commands: (map['commands'] as List<dynamic>? ?? const []).cast<String>(),
    target: map['target'] as String? ?? '',
    mode: map['mode'] as String? ?? '',
    flavors: (map['flavors'] as List<dynamic>? ?? const []).cast<String>(),
    startedAt:
        DateTime.tryParse(map['startedAt'] as String? ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0),
    finishedAt: DateTime.tryParse(map['finishedAt'] as String? ?? ''),
    flutterVersion: map['flutterVersion'] as String?,
    status: BuildSessionStatus.values.firstWhere(
      (status) => status.name == map['status'],
      orElse: () => BuildSessionStatus.failed,
    ),
    exitCode: map['exitCode'] as int?,
    artifactIds: (map['artifactIds'] as List<dynamic>? ?? const [])
        .cast<String>(),
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'projectPath': projectPath,
    'taskId': taskId,
    'label': label,
    'commands': commands,
    'target': target,
    'mode': mode,
    'flavors': flavors,
    'startedAt': startedAt.toIso8601String(),
    'finishedAt': finishedAt?.toIso8601String(),
    'flutterVersion': flutterVersion,
    'status': status.name,
    'exitCode': exitCode,
    'artifactIds': artifactIds,
  };
}

class BuildArtifactRecord {
  const BuildArtifactRecord({
    required this.id,
    required this.buildSessionId,
    required this.projectPath,
    required this.path,
    required this.name,
    required this.type,
    required this.platform,
    required this.size,
    required this.modified,
    required this.source,
    this.exists = true,
    this.fingerprint,
  });

  final String id;
  final String buildSessionId;
  final String projectPath;
  final String path;
  final String name;
  final String type;
  final String platform;
  final int size;
  final DateTime modified;
  final bool exists;
  final String source;
  final String? fingerprint;

  factory BuildArtifactRecord.fromMap(Map<String, dynamic> map) =>
      BuildArtifactRecord(
        id: map['id'] as String? ?? '',
        buildSessionId: map['buildSessionId'] as String? ?? '',
        projectPath: map['projectPath'] as String? ?? '',
        path: map['path'] as String? ?? '',
        name: map['name'] as String? ?? '',
        type: map['type'] as String? ?? '',
        platform: map['platform'] as String? ?? '',
        size: map['size'] as int? ?? 0,
        modified:
            DateTime.tryParse(map['modified'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
        exists: map['exists'] as bool? ?? true,
        source: map['source'] as String? ?? 'build',
        fingerprint: map['fingerprint'] as String?,
      );

  Map<String, dynamic> toMap() => {
    'id': id,
    'buildSessionId': buildSessionId,
    'projectPath': projectPath,
    'path': path,
    'name': name,
    'type': type,
    'platform': platform,
    'size': size,
    'modified': modified.toIso8601String(),
    'exists': exists,
    'source': source,
    'fingerprint': fingerprint,
  };
}

class BuildHistorySnapshot {
  const BuildHistorySnapshot({
    this.sessions = const [],
    this.artifacts = const [],
  });

  final List<BuildSession> sessions;
  final List<BuildArtifactRecord> artifacts;

  List<BuildSession> sessionsForProject(String projectPath) => sessions
      .where((session) => session.projectPath == projectPath)
      .toList(growable: false);

  List<BuildArtifactRecord> artifactsForSession(String sessionId) => artifacts
      .where((artifact) => artifact.buildSessionId == sessionId)
      .toList(growable: false);
}
