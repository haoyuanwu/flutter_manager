// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'project_models.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$FirConfig {

 String get apiToken; String get appName; String get bundleId; String get changelog; String get shortCode;
/// Create a copy of FirConfig
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FirConfigCopyWith<FirConfig> get copyWith => _$FirConfigCopyWithImpl<FirConfig>(this as FirConfig, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FirConfig&&(identical(other.apiToken, apiToken) || other.apiToken == apiToken)&&(identical(other.appName, appName) || other.appName == appName)&&(identical(other.bundleId, bundleId) || other.bundleId == bundleId)&&(identical(other.changelog, changelog) || other.changelog == changelog)&&(identical(other.shortCode, shortCode) || other.shortCode == shortCode));
}


@override
int get hashCode => Object.hash(runtimeType,apiToken,appName,bundleId,changelog,shortCode);

@override
String toString() {
  return 'FirConfig(apiToken: $apiToken, appName: $appName, bundleId: $bundleId, changelog: $changelog, shortCode: $shortCode)';
}


}

/// @nodoc
abstract mixin class $FirConfigCopyWith<$Res>  {
  factory $FirConfigCopyWith(FirConfig value, $Res Function(FirConfig) _then) = _$FirConfigCopyWithImpl;
@useResult
$Res call({
 String apiToken, String appName, String bundleId, String changelog, String shortCode
});




}
/// @nodoc
class _$FirConfigCopyWithImpl<$Res>
    implements $FirConfigCopyWith<$Res> {
  _$FirConfigCopyWithImpl(this._self, this._then);

  final FirConfig _self;
  final $Res Function(FirConfig) _then;

/// Create a copy of FirConfig
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? apiToken = null,Object? appName = null,Object? bundleId = null,Object? changelog = null,Object? shortCode = null,}) {
  return _then(_self.copyWith(
apiToken: null == apiToken ? _self.apiToken : apiToken // ignore: cast_nullable_to_non_nullable
as String,appName: null == appName ? _self.appName : appName // ignore: cast_nullable_to_non_nullable
as String,bundleId: null == bundleId ? _self.bundleId : bundleId // ignore: cast_nullable_to_non_nullable
as String,changelog: null == changelog ? _self.changelog : changelog // ignore: cast_nullable_to_non_nullable
as String,shortCode: null == shortCode ? _self.shortCode : shortCode // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [FirConfig].
extension FirConfigPatterns on FirConfig {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _FirConfig value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _FirConfig() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _FirConfig value)  $default,){
final _that = this;
switch (_that) {
case _FirConfig():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _FirConfig value)?  $default,){
final _that = this;
switch (_that) {
case _FirConfig() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String apiToken,  String appName,  String bundleId,  String changelog,  String shortCode)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _FirConfig() when $default != null:
return $default(_that.apiToken,_that.appName,_that.bundleId,_that.changelog,_that.shortCode);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String apiToken,  String appName,  String bundleId,  String changelog,  String shortCode)  $default,) {final _that = this;
switch (_that) {
case _FirConfig():
return $default(_that.apiToken,_that.appName,_that.bundleId,_that.changelog,_that.shortCode);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String apiToken,  String appName,  String bundleId,  String changelog,  String shortCode)?  $default,) {final _that = this;
switch (_that) {
case _FirConfig() when $default != null:
return $default(_that.apiToken,_that.appName,_that.bundleId,_that.changelog,_that.shortCode);case _:
  return null;

}
}

}

/// @nodoc


class _FirConfig extends FirConfig {
  const _FirConfig({this.apiToken = '', this.appName = '', this.bundleId = '', this.changelog = '', this.shortCode = ''}): super._();
  

@override@JsonKey() final  String apiToken;
@override@JsonKey() final  String appName;
@override@JsonKey() final  String bundleId;
@override@JsonKey() final  String changelog;
@override@JsonKey() final  String shortCode;

/// Create a copy of FirConfig
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$FirConfigCopyWith<_FirConfig> get copyWith => __$FirConfigCopyWithImpl<_FirConfig>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _FirConfig&&(identical(other.apiToken, apiToken) || other.apiToken == apiToken)&&(identical(other.appName, appName) || other.appName == appName)&&(identical(other.bundleId, bundleId) || other.bundleId == bundleId)&&(identical(other.changelog, changelog) || other.changelog == changelog)&&(identical(other.shortCode, shortCode) || other.shortCode == shortCode));
}


@override
int get hashCode => Object.hash(runtimeType,apiToken,appName,bundleId,changelog,shortCode);

@override
String toString() {
  return 'FirConfig(apiToken: $apiToken, appName: $appName, bundleId: $bundleId, changelog: $changelog, shortCode: $shortCode)';
}


}

