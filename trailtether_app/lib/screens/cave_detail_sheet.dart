import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/design_tokens.dart';
import '../models/cave_waypoint.dart';
import '../providers/static_data_provider.dart';
import '../providers/community_provider.dart';
import '../widgets/design/tt_pill.dart';

/// Bottom sheet shown when a cave or rock-shelter waypoint is tapped on the
/// map. Surfaces the shelter / cave metadata, lets the hiker check-in when
/// physically nearby, and links any matching hiking routes.
class CaveDetailSheet extends StatelessWidget {
  final CaveWaypoint cave;
  final VoidCallback? onViewTrail;

  const CaveDetailSheet({super.key, required this.cave, this.onViewTrail});

  static void show(BuildContext context, CaveWaypoint cave,
      {VoidCallback? onViewTrail}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: TT.bg2,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(TT.rLg)),
      ),
      builder: (_) => CaveDetailSheet(cave: cave, onViewTrail: onViewTrail),
    );
  }

  @override
  Widget build(BuildContext context) {
    final emoji = cave.isShelter ? '🛖' : '🕳';
    final typeLabel = cave.isShelter ? 'Rock Shelter' : 'Cave';

    final data = context.read<StaticDataProvider>();
    final coreName = _coreName(cave.name);
    final linked = data.allTrails
        .where((t) => t.isCave && t.name.toLowerCase().contains(coreName))
        .toList();

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SheetHandle(),

            // ── Header ─────────────────────────────────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: TT.emberDim,
                    shape: BoxShape.circle,
                    border: Border.all(color: TT.line3, width: 1.2),
                  ),
                  alignment: Alignment.center,
                  child:
                      Text(emoji, style: const TextStyle(fontSize: 24)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(cave.name, style: TT.title(18)),
                      const SizedBox(height: 4),
                      Text('Drakensberg waypoint',
                          style: TT.body(size: 13, color: TT.text2)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          TTPill(label: typeLabel.toUpperCase()),
                          if (cave.elevationM > 0)
                            TTPill(
                              label:
                                  '${cave.elevationM.round()} M',
                              leadingIcon: Icons.height,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 18),
            const _TTDivider(),
            const SizedBox(height: 14),

            // ── Description ────────────────────────────────────────────────
            if (cave.description != null) ...[
              Text(
                cave.description!,
                style: TT.body(size: 13, color: TT.text2, w: FontWeight.w500)
                    .copyWith(height: 1.55),
              ),
              const SizedBox(height: 14),
              const _TTDivider(),
              const SizedBox(height: 14),
            ],

            // ── Elevation / Type meta rows ─────────────────────────────────
            _MetaRow(
              icon: Icons.height,
              label: 'ELEVATION',
              value: cave.elevationM > 0
                  ? '${cave.elevationM.round()} m'
                  : 'Unknown',
              mono: cave.elevationM > 0,
            ),
            const SizedBox(height: 10),
            _MetaRow(
              icon: Icons.terrain_outlined,
              label: 'TYPE',
              value: typeLabel,
            ),

            const SizedBox(height: 10),

            // ── Coordinates (tap to copy) ─────────────────────────────────
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                Clipboard.setData(ClipboardData(
                    text:
                        '${cave.lat.toStringAsFixed(6)}, ${cave.lon.toStringAsFixed(6)}'));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: TT.surf,
                    content: Text('Coordinates copied',
                        style: TT.body(size: 13)),
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.location_on_outlined,
                      color: TT.ember, size: 15),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('GPS COORDINATES',
                            style: TT.label(
                                size: 10,
                                color: TT.text3,
                                letterSpacing: 1.4)),
                        const SizedBox(height: 3),
                        Text(
                          '${cave.lat.toStringAsFixed(5)}, ${cave.lon.toStringAsFixed(5)}',
                          style: TT.mono(size: 12.5, color: TT.text),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.copy, color: TT.text3, size: 14),
                ],
              ),
            ),

            const SizedBox(height: 18),

            // ── Primary CTA: check-in ─────────────────────────────────────
            _CheckInButton(cave: cave),

            // ── Linked trails ─────────────────────────────────────────────
            if (linked.isNotEmpty) ...[
              const SizedBox(height: 18),
              const _TTDivider(),
              const SizedBox(height: 14),
              Text('HIKING ROUTES TO THIS CAVE',
                  style:
                      TT.label(size: 10.5, color: TT.text2, letterSpacing: 1.6)),
              const SizedBox(height: 10),
              ...linked.take(3).map((t) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        Navigator.pop(context);
                        context.read<StaticDataProvider>().selectTrail(t);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: TT.surf,
                          borderRadius: BorderRadius.circular(TT.rMd),
                          border: Border.all(color: TT.line, width: 1),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.route_outlined,
                                color: TT.ember, size: 15),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                t.name,
                                style: TT.body(size: 13, color: TT.text),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              '${t.distanceKm.toStringAsFixed(1)} km',
                              style: TT.mono(size: 11.5, color: TT.text2),
                            ),
                            const SizedBox(width: 6),
                            const Icon(Icons.chevron_right,
                                color: TT.text3, size: 16),
                          ],
                        ),
                      ),
                    ),
                  )),
            ],

            const SizedBox(height: 16),
            Text(
              'Cave locations sourced from field surveys. '
              'Always check conditions before entering any cave.',
              style: TT.body(size: 11, color: TT.text3, w: FontWeight.w500)
                  .copyWith(height: 1.5),
            ),
          ],
        ),
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

