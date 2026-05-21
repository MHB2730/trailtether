import 'dart:async';
import 'package:flutter/services.dart';

import '../providers/gpx_provider.dart';
import 'logger_service.dart';

class InboundFileService {
  InboundFileService._();

  static const _channel = MethodChannel('com.trailtether.app/inbound_files');
  static bool _initialized = false;

  static Future<void> init(GpxProvider gpxProvider) async {
    if (_initialized) return;
    _initialized = true;

    _channel.setMethodCallHandler((call) async {
      if (call.method == 'openGpx') {
        await _handlePayload(gpxProvider, call.arguments);
      }
    });

    try {
      final initial = await _channel.invokeMapMethod<String, dynamic>(
        'getInitialFile',
      );
      if (initial != null) {
        await _handlePayload(gpxProvider, initial);
      }
    } catch (e, stack) {
      LoggerService.error(
          'INBOUND_FILE', 'Initial file import failed: $e', stack);
    }
  }

  static Future<void> _handlePayload(
    GpxProvider gpxProvider,
    Object? payload,
  ) async {
    if (payload is! Map) return;

    final filename = payload['filename']?.toString() ?? 'imported.gpx';
    final bytes = payload['bytes'];
    if (bytes is! Uint8List || bytes.isEmpty) return;

    if (!filename.toLowerCase().endsWith('.gpx')) {
      LoggerService.log(
          'INBOUND_FILE', 'Ignoring non-GPX inbound file: $filename');
      return;
    }

    await gpxProvider.importBytes(
      bytes: bytes,
      filename: filename,
      authorName: 'Opened from Android',
    );
  }
}