/// @nodoc
abstract mixin class _$FirConfigCopyWith<$Res> implements $FirConfigCopyWith<$Res> {
  factory _$FirConfigCopyWith(_FirConfig value, $Res Function(_FirConfig) _then) = __$FirConfigCopyWithImpl;
@override @useResult
$Res call({
 String apiToken, String appName, String bundleId, String changelog, String shortCode
});




}
/// @nodoc
class __$FirConfigCopyWithImpl<$Res>
    implements _$FirConfigCopyWith<$Res> {
  __$FirConfigCopyWithImpl(this._self, this._then);

  final _FirConfig _self;
  final $Res Function(_FirConfig) _then;

/// Create a copy of FirConfig
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? apiToken = null,Object? appName = null,Object? bundleId = null,Object? changelog = null,Object? shortCode = null,}) {
  return _then(_FirConfig(
apiToken: null == apiToken ? _self.apiToken : apiToken // ignore: cast_nullable_to_non_nullable
as String,appName: null == appName ? _self.appName : appName // ignore: cast_nullable_to_non_nullable
as String,bundleId: null == bundleId ? _self.bundleId : bundleId // ignore: cast_nullable_to_non_nullable
as String,changelog: null == changelog ? _self.changelog : changelog // ignore: cast_nullable_to_non_nullable
as String,shortCode: null == shortCode ? _self.shortCode : shortCode // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
mixin _$PgyerConfig {

 String get apiKey; PgyerInstallType get installType; String get installPassword; String get updateDescription; String get buildShortcutUrl;
/// Create a copy of PgyerConfig
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PgyerConfigCopyWith<PgyerConfig> get copyWith => _$PgyerConfigCopyWithImpl<PgyerConfig>(this as PgyerConfig, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PgyerConfig&&(identical(other.apiKey, apiKey) || other.apiKey == apiKey)&&(identical(other.installType, installType) || other.installType == installType)&&(identical(other.installPassword, installPassword) || other.installPassword == installPassword)&&(identical(other.updateDescription, updateDescription) || other.updateDescription == updateDescription)&&(identical(other.buildShortcutUrl, buildShortcutUrl) || other.buildShortcutUrl == buildShortcutUrl));
}


@override
int get hashCode => Object.hash(runtimeType,apiKey,installType,installPassword,updateDescription,buildShortcutUrl);

@override
String toString() {
  return 'PgyerConfig(apiKey: $apiKey, installType: $installType, installPassword: $installPassword, updateDescription: $updateDescription, buildShortcutUrl: $buildShortcutUrl)';
}


}

/// @nodoc
abstract mixin class $PgyerConfigCopyWith<$Res>  {
  factory $PgyerConfigCopyWith(PgyerConfig value, $Res Function(PgyerConfig) _then) = _$PgyerConfigCopyWithImpl;
@useResult
$Res call({
 String apiKey, PgyerInstallType installType, String installPassword, String updateDescription, String buildShortcutUrl
});




}
/// @nodoc
class _$PgyerConfigCopyWithImpl<$Res>
    implements $PgyerConfigCopyWith<$Res> {
  _$PgyerConfigCopyWithImpl(this._self, this._then);

  final PgyerConfig _self;
  final $Res Function(PgyerConfig) _then;

/// Create a copy of PgyerConfig
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? apiKey = null,Object? installType = null,Object? installPassword = null,Object? updateDescription = null,Object? buildShortcutUrl = null,}) {
  return _then(_self.copyWith(
apiKey: null == apiKey ? _self.apiKey : apiKey // ignore: cast_nullable_to_non_nullable
as String,installType: null == installType ? _self.installType : installType // ignore: cast_nullable_to_non_nullable
as PgyerInstallType,installPassword: null == installPassword ? _self.installPassword : installPassword // ignore: cast_nullable_to_non_nullable
as String,updateDescription: null == updateDescription ? _self.updateDescription : updateDescription // ignore: cast_nullable_to_non_nullable
as String,buildShortcutUrl: null == buildShortcutUrl ? _self.buildShortcutUrl : buildShortcutUrl // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [PgyerConfig].
extension PgyerConfigPatterns on PgyerConfig {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PgyerConfig value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PgyerConfig() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PgyerConfig value)  $default,){
final _that = this;
switch (_that) {
case _PgyerConfig():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PgyerConfig value)?  $default,){
final _that = this;
switch (_that) {
case _PgyerConfig() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String apiKey,  PgyerInstallType installType,  String installPassword,  String updateDescription,  String buildShortcutUrl)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PgyerConfig() when $default != null:
return $default(_that.apiKey,_that.installType,_that.installPassword,_that.updateDescription,_that.buildShortcutUrl);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String apiKey,  PgyerInstallType installType,  String installPassword,  String updateDescription,  String buildShortcutUrl)  $default,) {final _that = this;
switch (_that) {
case _PgyerConfig():
return $default(_that.apiKey,_that.installType,_that.installPassword,_that.updateDescription,_that.buildShortcutUrl);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String apiKey,  PgyerInstallType installType,  String installPassword,  String updateDescription,  String buildShortcutUrl)?  $default,) {final _that = this;
switch (_that) {
case _PgyerConfig() when $default != null:
return $default(_that.apiKey,_that.installType,_that.installPassword,_that.updateDescription,_that.buildShortcutUrl);case _:
  return null;

}
}

}

/// @nodoc


class _PgyerConfig extends PgyerConfig {
  const _PgyerConfig({this.apiKey = '', this.installType = PgyerInstallType.public, this.installPassword = '', this.updateDescription = '', this.buildShortcutUrl = ''}): super._();
  

@override@JsonKey() final  String apiKey;
@override@JsonKey() final  PgyerInstallType installType;
@override@JsonKey() final  String installPassword;
@override@JsonKey() final  String updateDescription;
@override@JsonKey() final  String buildShortcutUrl;

/// Create a copy of PgyerConfig
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PgyerConfigCopyWith<_PgyerConfig> get copyWith => __$PgyerConfigCopyWithImpl<_PgyerConfig>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PgyerConfig&&(identical(other.apiKey, apiKey) || other.apiKey == apiKey)&&(identical(other.installType, installType) || other.installType == installType)&&(identical(other.installPassword, installPassword) || other.installPassword == installPassword)&&(identical(other.updateDescription, updateDescription) || other.updateDescription == updateDescription)&&(identical(other.buildShortcutUrl, buildShortcutUrl) || other.buildShortcutUrl == buildShortcutUrl));
}


@override
int get hashCode => Object.hash(runtimeType,apiKey,installType,installPassword,updateDescription,buildShortcutUrl);

@override
String toString() {
  return 'PgyerConfig(apiKey: $apiKey, installType: $installType, installPassword: $installPassword, updateDescription: $updateDescription, buildShortcutUrl: $buildShortcutUrl)';
}


}

