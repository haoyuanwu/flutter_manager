import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:pub_semver/pub_semver.dart';

import '../domain/project_dependency.dart';

class PubPackageService {
  PubPackageService(this._dio, {File? cacheFile})
    : _cacheFile = cacheFile ?? _defaultCacheFile();
  final Dio _dio;
  final File _cacheFile;
  List<String>? _names;
  DateTime? _namesFetchedAt;
  final _metadata = <String, PubPackage>{};
  final _metadataFetchedAt = <String, DateTime>{};

  static File _defaultCacheFile() {
    final home =
        Platform.environment[Platform.isWindows ? 'USERPROFILE' : 'HOME'] ??
        Directory.systemTemp.path;
    return File(
      '$home${Platform.pathSeparator}.fvm_manager${Platform.pathSeparator}cache${Platform.pathSeparator}pub-package-names.json',
    );
  }

  Future<List<String>> _packageNames(CancelToken? token) async {
    if (_names == null) {
      try {
        final cached = jsonDecode(await _cacheFile.readAsString()) as Map;
        _names = (cached['packages'] as List).cast<String>();
        _namesFetchedAt = DateTime.fromMillisecondsSinceEpoch(
          cached['fetchedAt'] as int,
        );
      } on Object {
        // Missing or damaged caches are refreshed from pub.dev.
      }
    }
    if (_names != null &&
        _namesFetchedAt != null &&
        DateTime.now().difference(_namesFetchedAt!) <
            const Duration(hours: 8)) {
      return _names!;
    }
    final response = await _dio.get<Map<String, dynamic>>(
      'https://pub.dev/api/package-name-completion-data',
      options: Options(
        headers: {'accept-encoding': 'gzip'},
        receiveTimeout: const Duration(seconds: 20),
      ),
      cancelToken: token,
    );
    final names = (response.data?['packages'] as List).cast<String>();
    _names = names;
    _namesFetchedAt = DateTime.now();
    try {
      await _cacheFile.parent.create(recursive: true);
      await _cacheFile.writeAsString(
        jsonEncode({
          'fetchedAt': _namesFetchedAt!.millisecondsSinceEpoch,
          'packages': names,
        }),
        flush: true,
      );
    } on FileSystemException {
      // Read-only cache locations must not prevent package search.
    }
    return names;
  }

  Future<PubPackage?> _package(String name, CancelToken? token) async {
    final fetchedAt = _metadataFetchedAt[name];
    if (fetchedAt != null &&
        DateTime.now().difference(fetchedAt) < const Duration(minutes: 2)) {
      return _metadata[name];
    }
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        'https://pub.dev/api/packages/${Uri.encodeComponent(name)}',
        options: Options(receiveTimeout: const Duration(seconds: 20)),
        cancelToken: token,
      );
      final data = response.data!;
      if (data['isDiscontinued'] == true) return null;
      final latest = data['latest'] as Map;
      final version = latest['version'] as String;
      Version.parse(version);
      final package = PubPackage(
        name: name,
        version: version,
        description: '${(latest['pubspec'] as Map)['description'] ?? ''}',
        downloadCount30Days: await _downloadCount(name, token),
      );
      _metadata[name] = package;
      _metadataFetchedAt[name] = DateTime.now();
      return package;
    } on DioException catch (error) {
      if (error.response?.statusCode == 404) return null;
      rethrow;
    }
  }

  Future<int?> _downloadCount(String name, CancelToken? token) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        'https://pub.dev/api/packages/${Uri.encodeComponent(name)}/score',
        options: Options(receiveTimeout: const Duration(seconds: 8)),
        cancelToken: token,
      );
      final count = response.data?['downloadCount30Days'];
      return count is int && count >= 0 ? count : null;
    } on DioException catch (error) {
      if (CancelToken.isCancel(error)) rethrow;
      // Download statistics are optional; metadata still supports adding a package.
      return null;
    }
  }

  Future<List<PubPackage>> search(
    String query, {
    CancelToken? cancelToken,
  }) async {
    final term = query.trim().toLowerCase();
    if (term.isEmpty) return const [];
    final names = await _packageNames(cancelToken);
    final matches = names.where((name) => name.contains(term)).toList();
    int rank(String name) => name == term
        ? 0
        : name.startsWith(term)
        ? 1
        : 2;
    matches.sort((a, b) => rank(a).compareTo(rank(b)));
    final requested = matches.take(10).toList();
    if (RegExp(r'^[a-z][a-z0-9_]*$').hasMatch(term) &&
        !requested.contains(term)) {
      requested.insert(0, term);
    }
    final results = <PubPackage>[];
    Object? failure;
    // Keep metadata requests bounded, and reuse metadata across searches.
    for (var offset = 0; offset < requested.length; offset += 3) {
      final packages = await Future.wait(
        requested.skip(offset).take(3).map((name) async {
          try {
            return await _package(name, cancelToken);
          } on Object catch (error) {
            if (error is DioException && CancelToken.isCancel(error)) rethrow;
            failure = error;
            return null;
          }
        }),
      );
      results.addAll(packages.whereType<PubPackage>());
    }
    if (results.isEmpty && failure != null) throw failure!;
    return results;
  }
}
