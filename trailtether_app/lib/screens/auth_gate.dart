import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'login_screen.dart';
import 'app_shell.dart';
import 'pc/pc_shell.dart';
import 'set_new_password_screen.dart';
import '../core/design_tokens.dart';

import 'onboarding_screen.dart'
    show hasCompletedOnboarding, markOnboardingDone, markPopiaConsented;
import 'tt_welcome_screen.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _onboardingDone = false;
  bool _loading = true;
  bool _recoveryMode = false;
  StreamSubscription<AuthState>? _authSub;

  @override
  void initState() {
    super.initState();
    _checkOnboarding();
    // Watch globally for password-recovery events. The recovery deep-link
    // hands the URL to Supabase via DeepLinkService -> getSessionFromUrl,
    // which then fires AuthChangeEvent.passwordRecovery here.
    _authSub = Supabase.instance.client.auth.onAuthStateChange.listen((s) {
      if (!mounted) return;
      if (s.event == AuthChangeEvent.passwordRecovery) {
        setState(() => _recoveryMode = true);
      } else if (s.event == AuthChangeEvent.signedOut) {
        setState(() => _recoveryMode = false);
      }
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  Future<void> _checkOnboarding() async {
    final done = await hasCompletedOnboarding();
    if (mounted) {
      setState(() {
        _onboardingDone = done;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: TT.bg,
        body: Center(child: CircularProgressIndicator(color: TT.ember)),
      );
    }

    if (!_onboardingDone) {
      return TTWelcomeScreen(
        onDone: () async {
          // TTWelcomeScreen replaces the legacy OnboardingScreen which carried
          // an explicit POPIA consent step. The welcome copy already explains
          // that data lives in South Africa and that the user controls who
          // sees their location, so we record consent at the same moment
          // onboarding completes. hasCompletedOnboarding() requires both keys
          // to be set, so without this the AuthGate would loop back to
          // Welcome on every cold start.
          await markOnboardingDone();
          await markPopiaConsented();
          if (mounted) setState(() => _onboardingDone = true);
        },
      );
    }

    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final session = Supabase.instance.client.auth.currentSession;

        // Recovery flow takes precedence: even though a session exists
        // (Supabase mints a short-lived one for the recovery link), the user
        // must set a new password before reaching the real shell.
        if (_recoveryMode && session != null) {
          return SetNewPasswordScreen(
            onCompleted: () => setState(() => _recoveryMode = false),
          );
        }

        if (session == null) {
          return const LoginScreen();
        }

        // Large screens (Windows / macOS / Linux desktop, plus oversized
        // tablets) get the dedicated PC base-camp shell. Phones and small
        // tablets stay on the mobile shell. The new shell is ported from
        // pc.html — see screens/pc/pc_shell.dart.
        final isLargeScreen = MediaQuery.of(context).size.width > 900;

        if (isLargeScreen) {
          return const MainPcShell();
        } else {
          return const AppShell();
        }
      },
    );
  }
}
