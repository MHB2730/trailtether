import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/runtime_config.dart';

class LoggerService {
  static File? _logFile;
  static final List<String> _memoryLogs = [];
  static const int _maxLogs = 1000;
  static List<String> get memoryLogs => List.unmodifiable(_memoryLogs);

  static final List<void Function(String)> _listeners = [];
  static const bool _remoteLoggingEnabled = true;
  static String? currentTeamId;

  /// Initialize the logger and open the log file.
  static Future<void> init() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      _logFile = File('${dir.path}/trailtether_logs.txt');

      // If file exists and is too large (>2MB), clear it
      if (await _logFile!.exists()) {
        final len = await _logFile!.length();
        if (len > 2 * 1024 * 1024) {
          await _logFile!
              .writeAsString('--- Log Reset (${DateTime.now()}) ---\n');
        }
      } else {
        await _logFile!.create();
      }

      log('LOGGER', 'System initialized');
    } catch (e) {
      debugPrint('Logger initialization failed: $e');
    }
  }

  /// Log a message with a tag.
  static void log(String tag, String message) {
    final timestamp = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
    final entry = '[$timestamp] [$tag] $message';

    // Print to console in debug
    debugPrint(entry);

    // Store in memory
    _memoryLogs.add(entry);
    if (_memoryLogs.length > _maxLogs) _memoryLogs.removeAt(0);

    // Notify listeners
    for (final listener in _listeners) {
      listener(entry);
    }

    // Write to file asynchronously
    _writeToFile(entry);

    // Remote sync
    if (_remoteLoggingEnabled) {
      _syncToSupabase(tag, message, 'info');
    }
  }

  static void addListener(void Function(String) listener) {
    _listeners.add(listener);
  }

  static void removeListener(void Function(String) listener) {
    _listeners.remove(listener);
  }

  static Future<void> _syncToSupabase(
      String tag, String message, String level) async {
    if (!kSupabaseAvailable) return;
    try {
      final client = Supabase.instance.client;
      final user = client.auth.currentUser;
      if (user == null) return;

      await client.from('app_logs').insert({
        'uid': user.id,
        'team_id': currentTeamId,
        'tag': tag,
        'message': message,
        'level': level,
        'platform': defaultTargetPlatform.name,
      });
    } catch (e) {
      // Surface failures via debugPrint only — never via log()/error() or
      // we'd loop. Previously this catch was silent, which hid the fact
      // that the table had no INSERT RLS policy and every sync failed.
      debugPrint('app_logs sync failed: $e');
    }
  }

  /// Log an error with stack trace.
  static void error(String tag, dynamic error, [StackTrace? stack]) {
    final timestamp = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
    final entry = '[$timestamp] [ERROR] [$tag] $error\n$stack';

    debugPrint(entry);
    _memoryLogs.add(entry);
    if (_memoryLogs.length > _maxLogs) _memoryLogs.removeAt(0);
    for (final listener in _listeners) {
      listener(entry);
    }
    _writeToFile(entry);

    // Mirror errors to the remote console too — that's the whole point of
    // the diagnostic console's "Remote" mode. Previously only log() was
    // synced, so the most interesting entries never reached the table.
    if (_remoteLoggingEnabled) {
      _syncToSupabase(tag, '$error', 'error');
    }
  }

  static Future<void> _writeToFile(String entry) async {
    if (_logFile == null) return;
    try {
      await _logFile!
          .writeAsString('$entry\n', mode: FileMode.append, flush: true);
    } catch (e) {
      debugPrint('Failed to write to log file: $e');
    }
  }

  /// Share the log file.
  static Future<void> shareLogs() async {
    if (_logFile == null || !await _logFile!.exists()) {
      debugPrint('Log file not found');
      return;
    }

    final xFile = XFile(_logFile!.path);
    await Share.shareXFiles([xFile], subject: 'Trailtether Debug Logs');
  }

  /// Clear all logs.
  static Future<void> clearLogs() async {
    _memoryLogs.clear();
    if (_logFile != null && await _logFile!.exists()) {
      await _logFile!
          .writeAsString('--- Logs Cleared (${DateTime.now()}) ---\n');
    }
  }

  /// Get all memory logs as a single string.
  static String getFullLogs() {
    return _memoryLogs.join('\n');
  }
}
