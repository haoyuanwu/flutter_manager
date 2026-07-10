import 'package:freezed_annotation/freezed_annotation.dart';

part 'project_models.freezed.dart';

enum ProjectBuildMode { debug, profile, release }

enum ProjectBuildTarget { apk, appbundle, ios, macos, windows }

enum PgyerInstallType { public, password, invite }

@freezed
abstract class FirConfig with _$FirConfig {
  const FirConfig._();

  const factory FirConfig({
    @Default('') String apiToken,
    @Default('') String appName,
    @Default('') String bundleId,
    @Default('') String changelog,
    @Default('') String shortCode,
  }) = _FirConfig;

  factory FirConfig.fromMap(Map<String, dynamic>? map) => FirConfig(
    apiToken: map?['apiToken'] as String? ?? '',
    appName: map?['appName'] as String? ?? '',
    bundleId: map?['bundleId'] as String? ?? '',
    changelog: map?['changelog'] as String? ?? '',
    shortCode: map?['shortCode'] as String? ?? '',
  );

  Map<String, dynamic> toMap() => {
    'apiToken': apiToken,
    'appName': appName,
    'bundleId': bundleId,
    'changelog': changelog,
    'shortCode': shortCode,
  };
}

@freezed
abstract class PgyerConfig with _$PgyerConfig {
  const PgyerConfig._();

  const factory PgyerConfig({
    @Default('') String apiKey,
    @Default(PgyerInstallType.public) PgyerInstallType installType,
    @Default('') String installPassword,
    @Default('') String updateDescription,
    @Default('') String buildShortcutUrl,
  }) = _PgyerConfig;

  factory PgyerConfig.fromMap(Map<String, dynamic>? map) => PgyerConfig(
    apiKey: map?['apiKey'] as String? ?? '',
    installType: PgyerInstallType.values.firstWhere(
      (value) => value.name == map?['installType'],
      orElse: () => PgyerInstallType.public,
    ),
    installPassword: map?['installPassword'] as String? ?? '',
    updateDescription: map?['updateDescription'] as String? ?? '',
    buildShortcutUrl: map?['buildShortcutUrl'] as String? ?? '',
  );

  Map<String, dynamic> toMap() => {
    'apiKey': apiKey,
    'installType': installType.name,
    'installPassword': installPassword,
    'updateDescription': updateDescription,
    'buildShortcutUrl': buildShortcutUrl,
  };
}

@freezed
abstract class BuglyUploadConfig with _$BuglyUploadConfig {
  const BuglyUploadConfig._();

  const factory BuglyUploadConfig({
    @Default(false) bool enabled,
    @Default('') String jarPath,
    @Default('') String appId,
    @Default('') String appKey,
    @Default('') String bundleId,
    @Default('') String version,
    @Default('') String buildNo,
  }) = _BuglyUploadConfig;

  factory BuglyUploadConfig.fromMap(Map<String, dynamic>? map) =>
      BuglyUploadConfig(
        enabled: map?['enabled'] as bool? ?? false,
        jarPath: map?['jarPath'] as String? ?? '',
        appId: map?['appId'] as String? ?? '',
        appKey: map?['appKey'] as String? ?? '',
        bundleId: map?['bundleId'] as String? ?? '',
        version: map?['version'] as String? ?? '',
        buildNo: map?['buildNo'] as String? ?? '',
      );

  Map<String, dynamic> toMap() => {
    'enabled': enabled,
    'jarPath': jarPath,
    'appId': appId,
    'appKey': appKey,
    'bundleId': bundleId,
    'version': version,
    'buildNo': buildNo,
  };
}

@freezed
abstract class FlutterProject with _$FlutterProject {
  const FlutterProject._();

