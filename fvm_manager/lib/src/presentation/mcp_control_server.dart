import 'dart:async';
import 'dart:convert';
import 'dart:io';

typedef McpToolHandler =
    Future<Map<String, dynamic>> Function(
      String tool,
      Map<String, dynamic> arguments,
    );

class McpControlServer {
  HttpServer? _server;
  Future<void> _operations = Future.value();
  String _token = '';
  McpToolHandler? _onToolCall;

  bool get isRunning => _server != null;
  int? get activePort => _server?.port;

  Future<void> start({
    required int port,
    required String token,
    required McpToolHandler onToolCall,
  }) => _serialize(() async {
    if (_server?.port == port) {
      _token = token;
      _onToolCall = onToolCall;
      return;
    }
    // Bind before replacing a working listener so failed reconfiguration is safe.
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
    final previous = _server;
    _server = server;
    _token = token;
    _onToolCall = onToolCall;
    unawaited(_serve(server));
    await previous?.close(force: true);
  });

  Future<void> stop() => _serialize(() async {
    final server = _server;
    _server = null;
    await server?.close(force: true);
  });

  Future<void> _serialize(Future<void> Function() operation) {
    final result = _operations.then((_) => operation());
    _operations = result.then((_) {}, onError: (Object error) {});
    return result;
  }

  static String describeStartFailure(Object error, int port) {
    if (error is SocketException) {
      final code = error.osError?.errorCode;
      if (const [48, 98, 10048].contains(code) ||
          error.osError?.message.startsWith('The shared flag to bind()') ==
              true) {
        return '端口 $port 已被占用，本窗口未能启动 MCP。'
            '请退出其他 Flutter Manager 实例后重试，或修改 MCP 端口并更新 AI 客户端配置。';
      }
      if (const [13, 10013].contains(code)) {
        return '系统拒绝绑定 MCP 端口 $port。请换一个未被保留的端口，'
            '并检查防火墙或安全软件的限制。';
      }
    }
    return 'MCP 端口 $port 启动失败：$error';
  }

  Future<void> _serve(HttpServer server) async {
    await for (final request in server) {
      unawaited(_handleRequest(request, _token, _onToolCall!));
    }
  }

  Future<void> _handleRequest(
    HttpRequest request,
    String token,
    McpToolHandler onToolCall,
  ) async {
    try {
      _applyCors(request.response);
      if (request.method == 'OPTIONS') {
        await request.response.close();
        return;
      }
      if (!_authorized(request, token)) {
        await _json(request.response, {
          'ok': false,
          'error': 'Unauthorized',
        }, 401);
        return;
      }
      if (request.method == 'GET' && request.uri.path == '/health') {
        await _json(request.response, {
          'ok': true,
          'service': 'flutter-manager',
          'processId': pid,
        });
        return;
      }
      if (request.method != 'POST' || !request.uri.path.startsWith('/tools/')) {
        await _json(request.response, {'ok': false, 'error': 'Not found'}, 404);
        return;
      }
      final tool = request.uri.pathSegments.length >= 2
          ? request.uri.pathSegments[1]
          : '';
      final body = await utf8.decoder.bind(request).join();
      final decoded = body.trim().isEmpty
          ? <String, dynamic>{}
          : (jsonDecode(body) as Map).cast<String, dynamic>();
      final result = await onToolCall(tool, decoded);
      await _json(request.response, {'ok': true, ...result});
    } on Object catch (error) {
      await _json(request.response, {
        'ok': false,
        'error': error.toString().replaceFirst('Exception: ', ''),
      }, 500);
    }
  }

  bool _authorized(HttpRequest request, String token) {
    if (token.isEmpty) return true;
    final header = request.headers.value(HttpHeaders.authorizationHeader);
    if (header == 'Bearer $token') return true;
    return request.headers.value('x-fvm-manager-token') == token;
  }

  void _applyCors(HttpResponse response) {
    response.headers
      ..set(HttpHeaders.accessControlAllowOriginHeader, 'http://127.0.0.1')
      ..set(HttpHeaders.accessControlAllowMethodsHeader, 'GET, POST, OPTIONS')
      ..set(
        HttpHeaders.accessControlAllowHeadersHeader,
        'authorization, content-type, x-fvm-manager-token',
      );
  }

  Future<void> _json(
    HttpResponse response,
    Map<String, dynamic> data, [
    int statusCode = 200,
  ]) async {
    response.statusCode = statusCode;
    response.headers.contentType = ContentType.json;
    response.write(jsonEncode(data));
    await response.close();
  }
}