// ── Shared primitives ──────────────────────────────────────────────────────

class _SheetHandle extends StatelessWidget {
  const _SheetHandle();
  @override
  Widget build(BuildContext context) => Center(
        child: Container(
          width: 42,
          height: 4,
          margin: const EdgeInsets.only(top: 6, bottom: 14),
          decoration: BoxDecoration(
            color: TT.line3,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      );
}

class _TTDivider extends StatelessWidget {
  const _TTDivider();
  @override
  Widget build(BuildContext context) => Container(height: 1, color: TT.line);
}

class _MetaRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool mono;
  const _MetaRow({
    required this.icon,
    required this.label,
    required this.value,
    this.mono = false,
  });

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: TT.ember, size: 15),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label,
                    style: TT.label(
                        size: 10, color: TT.text3, letterSpacing: 1.4)),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: mono
                      ? TT.mono(size: 12.5, color: TT.text)
                      : TT.body(size: 13, color: TT.text),
                ),
              ],
            ),
          ),
        ],
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
  bool _success = false;
  String? _status;

  Future<void> _checkIn() async {
    setState(() {
      _verifying = true;
      _success = false;
      _status = 'Verifying position…';
    });

    try {
      final pos = await Geolocator.getCurrentPosition();
      if (!mounted) return;
      final dist = Geolocator.distanceBetween(
          pos.latitude, pos.longitude, widget.cave.lat, widget.cave.lon);

      if (dist < 150) {
        // within 150 m of the waypoint — credit the check-in.
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
        setState(() {
          _success = true;
          _status = 'Checked in';
        });
        unawaited(HapticFeedback.heavyImpact());
      } else {
        setState(() {
          _success = false;
          _status =
              'Too far away (${(dist / 1000).toStringAsFixed(1)} km)';
        });
        unawaited(HapticFeedback.vibrate());
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _success = false;
        _status = 'Verification failed';
      });
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
    final disabled = _verifying;
    final bg = _success ? TT.green : (disabled ? TT.emberDim : TT.ember);
    const fg = TT.emberInk;
    final borderClr =
        _success ? TT.green : (disabled ? const Color(0x33FF6A2C) : TT.ember);

    return SizedBox(
      width: double.infinity,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: disabled ? null : _checkIn,
        child: AnimatedContainer(
          duration: TT.dFast,
          curve: TT.easeOut,
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: borderClr, width: 1),
            boxShadow: disabled ? null : TT.shadowEmber,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_verifying)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: TT.emberInk),
                )
              else
                Icon(
                  _success ? Icons.check : Icons.pin_drop_outlined,
                  color: fg,
                  size: 16,
                ),
              const SizedBox(width: 10),
              Text(
                _status ?? 'Check-in at cave',
                style: TT
                    .body(size: 14, color: fg, w: FontWeight.w800)
                    .copyWith(letterSpacing: 0.04 * 14),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
