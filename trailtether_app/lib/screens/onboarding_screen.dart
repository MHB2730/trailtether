import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import '../core/constants.dart';
import '../services/location_service.dart';
import 'privacy_policy_screen.dart';

const _kOnboardingDoneKey = 'onboarding_done_v1';
const _kPopiaConsentKey = 'popia_consent_at_v1';

/// Returns true when the user has already completed onboarding AND given POPIA consent.
Future<bool> hasCompletedOnboarding() async {
  final prefs = await SharedPreferences.getInstance();
  return (prefs.getBool(_kOnboardingDoneKey) ?? false) &&
      (prefs.getString(_kPopiaConsentKey) != null);
}

/// Persist onboarding-completed flag.
Future<void> markOnboardingDone() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(_kOnboardingDoneKey, true);
}

/// Persist POPIA consent timestamp (ISO 8601). Required by POPIA s.11(1)(a)
/// — proof of opt-in must be retained.
Future<void> markPopiaConsented() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_kPopiaConsentKey, DateTime.now().toIso8601String());
}

class OnboardingScreen extends StatefulWidget {
  final VoidCallback onDone;
  const OnboardingScreen({super.key, required this.onDone});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;

  // True when the user has ticked the POPIA consent box.
  bool _popiaConsented = false;

  // Total pages: 1 Welcome + 3 feature pages + 1 permission page + 1 consent page.
  static const _featurePageCount = 4;
  static const _totalPages = _featurePageCount + 2;
  // Index of the consent page (always last).
  int get _permissionPageIndex => _totalPages - 2;
  int get _consentPageIndex => _totalPages - 1;
  bool get _onConsentPage => _page == _consentPageIndex;

  static const _featurePages = [
    _WelcomePage(),
    _OnboardPage(
      emoji: '📡',
      title: 'Field Intel & Community',
      body: 'Become a field agent. Report water sources, viewpoints, '
          'and trail hazards in real-time. Check-in at summits '
          'and caves to verify your accomplishments.',
    ),
    _OnboardPage(
      emoji: '🏔',
      title: 'Navigation & Tracking',
      body: 'Map trails with elevation profiles and estimated hike times. '
          'Enable GPS to see your real-time position even offline.',
    ),
    _OnboardPage(
      emoji: '👥',
      title: 'Team Coordination',
      body: 'Create a team, invite friends, and plan hikes together. '
          'Share gear lists and coordinates to stay safe and connected.',
    ),
  ];