  const factory FlutterProject({
    required String name,
    @Default('') String alias,
    required String path,
    required DateTime lastOpened,
    String? description,
    String? fvmVersion,
    @Default(false) bool hasAndroid,
    @Default(false) bool hasIos,
    @Default(false) bool hasWindows,
    @Default(false) bool hasMacos,
    @Default(true) bool pathExists,
    @Default(<String>[]) List<String> androidFlavors,
    @Default(<String>[]) List<String> androidBuildTypes,
    @Default(BuglyUploadConfig()) BuglyUploadConfig bugly,
    @Default(PgyerConfig()) PgyerConfig pgyer,
    @Default(FirConfig()) FirConfig fir,
    @Default(<String>[]) List<String> selectedFlavors,
    @Default(ProjectBuildMode.release) ProjectBuildMode lastBuildMode,
    @Default(ProjectBuildTarget.apk) ProjectBuildTarget lastBuildTarget,
    @Default(false) bool cleanBeforeBuild,
    @Default('android-arm64') String androidTargetPlatform,
    @Default(false) bool useCustomCommands,
    @Default('') String customCommandCode,
    @Default(<String>[]) List<String> tags,
    @Default(0) int sortOrder,
  }) = _FlutterProject;

  String get displayName => alias.trim().isEmpty ? name : alias.trim();

  factory FlutterProject.fromMap(Map<String, dynamic> map) => FlutterProject(
    name: map['name'] as String? ?? 'Flutter Project',
    alias: map['alias'] as String? ?? '',
    path: map['path'] as String,
    lastOpened:
        DateTime.tryParse(map['lastOpened'] as String? ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0),
    description: map['description'] as String?,
    fvmVersion: map['fvmVersion'] as String?,
    hasAndroid: map['hasAndroid'] as bool? ?? false,
    hasIos: map['hasIos'] as bool? ?? false,
    hasWindows: map['hasWindows'] as bool? ?? false,
    hasMacos: map['hasMacos'] as bool? ?? false,
    pathExists: map['pathExists'] as bool? ?? true,
    androidFlavors: (map['androidFlavors'] as List<dynamic>? ?? const [])
        .cast<String>(),
    androidBuildTypes: (map['androidBuildTypes'] as List<dynamic>? ?? const [])
        .cast<String>(),
    bugly: BuglyUploadConfig.fromMap(
      (map['bugly'] as Map?)?.cast<String, dynamic>(),
    ),
    pgyer: PgyerConfig.fromMap((map['pgyer'] as Map?)?.cast<String, dynamic>()),
    fir: FirConfig.fromMap((map['fir'] as Map?)?.cast<String, dynamic>()),
    selectedFlavors: (map['selectedFlavors'] as List<dynamic>? ?? const [])
        .cast<String>(),
    lastBuildMode: ProjectBuildMode.values.firstWhere(
      (value) => value.name == map['lastBuildMode'],
      orElse: () => ProjectBuildMode.release,
    ),
    lastBuildTarget: ProjectBuildTarget.values.firstWhere(
      (value) => value.name == map['lastBuildTarget'],
      orElse: () => ProjectBuildTarget.apk,
    ),
    cleanBeforeBuild: map['cleanBeforeBuild'] as bool? ?? false,
    androidTargetPlatform:
        map['androidTargetPlatform'] as String? ?? 'android-arm64',
    useCustomCommands: map['useCustomCommands'] as bool? ?? false,
    customCommandCode: map['customCommandCode'] as String? ?? '',
    tags: (map['tags'] as List<dynamic>? ?? const []).cast<String>(),
    sortOrder: map['sortOrder'] as int? ?? 0,
  );

  Map<String, dynamic> toMap() => {
    'name': name,
    'alias': alias,
    'path': path,
    'lastOpened': lastOpened.toIso8601String(),
    'description': description,
    'fvmVersion': fvmVersion,
    'hasAndroid': hasAndroid,
    'hasIos': hasIos,
    'hasWindows': hasWindows,
    'hasMacos': hasMacos,
    'pathExists': pathExists,
    'androidFlavors': androidFlavors,
    'androidBuildTypes': androidBuildTypes,
    'bugly': bugly.toMap(),
    'pgyer': pgyer.toMap(),
    'fir': fir.toMap(),
    'selectedFlavors': selectedFlavors,
    'lastBuildMode': lastBuildMode.name,
    'lastBuildTarget': lastBuildTarget.name,
    'cleanBeforeBuild': cleanBeforeBuild,
    'androidTargetPlatform': androidTargetPlatform,
    'useCustomCommands': useCustomCommands,
    'customCommandCode': customCommandCode,
    'tags': tags,
    'sortOrder': sortOrder,
  };
}
