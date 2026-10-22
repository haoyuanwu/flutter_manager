import 'package:pub_semver/pub_semver.dart';

class ProjectDependency {
  const ProjectDependency({
    required this.name,
    required this.constraint,
    this.development = false,
  });
  final String name;
  final String constraint;
  final bool development;

  static String? validateConstraint(String? value) {
    if (value == null || value.trim().isEmpty) return '请填写版本约束';
    try {
      VersionConstraint.parse(value.trim());
      return null;
    } on FormatException {
      return '无效的版本约束';
    }
  }

  void validate() {
    if (!RegExp(r'^[a-z][a-z0-9_]*$').hasMatch(name) ||
        const [
          'flutter',
          'flutter_test',
          'flutter_driver',
          'flutter_localizations',
          'flutter_web_plugins',
        ].contains(name)) {
      throw ArgumentError('不能添加无效包名或覆盖 Flutter SDK 依赖：$name');
    }
    final error = validateConstraint(constraint);
    if (error != null) throw ArgumentError('$name：$error');
  }
}

class PubPackage {
  const PubPackage({
    required this.name,
    required this.version,
    required this.description,
    this.downloadCount30Days,
  });
  final String name;
  final String version;
  final String description;
  final int? downloadCount30Days;
}
