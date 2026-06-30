// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'models.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$FlutterRelease {

 String get version; ReleaseChannel get channel; String get archiveUrl; String get sha256; DateTime get releaseDate; String? get dartVersion;
/// Create a copy of FlutterRelease
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FlutterReleaseCopyWith<FlutterRelease> get copyWith => _$FlutterReleaseCopyWithImpl<FlutterRelease>(this as FlutterRelease, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FlutterRelease&&(identical(other.version, version) || other.version == version)&&(identical(other.channel, channel) || other.channel == channel)&&(identical(other.archiveUrl, archiveUrl) || other.archiveUrl == archiveUrl)&&(identical(other.sha256, sha256) || other.sha256 == sha256)&&(identical(other.releaseDate, releaseDate) || other.releaseDate == releaseDate)&&(identical(other.dartVersion, dartVersion) || other.dartVersion == dartVersion));
}


@override
int get hashCode => Object.hash(runtimeType,version,channel,archiveUrl,sha256,releaseDate,dartVersion);

@override
String toString() {
  return 'FlutterRelease(version: $version, channel: $channel, archiveUrl: $archiveUrl, sha256: $sha256, releaseDate: $releaseDate, dartVersion: $dartVersion)';
}


}

/// @nodoc
abstract mixin class $FlutterReleaseCopyWith<$Res>  {
  factory $FlutterReleaseCopyWith(FlutterRelease value, $Res Function(FlutterRelease) _then) = _$FlutterReleaseCopyWithImpl;
@useResult
$Res call({
 String version, ReleaseChannel channel, String archiveUrl, String sha256, DateTime releaseDate, String? dartVersion
});




}
/// @nodoc
class _$FlutterReleaseCopyWithImpl<$Res>
    implements $FlutterReleaseCopyWith<$Res> {
  _$FlutterReleaseCopyWithImpl(this._self, this._then);

  final FlutterRelease _self;
  final $Res Function(FlutterRelease) _then;

/// Create a copy of FlutterRelease
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? version = null,Object? channel = null,Object? archiveUrl = null,Object? sha256 = null,Object? releaseDate = null,Object? dartVersion = freezed,}) {
  return _then(_self.copyWith(
version: null == version ? _self.version : version // ignore: cast_nullable_to_non_nullable
as String,channel: null == channel ? _self.channel : channel // ignore: cast_nullable_to_non_nullable
as ReleaseChannel,archiveUrl: null == archiveUrl ? _self.archiveUrl : archiveUrl // ignore: cast_nullable_to_non_nullable
as String,sha256: null == sha256 ? _self.sha256 : sha256 // ignore: cast_nullable_to_non_nullable
as String,releaseDate: null == releaseDate ? _self.releaseDate : releaseDate // ignore: cast_nullable_to_non_nullable
as DateTime,dartVersion: freezed == dartVersion ? _self.dartVersion : dartVersion // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [FlutterRelease].
extension FlutterReleasePatterns on FlutterRelease {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _FlutterRelease value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _FlutterRelease() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _FlutterRelease value)  $default,){
final _that = this;
switch (_that) {
case _FlutterRelease():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _FlutterRelease value)?  $default,){
final _that = this;
switch (_that) {
case _FlutterRelease() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String version,  ReleaseChannel channel,  String archiveUrl,  String sha256,  DateTime releaseDate,  String? dartVersion)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _FlutterRelease() when $default != null:
return $default(_that.version,_that.channel,_that.archiveUrl,_that.sha256,_that.releaseDate,_that.dartVersion);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String version,  ReleaseChannel channel,  String archiveUrl,  String sha256,  DateTime releaseDate,  String? dartVersion)  $default,) {final _that = this;
switch (_that) {
case _FlutterRelease():
return $default(_that.version,_that.channel,_that.archiveUrl,_that.sha256,_that.releaseDate,_that.dartVersion);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String version,  ReleaseChannel channel,  String archiveUrl,  String sha256,  DateTime releaseDate,  String? dartVersion)?  $default,) {final _that = this;
switch (_that) {
case _FlutterRelease() when $default != null:
return $default(_that.version,_that.channel,_that.archiveUrl,_that.sha256,_that.releaseDate,_that.dartVersion);case _:
  return null;

}
}

}

/// @nodoc


class _FlutterRelease extends FlutterRelease {
  const _FlutterRelease({required this.version, required this.channel, required this.archiveUrl, required this.sha256, required this.releaseDate, this.dartVersion}): super._();
  

@override final  String version;
@override final  ReleaseChannel channel;
@override final  String archiveUrl;
@override final  String sha256;
@override final  DateTime releaseDate;
@override final  String? dartVersion;

/// Create a copy of FlutterRelease
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$FlutterReleaseCopyWith<_FlutterRelease> get copyWith => __$FlutterReleaseCopyWithImpl<_FlutterRelease>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _FlutterRelease&&(identical(other.version, version) || other.version == version)&&(identical(other.channel, channel) || other.channel == channel)&&(identical(other.archiveUrl, archiveUrl) || other.archiveUrl == archiveUrl)&&(identical(other.sha256, sha256) || other.sha256 == sha256)&&(identical(other.releaseDate, releaseDate) || other.releaseDate == releaseDate)&&(identical(other.dartVersion, dartVersion) || other.dartVersion == dartVersion));
}


@override
int get hashCode => Object.hash(runtimeType,version,channel,archiveUrl,sha256,releaseDate,dartVersion);

@override
String toString() {
  return 'FlutterRelease(version: $version, channel: $channel, archiveUrl: $archiveUrl, sha256: $sha256, releaseDate: $releaseDate, dartVersion: $dartVersion)';
}


}

