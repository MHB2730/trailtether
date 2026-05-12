import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/constants.dart';
import '../models/incident.dart';
import '../providers/auth_provider.dart' as ap;
import '../providers/safety_provider.dart';
import '../services/incident_service.dart';

class IncidentDetailSheet extends StatefulWidget {
  final Incident incident;

  const IncidentDetailSheet({super.key, required this.incident});

  static void show(BuildContext context, Incident incident) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
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
      if (mounted) {
        setState(() => _verifying = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Report verified. Thank you!'),
              backgroundColor: Color(0xFF4CAF50)),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _verifying = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(e.toString()), backgroundColor: const Color(0xFFE53935)),
        );
      }
    }
  }

  Future<void> _flagIncident() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: Text('Flag this report?',
            style: GoogleFonts.outfit(
                color: kColorCream, fontWeight: FontWeight.w700)),
        content: Text(
          'Flag this incident as inaccurate or inappropriate. '
          'Our team will review it.',
          style: GoogleFonts.outfit(
              color: kColorCream.withOpacity(0.7), fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel',
                style: GoogleFonts.outfit(color: kColorCream.withOpacity(0.5))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Flag',
                style: GoogleFonts.outfit(color: const Color(0xFFE53935))),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _flagging = true);
    try {
      await IncidentService.flagIncident(widget.incident.id);
      if (mounted) {
        setState(() {
          _flagging = false;
          _flagDone = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _flagging = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Could not flag — try again later.'),
              backgroundColor: Color(0xFFE53935)),
        );
      }
    }
  }

  Future<void> _deleteIncident() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: Text('Delete this incident?',
            style: GoogleFonts.outfit(
                color: kColorCream, fontWeight: FontWeight.w700)),
        content: Text(
          'This will permanently remove the report from Supabase. '
          'This cannot be undone.',
          style: GoogleFonts.outfit(
              color: kColorCream.withOpacity(0.7), fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel',
                style: GoogleFonts.outfit(color: kColorCream.withOpacity(0.5))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Delete',
                style: GoogleFonts.outfit(
                    color: const Color(0xFFE53935),
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _deleting = true);
    try {
      await IncidentService.deleteIncident(widget.incident.id);
      if (mounted) {
        // Immediately remove the marker from the map on all platforms.
        // On Android the live stream would eventually do this automatically,
        // but on Windows the stream is a completed one-shot — refresh()
        // re-fetches so the deleted doc is gone right away.
        context.read<SafetyProvider>().refresh();
        Navigator.pop(context); // close the sheet
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Incident deleted.'),
            backgroundColor: Color(0xFF4CAF50),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _deleting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Delete failed: $e'),
              backgroundColor: const Color(0xFFE53935)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final incident = widget.incident;
    final color = incident.type.color;
    final currentUid = Supabase.instance.client.auth.currentUser?.id ?? '';
    // Admin check now reads from server-side profiles.is_admin (see RLS migration).
    // The legacy kAdminEmail check was bypassable client-side.
    final isAdmin = context.read<ap.AuthProvider>().isAdmin;
    final isOwner = currentUid.isNotEmpty &&
        (incident.createdBy == currentUid || incident.deviceId == currentUid);
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
      decoration: const BoxDecoration(
        color: Color(0xFF111111),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Handle ────────────────────────────────────────────────────
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

          // ── Header ────────────────────────────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Type icon circle
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.18),
                  shape: BoxShape.circle,
                  border: Border.all(color: color.withOpacity(0.5), width: 1.5),
                ),
                child: Center(
                  child: Text(incident.type.emoji,
                      style: const TextStyle(fontSize: 22)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(incident.type.label,
                        style: GoogleFonts.outfit(
                            color: color,
                            fontSize: 16,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    // Severity badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: incident.severity.color.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                            color: incident.severity.color.withOpacity(0.5)),
                      ),
                      child: Text(
                        incident.severity.label,
                        style: GoogleFonts.outfit(
                            color: incident.severity.color,
                            fontSize: 11,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
              // Age
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(incident.ageString,
                      style: GoogleFonts.outfit(
                          color: kColorCream.withOpacity(0.35), fontSize: 11)),
                  if (incident.verifiedUids.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.verified,
                            color: Color(0xFF4CAF50), size: 12),
                        const SizedBox(width: 4),
                        Text(
                          '${incident.verifiedUids.length} verified',
                          style: GoogleFonts.outfit(
                              color: const Color(0xFF4CAF50),
                              fontSize: 10,
                              fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ],
          ),

          const SizedBox(height: 12),
          // Assignment Info
          if (incident.status == 'assigned')
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: kColorOrange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: kColorOrange.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.person_pin_circle_outlined,
                      color: kColorOrange, size: 14),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Assigned to: ${incident.assignedToName ?? "Team Member"}',
                      style: GoogleFonts.outfit(
                        color: kColorCream.withOpacity(0.8),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 16),
          _Divider(),

          // ── Description ────────────────────────────────────────────────
          const SizedBox(height: 14),
          Text(incident.description,
              style: GoogleFonts.outfit(
                  color: kColorCream.withOpacity(0.85),
                  fontSize: 14,
                  height: 1.6)),

          const SizedBox(height: 16),
          _Divider(),
          const SizedBox(height: 14),

          // ── Meta row ───────────────────────────────────────────────────
          _MetaRow(
            icon: Icons.event_outlined,
            label: 'Incident date',
            value: incident.formattedDate,
          ),

          if (incident.trailName != null) ...[
            const SizedBox(height: 8),
            _MetaRow(
              icon: Icons.terrain_outlined,
              label: 'Trail',
              value: incident.trailName!,
            ),
          ],

          const SizedBox(height: 8),
          _MetaRow(
            icon: Icons.location_on_outlined,
            label: 'Coordinates',
            value: '${incident.lat.toStringAsFixed(5)}, '
                '${incident.lon.toStringAsFixed(5)}',
          ),

          const SizedBox(height: 24),

          // ── Owner or admin: edit / delete buttons ─────────────────────
          if (isOwner || isAdmin) ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE53935).withOpacity(0.12),
                  foregroundColor: const Color(0xFFE53935),
                  side: const BorderSide(color: Color(0xFFE53935), width: 1),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  elevation: 0,
                ),
                onPressed: _deleting ? null : _deleteIncident,
                icon: _deleting
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                            strokeWidth: 1.5, color: Color(0xFFE53935)))
                    : const Icon(Icons.delete_outline, size: 16),
                label: Text(
                  _deleting ? 'Deleting…' : 'Delete Incident',
                  style: GoogleFonts.outfit(
                      fontWeight: FontWeight.w700, fontSize: 13),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],

          // ── Verify / Flag buttons ─────────────────────────────────────────
          Row(
            children: [
              if (!isOwner && !incident.verifiedUids.contains(currentUid))
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _verifying ? null : _verifyIncident,
                    icon: _verifying
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                                strokeWidth: 1.5, color: Color(0xFF4CAF50)))
                        : const Icon(Icons.verified_outlined, size: 16),
                    label: Text(_verifying ? 'Verifying…' : 'Verify Report'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4CAF50).withOpacity(0.12),
                      foregroundColor: const Color(0xFF4CAF50),
                      side:
                          const BorderSide(color: Color(0xFF4CAF50), width: 1),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      elevation: 0,
                    ),
                  ),
                ),
              if (!isOwner && !incident.verifiedUids.contains(currentUid))
                const SizedBox(width: 12),
              Expanded(
                child: _flagDone
                    ? Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF4CAF50).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.check_circle_outline,
                                color: Color(0xFF4CAF50), size: 14),
                            const SizedBox(width: 6),
                            Text('Flagged',
                                style: GoogleFonts.outfit(
                                    color: const Color(0xFF4CAF50),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600)),
                          ],
                        ),
                      )
                    : OutlinedButton.icon(
                        onPressed: _flagging ? null : _flagIncident,
                        icon: _flagging
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                    strokeWidth: 1.5, color: Color(0xFFE53935)))
                            : const Icon(Icons.flag_outlined, size: 16),
                        label: Text(_flagging ? 'Flagging…' : 'Flag Inaccurate'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFE53935),
                          side: const BorderSide(
                              color: Color(0xFFE53935), width: 1),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // ── Disclaimer ─────────────────────────────────────────────────
          Text(
            'Reports are submitted by the hiking community. '
            'Always exercise your own judgement on trail conditions.',
            style: GoogleFonts.outfit(
                color: kColorCream.withOpacity(0.3), fontSize: 11, height: 1.5),
          ),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        height: 1,
        color: kColorCream.withOpacity(0.07),
      );
}

class _MetaRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _MetaRow(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: kColorOrange.withOpacity(0.6), size: 15),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: GoogleFonts.outfit(
                      color: kColorCream.withOpacity(0.35),
                      fontSize: 10,
                      letterSpacing: 0.4)),
              Text(value,
                  style: GoogleFonts.outfit(
                      color: kColorCream.withOpacity(0.8), fontSize: 13)),
            ],
          ),
        ],
      );
}
