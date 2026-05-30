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

    // OAuth callback (desktop browser PKCE), the email confirm-signup link,
    // and the password-recovery link all carry an OTP/code in the URL that
    // Supabase exchanges for a session. getSessionFromUrl handles all three.
    // For recovery URLs Supabase additionally emits AuthChangeEvent.passwordRecovery
    // — AuthGate listens for that and renders SetNewPasswordScreen.
    const exchangeHosts = {'login-callback', 'reset-password', 'confirm'};
    if (exchangeHosts.contains(uri.host)) {
      // Defense-in-depth: only attempt the session exchange when the URI
      // actually carries an auth payload. PKCE puts `code` in the query;
      // the implicit/recovery flow puts `access_token`/`token_hash` (or an
      // `error`) in the fragment. A bare `trailtether://reset-password` with
      // no payload is ignored rather than handed to the auth client.
      if (!_carriesAuthPayload(uri)) {
        LoggerService.log('DEEP_LINK', 'ignored ${uri.host}: no auth payload');
        return;
      }
      try {
        await Supabase.instance.client.auth.getSessionFromUrl(uri);
        LoggerService.log('DEEP_LINK', 'session exchanged (${uri.host})');
      } catch (e, stack) {
        LoggerService.error('DEEP_LINK', 'getSessionFromUrl failed: $e', stack);
      }
    }
  }

  /// True when [uri] carries a Supabase auth payload in either the query or
  /// the fragment (PKCE `code`, implicit `access_token`/`token_hash`, or an
  /// `error`). Guards against acting on payload-less inbound links.
  static bool _carriesAuthPayload(Uri uri) {
    const keys = ['code', 'access_token', 'token_hash', 'error', 'error_code'];
    for (final k in keys) {
      if (uri.queryParameters.containsKey(k)) return true;
    }
    final frag = uri.fragment;
    if (frag.isNotEmpty) {
      for (final k in keys) {
        if (frag.contains('$k=')) return true;
      }
    }
    return false;
  }

  static Future<void> dispose() async {
    await _sub?.cancel();
    _sub = null;
    _initialized = false;
  }
}