/// @nodoc
abstract mixin class _$FlutterReleaseCopyWith<$Res> implements $FlutterReleaseCopyWith<$Res> {
  factory _$FlutterReleaseCopyWith(_FlutterRelease value, $Res Function(_FlutterRelease) _then) = __$FlutterReleaseCopyWithImpl;
@override @useResult
$Res call({
 String version, ReleaseChannel channel, String archiveUrl, String sha256, DateTime releaseDate, String? dartVersion
});




}
/// @nodoc
class __$FlutterReleaseCopyWithImpl<$Res>
    implements _$FlutterReleaseCopyWith<$Res> {
  __$FlutterReleaseCopyWithImpl(this._self, this._then);

  final _FlutterRelease _self;
  final $Res Function(_FlutterRelease) _then;

/// Create a copy of FlutterRelease
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? version = null,Object? channel = null,Object? archiveUrl = null,Object? sha256 = null,Object? releaseDate = null,Object? dartVersion = freezed,}) {
  return _then(_FlutterRelease(
version: null == version ? _self.version : version // ignore: cast_nullable_to_non_nullable
as String,channel: null == channel ? _self.channel : channel // ignore: cast_nullable_to_non_nullable
as ReleaseChannel,archiveUrl: null == archiveUrl ? _self.archiveUrl : archiveUrl // ignore: cast_nullable_to_non_nullable
as String,sha256: null == sha256 ? _self.sha256 : sha256 // ignore: cast_nullable_to_non_nullable
as String,releaseDate: null == releaseDate ? _self.releaseDate : releaseDate // ignore: cast_nullable_to_non_nullable
as DateTime,dartVersion: freezed == dartVersion ? _self.dartVersion : dartVersion // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

/// @nodoc
mixin _$InstalledSdk {

 String get name; String get flutterVersion; String get dartVersion; String get directory; bool get isSetup;
/// Create a copy of InstalledSdk
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$InstalledSdkCopyWith<InstalledSdk> get copyWith => _$InstalledSdkCopyWithImpl<InstalledSdk>(this as InstalledSdk, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is InstalledSdk&&(identical(other.name, name) || other.name == name)&&(identical(other.flutterVersion, flutterVersion) || other.flutterVersion == flutterVersion)&&(identical(other.dartVersion, dartVersion) || other.dartVersion == dartVersion)&&(identical(other.directory, directory) || other.directory == directory)&&(identical(other.isSetup, isSetup) || other.isSetup == isSetup));
}


@override
int get hashCode => Object.hash(runtimeType,name,flutterVersion,dartVersion,directory,isSetup);

@override
String toString() {
  return 'InstalledSdk(name: $name, flutterVersion: $flutterVersion, dartVersion: $dartVersion, directory: $directory, isSetup: $isSetup)';
}


}

/// @nodoc
abstract mixin class $InstalledSdkCopyWith<$Res>  {
  factory $InstalledSdkCopyWith(InstalledSdk value, $Res Function(InstalledSdk) _then) = _$InstalledSdkCopyWithImpl;
@useResult
$Res call({
 String name, String flutterVersion, String dartVersion, String directory, bool isSetup
});




}
/// @nodoc
class _$InstalledSdkCopyWithImpl<$Res>
    implements $InstalledSdkCopyWith<$Res> {
  _$InstalledSdkCopyWithImpl(this._self, this._then);

  final InstalledSdk _self;
  final $Res Function(InstalledSdk) _then;

/// Create a copy of InstalledSdk
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? name = null,Object? flutterVersion = null,Object? dartVersion = null,Object? directory = null,Object? isSetup = null,}) {
  return _then(_self.copyWith(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,flutterVersion: null == flutterVersion ? _self.flutterVersion : flutterVersion // ignore: cast_nullable_to_non_nullable
as String,dartVersion: null == dartVersion ? _self.dartVersion : dartVersion // ignore: cast_nullable_to_non_nullable
as String,directory: null == directory ? _self.directory : directory // ignore: cast_nullable_to_non_nullable
as String,isSetup: null == isSetup ? _self.isSetup : isSetup // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [InstalledSdk].
extension InstalledSdkPatterns on InstalledSdk {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _InstalledSdk value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _InstalledSdk() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _InstalledSdk value)  $default,){
final _that = this;
switch (_that) {
case _InstalledSdk():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _InstalledSdk value)?  $default,){
final _that = this;
switch (_that) {
case _InstalledSdk() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String name,  String flutterVersion,  String dartVersion,  String directory,  bool isSetup)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _InstalledSdk() when $default != null:
return $default(_that.name,_that.flutterVersion,_that.dartVersion,_that.directory,_that.isSetup);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String name,  String flutterVersion,  String dartVersion,  String directory,  bool isSetup)  $default,) {final _that = this;
switch (_that) {
case _InstalledSdk():
return $default(_that.name,_that.flutterVersion,_that.dartVersion,_that.directory,_that.isSetup);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String name,  String flutterVersion,  String dartVersion,  String directory,  bool isSetup)?  $default,) {final _that = this;
switch (_that) {
case _InstalledSdk() when $default != null:
return $default(_that.name,_that.flutterVersion,_that.dartVersion,_that.directory,_that.isSetup);case _:
  return null;

}
}

}

/// @nodoc


class _InstalledSdk implements InstalledSdk {
  const _InstalledSdk({required this.name, required this.flutterVersion, required this.dartVersion, required this.directory, this.isSetup = false});
  

@override final  String name;
@override final  String flutterVersion;
@override final  String dartVersion;
@override final  String directory;
@override@JsonKey() final  bool isSetup;

/// Create a copy of InstalledSdk
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$InstalledSdkCopyWith<_InstalledSdk> get copyWith => __$InstalledSdkCopyWithImpl<_InstalledSdk>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _InstalledSdk&&(identical(other.name, name) || other.name == name)&&(identical(other.flutterVersion, flutterVersion) || other.flutterVersion == flutterVersion)&&(identical(other.dartVersion, dartVersion) || other.dartVersion == dartVersion)&&(identical(other.directory, directory) || other.directory == directory)&&(identical(other.isSetup, isSetup) || other.isSetup == isSetup));
}


@override
int get hashCode => Object.hash(runtimeType,name,flutterVersion,dartVersion,directory,isSetup);

@override
String toString() {
  return 'InstalledSdk(name: $name, flutterVersion: $flutterVersion, dartVersion: $dartVersion, directory: $directory, isSetup: $isSetup)';
}


}

