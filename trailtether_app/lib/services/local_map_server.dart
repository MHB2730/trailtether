import 'dart:convert' as dart_convert;
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class LocalMapServer {
  static HttpServer? _server;
  static int _port = 8080;

  static int get port => _port;

  static Future<void> start() async {
    if (_server != null) return;
    try {
      _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      _port = _server!.port;

      _server!.listen((HttpRequest request) async {
        try {
          final path = request.uri.path;

          // Set permissive CORS + no-cache on every response so WebView2
          // never blocks sub-resources or serves a stale (empty) JS file.
          void cors(HttpResponse r, ContentType ct) {
            r.headers
              ..contentType = ct
              ..add('Access-Control-Allow-Origin', '*')
              ..add('Cache-Control', 'no-store');
          }

          if (path == '/' || path == '/map3d.html') {
            final content =
                await rootBundle.loadString('assets/map/map3d.html');
            final bytes = dart_convert.utf8.encode(content);
            cors(request.response, ContentType.html);
            request.response
              ..contentLength = bytes.length
              ..add(bytes);
          } else if (path == '/maplibre-gl.js') {
            final data = await rootBundle.load('assets/map/maplibre-gl.js');
            // Must use offsetInBytes + lengthInBytes — the ByteData is a view
            // into a larger buffer; asUint8List() without args serves garbage.
            final bytes =
                data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
            cors(request.response, ContentType('application', 'javascript'));
            request.response
              ..contentLength = bytes.length
              ..add(bytes);
          } else if (path == '/maplibre-gl.css') {
            final data = await rootBundle.load('assets/map/maplibre-gl.css');
            final bytes =
                data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
            cors(request.response, ContentType('text', 'css'));
            request.response
              ..contentLength = bytes.length
              ..add(bytes);
          } else if (path == '/routes.json') {
            final content =
                await rootBundle.loadString('assets/data/routes_cleaned.json');
            final bytes = dart_convert.utf8.encode(content);
            cors(request.response, ContentType.json);
            request.response
              ..contentLength = bytes.length
              ..add(bytes);
          } else {
            request.response.statusCode = HttpStatus.notFound;
          }
        } catch (e) {
          request.response.statusCode = HttpStatus.internalServerError;
        } finally {
          await request.response.close();
        }
      });
    } catch (e) {
      debugPrint('LocalMapServer error: $e');
    }
  }

  static Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
  }
}