/// @nodoc
abstract mixin class _$PgyerConfigCopyWith<$Res> implements $PgyerConfigCopyWith<$Res> {
  factory _$PgyerConfigCopyWith(_PgyerConfig value, $Res Function(_PgyerConfig) _then) = __$PgyerConfigCopyWithImpl;
@override @useResult
$Res call({
 String apiKey, PgyerInstallType installType, String installPassword, String updateDescription, String buildShortcutUrl
});




}
/// @nodoc
class __$PgyerConfigCopyWithImpl<$Res>
    implements _$PgyerConfigCopyWith<$Res> {
  __$PgyerConfigCopyWithImpl(this._self, this._then);

  final _PgyerConfig _self;
  final $Res Function(_PgyerConfig) _then;

/// Create a copy of PgyerConfig
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? apiKey = null,Object? installType = null,Object? installPassword = null,Object? updateDescription = null,Object? buildShortcutUrl = null,}) {
  return _then(_PgyerConfig(
apiKey: null == apiKey ? _self.apiKey : apiKey // ignore: cast_nullable_to_non_nullable
as String,installType: null == installType ? _self.installType : installType // ignore: cast_nullable_to_non_nullable
as PgyerInstallType,installPassword: null == installPassword ? _self.installPassword : installPassword // ignore: cast_nullable_to_non_nullable
as String,updateDescription: null == updateDescription ? _self.updateDescription : updateDescription // ignore: cast_nullable_to_non_nullable
as String,buildShortcutUrl: null == buildShortcutUrl ? _self.buildShortcutUrl : buildShortcutUrl // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
mixin _$BuglyUploadConfig {

 bool get enabled; String get jarPath; String get appId; String get appKey; String get bundleId; String get version; String get buildNo;
/// Create a copy of BuglyUploadConfig
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BuglyUploadConfigCopyWith<BuglyUploadConfig> get copyWith => _$BuglyUploadConfigCopyWithImpl<BuglyUploadConfig>(this as BuglyUploadConfig, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is BuglyUploadConfig&&(identical(other.enabled, enabled) || other.enabled == enabled)&&(identical(other.jarPath, jarPath) || other.jarPath == jarPath)&&(identical(other.appId, appId) || other.appId == appId)&&(identical(other.appKey, appKey) || other.appKey == appKey)&&(identical(other.bundleId, bundleId) || other.bundleId == bundleId)&&(identical(other.version, version) || other.version == version)&&(identical(other.buildNo, buildNo) || other.buildNo == buildNo));
}


@override
int get hashCode => Object.hash(runtimeType,enabled,jarPath,appId,appKey,bundleId,version,buildNo);

@override
String toString() {
  return 'BuglyUploadConfig(enabled: $enabled, jarPath: $jarPath, appId: $appId, appKey: $appKey, bundleId: $bundleId, version: $version, buildNo: $buildNo)';
}


}

/// @nodoc
abstract mixin class $BuglyUploadConfigCopyWith<$Res>  {
  factory $BuglyUploadConfigCopyWith(BuglyUploadConfig value, $Res Function(BuglyUploadConfig) _then) = _$BuglyUploadConfigCopyWithImpl;
@useResult
$Res call({
 bool enabled, String jarPath, String appId, String appKey, String bundleId, String version, String buildNo
});




}
/// @nodoc
class _$BuglyUploadConfigCopyWithImpl<$Res>
    implements $BuglyUploadConfigCopyWith<$Res> {
  _$BuglyUploadConfigCopyWithImpl(this._self, this._then);

  final BuglyUploadConfig _self;
  final $Res Function(BuglyUploadConfig) _then;

/// Create a copy of BuglyUploadConfig
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? enabled = null,Object? jarPath = null,Object? appId = null,Object? appKey = null,Object? bundleId = null,Object? version = null,Object? buildNo = null,}) {
  return _then(_self.copyWith(
enabled: null == enabled ? _self.enabled : enabled // ignore: cast_nullable_to_non_nullable
as bool,jarPath: null == jarPath ? _self.jarPath : jarPath // ignore: cast_nullable_to_non_nullable
as String,appId: null == appId ? _self.appId : appId // ignore: cast_nullable_to_non_nullable
as String,appKey: null == appKey ? _self.appKey : appKey // ignore: cast_nullable_to_non_nullable
as String,bundleId: null == bundleId ? _self.bundleId : bundleId // ignore: cast_nullable_to_non_nullable
as String,version: null == version ? _self.version : version // ignore: cast_nullable_to_non_nullable
as String,buildNo: null == buildNo ? _self.buildNo : buildNo // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [BuglyUploadConfig].
extension BuglyUploadConfigPatterns on BuglyUploadConfig {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _BuglyUploadConfig value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _BuglyUploadConfig() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _BuglyUploadConfig value)  $default,){
final _that = this;
switch (_that) {
case _BuglyUploadConfig():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _BuglyUploadConfig value)?  $default,){
final _that = this;
switch (_that) {
case _BuglyUploadConfig() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( bool enabled,  String jarPath,  String appId,  String appKey,  String bundleId,  String version,  String buildNo)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _BuglyUploadConfig() when $default != null:
return $default(_that.enabled,_that.jarPath,_that.appId,_that.appKey,_that.bundleId,_that.version,_that.buildNo);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( bool enabled,  String jarPath,  String appId,  String appKey,  String bundleId,  String version,  String buildNo)  $default,) {final _that = this;
switch (_that) {
case _BuglyUploadConfig():
return $default(_that.enabled,_that.jarPath,_that.appId,_that.appKey,_that.bundleId,_that.version,_that.buildNo);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( bool enabled,  String jarPath,  String appId,  String appKey,  String bundleId,  String version,  String buildNo)?  $default,) {final _that = this;
switch (_that) {
case _BuglyUploadConfig() when $default != null:
return $default(_that.enabled,_that.jarPath,_that.appId,_that.appKey,_that.bundleId,_that.version,_that.buildNo);case _:
  return null;

}
}

}

/// @nodoc


class _BuglyUploadConfig extends BuglyUploadConfig {
  const _BuglyUploadConfig({this.enabled = false, this.jarPath = '', this.appId = '', this.appKey = '', this.bundleId = '', this.version = '', this.buildNo = ''}): super._();
  

@override@JsonKey() final  bool enabled;
@override@JsonKey() final  String jarPath;
@override@JsonKey() final  String appId;
@override@JsonKey() final  String appKey;
@override@JsonKey() final  String bundleId;
@override@JsonKey() final  String version;
@override@JsonKey() final  String buildNo;

/// Create a copy of BuglyUploadConfig
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$BuglyUploadConfigCopyWith<_BuglyUploadConfig> get copyWith => __$BuglyUploadConfigCopyWithImpl<_BuglyUploadConfig>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _BuglyUploadConfig&&(identical(other.enabled, enabled) || other.enabled == enabled)&&(identical(other.jarPath, jarPath) || other.jarPath == jarPath)&&(identical(other.appId, appId) || other.appId == appId)&&(identical(other.appKey, appKey) || other.appKey == appKey)&&(identical(other.bundleId, bundleId) || other.bundleId == bundleId)&&(identical(other.version, version) || other.version == version)&&(identical(other.buildNo, buildNo) || other.buildNo == buildNo));
}


@override
int get hashCode => Object.hash(runtimeType,enabled,jarPath,appId,appKey,bundleId,version,buildNo);

@override
String toString() {
  return 'BuglyUploadConfig(enabled: $enabled, jarPath: $jarPath, appId: $appId, appKey: $appKey, bundleId: $bundleId, version: $version, buildNo: $buildNo)';
}


}

/// @nodoc
abstract mixin class _$BuglyUploadConfigCopyWith<$Res> implements $BuglyUploadConfigCopyWith<$Res> {
  factory _$BuglyUploadConfigCopyWith(_BuglyUploadConfig value, $Res Function(_BuglyUploadConfig) _then) = __$BuglyUploadConfigCopyWithImpl;
@override @useResult
$Res call({
 bool enabled, String jarPath, String appId, String appKey, String bundleId, String version, String buildNo
});




}
/// @nodoc
class __$BuglyUploadConfigCopyWithImpl<$Res>
    implements _$BuglyUploadConfigCopyWith<$Res> {
  __$BuglyUploadConfigCopyWithImpl(this._self, this._then);

  final _BuglyUploadConfig _self;
  final $Res Function(_BuglyUploadConfig) _then;

/// Create a copy of BuglyUploadConfig
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? enabled = null,Object? jarPath = null,Object? appId = null,Object? appKey = null,Object? bundleId = null,Object? version = null,Object? buildNo = null,}) {
  return _then(_BuglyUploadConfig(
enabled: null == enabled ? _self.enabled : enabled // ignore: cast_nullable_to_non_nullable
as bool,jarPath: null == jarPath ? _self.jarPath : jarPath // ignore: cast_nullable_to_non_nullable
as String,appId: null == appId ? _self.appId : appId // ignore: cast_nullable_to_non_nullable
as String,appKey: null == appKey ? _self.appKey : appKey // ignore: cast_nullable_to_non_nullable
as String,bundleId: null == bundleId ? _self.bundleId : bundleId // ignore: cast_nullable_to_non_nullable
as String,version: null == version ? _self.version : version // ignore: cast_nullable_to_non_nullable
as String,buildNo: null == buildNo ? _self.buildNo : buildNo // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
mixin _$FlutterProject {

 String get name; String get alias; String get path; DateTime get lastOpened; String? get description; String? get fvmVersion; bool get hasAndroid; bool get hasIos; bool get hasWindows; bool get hasMacos; bool get pathExists; List<String> get androidFlavors; List<String> get androidBuildTypes; BuglyUploadConfig get bugly; PgyerConfig get pgyer; FirConfig get fir; List<String> get selectedFlavors; ProjectBuildMode get lastBuildMode; ProjectBuildTarget get lastBuildTarget; bool get cleanBeforeBuild; String get androidTargetPlatform; bool get useCustomCommands; String get customCommandCode;
/// Create a copy of FlutterProject
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FlutterProjectCopyWith<FlutterProject> get copyWith => _$FlutterProjectCopyWithImpl<FlutterProject>(this as FlutterProject, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FlutterProject&&(identical(other.name, name) || other.name == name)&&(identical(other.alias, alias) || other.alias == alias)&&(identical(other.path, path) || other.path == path)&&(identical(other.lastOpened, lastOpened) || other.lastOpened == lastOpened)&&(identical(other.description, description) || other.description == description)&&(identical(other.fvmVersion, fvmVersion) || other.fvmVersion == fvmVersion)&&(identical(other.hasAndroid, hasAndroid) || other.hasAndroid == hasAndroid)&&(identical(other.hasIos, hasIos) || other.hasIos == hasIos)&&(identical(other.hasWindows, hasWindows) || other.hasWindows == hasWindows)&&(identical(other.hasMacos, hasMacos) || other.hasMacos == hasMacos)&&(identical(other.pathExists, pathExists) || other.pathExists == pathExists)&&const DeepCollectionEquality().equals(other.androidFlavors, androidFlavors)&&const DeepCollectionEquality().equals(other.androidBuildTypes, androidBuildTypes)&&(identical(other.bugly, bugly) || other.bugly == bugly)&&(identical(other.pgyer, pgyer) || other.pgyer == pgyer)&&(identical(other.fir, fir) || other.fir == fir)&&const DeepCollectionEquality().equals(other.selectedFlavors, selectedFlavors)&&(identical(other.lastBuildMode, lastBuildMode) || other.lastBuildMode == lastBuildMode)&&(identical(other.lastBuildTarget, lastBuildTarget) || other.lastBuildTarget == lastBuildTarget)&&(identical(other.cleanBeforeBuild, cleanBeforeBuild) || other.cleanBeforeBuild == cleanBeforeBuild)&&(identical(other.androidTargetPlatform, androidTargetPlatform) || other.androidTargetPlatform == androidTargetPlatform)&&(identical(other.useCustomCommands, useCustomCommands) || other.useCustomCommands == useCustomCommands)&&(identical(other.customCommandCode, customCommandCode) || other.customCommandCode == customCommandCode));
}


@override
int get hashCode => Object.hashAll([runtimeType,name,alias,path,lastOpened,description,fvmVersion,hasAndroid,hasIos,hasWindows,hasMacos,pathExists,const DeepCollectionEquality().hash(androidFlavors),const DeepCollectionEquality().hash(androidBuildTypes),bugly,pgyer,fir,const DeepCollectionEquality().hash(selectedFlavors),lastBuildMode,lastBuildTarget,cleanBeforeBuild,androidTargetPlatform,useCustomCommands,customCommandCode]);

@override
String toString() {
  return 'FlutterProject(name: $name, alias: $alias, path: $path, lastOpened: $lastOpened, description: $description, fvmVersion: $fvmVersion, hasAndroid: $hasAndroid, hasIos: $hasIos, hasWindows: $hasWindows, hasMacos: $hasMacos, pathExists: $pathExists, androidFlavors: $androidFlavors, androidBuildTypes: $androidBuildTypes, bugly: $bugly, pgyer: $pgyer, fir: $fir, selectedFlavors: $selectedFlavors, lastBuildMode: $lastBuildMode, lastBuildTarget: $lastBuildTarget, cleanBeforeBuild: $cleanBeforeBuild, androidTargetPlatform: $androidTargetPlatform, useCustomCommands: $useCustomCommands, customCommandCode: $customCommandCode)';
}


}

/// @nodoc
abstract mixin class $FlutterProjectCopyWith<$Res>  {
  factory $FlutterProjectCopyWith(FlutterProject value, $Res Function(FlutterProject) _then) = _$FlutterProjectCopyWithImpl;
@useResult
$Res call({
 String name, String alias, String path, DateTime lastOpened, String? description, String? fvmVersion, bool hasAndroid, bool hasIos, bool hasWindows, bool hasMacos, bool pathExists, List<String> androidFlavors, List<String> androidBuildTypes, BuglyUploadConfig bugly, PgyerConfig pgyer, FirConfig fir, List<String> selectedFlavors, ProjectBuildMode lastBuildMode, ProjectBuildTarget lastBuildTarget, bool cleanBeforeBuild, String androidTargetPlatform, bool useCustomCommands, String customCommandCode
});


$BuglyUploadConfigCopyWith<$Res> get bugly;$PgyerConfigCopyWith<$Res> get pgyer;$FirConfigCopyWith<$Res> get fir;

}
/// @nodoc
class _$FlutterProjectCopyWithImpl<$Res>
    implements $FlutterProjectCopyWith<$Res> {
  _$FlutterProjectCopyWithImpl(this._self, this._then);

  final FlutterProject _self;
  final $Res Function(FlutterProject) _then;

/// Create a copy of FlutterProject
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? name = null,Object? alias = null,Object? path = null,Object? lastOpened = null,Object? description = freezed,Object? fvmVersion = freezed,Object? hasAndroid = null,Object? hasIos = null,Object? hasWindows = null,Object? hasMacos = null,Object? pathExists = null,Object? androidFlavors = null,Object? androidBuildTypes = null,Object? bugly = null,Object? pgyer = null,Object? fir = null,Object? selectedFlavors = null,Object? lastBuildMode = null,Object? lastBuildTarget = null,Object? cleanBeforeBuild = null,Object? androidTargetPlatform = null,Object? useCustomCommands = null,Object? customCommandCode = null,}) {
  return _then(_self.copyWith(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,alias: null == alias ? _self.alias : alias // ignore: cast_nullable_to_non_nullable
as String,path: null == path ? _self.path : path // ignore: cast_nullable_to_non_nullable
as String,lastOpened: null == lastOpened ? _self.lastOpened : lastOpened // ignore: cast_nullable_to_non_nullable
as DateTime,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,fvmVersion: freezed == fvmVersion ? _self.fvmVersion : fvmVersion // ignore: cast_nullable_to_non_nullable
as String?,hasAndroid: null == hasAndroid ? _self.hasAndroid : hasAndroid // ignore: cast_nullable_to_non_nullable
as bool,hasIos: null == hasIos ? _self.hasIos : hasIos // ignore: cast_nullable_to_non_nullable
as bool,hasWindows: null == hasWindows ? _self.hasWindows : hasWindows // ignore: cast_nullable_to_non_nullable
as bool,hasMacos: null == hasMacos ? _self.hasMacos : hasMacos // ignore: cast_nullable_to_non_nullable
as bool,pathExists: null == pathExists ? _self.pathExists : pathExists // ignore: cast_nullable_to_non_nullable
as bool,androidFlavors: null == androidFlavors ? _self.androidFlavors : androidFlavors // ignore: cast_nullable_to_non_nullable
as List<String>,androidBuildTypes: null == androidBuildTypes ? _self.androidBuildTypes : androidBuildTypes // ignore: cast_nullable_to_non_nullable
as List<String>,bugly: null == bugly ? _self.bugly : bugly // ignore: cast_nullable_to_non_nullable
as BuglyUploadConfig,pgyer: null == pgyer ? _self.pgyer : pgyer // ignore: cast_nullable_to_non_nullable
as PgyerConfig,fir: null == fir ? _self.fir : fir // ignore: cast_nullable_to_non_nullable
as FirConfig,selectedFlavors: null == selectedFlavors ? _self.selectedFlavors : selectedFlavors // ignore: cast_nullable_to_non_nullable
as List<String>,lastBuildMode: null == lastBuildMode ? _self.lastBuildMode : lastBuildMode // ignore: cast_nullable_to_non_nullable
as ProjectBuildMode,lastBuildTarget: null == lastBuildTarget ? _self.lastBuildTarget : lastBuildTarget // ignore: cast_nullable_to_non_nullable
as ProjectBuildTarget,cleanBeforeBuild: null == cleanBeforeBuild ? _self.cleanBeforeBuild : cleanBeforeBuild // ignore: cast_nullable_to_non_nullable
as bool,androidTargetPlatform: null == androidTargetPlatform ? _self.androidTargetPlatform : androidTargetPlatform // ignore: cast_nullable_to_non_nullable
as String,useCustomCommands: null == useCustomCommands ? _self.useCustomCommands : useCustomCommands // ignore: cast_nullable_to_non_nullable
as bool,customCommandCode: null == customCommandCode ? _self.customCommandCode : customCommandCode // ignore: cast_nullable_to_non_nullable
as String,
  ));
}
/// Create a copy of FlutterProject
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$BuglyUploadConfigCopyWith<$Res> get bugly {
  
  return $BuglyUploadConfigCopyWith<$Res>(_self.bugly, (value) {
    return _then(_self.copyWith(bugly: value));
  });
}/// Create a copy of FlutterProject
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PgyerConfigCopyWith<$Res> get pgyer {
  
  return $PgyerConfigCopyWith<$Res>(_self.pgyer, (value) {
    return _then(_self.copyWith(pgyer: value));
  });
}/// Create a copy of FlutterProject
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$FirConfigCopyWith<$Res> get fir {
  
  return $FirConfigCopyWith<$Res>(_self.fir, (value) {
    return _then(_self.copyWith(fir: value));
  });
}
}


/// Adds pattern-matching-related methods to [FlutterProject].
extension FlutterProjectPatterns on FlutterProject {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _FlutterProject value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _FlutterProject() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _FlutterProject value)  $default,){
final _that = this;
switch (_that) {
case _FlutterProject():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _FlutterProject value)?  $default,){
final _that = this;
switch (_that) {
case _FlutterProject() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String name,  String alias,  String path,  DateTime lastOpened,  String? description,  String? fvmVersion,  bool hasAndroid,  bool hasIos,  bool hasWindows,  bool hasMacos,  bool pathExists,  List<String> androidFlavors,  List<String> androidBuildTypes,  BuglyUploadConfig bugly,  PgyerConfig pgyer,  FirConfig fir,  List<String> selectedFlavors,  ProjectBuildMode lastBuildMode,  ProjectBuildTarget lastBuildTarget,  bool cleanBeforeBuild,  String androidTargetPlatform,  bool useCustomCommands,  String customCommandCode)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _FlutterProject() when $default != null:
return $default(_that.name,_that.alias,_that.path,_that.lastOpened,_that.description,_that.fvmVersion,_that.hasAndroid,_that.hasIos,_that.hasWindows,_that.hasMacos,_that.pathExists,_that.androidFlavors,_that.androidBuildTypes,_that.bugly,_that.pgyer,_that.fir,_that.selectedFlavors,_that.lastBuildMode,_that.lastBuildTarget,_that.cleanBeforeBuild,_that.androidTargetPlatform,_that.useCustomCommands,_that.customCommandCode);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String name,  String alias,  String path,  DateTime lastOpened,  String? description,  String? fvmVersion,  bool hasAndroid,  bool hasIos,  bool hasWindows,  bool hasMacos,  bool pathExists,  List<String> androidFlavors,  List<String> androidBuildTypes,  BuglyUploadConfig bugly,  PgyerConfig pgyer,  FirConfig fir,  List<String> selectedFlavors,  ProjectBuildMode lastBuildMode,  ProjectBuildTarget lastBuildTarget,  bool cleanBeforeBuild,  String androidTargetPlatform,  bool useCustomCommands,  String customCommandCode)  $default,) {final _that = this;
switch (_that) {
case _FlutterProject():
return $default(_that.name,_that.alias,_that.path,_that.lastOpened,_that.description,_that.fvmVersion,_that.hasAndroid,_that.hasIos,_that.hasWindows,_that.hasMacos,_that.pathExists,_that.androidFlavors,_that.androidBuildTypes,_that.bugly,_that.pgyer,_that.fir,_that.selectedFlavors,_that.lastBuildMode,_that.lastBuildTarget,_that.cleanBeforeBuild,_that.androidTargetPlatform,_that.useCustomCommands,_that.customCommandCode);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String name,  String alias,  String path,  DateTime lastOpened,  String? description,  String? fvmVersion,  bool hasAndroid,  bool hasIos,  bool hasWindows,  bool hasMacos,  bool pathExists,  List<String> androidFlavors,  List<String> androidBuildTypes,  BuglyUploadConfig bugly,  PgyerConfig pgyer,  FirConfig fir,  List<String> selectedFlavors,  ProjectBuildMode lastBuildMode,  ProjectBuildTarget lastBuildTarget,  bool cleanBeforeBuild,  String androidTargetPlatform,  bool useCustomCommands,  String customCommandCode)?  $default,) {final _that = this;
switch (_that) {
case _FlutterProject() when $default != null:
return $default(_that.name,_that.alias,_that.path,_that.lastOpened,_that.description,_that.fvmVersion,_that.hasAndroid,_that.hasIos,_that.hasWindows,_that.hasMacos,_that.pathExists,_that.androidFlavors,_that.androidBuildTypes,_that.bugly,_that.pgyer,_that.fir,_that.selectedFlavors,_that.lastBuildMode,_that.lastBuildTarget,_that.cleanBeforeBuild,_that.androidTargetPlatform,_that.useCustomCommands,_that.customCommandCode);case _:
  return null;

}
}

}