/// @nodoc
abstract mixin class _$InstalledSdkCopyWith<$Res> implements $InstalledSdkCopyWith<$Res> {
  factory _$InstalledSdkCopyWith(_InstalledSdk value, $Res Function(_InstalledSdk) _then) = __$InstalledSdkCopyWithImpl;
@override @useResult
$Res call({
 String name, String flutterVersion, String dartVersion, String directory, bool isSetup
});




}
/// @nodoc
class __$InstalledSdkCopyWithImpl<$Res>
    implements _$InstalledSdkCopyWith<$Res> {
  __$InstalledSdkCopyWithImpl(this._self, this._then);

  final _InstalledSdk _self;
  final $Res Function(_InstalledSdk) _then;

/// Create a copy of InstalledSdk
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? name = null,Object? flutterVersion = null,Object? dartVersion = null,Object? directory = null,Object? isSetup = null,}) {
  return _then(_InstalledSdk(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,flutterVersion: null == flutterVersion ? _self.flutterVersion : flutterVersion // ignore: cast_nullable_to_non_nullable
as String,dartVersion: null == dartVersion ? _self.dartVersion : dartVersion // ignore: cast_nullable_to_non_nullable
as String,directory: null == directory ? _self.directory : directory // ignore: cast_nullable_to_non_nullable
as String,isSetup: null == isSetup ? _self.isSetup : isSetup // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

/// @nodoc
mixin _$FvmState {

 bool get loading; bool get fvmInstalled; String? get fvmVersion; String? get globalVersion; List<InstalledSdk> get installed; List<FlutterRelease> get releases; ReleaseChannel get selectedChannel; int get releaseDisplayLimit; String? get activeVersion; String? get removingVersion; double get downloadProgress; int get downloadReceivedBytes; int get downloadTotalBytes; double get downloadBytesPerSecond; String get downloadPhase; String? get projectPath; String? get projectVersion; String? get projectTargetVersion; String? get latestFvmVersion; String? get latestFlutterVersion; bool get hasFvmUpdate; bool get hasFlutterUpdate; String? get updateNotice; bool get useDomesticMirror; String get mirrorId; Map<String, int> get mirrorTestResults; List<FlutterProject> get managedProjects; String? get selectedManagedProjectPath; List<String> get selectedAndroidFlavors; ProjectBuildMode get projectBuildMode; ProjectBuildTarget get projectBuildTarget; bool get cleanBeforeBuild; String get androidTargetPlatform; List<Map<String, String>> get devices; String? get selectedDeviceId; bool get devicesLoading; bool get commandRunning; String get commandLog; String? get activeCommand; String? get statusMessage; String? get errorMessage;
/// Create a copy of FvmState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FvmStateCopyWith<FvmState> get copyWith => _$FvmStateCopyWithImpl<FvmState>(this as FvmState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FvmState&&(identical(other.loading, loading) || other.loading == loading)&&(identical(other.fvmInstalled, fvmInstalled) || other.fvmInstalled == fvmInstalled)&&(identical(other.fvmVersion, fvmVersion) || other.fvmVersion == fvmVersion)&&(identical(other.globalVersion, globalVersion) || other.globalVersion == globalVersion)&&const DeepCollectionEquality().equals(other.installed, installed)&&const DeepCollectionEquality().equals(other.releases, releases)&&(identical(other.selectedChannel, selectedChannel) || other.selectedChannel == selectedChannel)&&(identical(other.releaseDisplayLimit, releaseDisplayLimit) || other.releaseDisplayLimit == releaseDisplayLimit)&&(identical(other.activeVersion, activeVersion) || other.activeVersion == activeVersion)&&(identical(other.removingVersion, removingVersion) || other.removingVersion == removingVersion)&&(identical(other.downloadProgress, downloadProgress) || other.downloadProgress == downloadProgress)&&(identical(other.downloadReceivedBytes, downloadReceivedBytes) || other.downloadReceivedBytes == downloadReceivedBytes)&&(identical(other.downloadTotalBytes, downloadTotalBytes) || other.downloadTotalBytes == downloadTotalBytes)&&(identical(other.downloadBytesPerSecond, downloadBytesPerSecond) || other.downloadBytesPerSecond == downloadBytesPerSecond)&&(identical(other.downloadPhase, downloadPhase) || other.downloadPhase == downloadPhase)&&(identical(other.projectPath, projectPath) || other.projectPath == projectPath)&&(identical(other.projectVersion, projectVersion) || other.projectVersion == projectVersion)&&(identical(other.projectTargetVersion, projectTargetVersion) || other.projectTargetVersion == projectTargetVersion)&&(identical(other.latestFvmVersion, latestFvmVersion) || other.latestFvmVersion == latestFvmVersion)&&(identical(other.latestFlutterVersion, latestFlutterVersion) || other.latestFlutterVersion == latestFlutterVersion)&&(identical(other.hasFvmUpdate, hasFvmUpdate) || other.hasFvmUpdate == hasFvmUpdate)&&(identical(other.hasFlutterUpdate, hasFlutterUpdate) || other.hasFlutterUpdate == hasFlutterUpdate)&&(identical(other.updateNotice, updateNotice) || other.updateNotice == updateNotice)&&(identical(other.useDomesticMirror, useDomesticMirror) || other.useDomesticMirror == useDomesticMirror)&&(identical(other.mirrorId, mirrorId) || other.mirrorId == mirrorId)&&const DeepCollectionEquality().equals(other.mirrorTestResults, mirrorTestResults)&&const DeepCollectionEquality().equals(other.managedProjects, managedProjects)&&(identical(other.selectedManagedProjectPath, selectedManagedProjectPath) || other.selectedManagedProjectPath == selectedManagedProjectPath)&&const DeepCollectionEquality().equals(other.selectedAndroidFlavors, selectedAndroidFlavors)&&(identical(other.projectBuildMode, projectBuildMode) || other.projectBuildMode == projectBuildMode)&&(identical(other.projectBuildTarget, projectBuildTarget) || other.projectBuildTarget == projectBuildTarget)&&(identical(other.cleanBeforeBuild, cleanBeforeBuild) || other.cleanBeforeBuild == cleanBeforeBuild)&&(identical(other.androidTargetPlatform, androidTargetPlatform) || other.androidTargetPlatform == androidTargetPlatform)&&const DeepCollectionEquality().equals(other.devices, devices)&&(identical(other.selectedDeviceId, selectedDeviceId) || other.selectedDeviceId == selectedDeviceId)&&(identical(other.devicesLoading, devicesLoading) || other.devicesLoading == devicesLoading)&&(identical(other.commandRunning, commandRunning) || other.commandRunning == commandRunning)&&(identical(other.commandLog, commandLog) || other.commandLog == commandLog)&&(identical(other.activeCommand, activeCommand) || other.activeCommand == activeCommand)&&(identical(other.statusMessage, statusMessage) || other.statusMessage == statusMessage)&&(identical(other.errorMessage, errorMessage) || other.errorMessage == errorMessage));
}


@override
int get hashCode => Object.hashAll([runtimeType,loading,fvmInstalled,fvmVersion,globalVersion,const DeepCollectionEquality().hash(installed),const DeepCollectionEquality().hash(releases),selectedChannel,releaseDisplayLimit,activeVersion,removingVersion,downloadProgress,downloadReceivedBytes,downloadTotalBytes,downloadBytesPerSecond,downloadPhase,projectPath,projectVersion,projectTargetVersion,latestFvmVersion,latestFlutterVersion,hasFvmUpdate,hasFlutterUpdate,updateNotice,useDomesticMirror,mirrorId,const DeepCollectionEquality().hash(mirrorTestResults),const DeepCollectionEquality().hash(managedProjects),selectedManagedProjectPath,const DeepCollectionEquality().hash(selectedAndroidFlavors),projectBuildMode,projectBuildTarget,cleanBeforeBuild,androidTargetPlatform,const DeepCollectionEquality().hash(devices),selectedDeviceId,devicesLoading,commandRunning,commandLog,activeCommand,statusMessage,errorMessage]);

@override
String toString() {
  return 'FvmState(loading: $loading, fvmInstalled: $fvmInstalled, fvmVersion: $fvmVersion, globalVersion: $globalVersion, installed: $installed, releases: $releases, selectedChannel: $selectedChannel, releaseDisplayLimit: $releaseDisplayLimit, activeVersion: $activeVersion, removingVersion: $removingVersion, downloadProgress: $downloadProgress, downloadReceivedBytes: $downloadReceivedBytes, downloadTotalBytes: $downloadTotalBytes, downloadBytesPerSecond: $downloadBytesPerSecond, downloadPhase: $downloadPhase, projectPath: $projectPath, projectVersion: $projectVersion, projectTargetVersion: $projectTargetVersion, latestFvmVersion: $latestFvmVersion, latestFlutterVersion: $latestFlutterVersion, hasFvmUpdate: $hasFvmUpdate, hasFlutterUpdate: $hasFlutterUpdate, updateNotice: $updateNotice, useDomesticMirror: $useDomesticMirror, mirrorId: $mirrorId, mirrorTestResults: $mirrorTestResults, managedProjects: $managedProjects, selectedManagedProjectPath: $selectedManagedProjectPath, selectedAndroidFlavors: $selectedAndroidFlavors, projectBuildMode: $projectBuildMode, projectBuildTarget: $projectBuildTarget, cleanBeforeBuild: $cleanBeforeBuild, androidTargetPlatform: $androidTargetPlatform, devices: $devices, selectedDeviceId: $selectedDeviceId, devicesLoading: $devicesLoading, commandRunning: $commandRunning, commandLog: $commandLog, activeCommand: $activeCommand, statusMessage: $statusMessage, errorMessage: $errorMessage)';
}


}

/// @nodoc
abstract mixin class $FvmStateCopyWith<$Res>  {
  factory $FvmStateCopyWith(FvmState value, $Res Function(FvmState) _then) = _$FvmStateCopyWithImpl;
@useResult
$Res call({
 bool loading, bool fvmInstalled, String? fvmVersion, String? globalVersion, List<InstalledSdk> installed, List<FlutterRelease> releases, ReleaseChannel selectedChannel, int releaseDisplayLimit, String? activeVersion, String? removingVersion, double downloadProgress, int downloadReceivedBytes, int downloadTotalBytes, double downloadBytesPerSecond, String downloadPhase, String? projectPath, String? projectVersion, String? projectTargetVersion, String? latestFvmVersion, String? latestFlutterVersion, bool hasFvmUpdate, bool hasFlutterUpdate, String? updateNotice, bool useDomesticMirror, String mirrorId, Map<String, int> mirrorTestResults, List<FlutterProject> managedProjects, String? selectedManagedProjectPath, List<String> selectedAndroidFlavors, ProjectBuildMode projectBuildMode, ProjectBuildTarget projectBuildTarget, bool cleanBeforeBuild, String androidTargetPlatform, List<Map<String, String>> devices, String? selectedDeviceId, bool devicesLoading, bool commandRunning, String commandLog, String? activeCommand, String? statusMessage, String? errorMessage
});




}
/// @nodoc
class _$FvmStateCopyWithImpl<$Res>
    implements $FvmStateCopyWith<$Res> {
  _$FvmStateCopyWithImpl(this._self, this._then);

  final FvmState _self;
  final $Res Function(FvmState) _then;

/// Create a copy of FvmState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? loading = null,Object? fvmInstalled = null,Object? fvmVersion = freezed,Object? globalVersion = freezed,Object? installed = null,Object? releases = null,Object? selectedChannel = null,Object? releaseDisplayLimit = null,Object? activeVersion = freezed,Object? removingVersion = freezed,Object? downloadProgress = null,Object? downloadReceivedBytes = null,Object? downloadTotalBytes = null,Object? downloadBytesPerSecond = null,Object? downloadPhase = null,Object? projectPath = freezed,Object? projectVersion = freezed,Object? projectTargetVersion = freezed,Object? latestFvmVersion = freezed,Object? latestFlutterVersion = freezed,Object? hasFvmUpdate = null,Object? hasFlutterUpdate = null,Object? updateNotice = freezed,Object? useDomesticMirror = null,Object? mirrorId = null,Object? mirrorTestResults = null,Object? managedProjects = null,Object? selectedManagedProjectPath = freezed,Object? selectedAndroidFlavors = null,Object? projectBuildMode = null,Object? projectBuildTarget = null,Object? cleanBeforeBuild = null,Object? androidTargetPlatform = null,Object? devices = null,Object? selectedDeviceId = freezed,Object? devicesLoading = null,Object? commandRunning = null,Object? commandLog = null,Object? activeCommand = freezed,Object? statusMessage = freezed,Object? errorMessage = freezed,}) {
  return _then(_self.copyWith(
loading: null == loading ? _self.loading : loading // ignore: cast_nullable_to_non_nullable
as bool,fvmInstalled: null == fvmInstalled ? _self.fvmInstalled : fvmInstalled // ignore: cast_nullable_to_non_nullable
as bool,fvmVersion: freezed == fvmVersion ? _self.fvmVersion : fvmVersion // ignore: cast_nullable_to_non_nullable
as String?,globalVersion: freezed == globalVersion ? _self.globalVersion : globalVersion // ignore: cast_nullable_to_non_nullable
as String?,installed: null == installed ? _self.installed : installed // ignore: cast_nullable_to_non_nullable
as List<InstalledSdk>,releases: null == releases ? _self.releases : releases // ignore: cast_nullable_to_non_nullable
as List<FlutterRelease>,selectedChannel: null == selectedChannel ? _self.selectedChannel : selectedChannel // ignore: cast_nullable_to_non_nullable
as ReleaseChannel,releaseDisplayLimit: null == releaseDisplayLimit ? _self.releaseDisplayLimit : releaseDisplayLimit // ignore: cast_nullable_to_non_nullable
as int,activeVersion: freezed == activeVersion ? _self.activeVersion : activeVersion // ignore: cast_nullable_to_non_nullable
as String?,removingVersion: freezed == removingVersion ? _self.removingVersion : removingVersion // ignore: cast_nullable_to_non_nullable
as String?,downloadProgress: null == downloadProgress ? _self.downloadProgress : downloadProgress // ignore: cast_nullable_to_non_nullable
as double,downloadReceivedBytes: null == downloadReceivedBytes ? _self.downloadReceivedBytes : downloadReceivedBytes // ignore: cast_nullable_to_non_nullable
as int,downloadTotalBytes: null == downloadTotalBytes ? _self.downloadTotalBytes : downloadTotalBytes // ignore: cast_nullable_to_non_nullable
as int,downloadBytesPerSecond: null == downloadBytesPerSecond ? _self.downloadBytesPerSecond : downloadBytesPerSecond // ignore: cast_nullable_to_non_nullable
as double,downloadPhase: null == downloadPhase ? _self.downloadPhase : downloadPhase // ignore: cast_nullable_to_non_nullable
as String,projectPath: freezed == projectPath ? _self.projectPath : projectPath // ignore: cast_nullable_to_non_nullable
as String?,projectVersion: freezed == projectVersion ? _self.projectVersion : projectVersion // ignore: cast_nullable_to_non_nullable
as String?,projectTargetVersion: freezed == projectTargetVersion ? _self.projectTargetVersion : projectTargetVersion // ignore: cast_nullable_to_non_nullable
as String?,latestFvmVersion: freezed == latestFvmVersion ? _self.latestFvmVersion : latestFvmVersion // ignore: cast_nullable_to_non_nullable
as String?,latestFlutterVersion: freezed == latestFlutterVersion ? _self.latestFlutterVersion : latestFlutterVersion // ignore: cast_nullable_to_non_nullable
as String?,hasFvmUpdate: null == hasFvmUpdate ? _self.hasFvmUpdate : hasFvmUpdate // ignore: cast_nullable_to_non_nullable
as bool,hasFlutterUpdate: null == hasFlutterUpdate ? _self.hasFlutterUpdate : hasFlutterUpdate // ignore: cast_nullable_to_non_nullable
as bool,updateNotice: freezed == updateNotice ? _self.updateNotice : updateNotice // ignore: cast_nullable_to_non_nullable
as String?,useDomesticMirror: null == useDomesticMirror ? _self.useDomesticMirror : useDomesticMirror // ignore: cast_nullable_to_non_nullable
as bool,mirrorId: null == mirrorId ? _self.mirrorId : mirrorId // ignore: cast_nullable_to_non_nullable
as String,mirrorTestResults: null == mirrorTestResults ? _self.mirrorTestResults : mirrorTestResults // ignore: cast_nullable_to_non_nullable
as Map<String, int>,managedProjects: null == managedProjects ? _self.managedProjects : managedProjects // ignore: cast_nullable_to_non_nullable
as List<FlutterProject>,selectedManagedProjectPath: freezed == selectedManagedProjectPath ? _self.selectedManagedProjectPath : selectedManagedProjectPath // ignore: cast_nullable_to_non_nullable
as String?,selectedAndroidFlavors: null == selectedAndroidFlavors ? _self.selectedAndroidFlavors : selectedAndroidFlavors // ignore: cast_nullable_to_non_nullable
as List<String>,projectBuildMode: null == projectBuildMode ? _self.projectBuildMode : projectBuildMode // ignore: cast_nullable_to_non_nullable
as ProjectBuildMode,projectBuildTarget: null == projectBuildTarget ? _self.projectBuildTarget : projectBuildTarget // ignore: cast_nullable_to_non_nullable
as ProjectBuildTarget,cleanBeforeBuild: null == cleanBeforeBuild ? _self.cleanBeforeBuild : cleanBeforeBuild // ignore: cast_nullable_to_non_nullable
as bool,androidTargetPlatform: null == androidTargetPlatform ? _self.androidTargetPlatform : androidTargetPlatform // ignore: cast_nullable_to_non_nullable
as String,devices: null == devices ? _self.devices : devices // ignore: cast_nullable_to_non_nullable
as List<Map<String, String>>,selectedDeviceId: freezed == selectedDeviceId ? _self.selectedDeviceId : selectedDeviceId // ignore: cast_nullable_to_non_nullable
as String?,devicesLoading: null == devicesLoading ? _self.devicesLoading : devicesLoading // ignore: cast_nullable_to_non_nullable
as bool,commandRunning: null == commandRunning ? _self.commandRunning : commandRunning // ignore: cast_nullable_to_non_nullable
as bool,commandLog: null == commandLog ? _self.commandLog : commandLog // ignore: cast_nullable_to_non_nullable
as String,activeCommand: freezed == activeCommand ? _self.activeCommand : activeCommand // ignore: cast_nullable_to_non_nullable
as String?,statusMessage: freezed == statusMessage ? _self.statusMessage : statusMessage // ignore: cast_nullable_to_non_nullable
as String?,errorMessage: freezed == errorMessage ? _self.errorMessage : errorMessage // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [FvmState].
extension FvmStatePatterns on FvmState {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _FvmState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _FvmState() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _FvmState value)  $default,){
final _that = this;
switch (_that) {
case _FvmState():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _FvmState value)?  $default,){
final _that = this;
switch (_that) {
case _FvmState() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( bool loading,  bool fvmInstalled,  String? fvmVersion,  String? globalVersion,  List<InstalledSdk> installed,  List<FlutterRelease> releases,  ReleaseChannel selectedChannel,  int releaseDisplayLimit,  String? activeVersion,  String? removingVersion,  double downloadProgress,  int downloadReceivedBytes,  int downloadTotalBytes,  double downloadBytesPerSecond,  String downloadPhase,  String? projectPath,  String? projectVersion,  String? projectTargetVersion,  String? latestFvmVersion,  String? latestFlutterVersion,  bool hasFvmUpdate,  bool hasFlutterUpdate,  String? updateNotice,  bool useDomesticMirror,  String mirrorId,  Map<String, int> mirrorTestResults,  List<FlutterProject> managedProjects,  String? selectedManagedProjectPath,  List<String> selectedAndroidFlavors,  ProjectBuildMode projectBuildMode,  ProjectBuildTarget projectBuildTarget,  bool cleanBeforeBuild,  String androidTargetPlatform,  List<Map<String, String>> devices,  String? selectedDeviceId,  bool devicesLoading,  bool commandRunning,  String commandLog,  String? activeCommand,  String? statusMessage,  String? errorMessage)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _FvmState() when $default != null:
return $default(_that.loading,_that.fvmInstalled,_that.fvmVersion,_that.globalVersion,_that.installed,_that.releases,_that.selectedChannel,_that.releaseDisplayLimit,_that.activeVersion,_that.removingVersion,_that.downloadProgress,_that.downloadReceivedBytes,_that.downloadTotalBytes,_that.downloadBytesPerSecond,_that.downloadPhase,_that.projectPath,_that.projectVersion,_that.projectTargetVersion,_that.latestFvmVersion,_that.latestFlutterVersion,_that.hasFvmUpdate,_that.hasFlutterUpdate,_that.updateNotice,_that.useDomesticMirror,_that.mirrorId,_that.mirrorTestResults,_that.managedProjects,_that.selectedManagedProjectPath,_that.selectedAndroidFlavors,_that.projectBuildMode,_that.projectBuildTarget,_that.cleanBeforeBuild,_that.androidTargetPlatform,_that.devices,_that.selectedDeviceId,_that.devicesLoading,_that.commandRunning,_that.commandLog,_that.activeCommand,_that.statusMessage,_that.errorMessage);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( bool loading,  bool fvmInstalled,  String? fvmVersion,  String? globalVersion,  List<InstalledSdk> installed,  List<FlutterRelease> releases,  ReleaseChannel selectedChannel,  int releaseDisplayLimit,  String? activeVersion,  String? removingVersion,  double downloadProgress,  int downloadReceivedBytes,  int downloadTotalBytes,  double downloadBytesPerSecond,  String downloadPhase,  String? projectPath,  String? projectVersion,  String? projectTargetVersion,  String? latestFvmVersion,  String? latestFlutterVersion,  bool hasFvmUpdate,  bool hasFlutterUpdate,  String? updateNotice,  bool useDomesticMirror,  String mirrorId,  Map<String, int> mirrorTestResults,  List<FlutterProject> managedProjects,  String? selectedManagedProjectPath,  List<String> selectedAndroidFlavors,  ProjectBuildMode projectBuildMode,  ProjectBuildTarget projectBuildTarget,  bool cleanBeforeBuild,  String androidTargetPlatform,  List<Map<String, String>> devices,  String? selectedDeviceId,  bool devicesLoading,  bool commandRunning,  String commandLog,  String? activeCommand,  String? statusMessage,  String? errorMessage)  $default,) {final _that = this;
switch (_that) {
case _FvmState():
return $default(_that.loading,_that.fvmInstalled,_that.fvmVersion,_that.globalVersion,_that.installed,_that.releases,_that.selectedChannel,_that.releaseDisplayLimit,_that.activeVersion,_that.removingVersion,_that.downloadProgress,_that.downloadReceivedBytes,_that.downloadTotalBytes,_that.downloadBytesPerSecond,_that.downloadPhase,_that.projectPath,_that.projectVersion,_that.projectTargetVersion,_that.latestFvmVersion,_that.latestFlutterVersion,_that.hasFvmUpdate,_that.hasFlutterUpdate,_that.updateNotice,_that.useDomesticMirror,_that.mirrorId,_that.mirrorTestResults,_that.managedProjects,_that.selectedManagedProjectPath,_that.selectedAndroidFlavors,_that.projectBuildMode,_that.projectBuildTarget,_that.cleanBeforeBuild,_that.androidTargetPlatform,_that.devices,_that.selectedDeviceId,_that.devicesLoading,_that.commandRunning,_that.commandLog,_that.activeCommand,_that.statusMessage,_that.errorMessage);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( bool loading,  bool fvmInstalled,  String? fvmVersion,  String? globalVersion,  List<InstalledSdk> installed,  List<FlutterRelease> releases,  ReleaseChannel selectedChannel,  int releaseDisplayLimit,  String? activeVersion,  String? removingVersion,  double downloadProgress,  int downloadReceivedBytes,  int downloadTotalBytes,  double downloadBytesPerSecond,  String downloadPhase,  String? projectPath,  String? projectVersion,  String? projectTargetVersion,  String? latestFvmVersion,  String? latestFlutterVersion,  bool hasFvmUpdate,  bool hasFlutterUpdate,  String? updateNotice,  bool useDomesticMirror,  String mirrorId,  Map<String, int> mirrorTestResults,  List<FlutterProject> managedProjects,  String? selectedManagedProjectPath,  List<String> selectedAndroidFlavors,  ProjectBuildMode projectBuildMode,  ProjectBuildTarget projectBuildTarget,  bool cleanBeforeBuild,  String androidTargetPlatform,  List<Map<String, String>> devices,  String? selectedDeviceId,  bool devicesLoading,  bool commandRunning,  String commandLog,  String? activeCommand,  String? statusMessage,  String? errorMessage)?  $default,) {final _that = this;
switch (_that) {
case _FvmState() when $default != null:
return $default(_that.loading,_that.fvmInstalled,_that.fvmVersion,_that.globalVersion,_that.installed,_that.releases,_that.selectedChannel,_that.releaseDisplayLimit,_that.activeVersion,_that.removingVersion,_that.downloadProgress,_that.downloadReceivedBytes,_that.downloadTotalBytes,_that.downloadBytesPerSecond,_that.downloadPhase,_that.projectPath,_that.projectVersion,_that.projectTargetVersion,_that.latestFvmVersion,_that.latestFlutterVersion,_that.hasFvmUpdate,_that.hasFlutterUpdate,_that.updateNotice,_that.useDomesticMirror,_that.mirrorId,_that.mirrorTestResults,_that.managedProjects,_that.selectedManagedProjectPath,_that.selectedAndroidFlavors,_that.projectBuildMode,_that.projectBuildTarget,_that.cleanBeforeBuild,_that.androidTargetPlatform,_that.devices,_that.selectedDeviceId,_that.devicesLoading,_that.commandRunning,_that.commandLog,_that.activeCommand,_that.statusMessage,_that.errorMessage);case _:
  return null;

}
}

}

/// @nodoc


class _FvmState implements FvmState {
  const _FvmState({this.loading = false, this.fvmInstalled = false, this.fvmVersion, this.globalVersion, final  List<InstalledSdk> installed = const <InstalledSdk>[], final  List<FlutterRelease> releases = const <FlutterRelease>[], this.selectedChannel = ReleaseChannel.stable, this.releaseDisplayLimit = 30, this.activeVersion, this.removingVersion, this.downloadProgress = 0, this.downloadReceivedBytes = 0, this.downloadTotalBytes = 0, this.downloadBytesPerSecond = 0, this.downloadPhase = '准备下载', this.projectPath, this.projectVersion, this.projectTargetVersion, this.latestFvmVersion, this.latestFlutterVersion, this.hasFvmUpdate = false, this.hasFlutterUpdate = false, this.updateNotice, this.useDomesticMirror = false, this.mirrorId = 'official', final  Map<String, int> mirrorTestResults = const <String, int>{}, final  List<FlutterProject> managedProjects = const <FlutterProject>[], this.selectedManagedProjectPath, final  List<String> selectedAndroidFlavors = const <String>[], this.projectBuildMode = ProjectBuildMode.release, this.projectBuildTarget = ProjectBuildTarget.apk, this.cleanBeforeBuild = false, this.androidTargetPlatform = 'android-arm64', final  List<Map<String, String>> devices = const <Map<String, String>>[], this.selectedDeviceId, this.devicesLoading = false, this.commandRunning = false, this.commandLog = '', this.activeCommand, this.statusMessage, this.errorMessage}): _installed = installed,_releases = releases,_mirrorTestResults = mirrorTestResults,_managedProjects = managedProjects,_selectedAndroidFlavors = selectedAndroidFlavors,_devices = devices;
  

@override@JsonKey() final  bool loading;
@override@JsonKey() final  bool fvmInstalled;
@override final  String? fvmVersion;
@override final  String? globalVersion;
 final  List<InstalledSdk> _installed;
@override@JsonKey() List<InstalledSdk> get installed {
  if (_installed is EqualUnmodifiableListView) return _installed;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_installed);
}

 final  List<FlutterRelease> _releases;
@override@JsonKey() List<FlutterRelease> get releases {
  if (_releases is EqualUnmodifiableListView) return _releases;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_releases);
}

@override@JsonKey() final  ReleaseChannel selectedChannel;
@override@JsonKey() final  int releaseDisplayLimit;
@override final  String? activeVersion;
@override final  String? removingVersion;
@override@JsonKey() final  double downloadProgress;
@override@JsonKey() final  int downloadReceivedBytes;
@override@JsonKey() final  int downloadTotalBytes;
@override@JsonKey() final  double downloadBytesPerSecond;
@override@JsonKey() final  String downloadPhase;
@override final  String? projectPath;
@override final  String? projectVersion;
@override final  String? projectTargetVersion;
@override final  String? latestFvmVersion;
@override final  String? latestFlutterVersion;
@override@JsonKey() final  bool hasFvmUpdate;
@override@JsonKey() final  bool hasFlutterUpdate;
@override final  String? updateNotice;
@override@JsonKey() final  bool useDomesticMirror;
@override@JsonKey() final  String mirrorId;
 final  Map<String, int> _mirrorTestResults;
@override@JsonKey() Map<String, int> get mirrorTestResults {
  if (_mirrorTestResults is EqualUnmodifiableMapView) return _mirrorTestResults;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_mirrorTestResults);
}

 final  List<FlutterProject> _managedProjects;
@override@JsonKey() List<FlutterProject> get managedProjects {
  if (_managedProjects is EqualUnmodifiableListView) return _managedProjects;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_managedProjects);
}

@override final  String? selectedManagedProjectPath;
 final  List<String> _selectedAndroidFlavors;
@override@JsonKey() List<String> get selectedAndroidFlavors {
  if (_selectedAndroidFlavors is EqualUnmodifiableListView) return _selectedAndroidFlavors;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_selectedAndroidFlavors);
}

@override@JsonKey() final  ProjectBuildMode projectBuildMode;
@override@JsonKey() final  ProjectBuildTarget projectBuildTarget;
@override@JsonKey() final  bool cleanBeforeBuild;
@override@JsonKey() final  String androidTargetPlatform;
 final  List<Map<String, String>> _devices;
@override@JsonKey() List<Map<String, String>> get devices {
  if (_devices is EqualUnmodifiableListView) return _devices;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_devices);
}

