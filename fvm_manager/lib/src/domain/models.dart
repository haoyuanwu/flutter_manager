import 'package:freezed_annotation/freezed_annotation.dart';

import 'project_models.dart';

part 'models.freezed.dart';

enum ReleaseChannel { stable, beta, dev }

@freezed
abstract class FlutterRelease with _$FlutterRelease {
  const FlutterRelease._();

  const factory FlutterRelease({
    required String version,
    required ReleaseChannel channel,
    required String archiveUrl,
    required String sha256,
    required DateTime releaseDate,
    String? dartVersion,
  }) = _FlutterRelease;

  factory FlutterRelease.fromMap(Map<String, dynamic> map, String baseUrl) {
    final channelName = map['channel'] as String? ?? 'stable';
    return FlutterRelease(
      version: map['version'] as String,
      channel: ReleaseChannel.values.firstWhere(
        (value) => value.name == channelName,
        orElse: () => ReleaseChannel.stable,
      ),
      archiveUrl: '$baseUrl/${map['archive']}',
      sha256: map['sha256'] as String? ?? '',
      releaseDate:
          DateTime.tryParse(map['release_date'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      dartVersion: map['dart_sdk_version'] as String?,
    );
  }
}

@freezed
abstract class InstalledSdk with _$InstalledSdk {
  const factory InstalledSdk({
    required String name,
    required String flutterVersion,
    required String dartVersion,
    required String directory,
    @Default(false) bool isSetup,
  }) = _InstalledSdk;

  factory InstalledSdk.fromMap(Map<String, dynamic> map) => InstalledSdk(
    name: map['name'] as String? ?? '',
    flutterVersion: map['flutterSdkVersion'] as String? ?? '',
    dartVersion: map['dartSdkVersion'] as String? ?? '',
    directory: map['directory'] as String? ?? '',
    isSetup: map['isSetup'] as bool? ?? false,
  );
}

@freezed
abstract class FvmState with _$FvmState {
  const factory FvmState({
    @Default(false) bool loading,
    @Default(false) bool fvmInstalled,
    String? fvmVersion,
    String? globalVersion,
    @Default(<InstalledSdk>[]) List<InstalledSdk> installed,
    @Default(<FlutterRelease>[]) List<FlutterRelease> releases,
    @Default(ReleaseChannel.stable) ReleaseChannel selectedChannel,
    @Default(30) int releaseDisplayLimit,
    String? activeVersion,
    String? removingVersion,
    @Default(0) double downloadProgress,
    @Default(0) int downloadReceivedBytes,
    @Default(0) int downloadTotalBytes,
    @Default(0) double downloadBytesPerSecond,
    @Default('准备下载') String downloadPhase,
    String? projectPath,
    String? projectVersion,
    String? projectTargetVersion,
    String? latestFvmVersion,
    String? latestFlutterVersion,
    @Default(false) bool hasFvmUpdate,
    @Default(false) bool hasFlutterUpdate,
    String? updateNotice,
    @Default(false) bool useDomesticMirror,
    @Default('official') String mirrorId,
    @Default(<String, int>{}) Map<String, int> mirrorTestResults,
    @Default(<FlutterProject>[]) List<FlutterProject> managedProjects,
    String? selectedManagedProjectPath,
    @Default(<String>[]) List<String> selectedAndroidFlavors,
    @Default(ProjectBuildMode.release) ProjectBuildMode projectBuildMode,
    @Default(ProjectBuildTarget.apk) ProjectBuildTarget projectBuildTarget,
    @Default(false) bool cleanBeforeBuild,
    @Default('android-arm64') String androidTargetPlatform,
    @Default(<Map<String, String>>[]) List<Map<String, String>> devices,
    String? selectedDeviceId,
    @Default(false) bool devicesLoading,
    @Default(false) bool commandRunning,
    @Default('') String commandLog,
    String? activeCommand,
    String? statusMessage,
    String? errorMessage,
    Map<String, String>? vmServiceUris,
    @Default(true) bool autoOpenConsoleWindow,
    @Default(false) bool showMainWindowConsole,
    @Default(true) bool showConsoleQuickCommands,
    @Default(false) bool buildOpensConsoleWindow,
    @Default(false) bool buildConsoleVisible,
  }) = _FvmState;
}
