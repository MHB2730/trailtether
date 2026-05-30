import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/supabase_options.dart';

SupabaseClient get _supabase => Supabase.instance.client;

final GoogleSignIn _googleSignIn = GoogleSignIn(
  serverClientId: kGoogleWebClientId,
);

class AuthService {
  // â”€â”€ Stream â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  static Stream<AuthState> get authStateStream =>
      _supabase.auth.onAuthStateChange;

  static User? get currentUser => _supabase.auth.currentUser;
  static String? get currentUid => currentUser?.id;

  /// Deep-link target Supabase redirects to after a confirmation / recovery
  /// link is opened. Must be on the allowed redirect URLs list in
  /// Supabase Authentication -> URL Configuration.
  static const String confirmRedirect = 'trailtether://confirm';
  static const String recoveryRedirect = 'trailtether://reset-password';

  /// Sends the password-recovery email (Supabase fires the configured
  /// "Reset Password" template). The link opens the app via
  /// [recoveryRedirect] and Supabase emits `AuthChangeEvent.passwordRecovery`,
  /// which AuthGate routes to SetNewPasswordScreen.
  static Future<void> sendPasswordReset(String email) =>
      _supabase.auth.resetPasswordForEmail(email, redirectTo: recoveryRedirect);

  /// Set a new password for the currently-recovering user. The recovery
  /// session established by the deep link is required.
  static Future<UserResponse> updatePassword(String newPassword) =>
      _supabase.auth.updateUser(UserAttributes(password: newPassword));

  // ————————————————————————————————————————————————————————————————————————
  static Future<AuthResponse> signInEmail(String email, String password) =>
      _supabase.auth.signInWithPassword(email: email, password: password);

  static Future<AuthResponse> registerEmail(
          String email, String password, String? displayName) =>
      _supabase.auth.signUp(
        email: email,
        password: password,
        emailRedirectTo: confirmRedirect,
        data: displayName != null ? {'display_name': displayName} : null,
      );

  static Future<AuthResponse?> signInWithGoogle() async {
    // Mobile: native account picker via Play Services / Sign In with Apple
    // bridge. The Android OAuth client in Google Cloud Console (package
    // com.trailtether.app + the upload keystore's SHA-1) authorizes the
    // calling app; the Web client whose ID we pass as serverClientId is what
    // mints the ID token Supabase validates.
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null; // user dismissed the sheet

      final googleAuth = await googleUser.authentication;
      final idToken = googleAuth.idToken;
      if (idToken == null) {
        throw const AuthException(
          'Google did not return an ID token. Make sure the Android OAuth client in Google Cloud Console matches this app\'s package name and signing-cert SHA-1.',
        );
      }
      return _supabase.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: googleAuth.accessToken,
      );
    }

    // Desktop/web: browser PKCE flow. The OAuth redirect lands on
    // trailtether://login-callback, picked up by DeepLinkService which
    // exchanges the code through getSessionFromUrl. Returning null is
    // correct — AuthProvider's authStateStream listener notices the new
    // session asynchronously.
    final launched = await _supabase.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: 'trailtether://login-callback',
      authScreenLaunchMode: LaunchMode.externalApplication,
    );
    if (!launched) {
      throw const AuthException(
        'Could not open the browser for Google Sign-In. Check your default browser is set, then try again.',
      );
    }
    return null;
  }

  // â”€â”€ Sign out â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  static Future<void> signOut() async {
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      try {
        await _googleSignIn.signOut();
      } catch (_) {
        // not signed in via Google — fine, fall through to Supabase signOut
      }
    }
    await _supabase.auth.signOut();
  }

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