@override final  String? selectedDeviceId;
@override@JsonKey() final  bool devicesLoading;
@override@JsonKey() final  bool commandRunning;
@override@JsonKey() final  String commandLog;
@override final  String? activeCommand;
@override final  String? statusMessage;
@override final  String? errorMessage;

/// Create a copy of FvmState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$FvmStateCopyWith<_FvmState> get copyWith => __$FvmStateCopyWithImpl<_FvmState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _FvmState&&(identical(other.loading, loading) || other.loading == loading)&&(identical(other.fvmInstalled, fvmInstalled) || other.fvmInstalled == fvmInstalled)&&(identical(other.fvmVersion, fvmVersion) || other.fvmVersion == fvmVersion)&&(identical(other.globalVersion, globalVersion) || other.globalVersion == globalVersion)&&const DeepCollectionEquality().equals(other._installed, _installed)&&const DeepCollectionEquality().equals(other._releases, _releases)&&(identical(other.selectedChannel, selectedChannel) || other.selectedChannel == selectedChannel)&&(identical(other.releaseDisplayLimit, releaseDisplayLimit) || other.releaseDisplayLimit == releaseDisplayLimit)&&(identical(other.activeVersion, activeVersion) || other.activeVersion == activeVersion)&&(identical(other.removingVersion, removingVersion) || other.removingVersion == removingVersion)&&(identical(other.downloadProgress, downloadProgress) || other.downloadProgress == downloadProgress)&&(identical(other.downloadReceivedBytes, downloadReceivedBytes) || other.downloadReceivedBytes == downloadReceivedBytes)&&(identical(other.downloadTotalBytes, downloadTotalBytes) || other.downloadTotalBytes == downloadTotalBytes)&&(identical(other.downloadBytesPerSecond, downloadBytesPerSecond) || other.downloadBytesPerSecond == downloadBytesPerSecond)&&(identical(other.downloadPhase, downloadPhase) || other.downloadPhase == downloadPhase)&&(identical(other.projectPath, projectPath) || other.projectPath == projectPath)&&(identical(other.projectVersion, projectVersion) || other.projectVersion == projectVersion)&&(identical(other.projectTargetVersion, projectTargetVersion) || other.projectTargetVersion == projectTargetVersion)&&(identical(other.latestFvmVersion, latestFvmVersion) || other.latestFvmVersion == latestFvmVersion)&&(identical(other.latestFlutterVersion, latestFlutterVersion) || other.latestFlutterVersion == latestFlutterVersion)&&(identical(other.hasFvmUpdate, hasFvmUpdate) || other.hasFvmUpdate == hasFvmUpdate)&&(identical(other.hasFlutterUpdate, hasFlutterUpdate) || other.hasFlutterUpdate == hasFlutterUpdate)&&(identical(other.updateNotice, updateNotice) || other.updateNotice == updateNotice)&&(identical(other.useDomesticMirror, useDomesticMirror) || other.useDomesticMirror == useDomesticMirror)&&(identical(other.mirrorId, mirrorId) || other.mirrorId == mirrorId)&&const DeepCollectionEquality().equals(other._mirrorTestResults, _mirrorTestResults)&&const DeepCollectionEquality().equals(other._managedProjects, _managedProjects)&&(identical(other.selectedManagedProjectPath, selectedManagedProjectPath) || other.selectedManagedProjectPath == selectedManagedProjectPath)&&const DeepCollectionEquality().equals(other._selectedAndroidFlavors, _selectedAndroidFlavors)&&(identical(other.projectBuildMode, projectBuildMode) || other.projectBuildMode == projectBuildMode)&&(identical(other.projectBuildTarget, projectBuildTarget) || other.projectBuildTarget == projectBuildTarget)&&(identical(other.cleanBeforeBuild, cleanBeforeBuild) || other.cleanBeforeBuild == cleanBeforeBuild)&&(identical(other.androidTargetPlatform, androidTargetPlatform) || other.androidTargetPlatform == androidTargetPlatform)&&const DeepCollectionEquality().equals(other._devices, _devices)&&(identical(other.selectedDeviceId, selectedDeviceId) || other.selectedDeviceId == selectedDeviceId)&&(identical(other.devicesLoading, devicesLoading) || other.devicesLoading == devicesLoading)&&(identical(other.commandRunning, commandRunning) || other.commandRunning == commandRunning)&&(identical(other.commandLog, commandLog) || other.commandLog == commandLog)&&(identical(other.activeCommand, activeCommand) || other.activeCommand == activeCommand)&&(identical(other.statusMessage, statusMessage) || other.statusMessage == statusMessage)&&(identical(other.errorMessage, errorMessage) || other.errorMessage == errorMessage));
}