  void _next() {
    if (_page < _totalPages - 1) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    } else {
      // On the consent page → only finish if consented.
      if (_popiaConsented) _finish();
    }
  }

  void _finish() async {
    await markOnboardingDone();
    await markPopiaConsented();
    widget.onDone();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lastPage = _page == _totalPages - 1;
    final canFinish = !lastPage || _popiaConsented;

    return Scaffold(
      backgroundColor: kColorBg,
      body: SafeArea(
        child: Column(
          children: [
            // ── Skip — hidden on the consent page (POPIA opt-in is mandatory) ─
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, 12, 20, 0),
                child: _onConsentPage
                    ? const SizedBox(height: 36)
                    : TextButton(
                        onPressed: () => _controller.animateToPage(
                          _consentPageIndex,
                          duration: const Duration(milliseconds: 350),
                          curve: Curves.easeInOut,
                        ),
                        child: Text('Skip',
                            style: GoogleFonts.outfit(
                                color: kColorCream.withOpacity(0.4),
                                fontSize: 13)),
                      ),
              ),
            ),

            // ── Page content ───────────────────────────────────────────────
            Expanded(
              child: PageView.builder(
                controller: _controller,
                onPageChanged: (i) => setState(() => _page = i),
                itemCount: _totalPages,
                itemBuilder: (_, i) {
                  if (i < _featurePageCount) return _featurePages[i];
                  if (i == _permissionPageIndex) return const _PermissionPage();
                  return _ConsentPage(
                    consented: _popiaConsented,
                    onConsentChanged: (v) =>
                        setState(() => _popiaConsented = v),
                  );
                },
              ),
            ),

            // ── Dots ───────────────────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_totalPages, (i) {
                final active = i == _page;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: active ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: active ? kColorOrange : kColorCream.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),

            const SizedBox(height: 32),

            // ── CTA button ─────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(32, 0, 32, 32),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: canFinish ? _next : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kColorOrange,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: kColorOrange.withOpacity(0.25),
                    disabledForegroundColor: Colors.white70,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: Text(
                    !lastPage
                        ? 'Next'
                        : (_popiaConsented
                            ? 'I Accept & Enter'
                            : 'Accept terms to continue'),
                    style: GoogleFonts.outfit(
                        fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Consent page ─────────────────────────────────────────────────────────────
class _ConsentPage extends StatelessWidget {
  final bool consented;
  final ValueChanged<bool> onConsentChanged;
  const _ConsentPage({
    required this.consented,
    required this.onConsentChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: kColorOrange.withOpacity(0.1),
                shape: BoxShape.circle,
                border: Border.all(
                    color: kColorOrange.withOpacity(0.3), width: 1.5),
              ),
              child: const Center(
                child: Text('🔒', style: TextStyle(fontSize: 44)),
              ),
            ),
            const SizedBox(height: 28),
            Text(
              'Your Privacy',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                color: kColorCream,
                fontSize: 24,
                fontWeight: FontWeight.w800,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Trailtether is owned by Hilltrek (Pty) Ltd. We process the following information to provide our services:',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                  color: kColorCream.withOpacity(0.55),
                  fontSize: 14,
                  height: 1.5),
            ),
            const SizedBox(height: 14),
            // POPIA disclosures — list everything collected
            const _Bullet(
                'Username and display name you choose at registration'),
            const _Bullet(
                'Email address and password (hashed) for your account'),
            const _Bullet('GPS location while tracking is active'),
            const _Bullet('Reviews, photos and GPX routes you choose to share'),
            const _Bullet('Trail reports and incident submissions you create'),
            const _Bullet('Device ID and choice for anonymous attribution'),
            const SizedBox(height: 20),
            Text(
              'Indemnity & Waiver',
              style: GoogleFonts.outfit(
                color: kColorCream,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
              ),
              child: Text(
                'By using this app, you acknowledge that hiking is dangerous. '
                'You agree to indemnify and hold harmless Hilltrek (Pty) Ltd, '
                'its directors, and Trailtether from any loss, injury, or '
                'death resulting from your use of the app or any information '
                'provided herein. You use this service at your own risk.',
                style: GoogleFonts.outfit(
                    color: Colors.white70, fontSize: 12, height: 1.5),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: kColorPanel,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: kColorBorder),
              ),
              child: Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GestureDetector(
                        onTap: () => onConsentChanged(!consented),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            color:
                                consented ? kColorOrange : Colors.transparent,
                            borderRadius: BorderRadius.circular(5),
                            border: Border.all(
                                color: consented ? kColorOrange : kColorBorder),
                          ),
                          child: consented
                              ? const Icon(Icons.check,
                                  color: Colors.white, size: 14)
                              : null,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'I accept the Terms of Service, Waiver and Indemnity, '
                          'and consent to Hilltrek (Pty) Ltd processing my '
                          'personal information as described above.',
                          style: GoogleFonts.outfit(
                              color: kColorCream.withOpacity(0.8),
                              fontSize: 12,
                              height: 1.5),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const PrivacyPolicyScreen(),
                        ),
                      ),
                      child: Text('Read full Privacy Policy →',
                          style: GoogleFonts.outfit(
                              color: kColorOrange,
                              fontSize: 12,
                              fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  final String text;
  const _Bullet(this.text);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.fiber_manual_record,
                color: kColorOrange.withOpacity(0.7), size: 7),
            const SizedBox(width: 8),
            Expanded(
              child: Text(text,
                  style: GoogleFonts.outfit(
                      color: kColorCream.withOpacity(0.75),
                      fontSize: 13,
                      height: 1.5)),
            ),
          ],
        ),
      );
}

