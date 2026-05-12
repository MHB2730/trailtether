import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/constants.dart';

class UsefulInfoTool extends StatelessWidget {
  const UsefulInfoTool({super.key});

  static const Map<String, String> emergencyNumbers = {
    "Mountain Rescue": "0800005133",
    "Ambulance": "10177",
    "General Emergency": "112",
    "Police": "10111",
  };

  static const List<Map<String, String>> localContacts = [
    {"name": "Police Southern Berg", "phone": "0337021332"},
    {"name": "Community Watch", "phone": "0337021117"},
    {"name": "Underberg EMS", "phone": "0818570553"},
    {"name": "Underberg EMS WhatsApp", "phone": "0799769056"},
    {"name": "Doctor", "phone": "0337011819"},
    {"name": "Clinic", "phone": "0337011086"},
    {"name": "Sani Search & Rescue", "phone": "0763950119"},
  ];

  static const List<Map<String, dynamic>> rescuePoints = [
    {
      "name": "Cobham",
      "phones": ["0337020831", "0825599493"]
    },
    {
      "name": "Drak Gardens",
      "phones": ["0337011186", "0839623934"]
    }
  ];

  Future<void> _call(String phone) async {
    final uri = Uri.parse('tel:${phone.replaceAll(' ', '')}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSectionHeader("EMERGENCY NUMBERS", Icons.emergency_outlined),
        ...emergencyNumbers.entries
            .map((e) => _buildContactTile(e.key, e.value, isEmergency: true)),
        const SizedBox(height: 24),

        _buildSectionHeader("LOCAL CONTACTS", Icons.local_hospital_outlined),
        ...localContacts.map((c) => _buildContactTile(c['name']!, c['phone']!)),
        const SizedBox(height: 24),

        _buildSectionHeader("RESCUE POINTS", Icons.location_on_outlined),
        ...rescuePoints.map((p) =>
            _buildRescuePointTile(p['name'], List<String>.from(p['phones']))),
        const SizedBox(height: 100), // Extra space for bottom scrolling
      ],
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 4),
      child: Row(
        children: [
          Icon(icon, color: kColorOrange, size: 18),
          const SizedBox(width: 8),
          Text(
            title,
            style: GoogleFonts.outfit(
              color: kColorCream.withOpacity(0.5),
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactTile(String name, String phone,
      {bool isEmergency = false}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: kColorPanel,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: isEmergency ? kColorOrange.withOpacity(0.3) : kColorBorder),
      ),
      child: ListTile(
        onTap: () => _call(phone),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: (isEmergency ? kColorOrange : kColorCream).withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            isEmergency ? Icons.phone_android : Icons.phone_outlined,
            color: isEmergency ? kColorOrange : kColorCream,
            size: 20,
          ),
        ),
        title: Text(
          name,
          style: GoogleFonts.outfit(
            color: kColorCream,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          phone,
          style: GoogleFonts.outfit(
            color: kColorCream.withOpacity(0.5),
            fontSize: 13,
          ),
        ),
        trailing: Icon(Icons.call,
            color: isEmergency ? kColorOrange : kColorCream.withOpacity(0.3),
            size: 18),
      ),
    );
  }

  Widget _buildRescuePointTile(String name, List<String> phones) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: kColorPanel,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kColorBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.home_work_outlined,
                    color: kColorCream, size: 20),
                const SizedBox(width: 10),
                Text(
                  name,
                  style: GoogleFonts.outfit(
                    color: kColorCream,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...phones.map((phone) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: InkWell(
                    onTap: () => _call(phone),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: kColorCream.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Icon(Icons.phone,
                              color: kColorOrange, size: 14),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          phone,
                          style: GoogleFonts.outfit(
                            color: kColorCream.withOpacity(0.8),
                            fontSize: 14,
                          ),
                        ),
                        const Spacer(),
                        Icon(Icons.chevron_right,
                            color: kColorCream.withOpacity(0.2), size: 16),
                      ],
                    ),
                  ),
                )),
          ],
        ),
      ),
    );
  }
}
