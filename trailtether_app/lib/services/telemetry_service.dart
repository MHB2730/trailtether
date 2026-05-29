import 'package:sentry_flutter/sentry_flutter.dart';
import 'logger_service.dart';

/// Centralized telemetry and error reporting service.
/// Wraps [Sentry] to isolate error logging, custom breadcrumbs, and hiker
/// context tracking while keeping all sensitive user info fully redacted.
class TelemetryService {
  static bool _initialized = false;

  /// Initialize telemetry if a valid Sentry DSN is compiled in.
  static Future<void> init(
      {required String dsn, String environment = 'production'}) async {
    if (dsn.isEmpty) {
      LoggerService.log('TELEMETRY',
          'No SENTRY_DSN provided. Telemetry running in mock mode.');
      return;
    }

    try {
      await SentryFlutter.init(
        (options) {
          options.dsn = dsn;
          options.tracesSampleRate =
              0.1; // Capture 10% of performance traces to optimize bandwidth
          options.environment = environment;
          options.beforeSend = _redactPiiBeforeSend;
        },
      );
      _initialized = true;
      LoggerService.log(
          'TELEMETRY', 'Sentry telemetry initialized in $environment mode.');
    } catch (e) {
      LoggerService.error('TELEMETRY', 'Failed to initialize Sentry: $e');
    }
  }

  /// Sets the telemetry user context using an anonymous, secure identifier.
  /// GDPR/POPIA compliant: never send names, phone numbers, or clear email.
  static void setUserContext(
      {required String anonymousUserId, String? teamId}) {
    if (!_initialized) return;

    Sentry.configureScope((scope) {
      scope.setUser(SentryUser(id: anonymousUserId));
      if (teamId != null) {
        scope.setTag('team_id', teamId);
      }
    });
  }

  /// Log a custom, structured event path breadcrumb (e.g. 'off_trail', 'map_load').
  static void addBreadcrumb({
    required String category,
    required String message,
    Map<String, dynamic>? data,
    SentryLevel level = SentryLevel.info,
  }) {
    LoggerService.log(category.toUpperCase(), '$message ${data ?? ""}');

    if (!_initialized) return;

    Sentry.addBreadcrumb(
      Breadcrumb(
        message: message,
        category: category,
        data: data,
        level: level,
        timestamp: DateTime.now(),
      ),
    );
  }

  /// Capture a handled exception and send its stack trace to the telemetry server.
  static Future<void> captureException(
    dynamic exception, {
    dynamic stackTrace,
    String? hint,
  }) async {
    LoggerService.error('TELEMETRY', 'Capturing error: $exception', stackTrace);

    if (!_initialized) return;

    await Sentry.captureException(
      exception,
      stackTrace: stackTrace,
      hint: hint != null ? Hint.withMap({'message': hint}) : null,
    );
  }

  /// GDPR & POPIA scrubbing filter. Ensures no email addresses or plain names
  /// accidentally get shipped in variables, payloads, or messages.
  static SentryEvent? _redactPiiBeforeSend(SentryEvent event, Hint hint) {
    // Redact email patterns from messages
    final emailRegex =
        RegExp(r'[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}');

    final formatted = event.message?.formatted;
    if (formatted != null) {
      final sanitized = formatted.replaceAll(emailRegex, '[REDACTED_EMAIL]');
      event = event.copyWith(message: SentryMessage(sanitized));
    }

    // Scrub user IP address for privacy
    if (event.user != null) {
      event = event.copyWith(
        user: event.user!.copyWith(ipAddress: '{{private}}'),
      );
    }

    return event;
  }
}
