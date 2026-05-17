import 'dart:io' show Platform;

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../core/supabase_options.dart';

SupabaseClient get _supabase => Supabase.instance.client;

class AuthService {
  // â”€â”€ Stream â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  static Stream<AuthState> get authStateStream =>
      _supabase.auth.onAuthStateChange;

  static User? get currentUser => _supabase.auth.currentUser;
  static String? get currentUid => currentUser?.id;

  // ————————————————————————————————————————————————————————————————————————
  static Future<AuthResponse> signInEmail(String email, String password) =>
      _supabase.auth.signInWithPassword(email: email, password: password);

  static Future<AuthResponse> registerEmail(
          String email, String password, String? displayName) =>
      _supabase.auth.signUp(
        email: email,
        password: password,
        data: displayName != null ? {'display_name': displayName} : null,
      );

  static Future<AuthResponse?> signInWithGoogle() async {
    // google_sign_in only ships native plugins for Android and iOS. On Windows
    // / macOS / Linux the call throws MissingPluginException, which the auth
    // provider previously masked as "Something went wrong". Surface a real
    // message instead, until desktop OAuth (browser + deep-link) is wired up.
    if (!Platform.isAndroid && !Platform.isIOS) {
      throw const AuthException(
        'Google Sign-In is not yet supported on desktop. Please sign in with email and password.',
      );
    }

    try {
      // 1. Initialize Google Sign In
      // NOTE: For Android, the SHA-1 must be registered in Google Cloud Console.
      // For iOS, the reverse client ID must be added to Info.plist.
      final googleSignIn = GoogleSignIn(
        serverClientId: kGoogleWebClientId,
      );
      final googleUser = await googleSignIn.signIn();
      if (googleUser == null) return null; // User cancelled

      // 2. Get auth details from Google
      final googleAuth = await googleUser.authentication;
      final accessToken = googleAuth.accessToken;
      final idToken = googleAuth.idToken;

      if (idToken == null) {
        throw const AuthException('No ID Token found.');
      }

      // 3. Authenticate with Supabase
      return await _supabase.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );
    } catch (e) {
      rethrow;
    }
  }

  // â”€â”€ Sign out â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  static Future<void> signOut() => _supabase.auth.signOut();

  // â”€â”€ Helpers â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  /// Display-friendly error messages for Supabase AuthException.
  static String friendlyError(AuthException e) {
    final msg = e.message.toLowerCase();
    if (msg.contains('invalid login') || msg.contains('invalid credentials')) {
      return 'Incorrect email or password.';
    }
    if (msg.contains('user already registered') ||
        msg.contains('already been registered')) {
      return 'An account with that email already exists.';
    }
    if (msg.contains('password')) {
      if (msg.contains('leaked')) {
        return 'For your security, this password cannot be used as it was found in a data breach. Please choose a unique password.';
      }
      return 'Password must be at least 6 characters.';
    }
    if (msg.contains('email')) {
      return 'Please enter a valid email address.';
    }
    if (msg.contains('network') || msg.contains('connection')) {
      return 'No internet connection. Please try again.';
    }
    if (msg.contains('rate limit') || msg.contains('too many')) {
      return 'Too many attempts. Please wait a moment.';
    }
    return e.message;
  }
}

/// Extension so existing code that calls [user.uid] still compiles.
/// Supabase uses [User.id]; this adds [uid] as a transparent alias.
extension SupabaseUserX on User {
  String get uid => id;
  String? get displayName =>
      userMetadata?['display_name'] as String? ??
      userMetadata?['full_name'] as String?;
  bool get isGuest => false;
  String? get photoUrl =>
      userMetadata?['photo_url'] as String? ??
      userMetadata?['avatar_url'] as String?;
}