/// @nodoc


class _FlutterProject extends FlutterProject {
  const _FlutterProject({required this.name, this.alias = '', required this.path, required this.lastOpened, this.description, this.fvmVersion, this.hasAndroid = false, this.hasIos = false, this.hasWindows = false, this.hasMacos = false, this.pathExists = true, final  List<String> androidFlavors = const <String>[], final  List<String> androidBuildTypes = const <String>[], this.bugly = const BuglyUploadConfig(), this.pgyer = const PgyerConfig(), this.fir = const FirConfig(), final  List<String> selectedFlavors = const <String>[], this.lastBuildMode = ProjectBuildMode.release, this.lastBuildTarget = ProjectBuildTarget.apk, this.cleanBeforeBuild = false, this.androidTargetPlatform = 'android-arm64', this.useCustomCommands = false, this.customCommandCode = ''}): _androidFlavors = androidFlavors,_androidBuildTypes = androidBuildTypes,_selectedFlavors = selectedFlavors,super._();
  

@override final  String name;
@override@JsonKey() final  String alias;
@override final  String path;
@override final  DateTime lastOpened;
@override final  String? description;
@override final  String? fvmVersion;
@override@JsonKey() final  bool hasAndroid;
@override@JsonKey() final  bool hasIos;
@override@JsonKey() final  bool hasWindows;
@override@JsonKey() final  bool hasMacos;
@override@JsonKey() final  bool pathExists;
 final  List<String> _androidFlavors;
@override@JsonKey() List<String> get androidFlavors {
  if (_androidFlavors is EqualUnmodifiableListView) return _androidFlavors;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_androidFlavors);
}

 final  List<String> _androidBuildTypes;
