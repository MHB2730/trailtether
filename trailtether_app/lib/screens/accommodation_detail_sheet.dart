import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/constants.dart';
import '../models/accommodation.dart';

class AccommodationDetailSheet extends StatelessWidget {
  final Accommodation acc;

  const AccommodationDetailSheet({super.key, required this.acc});

  static void show(BuildContext context, Accommodation acc) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AccommodationDetailSheet(acc: acc),
    );
  }

  Future<void> _call(String phone) async {
    final uri = Uri.parse('tel:${phone.replaceAll(' ', '')}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    final emoji = switch (acc.type) {
      'hotel' => '🏨',
      'resort' => '🏖️',
      'lodge' => '🏡',
      'backpacker' => '🎒',
      'self_catering' => '🍳',
      'guesthouse' => '🛌',
      _ => '🏠',
    };

    return Container(
      margin: const EdgeInsets.only(top: 120),
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
      decoration: const BoxDecoration(
        color: Color(0xFF111111),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 14),
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: kColorCream.withOpacity(0.15),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.blueAccent.withOpacity(0.1),
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: Colors.blueAccent.withOpacity(0.3), width: 1.5),
                ),
                child: Center(
                    child: Text(emoji, style: const TextStyle(fontSize: 28))),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(acc.name,
                        style: GoogleFonts.outfit(
                            color: kColorCream,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            height: 1.2)),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: kColorPanel,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: kColorBorder),
                      ),
                      child: Text('${acc.region} Drakensberg',
                          style: GoogleFonts.outfit(
                              color: kColorCream.withOpacity(0.5),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.3)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          _StatRow(
            icon: Icons.category_outlined,
            label: 'Type',
            value: acc.type.replaceAll('_', ' ').toUpperCase(),
          ),
          const SizedBox(height: 12),
          if (acc.phone != null) ...[
            _StatRow(
              icon: Icons.phone_outlined,
              label: 'Phone',
              value: acc.phone!,
              onTap: () => _call(acc.phone!),
              actionIcon: Icons.call,
            ),
            const SizedBox(height: 12),
          ],
          _StatRow(
            icon: Icons.location_on_outlined,
            label: 'Coordinates',
            value:
                '${acc.lat.toStringAsFixed(5)}, ${acc.lon.toStringAsFixed(5)}',
            onTap: () {
              Clipboard.setData(ClipboardData(text: '${acc.lat}, ${acc.lon}'));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Coordinates copied')),
              );
            },
            actionIcon: Icons.copy,
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close),
              label: const Text('DISMISS'),
              style: ElevatedButton.styleFrom(
                backgroundColor: kColorPanel,
                foregroundColor: kColorCream,
                elevation: 0,
                side: const BorderSide(color: kColorBorder),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;
  final IconData? actionIcon;

  const _StatRow({
    required this.icon,
    required this.label,
    required this.value,
    this.onTap,
    this.actionIcon,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: kColorPanel,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: kColorBorder),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blueAccent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon,
                  color: Colors.blueAccent.withOpacity(0.8), size: 18),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: GoogleFonts.outfit(
                          color: kColorCream.withOpacity(0.3),
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8)),
                  const SizedBox(height: 2),
                  Text(value,
                      style: GoogleFonts.outfit(
                          color: kColorCream,
                          fontSize: 15,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            if (actionIcon != null)
              Icon(actionIcon, color: kColorCream.withOpacity(0.15), size: 18),
          ],
        ),
      ),
    );
  }
}