@override
int get hashCode => Object.hashAll([runtimeType,loading,fvmInstalled,fvmVersion,globalVersion,const DeepCollectionEquality().hash(_installed),const DeepCollectionEquality().hash(_releases),selectedChannel,releaseDisplayLimit,activeVersion,removingVersion,downloadProgress,downloadReceivedBytes,downloadTotalBytes,downloadBytesPerSecond,downloadPhase,projectPath,projectVersion,projectTargetVersion,latestFvmVersion,latestFlutterVersion,hasFvmUpdate,hasFlutterUpdate,updateNotice,useDomesticMirror,mirrorId,const DeepCollectionEquality().hash(_mirrorTestResults),const DeepCollectionEquality().hash(_managedProjects),selectedManagedProjectPath,const DeepCollectionEquality().hash(_selectedAndroidFlavors),projectBuildMode,projectBuildTarget,cleanBeforeBuild,androidTargetPlatform,const DeepCollectionEquality().hash(_devices),selectedDeviceId,devicesLoading,commandRunning,commandLog,activeCommand,statusMessage,errorMessage]);

@override
String toString() {
  return 'FvmState(loading: $loading, fvmInstalled: $fvmInstalled, fvmVersion: $fvmVersion, globalVersion: $globalVersion, installed: $installed, releases: $releases, selectedChannel: $selectedChannel, releaseDisplayLimit: $releaseDisplayLimit, activeVersion: $activeVersion, removingVersion: $removingVersion, downloadProgress: $downloadProgress, downloadReceivedBytes: $downloadReceivedBytes, downloadTotalBytes: $downloadTotalBytes, downloadBytesPerSecond: $downloadBytesPerSecond, downloadPhase: $downloadPhase, projectPath: $projectPath, projectVersion: $projectVersion, projectTargetVersion: $projectTargetVersion, latestFvmVersion: $latestFvmVersion, latestFlutterVersion: $latestFlutterVersion, hasFvmUpdate: $hasFvmUpdate, hasFlutterUpdate: $hasFlutterUpdate, updateNotice: $updateNotice, useDomesticMirror: $useDomesticMirror, mirrorId: $mirrorId, mirrorTestResults: $mirrorTestResults, managedProjects: $managedProjects, selectedManagedProjectPath: $selectedManagedProjectPath, selectedAndroidFlavors: $selectedAndroidFlavors, projectBuildMode: $projectBuildMode, projectBuildTarget: $projectBuildTarget, cleanBeforeBuild: $cleanBeforeBuild, androidTargetPlatform: $androidTargetPlatform, devices: $devices, selectedDeviceId: $selectedDeviceId, devicesLoading: $devicesLoading, commandRunning: $commandRunning, commandLog: $commandLog, activeCommand: $activeCommand, statusMessage: $statusMessage, errorMessage: $errorMessage)';
}


}

