import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'login_screen.dart';
import 'app_shell.dart';
import 'desktop_shell.dart';
import '../core/constants.dart';

import 'onboarding_screen.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _onboardingDone = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _checkOnboarding();
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
        backgroundColor: kColorBg,
        body: Center(child: CircularProgressIndicator(color: kColorOrange)),
      );
    }

    if (!_onboardingDone) {
      return OnboardingScreen(
        onDone: () {
          setState(() => _onboardingDone = true);
        },
      );
    }

    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final session = Supabase.instance.client.auth.currentSession;
        
        if (session == null) {
          return const LoginScreen();
        }

        // Determine if we should show desktop or mobile shell
        final isLargeScreen = MediaQuery.of(context).size.width > 900;
        
        if (isLargeScreen) {
          return const MainDesktopShell();
        } else {
          return const AppShell();
        }
      },
    );
  }
}
