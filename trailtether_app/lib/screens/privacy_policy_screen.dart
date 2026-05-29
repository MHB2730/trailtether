// Trailtether 3.0 — Privacy & Data screen.
//
// POPIA-compliant disclosure document reskinned to the v3 design tokens.
// Every legacy paragraph is preserved verbatim so the legal copy in
// `_kSections` remains the source of truth for South African compliance.
// The Contact section's `info@hilltrek.co.za` address is a tap-to-mailto
// link via url_launcher.

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/design_tokens.dart';
import '../widgets/design/tt_ambient.dart';
import '../widgets/design/tt_app_bar.dart';
import '../widgets/design/tt_glass_card.dart';
import '../widgets/design/tt_topo.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  static const String _contactEmail = 'info@hilltrek.co.za';

  Future<void> _openMail(BuildContext context) async {
    final uri = Uri(
      scheme: 'mailto',
      path: _contactEmail,
      queryParameters: const {'subject': 'Privacy Request — Trailtether'},
    );
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not open mail app. Email $_contactEmail directly.',
            style: TT.body(size: 13, color: TT.text),
          ),
          backgroundColor: TT.surf,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TT.bg,
      body: Stack(
        children: [
          const Positioned.fill(child: TTAmbient()),
          const Positioned.fill(child: TTTopoBackdrop(opacity: 0.4)),
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                _SubPageAppBar(
                  title: 'Privacy & Data',
                  onBack: () => Navigator.of(context).pop(),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(18, 4, 18, 32),
                    children: [
                      _IntroCard(onContactTap: () => _openMail(context)),
                      const SizedBox(height: 14),
                      for (var i = 0; i < _kSections.length; i++) ...[
                        _PolicySectionCard(
                          section: _kSections[i],
                          isContact: _kSections[i].title.startsWith('9.'),
                          onContactTap: () => _openMail(context),
                        ),
                        if (i < _kSections.length - 1)
                          const SizedBox(height: 14),
                      ],
                      const SizedBox(height: 20),
                      _FooterContact(onTap: () => _openMail(context)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Sub-page app bar — chevron-left back button + TRAILTETHER wordmark +
/// page title, matching the visual rhythm of [TTPageAppBar] used on top-level
/// screens.
class _SubPageAppBar extends StatelessWidget {
  final String title;
  final VoidCallback onBack;
  const _SubPageAppBar({required this.title, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 18, 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          TTIconBtn(icon: Icons.chevron_left, onTap: onBack),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const TTBrandMark(),
                const SizedBox(height: 4),
                Text(title, style: TT.title(22)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _IntroCard extends StatelessWidget {
  final VoidCallback onContactTap;
  const _IntroCard({required this.onContactTap});

  @override
  Widget build(BuildContext context) {
    return TTCard(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('POPIA · EFFECTIVE APRIL 2026',
              style: TT.label(color: TT.ember)),
          const SizedBox(height: 8),
          Text('Trailtether Privacy Policy', style: TT.title(20)),
          const SizedBox(height: 10),
          Text(
            'Trailtether ("the app", "we", "our") is owned and operated by Hilltrek (Pty) Ltd. '
            'This policy explains what information we collect, why, and your rights regarding '
            'that information. We are committed to compliance with South Africa\'s Protection '
            'of Personal Information Act (POPIA).',
            style: TT
                .body(size: 13, color: TT.text2, w: FontWeight.w500)
                .copyWith(height: 1.6),
          ),
        ],
      ),
    );
  }
}

class _PolicySectionCard extends StatelessWidget {
  final _Section section;
  final bool isContact;
  final VoidCallback onContactTap;

  const _PolicySectionCard({
    required this.section,
    required this.isContact,
    required this.onContactTap,
  });

  @override
  Widget build(BuildContext context) {
    return TTCard(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(section.title, style: TT.title(15)),
          const SizedBox(height: 10),
          const Divider(height: 1, thickness: 1, color: TT.line),
          const SizedBox(height: 12),
          if (isContact)
            _ContactBody(body: section.body, onTap: onContactTap)
          else
            Text(
              section.body,
              style: TT
                  .body(size: 13, color: TT.text2, w: FontWeight.w500)
                  .copyWith(height: 1.65),
            ),
        ],
      ),
    );
  }
}

class _ContactBody extends StatefulWidget {
  final String body;
  final VoidCallback onTap;
  const _ContactBody({required this.body, required this.onTap});

  @override
  State<_ContactBody> createState() => _ContactBodyState();
}

class _ContactBodyState extends State<_ContactBody> {
  late final TapGestureRecognizer _recognizer = TapGestureRecognizer()
    ..onTap = widget.onTap;

  @override
  void dispose() {
    _recognizer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const email = PrivacyPolicyScreen._contactEmail;
    final body = widget.body;
    final idx = body.indexOf(email);
    final base = TT
        .body(size: 13, color: TT.text2, w: FontWeight.w500)
        .copyWith(height: 1.65);
    if (idx < 0) return Text(body, style: base);

    final pre = body.substring(0, idx);
    final post = body.substring(idx + email.length);
    return RichText(
      text: TextSpan(
        style: base,
        children: [
          TextSpan(text: pre),
          TextSpan(
            text: email,
            style: base.copyWith(
              color: TT.ember,
              fontWeight: FontWeight.w800,
              decoration: TextDecoration.underline,
              decorationColor: TT.ember,
            ),
            recognizer: _recognizer,
          ),
          TextSpan(text: post),
        ],
      ),
    );
  }
}

class _FooterContact extends StatelessWidget {
  final VoidCallback onTap;
  const _FooterContact({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: TT.emberSoft,
          borderRadius: BorderRadius.circular(TT.rMd),
          border: Border.all(color: const Color(0x52FF6A2C), width: 1),
        ),
        child: Row(
          children: [
            const Icon(Icons.mail_outline_rounded, color: TT.ember, size: 18),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('CONTACT',
                      style: TT.label(color: TT.ember.withOpacity(0.85))),
                  const SizedBox(height: 4),
                  Text('Email ${PrivacyPolicyScreen._contactEmail}',
                      style: TT.body(
                          size: 13, w: FontWeight.w800, color: TT.ember)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_rounded, color: TT.ember, size: 16),
          ],
        ),
      ),
    );
  }
}

class _Section {
  final String title;
  final String body;
  const _Section(this.title, this.body);
}

const List<_Section> _kSections = [
  _Section(
    '1. Information We Collect',
    'a) Account Data\n'
        'When you register, we collect your email address and display name. '
        'This information is used to:\n'
        '• Authenticate your access to the platform.\n'
        '• Personalize your experience and enable community features.\n'
        '• Associate your trail reviews, incident reports, and recordings with your account.\n\n'
        'b) Profile Information\n'
        'You may optionally provide a bio, profile photo, and emergency contact details '
        'in your Profile. This data is used to enhance your safety and community interactions.\n\n'
        'c) GPS Location\n'
        'The app accesses your device location to provide navigation and tracking features. '
        'Live location data is processed locally. If you choice to record a hike or report '
        'an incident, your coordinates are saved to our servers to provide the requested '
        'service.\n\n'
        'd) Community Content\n'
        'Trail reviews and incident reports are stored in our secure database. '
        'These are shared with the community to improve trail safety for all users.',
  ),
  _Section(
    '2. Data Usage',
    'Your data is used strictly for provide the services offered by Trailtether. '
        'We do not sell your personal information to third parties. We may use anonymized '
        'and aggregated data for research or platform improvement purposes.',
  ),
  _Section(
    '3. Mandatory Registration',
    'Access to Trailtether is restricted to registered users only. '
        'This ensure accountability and enhances community safety. '
        'You may delete your account at any time from the Profile tab, '
        'which will remove your personal data from our active systems.',
  ),
  _Section(
    '4. Third-Party Services',
    'The app uses the following third-party services:\n\n'
        '• Supabase (Database, Storage, Auth) — data is stored '
        'on servers under Supabase\'s terms of service and '
        'standard contractual clauses.\n\n'
        '• MapTiler / OpenStreetMap / Esri — map tile images are '
        'fetched from these providers. Your IP address is disclosed '
        'to the tile server in the normal course of HTTP requests.\n\n'
        '• Google Fonts — font files are bundled in the app and '
        'do not require a network call at runtime.',
  ),
  _Section(
    '5. Offline Use',
    'Tile data cached for offline use is stored locally on your '
        'device in an SQLite database managed by flutter_map_tile_caching. '
        'No personal data is stored in this cache.',
  ),
  _Section(
    '6. Data Retention',
    'Community reviews and incident reports are retained '
        'indefinitely so that the hiking community can benefit from '
        'historical trail knowledge. You may request deletion of '
        'content you submitted by contacting us (see section 9).\n\n'
        'GPX uploads are retained until you or we remove them. We '
        'reserve the right to delete uploads that violate our '
        'community guidelines.',
  ),
  _Section(
    "7. Children's Privacy",
    'The app is not directed at children under the age of 13. '
        'We do not knowingly collect personal information from '
        'children. If you believe a child has submitted personal '
        'information, please contact us and we will delete it promptly.',
  ),
  _Section(
    '8. Your Rights (POPIA)',
    'Under POPIA you have the right to:\n'
        '• Access personal information we hold about you\n'
        '• Request correction of inaccurate information\n'
        '• Request deletion ("right to be forgotten")\n'
        '• Object to processing\n'
        '• Lodge a complaint with the Information Regulator of South Africa\n\n'
        'Because reviews and incident reports are anonymous by design, '
        'we cannot verify authorship without your device ID. You may '
        'provide it when making a request.',
  ),
  _Section(
    '9. Contact',
    'For privacy queries, correction or deletion requests:\n\n'
        'Hilltrek (Pty) Ltd\n'
        'Email: info@hilltrek.co.za\n'
        'Subject line: "Privacy Request — Trailtether"\n\n'
        'We will respond within 14 business days.',
  ),
  _Section(
    '10. Changes to This Policy',
    'We may update this policy from time to time. Significant '
        'changes will be notified via an in-app banner. Continued '
        'use of the app after the effective date constitutes '
        'acceptance of the updated policy.',
  ),
];