/// @nodoc
abstract mixin class _$FvmStateCopyWith<$Res> implements $FvmStateCopyWith<$Res> {
  factory _$FvmStateCopyWith(_FvmState value, $Res Function(_FvmState) _then) = __$FvmStateCopyWithImpl;
@override @useResult
$Res call({
 bool loading, bool fvmInstalled, String? fvmVersion, String? globalVersion, List<InstalledSdk> installed, List<FlutterRelease> releases, ReleaseChannel selectedChannel, int releaseDisplayLimit, String? activeVersion, String? removingVersion, double downloadProgress, int downloadReceivedBytes, int downloadTotalBytes, double downloadBytesPerSecond, String downloadPhase, String? projectPath, String? projectVersion, String? projectTargetVersion, String? latestFvmVersion, String? latestFlutterVersion, bool hasFvmUpdate, bool hasFlutterUpdate, String? updateNotice, bool useDomesticMirror, String mirrorId, Map<String, int> mirrorTestResults, List<FlutterProject> managedProjects, String? selectedManagedProjectPath, List<String> selectedAndroidFlavors, ProjectBuildMode projectBuildMode, ProjectBuildTarget projectBuildTarget, bool cleanBeforeBuild, String androidTargetPlatform, List<Map<String, String>> devices, String? selectedDeviceId, bool devicesLoading, bool commandRunning, String commandLog, String? activeCommand, String? statusMessage, String? errorMessage
});




}
/// @nodoc
class __$FvmStateCopyWithImpl<$Res>
    implements _$FvmStateCopyWith<$Res> {
  __$FvmStateCopyWithImpl(this._self, this._then);

  final _FvmState _self;
  final $Res Function(_FvmState) _then;

/// Create a copy of FvmState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? loading = null,Object? fvmInstalled = null,Object? fvmVersion = freezed,Object? globalVersion = freezed,Object? installed = null,Object? releases = null,Object? selectedChannel = null,Object? releaseDisplayLimit = null,Object? activeVersion = freezed,Object? removingVersion = freezed,Object? downloadProgress = null,Object? downloadReceivedBytes = null,Object? downloadTotalBytes = null,Object? downloadBytesPerSecond = null,Object? downloadPhase = null,Object? projectPath = freezed,Object? projectVersion = freezed,Object? projectTargetVersion = freezed,Object? latestFvmVersion = freezed,Object? latestFlutterVersion = freezed,Object? hasFvmUpdate = null,Object? hasFlutterUpdate = null,Object? updateNotice = freezed,Object? useDomesticMirror = null,Object? mirrorId = null,Object? mirrorTestResults = null,Object? managedProjects = null,Object? selectedManagedProjectPath = freezed,Object? selectedAndroidFlavors = null,Object? projectBuildMode = null,Object? projectBuildTarget = null,Object? cleanBeforeBuild = null,Object? androidTargetPlatform = null,Object? devices = null,Object? selectedDeviceId = freezed,Object? devicesLoading = null,Object? commandRunning = null,Object? commandLog = null,Object? activeCommand = freezed,Object? statusMessage = freezed,Object? errorMessage = freezed,}) {
  return _then(_FvmState(
loading: null == loading ? _self.loading : loading // ignore: cast_nullable_to_non_nullable
as bool,fvmInstalled: null == fvmInstalled ? _self.fvmInstalled : fvmInstalled // ignore: cast_nullable_to_non_nullable
as bool,fvmVersion: freezed == fvmVersion ? _self.fvmVersion : fvmVersion // ignore: cast_nullable_to_non_nullable
as String?,globalVersion: freezed == globalVersion ? _self.globalVersion : globalVersion // ignore: cast_nullable_to_non_nullable
as String?,installed: null == installed ? _self._installed : installed // ignore: cast_nullable_to_non_nullable
as List<InstalledSdk>,releases: null == releases ? _self._releases : releases // ignore: cast_nullable_to_non_nullable
as List<FlutterRelease>,selectedChannel: null == selectedChannel ? _self.selectedChannel : selectedChannel // ignore: cast_nullable_to_non_nullable
as ReleaseChannel,releaseDisplayLimit: null == releaseDisplayLimit ? _self.releaseDisplayLimit : releaseDisplayLimit // ignore: cast_nullable_to_non_nullable
as int,activeVersion: freezed == activeVersion ? _self.activeVersion : activeVersion // ignore: cast_nullable_to_non_nullable
as String?,removingVersion: freezed == removingVersion ? _self.removingVersion : removingVersion // ignore: cast_nullable_to_non_nullable
as String?,downloadProgress: null == downloadProgress ? _self.downloadProgress : downloadProgress // ignore: cast_nullable_to_non_nullable
as double,downloadReceivedBytes: null == downloadReceivedBytes ? _self.downloadReceivedBytes : downloadReceivedBytes // ignore: cast_nullable_to_non_nullable
as int,downloadTotalBytes: null == downloadTotalBytes ? _self.downloadTotalBytes : downloadTotalBytes // ignore: cast_nullable_to_non_nullable
as int,downloadBytesPerSecond: null == downloadBytesPerSecond ? _self.downloadBytesPerSecond : downloadBytesPerSecond // ignore: cast_nullable_to_non_nullable
as double,downloadPhase: null == downloadPhase ? _self.downloadPhase : downloadPhase // ignore: cast_nullable_to_non_nullable
as String,projectPath: freezed == projectPath ? _self.projectPath : projectPath // ignore: cast_nullable_to_non_nullable
as String?,projectVersion: freezed == projectVersion ? _self.projectVersion : projectVersion // ignore: cast_nullable_to_non_nullable
as String?,projectTargetVersion: freezed == projectTargetVersion ? _self.projectTargetVersion : projectTargetVersion // ignore: cast_nullable_to_non_nullable
as String?,latestFvmVersion: freezed == latestFvmVersion ? _self.latestFvmVersion : latestFvmVersion // ignore: cast_nullable_to_non_nullable
as String?,latestFlutterVersion: freezed == latestFlutterVersion ? _self.latestFlutterVersion : latestFlutterVersion // ignore: cast_nullable_to_non_nullable
as String?,hasFvmUpdate: null == hasFvmUpdate ? _self.hasFvmUpdate : hasFvmUpdate // ignore: cast_nullable_to_non_nullable
as bool,hasFlutterUpdate: null == hasFlutterUpdate ? _self.hasFlutterUpdate : hasFlutterUpdate // ignore: cast_nullable_to_non_nullable
as bool,updateNotice: freezed == updateNotice ? _self.updateNotice : updateNotice // ignore: cast_nullable_to_non_nullable
as String?,useDomesticMirror: null == useDomesticMirror ? _self.useDomesticMirror : useDomesticMirror // ignore: cast_nullable_to_non_nullable
as bool,mirrorId: null == mirrorId ? _self.mirrorId : mirrorId // ignore: cast_nullable_to_non_nullable
as String,mirrorTestResults: null == mirrorTestResults ? _self._mirrorTestResults : mirrorTestResults // ignore: cast_nullable_to_non_nullable
as Map<String, int>,managedProjects: null == managedProjects ? _self._managedProjects : managedProjects // ignore: cast_nullable_to_non_nullable
as List<FlutterProject>,selectedManagedProjectPath: freezed == selectedManagedProjectPath ? _self.selectedManagedProjectPath : selectedManagedProjectPath // ignore: cast_nullable_to_non_nullable
as String?,selectedAndroidFlavors: null == selectedAndroidFlavors ? _self._selectedAndroidFlavors : selectedAndroidFlavors // ignore: cast_nullable_to_non_nullable
as List<String>,projectBuildMode: null == projectBuildMode ? _self.projectBuildMode : projectBuildMode // ignore: cast_nullable_to_non_nullable
as ProjectBuildMode,projectBuildTarget: null == projectBuildTarget ? _self.projectBuildTarget : projectBuildTarget // ignore: cast_nullable_to_non_nullable
as ProjectBuildTarget,cleanBeforeBuild: null == cleanBeforeBuild ? _self.cleanBeforeBuild : cleanBeforeBuild // ignore: cast_nullable_to_non_nullable
as bool,androidTargetPlatform: null == androidTargetPlatform ? _self.androidTargetPlatform : androidTargetPlatform // ignore: cast_nullable_to_non_nullable
as String,devices: null == devices ? _self._devices : devices // ignore: cast_nullable_to_non_nullable
as List<Map<String, String>>,selectedDeviceId: freezed == selectedDeviceId ? _self.selectedDeviceId : selectedDeviceId // ignore: cast_nullable_to_non_nullable
as String?,devicesLoading: null == devicesLoading ? _self.devicesLoading : devicesLoading // ignore: cast_nullable_to_non_nullable
as bool,commandRunning: null == commandRunning ? _self.commandRunning : commandRunning // ignore: cast_nullable_to_non_nullable
as bool,commandLog: null == commandLog ? _self.commandLog : commandLog // ignore: cast_nullable_to_non_nullable
as String,activeCommand: freezed == activeCommand ? _self.activeCommand : activeCommand // ignore: cast_nullable_to_non_nullable
as String?,statusMessage: freezed == statusMessage ? _self.statusMessage : statusMessage // ignore: cast_nullable_to_non_nullable
as String?,errorMessage: freezed == errorMessage ? _self.errorMessage : errorMessage // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
