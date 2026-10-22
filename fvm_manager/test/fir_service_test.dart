import 'package:flutter_manager/src/data/fir_service.dart';
import 'package:flutter_manager/src/domain/project_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FirService.resolveDownloadUrl', () {
    test('uses a public download URL returned by the API', () {
      expect(
        FirService.resolveDownloadUrl({
          'download_url': 'http://download.example.com/app/abc',
        }),
        'https://download.example.com/app/abc',
      );
    });

    test('builds the public download page from a short code', () {
      expect(
        FirService.resolveDownloadUrl({'short': 'Abc_123'}),
        'https://fir.xcxwo.com/Abc_123',
      );
    });

    test('rejects a localhost download address', () {
      expect(
        () => FirService.resolveDownloadUrl({
          'download_url': 'http://127.0.0.1:3000/app',
          'short': 'http://127.0.0.1:3000',
        }),
        throwsA(isA<Exception>()),
      );
    });

    test('keeps only the short code from a localhost callback URL', () {
      expect(
        FirService.resolveDownloadUrl({
          'short': 'http://127.0.0.1:3000/Abc123',
        }),
        'https://fir.xcxwo.com/Abc123',
      );
    });

    test('uses the canonical fir download domain for a full short URL', () {
      expect(
        FirService.resolveDownloadUrl({
          'short': 'https://example.invalid/k3j4cqm7',
        }),
        'https://fir.xcxwo.com/k3j4cqm7',
      );
    });
  });

  test('distribution download identifiers persist with project config', () {
    final fir = FirConfig.fromMap({'shortCode': 'k3j4cqm7'});
    final pgyer = PgyerConfig.fromMap({'buildShortcutUrl': 'AbCd'});

    expect(fir.shortCode, 'k3j4cqm7');
    expect(fir.toMap()['shortCode'], 'k3j4cqm7');
    expect(pgyer.buildShortcutUrl, 'AbCd');
    expect(pgyer.toMap()['buildShortcutUrl'], 'AbCd');
  });
}