@override@JsonKey() List<String> get androidBuildTypes {
  if (_androidBuildTypes is EqualUnmodifiableListView) return _androidBuildTypes;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_androidBuildTypes);
}

@override@JsonKey() final  BuglyUploadConfig bugly;
@override@JsonKey() final  PgyerConfig pgyer;
@override@JsonKey() final  FirConfig fir;
 final  List<String> _selectedFlavors;
@override@JsonKey() List<String> get selectedFlavors {
  if (_selectedFlavors is EqualUnmodifiableListView) return _selectedFlavors;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_selectedFlavors);
}

@override@JsonKey() final  ProjectBuildMode lastBuildMode;
@override@JsonKey() final  ProjectBuildTarget lastBuildTarget;
@override@JsonKey() final  bool cleanBeforeBuild;
@override@JsonKey() final  String androidTargetPlatform;
@override@JsonKey() final  bool useCustomCommands;
@override@JsonKey() final  String customCommandCode;

/// Create a copy of FlutterProject
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$FlutterProjectCopyWith<_FlutterProject> get copyWith => __$FlutterProjectCopyWithImpl<_FlutterProject>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _FlutterProject&&(identical(other.name, name) || other.name == name)&&(identical(other.alias, alias) || other.alias == alias)&&(identical(other.path, path) || other.path == path)&&(identical(other.lastOpened, lastOpened) || other.lastOpened == lastOpened)&&(identical(other.description, description) || other.description == description)&&(identical(other.fvmVersion, fvmVersion) || other.fvmVersion == fvmVersion)&&(identical(other.hasAndroid, hasAndroid) || other.hasAndroid == hasAndroid)&&(identical(other.hasIos, hasIos) || other.hasIos == hasIos)&&(identical(other.hasWindows, hasWindows) || other.hasWindows == hasWindows)&&(identical(other.hasMacos, hasMacos) || other.hasMacos == hasMacos)&&(identical(other.pathExists, pathExists) || other.pathExists == pathExists)&&const DeepCollectionEquality().equals(other._androidFlavors, _androidFlavors)&&const DeepCollectionEquality().equals(other._androidBuildTypes, _androidBuildTypes)&&(identical(other.bugly, bugly) || other.bugly == bugly)&&(identical(other.pgyer, pgyer) || other.pgyer == pgyer)&&(identical(other.fir, fir) || other.fir == fir)&&const DeepCollectionEquality().equals(other._selectedFlavors, _selectedFlavors)&&(identical(other.lastBuildMode, lastBuildMode) || other.lastBuildMode == lastBuildMode)&&(identical(other.lastBuildTarget, lastBuildTarget) || other.lastBuildTarget == lastBuildTarget)&&(identical(other.cleanBeforeBuild, cleanBeforeBuild) || other.cleanBeforeBuild == cleanBeforeBuild)&&(identical(other.androidTargetPlatform, androidTargetPlatform) || other.androidTargetPlatform == androidTargetPlatform)&&(identical(other.useCustomCommands, useCustomCommands) || other.useCustomCommands == useCustomCommands)&&(identical(other.customCommandCode, customCommandCode) || other.customCommandCode == customCommandCode));
}


