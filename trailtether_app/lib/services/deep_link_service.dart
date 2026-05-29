import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'logger_service.dart';

/// Routes inbound `trailtether://` URLs into the appropriate handler.
///
/// Used for OAuth callback completion on desktop, where Supabase redirects
/// the browser to `trailtether://login-callback?code=...` after a successful
/// Google sign-in. The native code (Windows MSIX, Android intent-filter)
/// re-launches/foregrounds the app with the URL, and this listener passes it
/// to `Supabase.instance.client.auth.getSessionFromUrl` to exchange the code
/// for a session.
class DeepLinkService {
  DeepLinkService._();

  static final AppLinks _appLinks = AppLinks();
  static StreamSubscription<Uri>? _sub;
  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    try {
      final initial = await _appLinks.getInitialLink();
      if (initial != null) {
        unawaited(_handle(initial));
      }
    } catch (e, stack) {
      LoggerService.error('DEEP_LINK', 'getInitialLink failed: $e', stack);
    }

    _sub = _appLinks.uriLinkStream.listen(
      (uri) => unawaited(_handle(uri)),
      onError: (e, stack) =>
          LoggerService.error('DEEP_LINK', 'uriLinkStream error: $e', stack),
    );
  }

  static Future<void> _handle(Uri uri) async {
    LoggerService.log(
        'DEEP_LINK', 'received ${uri.scheme}://${uri.host}${uri.path}');
    if (uri.scheme != 'trailtether') return;

    if (uri.host == 'login-callback') {
      try {
        await Supabase.instance.client.auth.getSessionFromUrl(uri);
        LoggerService.log('DEEP_LINK', 'session exchanged');
      } catch (e, stack) {
        LoggerService.error('DEEP_LINK', 'getSessionFromUrl failed: $e', stack);
      }
    }
  }

  static Future<void> dispose() async {
    await _sub?.cancel();
    _sub = null;
    _initialized = false;
  }
}
