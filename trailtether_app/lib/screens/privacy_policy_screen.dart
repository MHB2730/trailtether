import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/constants.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kColorBg,
      appBar: AppBar(
        backgroundColor: kColorBg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: kColorCream, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Privacy Policy',
          style: GoogleFonts.outfit(
              color: kColorCream, fontSize: 17, fontWeight: FontWeight.w700),
        ),
      ),
      body: const SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, 8, 20, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Section(
              title: 'Trailtether Privacy Policy',
              body: 'Effective date: April 2026\n\n'
                  'Trailtether ("the app", "we", "our") is owned and operated by Hilltrek (Pty) Ltd. '
                  'This policy explains what information we collect, why, and your rights regarding '
                  'that information. We are committed to compliance with South Africa\'s Protection '
                  'of Personal Information Act (POPIA).',
            ),
            _Section(
              title: '1. Information We Collect',
              body: 'a) Account Data\n'
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
              title: '2. Data Usage',
              body:
                  'Your data is used strictly for provide the services offered by Trailtether. '
                  'We do not sell your personal information to third parties. We may use anonymized '
                  'and aggregated data for research or platform improvement purposes.',
            ),
            _Section(
              title: '3. Mandatory Registration',
              body:
                  'Access to Trailtether is restricted to registered users only. '
                  'This ensure accountability and enhances community safety. '
                  'You may delete your account at any time from the Profile tab, '
                  'which will remove your personal data from our active systems.',
            ),
            _Section(
              title: '4. Third-Party Services',
              body: 'The app uses the following third-party services:\n\n'
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
              title: '5. Offline Use',
              body:
                  'Tile data cached for offline use is stored locally on your '
                  'device in an SQLite database managed by flutter_map_tile_caching. '
                  'No personal data is stored in this cache.',
            ),
            _Section(
              title: '6. Data Retention',
              body: 'Community reviews and incident reports are retained '
                  'indefinitely so that the hiking community can benefit from '
                  'historical trail knowledge. You may request deletion of '
                  'content you submitted by contacting us (see section 9).\n\n'
                  'GPX uploads are retained until you or we remove them. We '
                  'reserve the right to delete uploads that violate our '
                  'community guidelines.',
            ),
            _Section(
              title: '7. Children\'s Privacy',
              body: 'The app is not directed at children under the age of 13. '
                  'We do not knowingly collect personal information from '
                  'children. If you believe a child has submitted personal '
                  'information, please contact us and we will delete it promptly.',
            ),
            _Section(
              title: '8. Your Rights (POPIA)',
              body: 'Under POPIA you have the right to:\n'
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
              title: '9. Contact',
              body: 'For privacy queries, correction or deletion requests:\n\n'
                  'Hilltrek (Pty) Ltd\n'
                  'Email: info@hilltrek.co.za\n'
                  'Subject line: "Privacy Request — Trailtether"\n\n'
                  'We will respond within 14 business days.',
            ),
            _Section(
              title: '10. Changes to This Policy',
              body: 'We may update this policy from time to time. Significant '
                  'changes will be notified via an in-app banner. Continued '
                  'use of the app after the effective date constitutes '
                  'acceptance of the updated policy.',
            ),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final String body;
  const _Section({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: GoogleFonts.outfit(
                  color: kColorCream,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  height: 1.3)),
          const SizedBox(height: 8),
          Text(body,
              style: GoogleFonts.outfit(
                  color: kColorCream.withOpacity(0.6),
                  fontSize: 13,
                  height: 1.65)),
        ],
      ),
    );
  }
}