@override
int get hashCode => Object.hashAll([runtimeType,name,alias,path,lastOpened,description,fvmVersion,hasAndroid,hasIos,hasWindows,hasMacos,pathExists,const DeepCollectionEquality().hash(_androidFlavors),const DeepCollectionEquality().hash(_androidBuildTypes),bugly,pgyer,fir,const DeepCollectionEquality().hash(_selectedFlavors),lastBuildMode,lastBuildTarget,cleanBeforeBuild,androidTargetPlatform,useCustomCommands,customCommandCode]);

@override
String toString() {
  return 'FlutterProject(name: $name, alias: $alias, path: $path, lastOpened: $lastOpened, description: $description, fvmVersion: $fvmVersion, hasAndroid: $hasAndroid, hasIos: $hasIos, hasWindows: $hasWindows, hasMacos: $hasMacos, pathExists: $pathExists, androidFlavors: $androidFlavors, androidBuildTypes: $androidBuildTypes, bugly: $bugly, pgyer: $pgyer, fir: $fir, selectedFlavors: $selectedFlavors, lastBuildMode: $lastBuildMode, lastBuildTarget: $lastBuildTarget, cleanBeforeBuild: $cleanBeforeBuild, androidTargetPlatform: $androidTargetPlatform, useCustomCommands: $useCustomCommands, customCommandCode: $customCommandCode)';
}


}

