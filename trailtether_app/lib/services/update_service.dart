import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/runtime_config.dart';
import 'logger_service.dart';

/// Self-hosted update channel.
///
/// On launch, the app calls [check] which compares the running version against
/// the latest row in `public.app_releases` for the current platform. If a newer
/// version exists, [UpdateStatus] surfaces the metadata. The UI layer decides
/// whether to show a soft banner or a blocking gate (when `is_critical` is
/// true or the build code is below `min_supported_version_code`).
///
/// When the user accepts, [downloadAndInstall] downloads the APK to the app's
/// cache directory and hands it to the system package installer via OpenFilex.
/// Windows isn't wired here yet — MSIX has its own .appinstaller pipeline.
class UpdateService {
  UpdateService._();
  static final UpdateService instance = UpdateService._();

  UpdateStatus _status = const UpdateStatus.unknown();
  UpdateStatus get status => _status;

  /// Streams of status changes so the UI can react without polling.
  final _controller = StreamController<UpdateStatus>.broadcast();
  Stream<UpdateStatus> get stream => _controller.stream;

  bool _downloading = false;
  double _downloadProgress = 0;
  double get downloadProgress => _downloadProgress;
  bool get downloading => _downloading;

  /// Query the latest release row and compare with the currently-running build.
  /// Safe to call many times; failures are swallowed so the app never blocks
  /// on a flaky update channel.
  Future<UpdateStatus> check() async {
    if (!kSupabaseAvailable) return _status;

    try {
      final info = await PackageInfo.fromPlatform();
      final currentCode = int.tryParse(info.buildNumber) ?? 0;
      final platform = _platformKey();
      if (platform == null) {
        // Update channel isn't wired for this OS yet — stay quiet.
        return _status = const UpdateStatus.unknown();
      }

      final row = await Supabase.instance.client
          .from('app_releases')
          .select()
          .eq('platform', platform)
          .order('version_code', ascending: false)
          .limit(1)
          .maybeSingle();

      if (row == null) {
        return _status = UpdateStatus.upToDate(
          currentVersion: info.version,
        );
      }

      final latestCode = (row['version_code'] as num).toInt();
      final minCode = (row['min_supported_version_code'] as num?)?.toInt() ?? 0;
      final isCritical = (row['is_critical'] as bool?) ?? false;
      final newer = latestCode > currentCode;
      final mustUpdate = currentCode < minCode || (newer && isCritical);

      if (!newer) {
        _status = UpdateStatus.upToDate(currentVersion: info.version);
      } else {
        _status = UpdateStatus.available(
          currentVersion: info.version,
          latestVersionName: row['version_name'] as String,
          latestVersionCode: latestCode,
          downloadUrl: row['download_url'] as String,
          releaseNotes: (row['release_notes'] as String?) ?? '',
          isCritical: mustUpdate,
        );
      }

      _controller.add(_status);
      LoggerService.log('UPDATE',
          'Check complete: current=${info.version}+${info.buildNumber}, status=${_status.runtimeType}');
      return _status;
    } catch (e, stack) {
      LoggerService.error('UPDATE', 'check failed: $e', stack);
      return _status;
    }
  }

  /// Download the APK to the cache dir, then trigger the system package
  /// installer. The user still has to tap "Install" in Android's UI — that's
  /// a security guarantee Android enforces; we can't bypass it.
  Future<bool> downloadAndInstall() async {
    final s = _status;
    if (s is! _AvailableUpdate) {
      LoggerService.log('UPDATE', 'downloadAndInstall called with no pending update');
      return false;
    }
    if (_downloading) return false;
    _downloading = true;
    _downloadProgress = 0;
    _controller.add(_status);

    try {
      final dir = await getTemporaryDirectory();
      final safeName =
          'trailtether-${s.latestVersionName}-${s.latestVersionCode}.apk';
      final file = File('${dir.path}/$safeName');

      final req = http.Request('GET', Uri.parse(s.downloadUrl));
      final res = await req.send();
      if (res.statusCode != 200) {
        throw Exception('Download failed: HTTP ${res.statusCode}');
      }
      final total = res.contentLength ?? 0;
      final sink = file.openWrite();
      int received = 0;
      await for (final chunk in res.stream) {
        sink.add(chunk);
        received += chunk.length;
        if (total > 0) {
          _downloadProgress = received / total;
          _controller.add(_status);
        }
      }
      await sink.close();
      LoggerService.log('UPDATE',
          'APK downloaded to ${file.path} (${file.lengthSync()} bytes)');

      // Hand the APK to the system package installer. On Android this uses
      // FileProvider via open_filex, which respects REQUEST_INSTALL_PACKAGES.
      final result = await OpenFilex.open(
        file.path,
        type: 'application/vnd.android.package-archive',
      );
      LoggerService.log('UPDATE', 'OpenFilex returned: ${result.message}');
      return result.type == ResultType.done;
    } catch (e, stack) {
      LoggerService.error('UPDATE', 'downloadAndInstall failed: $e', stack);
      return false;
    } finally {
      _downloading = false;
      _controller.add(_status);
    }
  }

  String? _platformKey() {
    if (Platform.isAndroid) return 'android';
    // Windows uses MSIX .appinstaller, not this code path.
    return null;
  }

  @visibleForTesting
  void debugSet(UpdateStatus s) {
    _status = s;
    _controller.add(s);
  }
}

// ── Status sum-type ──────────────────────────────────────────────────────────

sealed class UpdateStatus {
  const UpdateStatus();
  const factory UpdateStatus.unknown() = _UnknownUpdate;
  const factory UpdateStatus.upToDate({required String currentVersion}) =
      _UpToDate;
  const factory UpdateStatus.available({
    required String currentVersion,
    required String latestVersionName,
    required int latestVersionCode,
    required String downloadUrl,
    required String releaseNotes,
    required bool isCritical,
  }) = _AvailableUpdate;
}

class _UnknownUpdate extends UpdateStatus {
  const _UnknownUpdate();
}

class _UpToDate extends UpdateStatus {
  final String currentVersion;
  const _UpToDate({required this.currentVersion});
}

class _AvailableUpdate extends UpdateStatus {
  final String currentVersion;
  final String latestVersionName;
  final int latestVersionCode;
  final String downloadUrl;
  final String releaseNotes;
  final bool isCritical;
  const _AvailableUpdate({
    required this.currentVersion,
    required this.latestVersionName,
    required this.latestVersionCode,
    required this.downloadUrl,
    required this.releaseNotes,
    required this.isCritical,
  });
}

extension UpdateStatusX on UpdateStatus {
  bool get hasUpdate => this is _AvailableUpdate;
  bool get isCritical =>
      this is _AvailableUpdate && (this as _AvailableUpdate).isCritical;
  String? get latestVersionName => switch (this) {
        final _AvailableUpdate a => a.latestVersionName,
        _ => null,
      };
  String? get releaseNotes => switch (this) {
        final _AvailableUpdate a => a.releaseNotes,
        _ => null,
      };
}
