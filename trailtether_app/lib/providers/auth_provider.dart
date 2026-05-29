import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/runtime_config.dart';
import '../services/auth_service.dart';
import '../services/logger_service.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthProvider extends ChangeNotifier {
  AuthStatus _status = AuthStatus.unknown;
  User? _user;
  bool _busy = false;
  String? _error;

  StreamSubscription<AuthState>? _sub;

  AuthStatus get status => _status;
  User? get user => _user;
  bool get busy => _busy;
  String? get error => _error;
  bool get isAuth => _status == AuthStatus.authenticated;

  /// Convenience getters so screens don't import supabase_flutter directly.
  String? get uid => _user?.id;
  String? get email => _user?.email;
  String? get displayName =>
      _user?.userMetadata?['display_name'] ?? _user?.displayName;
  String? get photoUrl => _user?.userMetadata?['avatar_url'];

  /// Server-side admin flag, read from `profiles.is_admin`. Cached after first
  /// fetch and refreshed on auth change. This replaces the legacy hardcoded
  /// email check (kAdminEmail) so admin status is enforced by the database, not
  /// a string comparison in client code that anyone can bypass.
  bool _isAdmin = false;
  bool get isAdmin => _isAdmin;

  Future<void> _refreshAdminFlag() async {
    final id = _user?.id;
    if (id == null) {
      _isAdmin = false;
      return;
    }
    try {
      final row = await Supabase.instance.client
          .from('profiles')
          .select('is_admin')
          .eq('id', id)
          .maybeSingle();
      _isAdmin = (row?['is_admin'] as bool?) ?? false;
      notifyListeners();
    } catch (e) {
      LoggerService.log('AUTH', 'admin flag fetch failed: $e');
    }
  }

  AuthProvider() {
    if (kSupabaseAvailable) {
      LoggerService.log('AUTH', 'Initializing auth listener');
      // Emit the current session immediately, then listen for changes.
      final currentUser = AuthService.currentUser;
      _onAuthChange(currentUser);
      _sub = AuthService.authStateStream.listen((state) {
        LoggerService.log('AUTH', 'State change: ${state.event}');
        _onAuthChange(state.session?.user);
      });
    } else {
      _status = AuthStatus.unauthenticated;
    }
  }

  void _onAuthChange(User? user) {
    _user = user;
    _status =
        user != null ? AuthStatus.authenticated : AuthStatus.unauthenticated;
    if (user != null) {
      // Log the uid only — never the email — so we don't persist PII to logs.
      LoggerService.log('AUTH', 'Authenticated (${user.id})');
      unawaited(_refreshAdminFlag());
    } else {
      LoggerService.log('AUTH', 'Unauthenticated');
      _isAdmin = false;
    }
    notifyListeners();
  }

  // ── Email / password ────────────────────────────────────────────────────────
  Future<bool> signInEmail(String email, String password) =>
      _run(() => AuthService.signInEmail(email, password));

  Future<bool> registerEmail(String email, String password,
          [String? displayName]) =>
      _run(() => AuthService.registerEmail(email, password, displayName));

  Future<bool> signInWithGoogle() => _run(() => AuthService.signInWithGoogle());

  // ── Sign out ───────────────────────────────────────────────────────────
  Future<void> signOut() async {
    LoggerService.log('AUTH', 'Signing out');
    await AuthService.signOut();
  }

  // ── Generic runner ────────────────────────────────────────────────────────
  Future<bool> _run(Future Function() fn) async {
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      await fn();
      _busy = false;
      notifyListeners();
      return true;
    } on AuthException catch (e, stack) {
      _error = AuthService.friendlyError(e);
      LoggerService.error('AUTH_FAIL', _error, stack);
      _busy = false;
      notifyListeners();
      return false;
    } on PlatformException catch (e, stack) {
      _error = _friendlyPlatformError(e);
      LoggerService.error('AUTH_PLATFORM_ERROR', _error, stack);
      _busy = false;
      notifyListeners();
      return false;
    } catch (e, stack) {
      _error = 'Something went wrong. Please try again.';
      LoggerService.error('AUTH_ERROR', e, stack);
      _busy = false;
      notifyListeners();
      return false;
    }
  }

  String _friendlyPlatformError(PlatformException e) {
    final msg = e.message ?? '';
    if (msg.toLowerCase().contains('network')) {
      return 'No internet connection. Please check your network and try again.';
    }
    return 'Sign-in failed: ${e.message ?? e.toString()}';
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
