import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_manager/src/data/pub_package_service.dart';

class _Adapter implements HttpClientAdapter {
  final requests = <String>[];
  Object? downloadCount = 1234567;
  int scoreStatus = 200;
  bool cancelScore = false;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options.path);
    Object data;
    var status = 200;
    if (options.path.endsWith('package-name-completion-data')) {
      data = {
        'packages': ['dio_cache', 'dio', 'http', 'discontinued'],
      };
    } else if (options.path.endsWith('/score')) {
      if (cancelScore) {
        throw DioException(
          requestOptions: options,
          type: DioExceptionType.cancel,
        );
      }
      status = scoreStatus;
      data = {'downloadCount30Days': downloadCount};
    } else {
      final name = Uri.parse(options.path).pathSegments.last;
      if (name == 'missing') {
        status = 404;
        data = {};
      } else {
        data = {
          'isDiscontinued': name == 'discontinued',
          'latest': {
            'version': '1.2.3',
            'pubspec': {'description': 'Description of $name'},
          },
        };
      }
    }
    return ResponseBody.fromString(
      jsonEncode(data),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late Directory root;
  late Dio dio;
  late _Adapter adapter;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('pub_packages_');
    adapter = _Adapter();
    dio = Dio()..httpClientAdapter = adapter;
  });
  tearDown(() {
    dio.close();
    return root.delete(recursive: true);
  });

  test(
    'search uses supported name index, ranks exact matches and caches metadata',
    () async {
      final service = PubPackageService(
        dio,
        cacheFile: File('${root.path}/names.json'),
      );
      final results = await service.search('dio');
      expect(results.first.name, 'dio');
      expect(results.first.version, '1.2.3');
      expect(results.first.description, 'Description of dio');
      expect(results.first.downloadCount30Days, 1234567);
      final count = adapter.requests.length;
      await service.search('dio');
      expect(adapter.requests, hasLength(count));
      final reloaded = PubPackageService(
        dio,
        cacheFile: File('${root.path}/names.json'),
      );
      await reloaded.search('http');
      expect(
        adapter.requests.where(
          (path) => path.endsWith('package-name-completion-data'),
        ),
        hasLength(1),
      );
    },
  );

  test(
    'exact names outside index can be added, missing and discontinued packages are omitted',
    () async {
      final service = PubPackageService(
        dio,
        cacheFile: File('${root.path}/names.json'),
      );
      expect(
        (await service.search('unlisted_package')).single.name,
        'unlisted_package',
      );
      expect(await service.search('missing'), isEmpty);
      expect(await service.search('discontinued'), isEmpty);
    },
  );

  test(
    'missing, invalid and unavailable download statistics do not hide packages',
    () async {
      for (final value in [null, -1, 'invalid', 0]) {
        adapter.downloadCount = value;
        final service = PubPackageService(
          dio,
          cacheFile: File('${root.path}/names.json'),
        );
        final result = (await service.search('http')).single;
        expect(result.downloadCount30Days, value == 0 ? 0 : isNull);
      }
      adapter.scoreStatus = 503;
      final service = PubPackageService(
        dio,
        cacheFile: File('${root.path}/names.json'),
      );
      expect((await service.search('http')).single.downloadCount30Days, isNull);
    },
  );

  test('cancellation of download statistics cancels the search', () async {
    adapter.cancelScore = true;
    final service = PubPackageService(
      dio,
      cacheFile: File('${root.path}/names.json'),
    );
    await expectLater(
      service.search('http'),
      throwsA(
        isA<DioException>().having(
          (error) => error.type,
          'type',
          DioExceptionType.cancel,
        ),
      ),
    );
  });
}
