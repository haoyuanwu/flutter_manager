import 'dart:io';
import 'project_dependency.dart';

enum FlutterProjectTemplate {
  app('app', 'Flutter 应用'),
  module('module', '嵌入式 Flutter 模块'),
  package('package', 'Flutter Package'),
  plugin('plugin', '平台插件'),
  packageFfi('package_ffi', 'FFI Package'),
  pluginFfi('plugin_ffi', 'FFI 插件（旧模板）');

  const FlutterProjectTemplate(this.argument, this.label);
  final String argument;
  final String label;

  bool get supportsPlatforms =>
      this == app || this == plugin || this == pluginFfi;
  bool get supportsAndroidLanguage =>
      this == app || this == module || this == plugin;
}

enum FlutterAppStarter { standard, empty, sample }

class ProjectCreationOptions {
  const ProjectCreationOptions({
    required this.name,
    required this.parentDirectory,
    required this.directoryName,
    this.alias = '',
    this.description = 'A new Flutter project.',
    this.organization = 'com.example',
    this.template = FlutterProjectTemplate.app,
    this.platforms = const [
      'android',
      'ios',
      'web',
      'windows',
      'macos',
      'linux',
    ],
    this.androidLanguage = 'kotlin',
    this.starter = FlutterAppStarter.standard,
    this.sampleId = '',
    this.pubGet = true,
    this.offline = false,
    this.version = '1.0.0',
    this.buildNumber = '1',
    this.sdkDirectory,
    this.sdkVersion,
    this.pinSdk = true,
    this.dependencies = const [],
  });

  final String name;
  final String parentDirectory;
  final String directoryName;
  final String alias;
  final String description;
  final String organization;
  final FlutterProjectTemplate template;
  final List<String> platforms;
  final String androidLanguage;
  final FlutterAppStarter starter;
  final String sampleId;
  final bool pubGet;
  final bool offline;
  final String version;
  final String buildNumber;
  final String? sdkDirectory;
  final String? sdkVersion;
  final bool pinSdk;
  final List<ProjectDependency> dependencies;

  String get projectPath => Directory(parentDirectory.trim()).absolute.uri
      .resolve(Uri.encodeComponent(directoryName.trim()))
      .toFilePath();

  static String? validateName(String? value) {
    final name = value?.trim() ?? '';
    if (!RegExp(r'^[a-z][a-z0-9_]*$').hasMatch(name)) {
      return '以小写字母开头，仅使用小写字母、数字和下划线';
    }
    const reserved = {
      'assert',
      'break',
      'case',
      'catch',
      'class',
      'const',
      'continue',
      'default',
      'do',
      'else',
      'enum',
      'extends',
      'false',
      'final',
      'finally',
      'for',
      'if',
      'in',
      'is',
      'new',
      'null',
      'rethrow',
      'return',
      'super',
      'switch',
      'this',
      'throw',
      'true',
      'try',
      'var',
      'void',
      'while',
      'with',
      'flutter',
    };
    return reserved.contains(name) ? '不能使用 Dart 保留字或 flutter 作为项目名' : null;
  }

  static String? validateDirectoryName(String? value) {
    final name = value?.trim() ?? '';
    if (name.isEmpty ||
        name == '.' ||
        name == '..' ||
        RegExp(r'[<>:"/\\|?*\x00-\x1f]').hasMatch(name) ||
        name.endsWith('.') ||
        name.endsWith(' ') ||
        RegExp(
          r'^(con|prn|aux|nul|com[1-9]|lpt[1-9])(?:\.|$)',
          caseSensitive: false,
        ).hasMatch(name)) {
      return '请输入有效的文件夹名称，不包含路径分隔符或系统保留名称';
    }
    return null;
  }

  static String? validateOrganization(String? value) =>
      RegExp(
        r'^[a-zA-Z][a-zA-Z0-9_]*(?:\.[a-zA-Z][a-zA-Z0-9_]*)+$',
      ).hasMatch(value?.trim() ?? '')
      ? null
      : '请输入反向域名，例如 com.example';

  void validate() {
    final dependencyNames = <String>{};
    for (final dependency in dependencies) {
      dependency.validate();
      if (dependency.name == name.trim() ||
          !dependencyNames.add(dependency.name)) {
        throw ArgumentError('依赖不能与项目同名，也不能重复添加：${dependency.name}');
      }
    }
    final error =
        validateName(name) ??
        validateDirectoryName(directoryName) ??
        validateOrganization(organization);
    if (error != null) throw ArgumentError(error);
    if (parentDirectory.trim().isEmpty) throw ArgumentError('请选择保存位置');
    if (description.trim().isEmpty) throw ArgumentError('请填写项目描述');
    if (!RegExp(
          r'^\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?$',
        ).hasMatch(version.trim()) ||
        !RegExp(r'^[1-9]\d*$').hasMatch(buildNumber.trim())) {
      throw ArgumentError('版本号应类似 1.0.0，Build No 应为正整数');
    }
    if (!const ['kotlin', 'java'].contains(androidLanguage)) {
      throw ArgumentError('无效的 Android 语言');
    }
    if (template.supportsPlatforms &&
        (platforms.isEmpty ||
            platforms.any(
              (p) => !const [
                'android',
                'ios',
                'web',
                'windows',
                'macos',
                'linux',
                'darwin',
              ].contains(p),
            ))) {
      throw ArgumentError('请至少选择一个有效的目标平台');
    }
    if (platforms.contains('darwin') &&
        template.supportsPlatforms &&
        (template != FlutterProjectTemplate.plugin ||
            platforms.contains('ios') ||
            platforms.contains('macos'))) {
      throw ArgumentError('Darwin 仅供平台插件使用，不能与 iOS / macOS 同时选择');
    }
    if (template == FlutterProjectTemplate.pluginFfi &&
        platforms.contains('web')) {
      throw ArgumentError('FFI 插件不支持 Web');
    }
    if (template == FlutterProjectTemplate.app &&
        starter == FlutterAppStarter.sample &&
        !RegExp(r'^[a-zA-Z0-9_.-]+$').hasMatch(sampleId.trim())) {
      throw ArgumentError('请填写有效的 Flutter 示例 ID');
    }
    if (sdkDirectory != null && sdkDirectory!.trim().isEmpty) {
      throw ArgumentError('Flutter SDK 路径无效');
    }
  }

  List<String> get arguments => [
    'create',
    '--no-overwrite',
    '--project-name',
    name.trim(),
    '--description',
    description.trim(),
    '--org',
    organization.trim(),
    '--template',
    template.argument,
    if (template.supportsPlatforms) '--platforms=${platforms.join(',')}',
    if (template.supportsAndroidLanguage &&
        (template == FlutterProjectTemplate.module ||
            platforms.contains('android')))
      '--android-language=$androidLanguage',
    if (template == FlutterProjectTemplate.app &&
        starter == FlutterAppStarter.empty)
      '--empty',
    if (template == FlutterProjectTemplate.app &&
        starter == FlutterAppStarter.sample)
      '--sample=${sampleId.trim()}',
    '--no-pub',
    projectPath,
  ];
}