/// @nodoc
abstract mixin class _$FlutterProjectCopyWith<$Res> implements $FlutterProjectCopyWith<$Res> {
  factory _$FlutterProjectCopyWith(_FlutterProject value, $Res Function(_FlutterProject) _then) = __$FlutterProjectCopyWithImpl;
@override @useResult
$Res call({
 String name, String alias, String path, DateTime lastOpened, String? description, String? fvmVersion, bool hasAndroid, bool hasIos, bool hasWindows, bool hasMacos, bool pathExists, List<String> androidFlavors, List<String> androidBuildTypes, BuglyUploadConfig bugly, PgyerConfig pgyer, FirConfig fir, List<String> selectedFlavors, ProjectBuildMode lastBuildMode, ProjectBuildTarget lastBuildTarget, bool cleanBeforeBuild, String androidTargetPlatform, bool useCustomCommands, String customCommandCode
});


@override $BuglyUploadConfigCopyWith<$Res> get bugly;@override $PgyerConfigCopyWith<$Res> get pgyer;@override $FirConfigCopyWith<$Res> get fir;

}
/// @nodoc
class __$FlutterProjectCopyWithImpl<$Res>
    implements _$FlutterProjectCopyWith<$Res> {
  __$FlutterProjectCopyWithImpl(this._self, this._then);

  final _FlutterProject _self;
  final $Res Function(_FlutterProject) _then;

/// Create a copy of FlutterProject
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? name = null,Object? alias = null,Object? path = null,Object? lastOpened = null,Object? description = freezed,Object? fvmVersion = freezed,Object? hasAndroid = null,Object? hasIos = null,Object? hasWindows = null,Object? hasMacos = null,Object? pathExists = null,Object? androidFlavors = null,Object? androidBuildTypes = null,Object? bugly = null,Object? pgyer = null,Object? fir = null,Object? selectedFlavors = null,Object? lastBuildMode = null,Object? lastBuildTarget = null,Object? cleanBeforeBuild = null,Object? androidTargetPlatform = null,Object? useCustomCommands = null,Object? customCommandCode = null,}) {
  return _then(_FlutterProject(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,alias: null == alias ? _self.alias : alias // ignore: cast_nullable_to_non_nullable
as String,path: null == path ? _self.path : path // ignore: cast_nullable_to_non_nullable
as String,lastOpened: null == lastOpened ? _self.lastOpened : lastOpened // ignore: cast_nullable_to_non_nullable
as DateTime,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,fvmVersion: freezed == fvmVersion ? _self.fvmVersion : fvmVersion // ignore: cast_nullable_to_non_nullable
as String?,hasAndroid: null == hasAndroid ? _self.hasAndroid : hasAndroid // ignore: cast_nullable_to_non_nullable
as bool,hasIos: null == hasIos ? _self.hasIos : hasIos // ignore: cast_nullable_to_non_nullable
as bool,hasWindows: null == hasWindows ? _self.hasWindows : hasWindows // ignore: cast_nullable_to_non_nullable
as bool,hasMacos: null == hasMacos ? _self.hasMacos : hasMacos // ignore: cast_nullable_to_non_nullable
as bool,pathExists: null == pathExists ? _self.pathExists : pathExists // ignore: cast_nullable_to_non_nullable
as bool,androidFlavors: null == androidFlavors ? _self._androidFlavors : androidFlavors // ignore: cast_nullable_to_non_nullable
as List<String>,androidBuildTypes: null == androidBuildTypes ? _self._androidBuildTypes : androidBuildTypes // ignore: cast_nullable_to_non_nullable
as List<String>,bugly: null == bugly ? _self.bugly : bugly // ignore: cast_nullable_to_non_nullable
as BuglyUploadConfig,pgyer: null == pgyer ? _self.pgyer : pgyer // ignore: cast_nullable_to_non_nullable
as PgyerConfig,fir: null == fir ? _self.fir : fir // ignore: cast_nullable_to_non_nullable
as FirConfig,selectedFlavors: null == selectedFlavors ? _self._selectedFlavors : selectedFlavors // ignore: cast_nullable_to_non_nullable
as List<String>,lastBuildMode: null == lastBuildMode ? _self.lastBuildMode : lastBuildMode // ignore: cast_nullable_to_non_nullable
as ProjectBuildMode,lastBuildTarget: null == lastBuildTarget ? _self.lastBuildTarget : lastBuildTarget // ignore: cast_nullable_to_non_nullable
as ProjectBuildTarget,cleanBeforeBuild: null == cleanBeforeBuild ? _self.cleanBeforeBuild : cleanBeforeBuild // ignore: cast_nullable_to_non_nullable
as bool,androidTargetPlatform: null == androidTargetPlatform ? _self.androidTargetPlatform : androidTargetPlatform // ignore: cast_nullable_to_non_nullable
as String,useCustomCommands: null == useCustomCommands ? _self.useCustomCommands : useCustomCommands // ignore: cast_nullable_to_non_nullable
as bool,customCommandCode: null == customCommandCode ? _self.customCommandCode : customCommandCode // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

/// Create a copy of FlutterProject
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$BuglyUploadConfigCopyWith<$Res> get bugly {
  
  return $BuglyUploadConfigCopyWith<$Res>(_self.bugly, (value) {
    return _then(_self.copyWith(bugly: value));
  });
}/// Create a copy of FlutterProject
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PgyerConfigCopyWith<$Res> get pgyer {
  
  return $PgyerConfigCopyWith<$Res>(_self.pgyer, (value) {
    return _then(_self.copyWith(pgyer: value));
  });
}/// Create a copy of FlutterProject
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$FirConfigCopyWith<$Res> get fir {
  
  return $FirConfigCopyWith<$Res>(_self.fir, (value) {
    return _then(_self.copyWith(fir: value));
  });
}
}

// dart format on
