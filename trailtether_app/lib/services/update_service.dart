import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/runtime_config.dart';
import 'logger_service.dart';

/// GitHub repo hosting the Windows MSIX releases. The latest tag is queried
/// by [UpdateService.check] on Windows. Tags follow the format
/// `v<versionName>-<buildNumber>` (e.g. `v1.0.6-9`), and the .msix is
/// attached as a release asset.
const _kGithubRepoSlug = 'MHB2730/trailtether';
const _kGithubLatestReleaseUrl =
    'https://api.github.com/repos/$_kGithubRepoSlug/releases/latest';

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

  /// Query the latest release for the current platform and compare with the
  /// currently-running build. Safe to call many times; failures are swallowed
  /// so the app never blocks on a flaky update channel.
  ///
  /// Backends:
  ///   - Android → Supabase `public.app_releases`
  ///   - Windows → GitHub Releases (`/repos/.../releases/latest`)
  ///   - Others  → unknown (no-op)
  Future<UpdateStatus> check() async {
    try {
      // Under Google Play Store guidelines, self-updates are strictly prohibited.
      const flavor = String.fromEnvironment('FLUTTER_APP_FLAVOR');
      if (flavor == 'playStore') {
        LoggerService.log('UPDATE', 'Self-update disabled for Google Play Store build');
        return _status = const UpdateStatus.unknown();
      }

      final info = await PackageInfo.fromPlatform();
      final currentCode = int.tryParse(info.buildNumber) ?? 0;

      _LatestRelease? latest;
      if (Platform.isAndroid) {
        if (!kSupabaseAvailable) return _status;
        latest = await _fetchAndroidLatest();
      } else if (Platform.isWindows) {
        latest = await _fetchWindowsLatest();
      } else {
        // Update channel isn't wired for this OS yet — stay quiet.
        return _status = const UpdateStatus.unknown();
      }

      if (latest == null) {
        return _status = UpdateStatus.upToDate(currentVersion: info.version);
      }

      final newer = latest.versionCode > currentCode;
      final mustUpdate =
          currentCode < latest.minSupportedVersionCode || (newer && latest.isCritical);

      if (!newer) {
        _status = UpdateStatus.upToDate(currentVersion: info.version);
      } else {
        _status = UpdateStatus.available(
          currentVersion: info.version,
          latestVersionName: latest.versionName,
          latestVersionCode: latest.versionCode,
          downloadUrl: latest.downloadUrl,
          releaseNotes: latest.releaseNotes,
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

  Future<_LatestRelease?> _fetchAndroidLatest() async {
    final row = await Supabase.instance.client
        .from('app_releases')
        .select()
        .eq('platform', 'android')
        .order('version_code', ascending: false)
        .limit(1)
        .maybeSingle();
    if (row == null) return null;
    return _LatestRelease(
      versionName: row['version_name'] as String,
      versionCode: (row['version_code'] as num).toInt(),
      downloadUrl: row['download_url'] as String,
      releaseNotes: (row['release_notes'] as String?) ?? '',
      isCritical: (row['is_critical'] as bool?) ?? false,
      minSupportedVersionCode:
          (row['min_supported_version_code'] as num?)?.toInt() ?? 0,
    );
  }

  Future<_LatestRelease?> _fetchWindowsLatest() async {
    final res = await http.get(
      Uri.parse(_kGithubLatestReleaseUrl),
      headers: const {'Accept': 'application/vnd.github+json'},
    );
    if (res.statusCode == 404) {
      // Repo has no releases yet — not an error.
      return null;
    }
    if (res.statusCode != 200) {
      throw Exception('GitHub API ${res.statusCode}: ${res.body}');
    }
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    final tag = json['tag_name'] as String?;
    final body = (json['body'] as String?) ?? '';
    final assets = (json['assets'] as List?) ?? const [];
    if (tag == null) return null;

    final parsed = _parseTag(tag);
    if (parsed == null) return null;

    final msix = assets
        .cast<Map<String, dynamic>>()
        .firstWhere(
          (a) =>
              ((a['name'] as String?) ?? '').toLowerCase().endsWith('.msix'),
          orElse: () => const {},
        );
    final downloadUrl = msix['browser_download_url'] as String?;
    if (downloadUrl == null) return null;

    return _LatestRelease(
      versionName: parsed.$1,
      versionCode: parsed.$2,
      downloadUrl: downloadUrl,
      releaseNotes: body,
      isCritical: false,
      minSupportedVersionCode: 0,
    );
  }

  /// Tags look like `v1.0.6-9` or `v1.0.6+9` (with `+` percent-encoded the
  /// API still returns it). Returns (versionName, buildNumber) or null.
  (String, int)? _parseTag(String tag) {
    final clean = tag.startsWith('v') ? tag.substring(1) : tag;
    final match = RegExp(r'^(\d+\.\d+\.\d+)[+\-](\d+)$').firstMatch(clean);
    if (match == null) return null;
    final name = match.group(1)!;
    final code = int.tryParse(match.group(2)!);
    if (code == null) return null;
    return (name, code);
  }

  /// Download the installer (APK on Android, MSIX on Windows) to a temp
  /// location, then hand it to the system installer. The OS-level "Install?"
  /// prompt the user sees is a security guarantee — we can't bypass it.
  Future<bool> downloadAndInstall() async {
    const flavor = String.fromEnvironment('FLUTTER_APP_FLAVOR');
    if (flavor == 'playStore') {
      LoggerService.log('UPDATE', 'downloadAndInstall aborted: self-updates disabled on Google Play');
      return false;
    }

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
      final ext = Platform.isWindows ? 'msix' : 'apk';
      final safeName =
          'trailtether-${s.latestVersionName}-${s.latestVersionCode}.$ext';
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
          'Installer downloaded to ${file.path} (${file.lengthSync()} bytes)');

      // Hand the installer to the OS. Android uses FileProvider via
      // open_filex (REQUEST_INSTALL_PACKAGES). Windows opens the .msix with
      // App Installer, which prompts the user to update — same signature
      // requirements as a manual install: the new MSIX must be signed with
      // the same cert that signed the currently-installed version.
      final mime = Platform.isWindows
          ? 'application/msix'
          : 'application/vnd.android.package-archive';
      final result = await OpenFilex.open(file.path, type: mime);
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

  @visibleForTesting
  void debugSet(UpdateStatus s) {
    _status = s;
    _controller.add(s);
  }
}

/// Normalized "latest release" row used by [UpdateService.check] regardless
/// of which backend (Supabase / GitHub) produced it.
class _LatestRelease {
  final String versionName;
  final int versionCode;
  final String downloadUrl;
  final String releaseNotes;
  final bool isCritical;
  final int minSupportedVersionCode;
  const _LatestRelease({
    required this.versionName,
    required this.versionCode,
    required this.downloadUrl,
    required this.releaseNotes,
    required this.isCritical,
    required this.minSupportedVersionCode,
  });
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
