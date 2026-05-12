import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/constants.dart';
import '../models/cave_waypoint.dart';
import '../providers/static_data_provider.dart';
import '../providers/community_provider.dart';

class CaveDetailSheet extends StatelessWidget {
  final CaveWaypoint cave;
  final VoidCallback? onViewTrail;

  const CaveDetailSheet({super.key, required this.cave, this.onViewTrail});

  static void show(BuildContext context, CaveWaypoint cave,
      {VoidCallback? onViewTrail}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CaveDetailSheet(cave: cave, onViewTrail: onViewTrail),
    );
  }

  static const _caveBrown = Color(0xFF795548);
  static const _shelterTeal = Color(0xFF00897B);

  @override
  Widget build(BuildContext context) {
    final color = cave.isShelter ? _shelterTeal : _caveBrown;
    final emoji = cave.isShelter ? '🛖' : '🕳';
    final typeLabel = cave.isShelter ? 'Rock Shelter' : 'Cave';

    // Find any hike route that mentions this cave name
    final data = context.read<StaticDataProvider>();
    final coreName = _coreName(cave.name);
    final linked = data.allTrails
        .where((t) => t.isCave && t.name.toLowerCase().contains(coreName))
        .toList();

    return Container(
      margin: const EdgeInsets.only(top: 80),
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
      decoration: const BoxDecoration(
        color: Color(0xFF111111),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Handle ──────────────────────────────────────────────
          Center(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: kColorCream.withOpacity(0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // ── Header ──────────────────────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.18),
                  shape: BoxShape.circle,
                  border: Border.all(color: color.withOpacity(0.5), width: 1.5),
                ),
                child: Center(
                    child: Text(emoji, style: const TextStyle(fontSize: 24))),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(cave.name,
                        style: GoogleFonts.outfit(
                            color: kColorCream,
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            height: 1.2)),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: color.withOpacity(0.4)),
                      ),
                      child: Text(typeLabel,
                          style: GoogleFonts.outfit(
                              color: color,
                              fontSize: 11,
                              fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),
          _Divider(),
          const SizedBox(height: 16),

          // ── Stats ────────────────────────────────────────────────
          Row(children: [
            _StatChip(
              icon: Icons.height,
              label: 'Elevation',
              value: cave.elevationM > 0
                  ? '${cave.elevationM.round()} m'
                  : 'Unknown',
            ),
            const SizedBox(width: 12),
            _StatChip(
              icon: Icons.terrain,
              label: 'Type',
              value: typeLabel,
            ),
          ]),

          const SizedBox(height: 16),

          // ── Description (if available) ───────────────────────────
          if (cave.description != null) ...[
            Text(cave.description!,
                style: GoogleFonts.outfit(
                    color: kColorCream.withOpacity(0.7),
                    fontSize: 13,
                    height: 1.6)),
            const SizedBox(height: 16),
            _Divider(),
            const SizedBox(height: 16),
          ],

          // ── Coordinates ──────────────────────────────────────────
          GestureDetector(
            onTap: () {
              Clipboard.setData(ClipboardData(
                  text: '${cave.lat.toStringAsFixed(6)}, '
                      '${cave.lon.toStringAsFixed(6)}'));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('Coordinates copied'),
                    duration: Duration(seconds: 2)),
              );
            },
            child: Row(children: [
              Icon(Icons.location_on_outlined,
                  color: kColorOrange.withOpacity(0.6), size: 15),
              const SizedBox(width: 8),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('GPS Coordinates',
                    style: GoogleFonts.outfit(
                        color: kColorCream.withOpacity(0.35),
                        fontSize: 10,
                        letterSpacing: 0.4)),
                Text(
                    '${cave.lat.toStringAsFixed(5)}, '
                    '${cave.lon.toStringAsFixed(5)}',
                    style: GoogleFonts.outfit(
                        color: kColorCream.withOpacity(0.8), fontSize: 13)),
              ]),
              const Spacer(),
              Icon(Icons.copy, color: kColorCream.withOpacity(0.25), size: 13),
            ]),
          ),

          const SizedBox(height: 20),
          _CheckInButton(cave: cave),

          // ── Linked trails ────────────────────────────────────────
          if (linked.isNotEmpty) ...[
            const SizedBox(height: 16),
            _Divider(),
            const SizedBox(height: 14),
            Text('Hiking routes to this cave',
                style: GoogleFonts.outfit(
                    color: kColorCream.withOpacity(0.4),
                    fontSize: 11,
                    letterSpacing: 0.5)),
            const SizedBox(height: 8),
            ...linked.take(3).map((t) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                      context.read<StaticDataProvider>().selectTrail(t);
                    },
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: kColorPanel,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: kColorBorder),
                      ),
                      child: Row(children: [
                        Icon(Icons.route_outlined,
                            color: _caveBrown.withOpacity(0.7), size: 14),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(t.name,
                              style: GoogleFonts.outfit(
                                  color: kColorCream.withOpacity(0.8),
                                  fontSize: 12),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                        ),
                        Text('${t.distanceKm.toStringAsFixed(1)} km',
                            style: GoogleFonts.outfit(
                                color: kColorCream.withOpacity(0.4),
                                fontSize: 11)),
                        const SizedBox(width: 4),
                        Icon(Icons.chevron_right,
                            color: kColorCream.withOpacity(0.2), size: 16),
                      ]),
                    ),
                  ),
                )),
          ],

          const SizedBox(height: 20),

          // ── Disclaimer ───────────────────────────────────────────
          Text(
            'Cave locations sourced from field surveys. '
            'Always check conditions before entering any cave.',
            style: GoogleFonts.outfit(
                color: kColorCream.withOpacity(0.3), fontSize: 11, height: 1.5),
          ),
        ],
      ),
    );
  }

  /// Extract the core cave name for trail matching.
  /// e.g. "Bushmans Cave" → "bushmans cave"
  String _coreName(String name) => name
      .toLowerCase()
      .replaceAll(
          RegExp(
              r'\s+(cave|shelter|chalet|hut|annexe|north|south|east|west|\d+)$'),
          '')
      .trim();
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      Container(height: 1, color: kColorCream.withOpacity(0.07));
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _StatChip(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: kColorPanel,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: kColorBorder),
          ),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(icon, color: kColorOrange.withOpacity(0.6), size: 12),
              const SizedBox(width: 4),
              Text(label,
                  style: GoogleFonts.outfit(
                      color: kColorCream.withOpacity(0.35),
                      fontSize: 10,
                      letterSpacing: 0.4)),
            ]),
            const SizedBox(height: 4),
            Text(value,
                style: GoogleFonts.outfit(
                    color: kColorCream.withOpacity(0.9),
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
          ]),
        ),
      );
}

