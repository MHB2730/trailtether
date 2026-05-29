import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/design_tokens.dart';
import '../models/incident.dart';
import '../providers/auth_provider.dart' as ap;
import '../providers/safety_provider.dart';
import '../services/incident_service.dart';
import 'design/tt_pill.dart';

/// Bottom sheet that surfaces a single [Incident] reached from the map or the
/// home-screen "field intel" rows. Lets viewers verify or flag the report,
/// and lets the owner / admin delete it outright.
class IncidentDetailSheet extends StatefulWidget {
  final Incident incident;

  const IncidentDetailSheet({super.key, required this.incident});

  static void show(BuildContext context, Incident incident) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: TT.bg2,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(TT.rLg)),
      ),
      builder: (_) => IncidentDetailSheet(incident: incident),
    );
  }

  @override
  State<IncidentDetailSheet> createState() => _IncidentDetailSheetState();
}

class _IncidentDetailSheetState extends State<IncidentDetailSheet> {
  bool _flagging = false;
  bool _flagDone = false;
  bool _deleting = false;
  bool _verifying = false;

  Future<void> _verifyIncident() async {
    setState(() => _verifying = true);
    try {
      await IncidentService.verifyIncident(widget.incident.id);
      if (!mounted) return;
      setState(() => _verifying = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: TT.surf,
          content:
              Text('Report verified. Thank you.', style: TT.body(size: 13)),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _verifying = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: TT.surf,
          content: Text(e.toString(), style: TT.body(size: 13, color: TT.red)),
        ),
      );
    }
  }

  Future<void> _flagIncident() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: TT.bg2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(TT.rLg),
          side: const BorderSide(color: TT.line),
        ),
        title: Text('Flag this report?', style: TT.title(16)),
        content: Text(
          'Flag this incident as inaccurate or inappropriate. '
          'Our team will review it.',
          style: TT.body(size: 13, color: TT.text2),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel',
                style: TT.body(size: 13, color: TT.text2, w: FontWeight.w700)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Flag',
                style: TT.body(size: 13, color: TT.red, w: FontWeight.w800)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _flagging = true);
    try {
      await IncidentService.flagIncident(widget.incident.id);
      if (!mounted) return;
      setState(() {
        _flagging = false;
        _flagDone = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _flagging = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: TT.surf,
          content: Text('Could not flag. Try again later.',
              style: TT.body(size: 13, color: TT.red)),
        ),
      );
    }
  }

  Future<void> _deleteIncident() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: TT.bg2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(TT.rLg),
          side: const BorderSide(color: TT.line),
        ),
        title: Text('Delete this incident?', style: TT.title(16)),
        content: Text(
          'This will permanently remove the report from Supabase. '
          'This cannot be undone.',
          style: TT.body(size: 13, color: TT.text2),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel',
                style: TT.body(size: 13, color: TT.text2, w: FontWeight.w700)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Delete',
                style: TT.body(size: 13, color: TT.red, w: FontWeight.w800)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _deleting = true);
    try {
      await IncidentService.deleteIncident(widget.incident.id);
      if (!mounted) return;
      // Immediately remove the marker from the map on all platforms.
      // On Android the live stream would eventually do this automatically,
      // but on Windows the stream is a completed one-shot — refresh()
      // re-fetches so the deleted doc is gone right away.
      context.read<SafetyProvider>().refresh();
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: TT.surf,
          content: Text('Incident deleted.', style: TT.body(size: 13)),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _deleting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: TT.surf,
          content: Text('Delete failed: $e',
              style: TT.body(size: 13, color: TT.red)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final incident = widget.incident;
    final color = incident.type.color;
    final currentUid = Supabase.instance.client.auth.currentUser?.id ?? '';
    // Admin check now reads from server-side profiles.is_admin (see RLS
    // migration). The legacy kAdminEmail check was bypassable client-side.
    final isAdmin = context.read<ap.AuthProvider>().isAdmin;
    final isOwner = currentUid.isNotEmpty &&
        (incident.createdBy == currentUid || incident.deviceId == currentUid);
    final alreadyVerified = incident.verifiedUids.contains(currentUid);

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
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.16),
                    shape: BoxShape.circle,
                    border:
                        Border.all(color: color.withOpacity(0.55), width: 1.4),
                  ),
                  alignment: Alignment.center,
                  child: Text(incident.type.emoji,
                      style: const TextStyle(fontSize: 22)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(incident.type.label, style: TT.title(18)),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          TTPill(
                            label: incident.severity.label.toUpperCase(),
                            variant:
                                incident.severity == IncidentSeverity.serious ||
                                        incident.severity ==
                                            IncidentSeverity.critical
                                    ? TTPillVariant.danger
                                    : TTPillVariant.neutral,
                          ),
                          if (incident.verifiedUids.isNotEmpty)
                            TTPill(
                              label: '${incident.verifiedUids.length} VERIFIED',
                              leadingIcon: Icons.verified_outlined,
                            ),
                          if (incident.status == 'assigned')
                            const TTPill(
                              label: 'ASSIGNED',
                              variant: TTPillVariant.ember,
                              leadingIcon: Icons.person_pin_circle_outlined,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                Text(incident.ageString.toUpperCase(),
                    style: TT.mono(size: 10, color: TT.text3)),
              ],
            ),

            if (incident.status == 'assigned' &&
                incident.assignedToName != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.person_pin_circle_outlined,
                      color: TT.ember, size: 14),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Assigned to ${incident.assignedToName}',
                      style: TT.body(size: 12, color: TT.text2),
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 18),
            const _TTDivider(),
            const SizedBox(height: 14),

            // ── Description ───────────────────────────────────────────────
            Text(
              incident.description,
              style: TT
                  .body(size: 13, color: TT.text2, w: FontWeight.w500)
                  .copyWith(height: 1.55),
            ),

            if ((incident.photoUrl ?? '').isNotEmpty) ...[
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(TT.rMd),
                child: Image.network(
                  incident.photoUrl!,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  loadingBuilder: (_, child, progress) {
                    if (progress == null) return child;
                    return Container(
                      height: 180,
                      alignment: Alignment.center,
                      color: TT.surf,
                      child: const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: TT.ember),
                      ),
                    );
                  },
                  errorBuilder: (_, __, ___) => Container(
                    height: 80,
                    alignment: Alignment.center,
                    color: TT.surf,
                    child: Text(
                      'Photo unavailable offline',
                      style: TT.body(size: 12, color: TT.text3),
                    ),
                  ),
                ),
              ),
            ],

            const SizedBox(height: 16),
            const _TTDivider(),
            const SizedBox(height: 14),

            // ── Meta ──────────────────────────────────────────────────────
            _MetaRow(
              icon: Icons.event_outlined,
              label: 'INCIDENT DATE',
              value: incident.formattedDate,
              mono: true,
            ),
            if (incident.trailName != null) ...[
              const SizedBox(height: 10),
              _MetaRow(
                icon: Icons.terrain_outlined,
                label: 'TRAIL',
                value: incident.trailName!,
              ),
            ],
            const SizedBox(height: 10),
            _MetaRow(
              icon: Icons.location_on_outlined,
              label: 'COORDINATES',
              value: '${incident.lat.toStringAsFixed(5)}, '
                  '${incident.lon.toStringAsFixed(5)}',
              mono: true,
            ),

            const SizedBox(height: 20),

            // ── Owner / admin destructive action ──────────────────────────
            if (isOwner || isAdmin) ...[
              _DangerOutlineButton(
                label: _deleting ? 'Deleting…' : 'Delete incident',
                icon: Icons.delete_outline,
                busy: _deleting,
                onTap: _deleting ? null : _deleteIncident,
              ),
              const SizedBox(height: 10),
            ],

            // ── Verify / Flag ─────────────────────────────────────────────
            Row(
              children: [
                if (!isOwner && !alreadyVerified)
                  Expanded(
                    child: _EmberPillButton(
                      label: _verifying ? 'Verifying…' : 'Verify report',
                      icon: Icons.verified_outlined,
                      busy: _verifying,
                      onTap: _verifying ? null : _verifyIncident,
                    ),
                  ),
                if (!isOwner && !alreadyVerified) const SizedBox(width: 10),
                Expanded(
                  child: _flagDone
                      ? Container(
                          height: 44,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: const Color(0x1A4CC38A),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: const Color(0x594CC38A)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.check_circle_outline,
                                  color: TT.green, size: 14),
                              const SizedBox(width: 6),
                              Text('Flagged',
                                  style: TT.body(
                                      size: 13,
                                      color: TT.green,
                                      w: FontWeight.w800)),
                            ],
                          ),
                        )
                      : _OutlineButton(
                          label: _flagging ? 'Flagging…' : 'Flag inaccurate',
                          icon: Icons.flag_outlined,
                          busy: _flagging,
                          onTap: _flagging ? null : _flagIncident,
                        ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            // ── Disclaimer ────────────────────────────────────────────────
            Text(
              'Reports are submitted by the hiking community. '
              'Always exercise your own judgement on trail conditions.',
              style: TT
                  .body(size: 11, color: TT.text3, w: FontWeight.w500)
                  .copyWith(height: 1.5),
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

class _EmberPillButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool busy;
  final VoidCallback? onTap;
  const _EmberPillButton({
    required this.label,
    required this.icon,
    required this.busy,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: disabled ? TT.emberDim : TT.ember,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
              color: disabled ? const Color(0x33FF6A2C) : TT.ember, width: 1),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (busy)
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                    strokeWidth: 1.6, color: TT.emberInk),
              )
            else
              Icon(icon, color: TT.emberInk, size: 15),
            const SizedBox(width: 8),
            Text(
              label,
              style: TT
                  .body(size: 13, color: TT.emberInk, w: FontWeight.w800)
                  .copyWith(letterSpacing: 0.04 * 13),
            ),
          ],
        ),
      ),
    );
  }
}

class _OutlineButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool busy;
  final VoidCallback? onTap;
  const _OutlineButton({
    required this.label,
    required this.icon,
    required this.busy,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: 44,
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
            if (busy)
              const SizedBox(
                width: 14,
                height: 14,
                child:
                    CircularProgressIndicator(strokeWidth: 1.6, color: TT.text),
              )
            else
              Icon(icon, color: TT.text, size: 15),
            const SizedBox(width: 8),
            Text(label,
                style: TT.body(size: 13, color: TT.text, w: FontWeight.w800)),
          ],
        ),
      ),
    );
  }
}

class _DangerOutlineButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool busy;
  final VoidCallback? onTap;
  const _DangerOutlineButton({
    required this.label,
    required this.icon,
    required this.busy,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0x1AE63D2E),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: const Color(0x59E63D2E), width: 1),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (busy)
              const SizedBox(
                width: 14,
                height: 14,
                child:
                    CircularProgressIndicator(strokeWidth: 1.6, color: TT.red),
              )
            else
              Icon(icon, color: TT.red, size: 15),
            const SizedBox(width: 8),
            Text(label,
                style: TT.body(size: 13, color: TT.red, w: FontWeight.w800)),
          ],
        ),
      ),
    );
  }
}
