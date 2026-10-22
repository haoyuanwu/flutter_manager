import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_manager/src/data/pub_environment_service.dart';
import 'package:flutter_manager/src/presentation/mcp_control_server.dart';
import 'package:flutter_manager/src/presentation/providers.dart';

class _Environment extends PubEnvironmentService {
  @override
  Future<void> setMcpServerEnabled(bool enabled) async {}
  @override
  Future<void> setMcpServerPort(int port) async {}
}

void main() {
  Future<Map<String, dynamic>> handler(
    String tool,
    Map<String, dynamic> args,
  ) async => {'tool': tool};

  Future<int> unusedPort() async {
    final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final port = socket.port;
    await socket.close();
    return port;
  }

  Future<(int, Map<String, dynamic>)> health(int port, String token) async {
    final client = HttpClient();
    try {
      final request = await client.getUrl(
        Uri.parse('http://127.0.0.1:$port/health'),
      );
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
      final response = await request.close();
      return (
        response.statusCode,
        jsonDecode(await utf8.decoder.bind(response).join())
            as Map<String, dynamic>,
      );
    } finally {
      client.close(force: true);
    }
  }

  test(
    'concurrent starts reuse one listener and token updates do not rebind',
    () async {
      final server = McpControlServer();
      addTearDown(server.stop);
      final port = await unusedPort();
      await Future.wait(
        List.generate(
          5,
          (_) => server.start(port: port, token: 'old', onToolCall: handler),
        ),
      );
      expect(server.isRunning, isTrue);
      expect(server.activePort, port);
      expect((await health(port, 'old')).$1, 200);
      await server.start(port: port, token: 'new', onToolCall: handler);
      expect((await health(port, 'old')).$1, 401);
      final result = await health(port, 'new');
      expect(result.$1, 200);
      expect(result.$2['service'], 'flutter-manager');
      expect(result.$2['processId'], pid);
    },
  );

  test('a failed port change keeps the existing listener alive', () async {
    final server = McpControlServer();
    addTearDown(server.stop);
    await server.start(port: 0, token: 'original', onToolCall: handler);
    final originalPort = server.activePort!;
    final occupied = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(occupied.close);
    await expectLater(
      server.start(
        port: occupied.port,
        token: 'replacement',
        onToolCall: handler,
      ),
      throwsA(isA<SocketException>()),
    );
    expect(server.activePort, originalPort);
    expect((await health(originalPort, 'original')).$1, 200);
  });

  test(
    'stop during startup leaves no orphan listener and can restart',
    () async {
      final server = McpControlServer();
      addTearDown(server.stop);
      final port = await unusedPort();
      final starting = server.start(port: port, token: '', onToolCall: handler);
      final stopping = server.stop();
      await Future.wait([starting, stopping]);
      expect(server.isRunning, isFalse);
      final check = await ServerSocket.bind(InternetAddress.loopbackIPv4, port);
      await check.close();
      await server.start(port: port, token: '', onToolCall: handler);
      expect((await health(port, '')).$1, 200);
    },
  );

  test('bind errors provide actionable port and permission messages', () {
    for (final code in [48, 98, 10048]) {
      expect(
        McpControlServer.describeStartFailure(
          SocketException('bind', osError: OSError('occupied', code)),
          17891,
        ),
        contains('端口 17891 已被占用'),
      );
    }
    expect(
      McpControlServer.describeStartFailure(
        const SocketException('bind', osError: OSError('permission', 10013)),
        17891,
      ),
      contains('系统拒绝绑定'),
    );
  });

  test(
    'controller exposes failed startup, then clears it after retry succeeds',
    () async {
      final occupied = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final port = occupied.port;
      final container = ProviderContainer(
        overrides: [
          pubEnvironmentServiceProvider.overrideWithValue(_Environment()),
        ],
      );
      addTearDown(container.dispose);
      final controller = container.read(fvmControllerProvider.notifier);
      final server = container.read(mcpControlServerProvider);
      addTearDown(server.stop);
      await controller.setMcpServerPort(port);
      await controller.setMcpServerEnabled(true);
      expect(container.read(mcpServerRuntimeProvider).running, isFalse);
      expect(
        container.read(mcpServerRuntimeProvider).error,
        contains('端口 $port 已被占用'),
      );
      expect(await controller.ensureMcpServerRunning(), isFalse);
      await occupied.close();
      await controller.retryMcpServer();
      expect(container.read(mcpServerRuntimeProvider).running, isTrue);
      expect(container.read(mcpServerRuntimeProvider).error, isNull);
      expect(container.read(fvmControllerProvider).errorMessage, isNull);
      expect(await controller.ensureMcpServerRunning(), isTrue);
      await controller.setMcpServerEnabled(false);
      expect(container.read(mcpServerRuntimeProvider).running, isFalse);
    },
  );
}
