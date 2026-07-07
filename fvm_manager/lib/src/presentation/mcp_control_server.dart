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

  bool get isRunning => _server != null;
  int? get activePort => _server?.port;

  Future<void> start({
    required int port,
    required String token,
    required McpToolHandler onToolCall,
  }) async {
    await stop();
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
    _server = server;
    unawaited(_serve(server, token, onToolCall));
  }

  Future<void> stop() async {
    final server = _server;
    _server = null;
    await server?.close(force: true);
  }

  Future<void> _serve(
    HttpServer server,
    String token,
    McpToolHandler onToolCall,
  ) async {
    await for (final request in server) {
      unawaited(_handleRequest(request, token, onToolCall));
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
        await _json(request.response, {'ok': true});
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
