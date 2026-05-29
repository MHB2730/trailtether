import 'dart:io';
import 'package:http/io_client.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';
import '../core/constants.dart';
import 'logger_service.dart';

class OfflineMapService {
  static const _storeName = 'trail_tiles';
  static bool _initialised = false;

  // ── Initialisation ────────────────────────────────────────────────────
  static Future<void> init() async {
    if (_initialised) return;
    try {
      await FMTCObjectBoxBackend().initialise();
      await const FMTCStore(_storeName).manage.create();
      _initialised = true;
    } catch (e, stack) {
      LoggerService.error('OFFLINE_MAP', 'FMTC init failed: $e', stack);
    }
  }

  // ── Tile provider for FlutterMap ──────────────────────────────────────
  /// Returns an FMTC caching tile provider when available, otherwise
  /// falls back to a plain network provider (demo / Windows mode).
  static TileProvider tileProvider() {
    final headers = {'User-Agent': kTileUserAgent};
    try {
      if (!_initialised) {
        LoggerService.log('OFFLINE_MAP',
            'Provider requested before init - using NetworkTileProvider');
        return NetworkTileProvider(headers: headers);
      }

      return const FMTCStore(_storeName).getTileProvider(
        httpClient: IOClient(
          HttpClient()..connectionTimeout = const Duration(seconds: 15),
        ),
        settings: FMTCTileProviderSettings(
          behavior: CacheBehavior.cacheFirst,
        ),
      );
    } catch (e, stack) {
      LoggerService.error('OFFLINE_MAP',
          'FMTC provider failed - falling back to network: $e', stack);
      return NetworkTileProvider(headers: headers);
    }
  }

  // ── Region definition ─────────────────────────────────────────────────
  static DownloadableRegion<RectangleRegion> _region(
    LatLngBounds bounds,
    String urlTemplate,
  ) {
    return RectangleRegion(
      bounds,
    ).toDownloadable(
      minZoom: 10,
      maxZoom: 15,
      options: TileLayer(urlTemplate: urlTemplate),
    );
  }

  // ── Download with progress callback ───────────────────────────────────
  /// Downloads the selected trail area (zoom 10-15).
  /// [onProgress] is called with (downloadedTiles, totalTiles).
  static Future<void> downloadRegion({
    required LatLngBounds bounds,
    required void Function(int downloaded, int total) onProgress,
  }) async {
    const urlTemplate = kTileUrl;
    final region = _region(bounds, urlTemplate);

    final stream = const FMTCStore(_storeName).download.startForeground(
          region: region,
          parallelThreads: 2,
          maxBufferLength: 200,
          skipExistingTiles: true,
          skipSeaTiles: true,
        );

    await for (final progress in stream) {
      // DownloadProgress in FMTC v9.1 exposes successfulTiles / maxTiles
      onProgress(progress.successfulTiles, progress.maxTiles);
    }
  }

  // ── Cache helpers ─────────────────────────────────────────────────────
  static Future<void> clearCache() async {
    try {
      await const FMTCStore(_storeName).manage.reset();
    } catch (e, stack) {
      LoggerService.error(
          'OFFLINE_MAP', 'Failed to clear tile cache: $e', stack);
    }
  }
}