class _WelcomePage extends StatelessWidget {
  const _WelcomePage();
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: Image.asset(
            'assets/icon/hero_mountains.jpg',
            fit: BoxFit.cover,
          ),
        ),
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.2),
                  Colors.transparent,
                  Colors.black.withOpacity(0.5),
                  Colors.black.withOpacity(0.9),
                ],
              ),
            ),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  'WELCOME TO',
                  style: GoogleFonts.outfit(
                    color: Colors.white70,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 6,
                  ),
                ),
                const SizedBox(height: 8),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    'TRAILTETHER',
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 48,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -2,
                      height: 1,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: kColorOrange,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: kColorOrange.withOpacity(0.4),
                        blurRadius: 15,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Text(
                    'FIELD INTELLIGENCE',
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2,
                    ),
                  ),
                ),
                const SizedBox(height: 60),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── Single onboarding page ───────────────────────────────────────────────────

class _OnboardPage extends StatelessWidget {
  final String emoji;
  final String title;
  final String body;

  const _OnboardPage({
    required this.emoji,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 36),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Emoji icon
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: kColorOrange.withOpacity(0.1),
              shape: BoxShape.circle,
              border:
                  Border.all(color: kColorOrange.withOpacity(0.3), width: 1.5),
            ),
            child: Center(
              child: Text(emoji, style: const TextStyle(fontSize: 44)),
            ),
          ),

          const SizedBox(height: 36),

          Text(
            title,
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              color: kColorCream,
              fontSize: 24,
              fontWeight: FontWeight.w800,
              height: 1.2,
            ),
          ),

          const SizedBox(height: 16),

          Text(
            body,
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              color: kColorCream.withOpacity(0.55),
              fontSize: 15,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}

class _PermissionPage extends StatefulWidget {
  const _PermissionPage();
  @override
  State<_PermissionPage> createState() => _PermissionPageState();
}

class _PermissionPageState extends State<_PermissionPage> {
  bool _locDone = false;
  bool _notifDone = false;
  bool _mediaDone = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: kColorOrange.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child:
                const Center(child: Text('📱', style: TextStyle(fontSize: 40))),
          ),
          const SizedBox(height: 24),
          Text(
            'App Permissions',
            style: GoogleFonts.outfit(
                color: kColorCream, fontSize: 24, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          Text(
            'To provide a safe and community-driven experience, Trailtether requires the following access:',
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
                color: kColorCream.withOpacity(0.6), fontSize: 14, height: 1.5),
          ),
          const SizedBox(height: 32),
          _PermItem(
            icon: Icons.location_on_rounded,
            title: 'GPS Location',
            body:
                'Used for live tracking, trail navigation, and recording your hikes.',
            done: _locDone,
            onTap: () async {
              final granted =
                  await LocationService.requestPermission(background: true);
              setState(() => _locDone = granted);
            },
          ),
          const SizedBox(height: 16),
          _PermItem(
            icon: Icons.notifications_active_rounded,
            title: 'Notifications',
            body:
                'Receive SOS alerts, team messages, and community safety updates.',
            done: _notifDone,
            onTap: () async {
              final status = await Permission.notification.request();
              setState(() => _notifDone = status.isGranted);
            },
          ),
          const SizedBox(height: 16),
          _PermItem(
            icon: Icons.photo_library_rounded,
            title: 'Camera & Media',
            body:
                'Required for taking profile photos and uploading trail intel reports.',
            done: _mediaDone,
            onTap: () async {
              final s1 = await Permission.camera.request();
              final s2 = await Permission.photos.request();
              setState(() => _mediaDone = s1.isGranted || s2.isGranted);
            },
          ),
        ],
      ),
    );
  }
}

class _PermItem extends StatelessWidget {
  final IconData icon;
  final String title, body;
  final bool done;
  final VoidCallback onTap;
  const _PermItem(
      {required this.icon,
      required this.title,
      required this.body,
      required this.done,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: kColorPanel,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: done ? kColorOrange : kColorBorder),
        ),
        child: Row(
          children: [
            Icon(icon,
                color: done ? kColorOrange : kColorCream.withOpacity(0.4)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: GoogleFonts.outfit(
                          color: kColorCream,
                          fontSize: 15,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text(body,
                      style: GoogleFonts.outfit(
                          color: kColorCream.withOpacity(0.5), fontSize: 12)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (done)
              const Icon(Icons.check_circle, color: kColorOrange, size: 20)
            else
              const Icon(Icons.chevron_right, color: Colors.white24),
          ],
        ),
      ),
    );
  }
}