class _CheckInButton extends StatefulWidget {
  final CaveWaypoint cave;
  const _CheckInButton({required this.cave});

  @override
  State<_CheckInButton> createState() => _CheckInButtonState();
}

class _CheckInButtonState extends State<_CheckInButton> {
  bool _verifying = false;
  String? _status;

  Future<void> _checkIn() async {
    setState(() {
      _verifying = true;
      _status = 'Verifying position...';
    });

    try {
      final pos = await Geolocator.getCurrentPosition();
      if (!mounted) return;
      final dist = Geolocator.distanceBetween(
          pos.latitude, pos.longitude, widget.cave.lat, widget.cave.lon);

      if (dist < 150) {
        // within 150m
        setState(() => _status = 'Verified! 🕳');
        final uid = Supabase.instance.client.auth.currentUser?.id ?? '';
        final userEmail =
            Supabase.instance.client.auth.currentUser?.email ?? 'A hiker';

        await Supabase.instance.client.from('community_activities').insert({
          'user_id': uid,
          'user_name': userEmail.split('@')[0],
          'type': 'check_in',
          'title': 'Visited Cave',
          'subtitle': 'Verified at ${widget.cave.name}',
          'timestamp': DateTime.now().toIso8601String(),
        });

        if (!mounted) return;
        unawaited(context.read<CommunityProvider>().refresh());
        setState(() => _status = 'Checked in!');
        unawaited(HapticFeedback.heavyImpact());
      } else {
        setState(() =>
            _status = 'Too far away (${(dist / 1000).toStringAsFixed(1)}km)');
        unawaited(HapticFeedback.vibrate());
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _status = 'Verification failed');
    } finally {
      if (mounted) {
        unawaited(Future.delayed(const Duration(seconds: 3), () {
          if (mounted) {
            setState(() {
              _verifying = false;
              _status = null;
            });
          }
        }));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: GestureDetector(
        onTap: _verifying ? null : _checkIn,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: _status == 'Checked in!'
                ? const Color(0xFF4CAF50)
                : kColorOrange,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: kColorOrange.withOpacity(0.3),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_verifying) ...[
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2),
                  ),
                  const SizedBox(width: 12),
                ] else
                  Icon(_status == 'Checked in!' ? Icons.check : Icons.pin_drop,
                      color: Colors.white, size: 18),
                const SizedBox(width: 10),
                Text(
                  _status ?? 'Check-in at Cave',
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
