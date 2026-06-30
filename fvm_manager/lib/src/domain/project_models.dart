import 'package:freezed_annotation/freezed_annotation.dart';

part 'project_models.freezed.dart';

enum ProjectBuildMode { debug, profile, release }

enum ProjectBuildTarget { apk, appbundle, ios, macos, windows }

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
    @Default(<String>[]) List<String> selectedFlavors,
    @Default(ProjectBuildMode.release) ProjectBuildMode lastBuildMode,
    @Default(ProjectBuildTarget.apk) ProjectBuildTarget lastBuildTarget,
    @Default(false) bool cleanBeforeBuild,
    @Default('android-arm64') String androidTargetPlatform,
    @Default(false) bool useCustomCommands,
    @Default('') String customCommandCode,
  }) = _FlutterProject;

  factory FlutterProject.fromMap(Map<String, dynamic> map) => FlutterProject(
    name: map['name'] as String? ?? 'Flutter Project',
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
  );

  Map<String, dynamic> toMap() => {
    'name': name,
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
    'selectedFlavors': selectedFlavors,
    'lastBuildMode': lastBuildMode.name,
    'lastBuildTarget': lastBuildTarget.name,
    'cleanBeforeBuild': cleanBeforeBuild,
    'androidTargetPlatform': androidTargetPlatform,
    'useCustomCommands': useCustomCommands,
    'customCommandCode': customCommandCode,
  };
}
