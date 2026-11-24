/// Deskcite product API over mesgd HTTPS, with mesgd WebSocket event
/// subscriptions. The Erlang `deskcite.erl` is the reference implementation and
/// JavaScript `deskcite.mjs` the secondary reference; this mirrors both: the
/// same operation contract, the same input validation, and raw HTTP status,
/// headers, and non-JSON bodies kept intact.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:mesgd/mesgd.dart';

part 'operations.dart';

/// A non-2xx response surfaced as an exception, keeping status/headers/body.
class DeskciteError implements Exception {
  DeskciteError(this.response);

  final Response response;

  @override
  String toString() => 'Deskcite HTTP ${response.status}';
}

/// One HTTP response. [body] is decoded JSON for JSON routes, and the raw bytes
/// for a document fetch or any error response.
class Response {
  Response(this.status, this.headers, this.body);

  final int status;
  final Map<String, String> headers;
  dynamic body;
}

/// A transport is `(method, path, body, token) -> (status, headers, bytes)`.
/// Inject one to test without a socket; the default uses dart:io HTTPS.
typedef Transport = Future<(int, Map<String, String>, List<int>)> Function(
    String method, String path, Object? body, String token);

String _bearer(String token) {
  if (token.isEmpty || token.codeUnits.any((c) => c < 33 || c > 126)) {
    throw ArgumentError('expected bearer token');
  }
  return token;
}

/// Accept the service's already-encoded source URL path verbatim. Never accept
/// an origin, query, fragment, traversal, or an unrelated route.
String _documentPath(String path) {
  bool rawBad(int c) => c <= 0x20 || c == 0x3f || c == 0x23 || c == 0x5c;
  if (!path.startsWith('/deskcite/documents/') || path.codeUnits.any(rawBad)) {
    throw ArgumentError('expected a Deskcite document URL path');
  }
  final decoded = Uri.decodeComponent(path);
  bool decodedBad(int c) => c < 0x20 || c == 0x7f || c == 0x5c;
  if (decoded.codeUnits.any(decodedBad) ||
      decoded.split('/').any((s) => s == '.' || s == '..')) {
    throw ArgumentError('invalid document path');
  }
  return path;
}

/// Deskcite API client. One client holds one origin and one bearer; replace the
/// bearer with [setToken] after a refresh. The caller owns credential storage
/// and event lifetimes — there is no automatic refresh or request replay.
class Client {
  Client(
    String origin,
    String token, {
    this.timeout = const Duration(seconds: 30),
    SecurityContext? securityContext,
    Transport? transport,
  })  : origin = _origin(origin),
        _securityContext = securityContext,
        _transport = transport {
    _token = _bearer(token);
  }

  final String origin;
  final Duration timeout;
  final SecurityContext? _securityContext;
  final Transport? _transport;
  late String _token;

  static String _origin(String value) {
    final u = Uri.parse(value);
    if (u.scheme != 'https' ||
        u.host.isEmpty ||
        u.userInfo.isNotEmpty ||
        (u.path.isNotEmpty && u.path != '/') ||
        u.hasQuery ||
        u.hasFragment) {
      throw ArgumentError('expected an HTTPS origin');
    }
    return 'https://${u.host}${u.hasPort ? ':${u.port}' : ''}';
  }

  void setToken(String token) => _token = _bearer(token);

  Future<Response> call(String operation,
      [Map<String, dynamic> args = const {}]) async {
    final spec = operations[operation];
    if (spec == null) throw ArgumentError('unknown operation: $operation');
    final kind = spec['kind'];
    var path = spec['path']!;
    if (kind == 'id') {
      final id = args['id'];
      if (id is! String || id.isEmpty) throw ArgumentError('expected id');
      path += Uri.encodeComponent(id);
    }
    if (kind == 'document') {
      final p = args['path'];
      if (p is! String) throw ArgumentError('expected document path');
      path = _documentPath(p);
    }
    if (kind == 'none' && args.isNotEmpty) {
      throw ArgumentError('operation takes no arguments');
    }
    final body = kind == 'json' ? args : null;
    final (status, headers, bytes) =
        await (_transport ?? _https)(spec['method']!, path, body, _token);
    final response = Response(status, headers, bytes);
    if (status < 200 || status >= 300) throw DeskciteError(response);
    if (kind != 'document') {
      response.body = jsonDecode(utf8.decode(bytes));
    }
    return response;
  }

  Future<Response> question(String id) => call('question', {'id': id});

  Future<Response> document(String path) => call('document', {'path': path});

  Future<(int, Map<String, String>, List<int>)> _https(
      String method, String path, Object? body, String token) async {
    final client = HttpClient(context: _securityContext);
    client.connectionTimeout = timeout;
    try {
      final request = await client.openUrl(method, Uri.parse(origin + path));
      request.followRedirects = false;
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
      if (body != null) {
        request.headers.contentType = ContentType('application', 'json');
        request.add(utf8.encode(jsonEncode(body)));
      }
      final response = await request.close().timeout(timeout);
      final bytes = <int>[];
      await for (final chunk in response) {
        bytes.addAll(chunk);
      }
      final headers = <String, String>{};
      response.headers
          .forEach((name, values) => headers[name] = values.join(', '));
      return (response.statusCode, headers, bytes);
    } finally {
      client.close(force: true);
    }
  }

  /// Open one mesgd WebSocket for the current credential and dispatch every
  /// event to [handler]. Call [Mesgd.recv] or [Mesgd.listen] in the host's
  /// receive loop, and close it before replacing the bearer and reconnecting.
  Future<Mesgd> events(
    MesgdHandler handler, {
    Map<String, dynamic>? serverPub,
    Map<String, String>? headers,
    bool bearerHeader = false,
    Duration? timeout,
  }) async {
    final url = 'wss://${origin.substring('https://'.length)}/deskcite/events';
    final connection = await Mesgd.connect(
      url,
      token: _token,
      securityContext: _securityContext,
      serverPub: serverPub,
      headers: headers,
      bearerHeader: bearerHeader,
      timeout: timeout ?? this.timeout,
    );
    connection.on('*', handler);
    return connection;
  }
}
