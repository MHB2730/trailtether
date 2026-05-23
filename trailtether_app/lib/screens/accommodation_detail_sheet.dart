import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/design_tokens.dart';
import '../models/accommodation.dart';
import '../widgets/design/tt_pill.dart';

/// Bottom sheet that surfaces an [Accommodation] entry tapped on the map.
/// Lets the hiker call the listed phone number (if any), copy the
/// coordinates, and dismiss.
class AccommodationDetailSheet extends StatelessWidget {
  final Accommodation acc;

  const AccommodationDetailSheet({super.key, required this.acc});

  static void show(BuildContext context, Accommodation acc) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: TT.bg2,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(TT.rLg)),
      ),
      builder: (_) => AccommodationDetailSheet(acc: acc),
    );
  }

  Future<void> _call(String phone) async {
    final uri = Uri.parse('tel:${phone.replaceAll(' ', '')}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  String get _emoji => switch (acc.type) {
        'hotel' => '🏨',
        'resort' => '🏖️',
        'lodge' => '🏡',
        'backpacker' => '🎒',
        'self_catering' => '🍳',
        'guesthouse' => '🛌',
        _ => '🏠',
      };

  @override
  Widget build(BuildContext context) {
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
                  child: Text(_emoji, style: const TextStyle(fontSize: 24)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(acc.name, style: TT.title(18)),
                      const SizedBox(height: 4),
                      Text('${acc.region} Drakensberg',
                          style: TT.body(size: 13, color: TT.text2)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          TTPill(
                              label: acc.type
                                  .replaceAll('_', ' ')
                                  .toUpperCase()),
                          if (acc.phone != null)
                            const TTPill(
                              label: 'CALL AVAILABLE',
                              leadingIcon: Icons.phone_outlined,
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

            // ── Phone (tap to call) ───────────────────────────────────────
            if (acc.phone != null) ...[
              _MetaRow(
                icon: Icons.phone_outlined,
                label: 'PHONE',
                value: acc.phone!,
                actionIcon: Icons.call,
                onTap: () => _call(acc.phone!),
              ),
              const SizedBox(height: 10),
            ],

            // ── Coordinates (tap to copy) ─────────────────────────────────
            _MetaRow(
              icon: Icons.location_on_outlined,
              label: 'COORDINATES',
              value:
                  '${acc.lat.toStringAsFixed(5)}, ${acc.lon.toStringAsFixed(5)}',
              mono: true,
              actionIcon: Icons.copy,
              onTap: () {
                Clipboard.setData(
                    ClipboardData(text: '${acc.lat}, ${acc.lon}'));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: TT.surf,
                    content: Text('Coordinates copied',
                        style: TT.body(size: 13)),
                  ),
                );
              },
            ),

            const SizedBox(height: 20),

            // ── Primary CTA: dismiss (outline) ────────────────────────────
            _OutlineButton(
              label: 'Dismiss',
              icon: Icons.close,
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }
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
  final IconData? actionIcon;
  final VoidCallback? onTap;
  const _MetaRow({
    required this.icon,
    required this.label,
    required this.value,
    this.mono = false,
    this.actionIcon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Row(
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
            if (actionIcon != null)
              Icon(actionIcon, color: TT.text3, size: 14),
          ],
        ),
      );
}

class _OutlineButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  const _OutlineButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0x07FFFFFF),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: TT.line2, width: 1),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: TT.text, size: 15),
              const SizedBox(width: 8),
              Text(label,
                  style: TT
                      .body(size: 14, color: TT.text, w: FontWeight.w800)
                      .copyWith(letterSpacing: 0.04 * 14)),
            ],
          ),
        ),
      ),
    );
  }
}
