import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../providers/team_provider.dart';

import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/constants.dart';
import '../models/incident.dart';
import '../models/trail.dart';
import '../providers/safety_provider.dart';
import '../services/device_service.dart';
import '../services/incident_service.dart';

class FieldIntelSheet extends StatefulWidget {
  final LatLng position; // tapped map location
  final Trail? nearestTrail;

  const FieldIntelSheet({
    super.key,
    required this.position,
    this.nearestTrail,
  });

  @override
  State<FieldIntelSheet> createState() => _FieldIntelSheetState();
}

class _FieldIntelSheetState extends State<FieldIntelSheet> {
  IncidentType _type = IncidentType.other;
  IncidentSeverity _severity = IncidentSeverity.moderate;
  DateTime _date = DateTime.now();
  final _descCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  bool _submitting = false;
  String? _error;
  File? _photo;
  final _picker = ImagePicker();

  Future<void> _pickPhoto(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 1920,
        imageQuality: 80,
      );
      if (picked == null || !mounted) return;
      setState(() => _photo = File(picked.path));
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'Could not load that photo.');
      }
    }
  }

  @override
  void dispose() {
    _descCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(now.year - 2),
      lastDate: now,
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFFE8541A),
            surface: Color(0xFF1A1A1A),
          ),
        ),
        child: child!,
      ),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_date),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFFE8541A),
            surface: Color(0xFF1A1A1A),
          ),
        ),
        child: child!,
      ),
    );
    if (!mounted) return;

    setState(() {
      _date = DateTime(
        date.year,
        date.month,
        date.day,
        time?.hour ?? _date.hour,
        time?.minute ?? _date.minute,
      );
    });
  }

  Future<void> _submit() async {
    final desc = _descCtrl.text.trim();
    final name = _nameCtrl.text.trim();

    if (desc.isEmpty) {
      setState(() => _error = 'Please describe what happened.');
      return;
    }
    if (desc.length > 800) {
      setState(() => _error = 'Description is too long (max 800 characters).');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    final teamId = context.read<TeamProvider>().selectedTeam?.id;
    try {
      final deviceId = await DeviceService.getDeviceId();
      final uid = Supabase.instance.client.auth.currentUser?.id ?? '';

      // Upload the photo (if any) first so the URL can land on the row in
      // a single insert. Upload failure doesn't block the report -- the
      // text content is the safety-critical part; the photo is supporting.
      String? photoUrl;
      if (_photo != null && uid.isNotEmpty) {
        photoUrl = await IncidentService.uploadPhoto(_photo!, uid);
      }

      final incident = Incident(
        id: '',
        lat: widget.position.latitude,
        lon: widget.position.longitude,
        type: _type,
        severity: _severity,
        description: desc,
        incidentDate: _date,
        reportedAt: DateTime.now(),
        deviceId: deviceId,
        createdBy: uid,
        trailId: widget.nearestTrail?.id,
        trailName: name.isNotEmpty ? name : widget.nearestTrail?.name,
        incidentTeamId: teamId,
        photoUrl: photoUrl,
      );

      await IncidentService.addIncident(incident);

      if (!mounted) return;

      // Refresh provider so the new marker appears immediately
      context.read<SafetyProvider>().refresh();

      Navigator.pop(context, true); // true = success
    } catch (e) {
      if (mounted) {
        setState(() {
          _submitting = false;
          _error = 'Could not submit report. Please try again.';
        });
      }
    }
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + bottom),
      decoration: const BoxDecoration(
        color: Color(0xFF111111),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Handle ───────────────────────────────────────────────────
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

            // ── Title ─────────────────────────────────────────────────────
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: kColorOrange.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.warning_amber_rounded,
                      color: kColorOrange, size: 20),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Report Field Intel',
                        style: GoogleFonts.outfit(
                            color: kColorCream,
                            fontSize: 17,
                            fontWeight: FontWeight.w700)),
                    Text(
                      '${widget.position.latitude.toStringAsFixed(5)}, '
                      '${widget.position.longitude.toStringAsFixed(5)}',
                      style: GoogleFonts.outfit(
                          color: kColorCream.withOpacity(0.4), fontSize: 11),
                    ),
                  ],
                ),
              ],
            ),

            if (widget.nearestTrail != null) ...[
              const SizedBox(height: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: kColorOrange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: kColorOrange.withOpacity(0.25)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.terrain,
                        color: kColorOrange.withOpacity(0.7), size: 12),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'Near: ${widget.nearestTrail!.name}',
                        style: GoogleFonts.outfit(
                            color: kColorOrange.withOpacity(0.9), fontSize: 11),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 20),

            // ── Intel type grid ─────────────────────────────────────────
            const _SectionLabel('Category'),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: IncidentType.values.map((t) {
                final sel = t == _type;
                return GestureDetector(
                  onTap: () => setState(() => _type = t),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: sel
                          ? t.color.withOpacity(0.2)
                          : Colors.white.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: sel
                            ? t.color.withOpacity(0.75)
                            : Colors.white.withOpacity(0.1),
                        width: sel ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(t.emoji, style: const TextStyle(fontSize: 14)),
                        const SizedBox(width: 6),
                        Text(t.label,
                            style: GoogleFonts.outfit(
                                color: sel
                                    ? kColorCream
                                    : kColorCream.withOpacity(0.55),
                                fontSize: 12,
                                fontWeight:
                                    sel ? FontWeight.w600 : FontWeight.w400)),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 20),

            // ── Severity ───────────────────────────────────────────────────
            const _SectionLabel('Severity'),
            const SizedBox(height: 10),
            Row(
              children: IncidentSeverity.values.map((s) {
                final sel = s == _severity;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _severity = s),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      margin: EdgeInsets.only(
                          right: s != IncidentSeverity.critical ? 6 : 0),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: sel
                            ? s.color.withOpacity(0.2)
                            : Colors.white.withOpacity(0.04),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: sel
                              ? s.color.withOpacity(0.75)
                              : Colors.white.withOpacity(0.1),
                          width: sel ? 1.5 : 1,
                        ),
                      ),
                      child: Center(
                        child: Text(s.label,
                            style: GoogleFonts.outfit(
                                color: sel
                                    ? s.color
                                    : kColorCream.withOpacity(0.45),
                                fontSize: 12,
                                fontWeight:
                                    sel ? FontWeight.w700 : FontWeight.w400)),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 20),

            if (_type == IncidentType.hazardZone) ...[
              const _SectionLabel('Zone Name (Optional)'),
              const SizedBox(height: 10),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                ),
                child: TextField(
                  controller: _nameCtrl,
                  style: GoogleFonts.outfit(color: kColorCream, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'e.g. Loose Rock, Wasp Nest, Slippery Slope',
                    hintStyle: GoogleFonts.outfit(
                        color: kColorCream.withOpacity(0.3), fontSize: 13),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],

            // ── Date & time ────────────────────────────────────────────────
            const _SectionLabel('Time of Observation'),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: _pickDate,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.calendar_today_outlined,
                        color: kColorOrange.withOpacity(0.7), size: 16),
                    const SizedBox(width: 10),
                    Text(
                      _formatDate(_date),
                      style:
                          GoogleFonts.outfit(color: kColorCream, fontSize: 14),
                    ),
                    const Spacer(),
                    Icon(Icons.edit_outlined,
                        color: kColorCream.withOpacity(0.3), size: 14),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // ── Description ────────────────────────────────────────────────
            const _SectionLabel('Details'),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.04),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _error != null
                      ? kColorOrange.withOpacity(0.6)
                      : Colors.white.withOpacity(0.1),
                ),
              ),
              child: TextField(
                controller: _descCtrl,
                maxLines: 5,
                maxLength: 800,
                style: GoogleFonts.outfit(color: kColorCream, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Describe what happened, where exactly, '
                      'and any important details for other hikers…',
                  hintStyle: GoogleFonts.outfit(
                      color: kColorCream.withOpacity(0.3), fontSize: 13),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.all(14),
                  counterStyle: GoogleFonts.outfit(
                      color: kColorCream.withOpacity(0.3), fontSize: 11),
                ),
                onChanged: (_) {
                  if (_error != null) setState(() => _error = null);
                },
              ),
            ),

            const SizedBox(height: 20),

            // ── Photo (optional) ────────────────────────────────────────────
            const _SectionLabel('Photo (optional)'),
            const SizedBox(height: 10),
            _PhotoPicker(
              photo: _photo,
              onPickCamera: () => _pickPhoto(ImageSource.camera),
              onPickGallery: () => _pickPhoto(ImageSource.gallery),
              onRemove: () => setState(() => _photo = null),
            ),

            // ── Error ──────────────────────────────────────────────────────
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!,
                  style: GoogleFonts.outfit(
                      color: const Color(0xFFE53935), fontSize: 12)),
            ],

            const SizedBox(height: 20),

            // ── Disclaimer ─────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.03),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white.withOpacity(0.08)),
              ),
              child: Text(
                '⚠️  For life-threatening emergencies, call emergency services '
                'first (SA Mountain Rescue: 10111). This report is for '
                'community awareness only.',
                style: GoogleFonts.outfit(
                    color: kColorCream.withOpacity(0.4),
                    fontSize: 11,
                    height: 1.5),
              ),
            ),

            const SizedBox(height: 16),

            // ── Submit button ──────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              child: GestureDetector(
                onTap: _submitting ? null : _submit,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  decoration: BoxDecoration(
                    color: _submitting
                        ? kColorOrange.withOpacity(0.4)
                        : kColorOrange,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: _submitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Text('Submit Field Intel',
                            style: GoogleFonts.outfit(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w700)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime d) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}  '
        '${d.hour.toString().padLeft(2, '0')}:'
        '${d.minute.toString().padLeft(2, '0')}';
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: GoogleFonts.outfit(
          color: kColorCream.withOpacity(0.55),
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      );
}

class _PhotoPicker extends StatelessWidget {
  final File? photo;
  final VoidCallback onPickCamera;
  final VoidCallback onPickGallery;
  final VoidCallback onRemove;

  const _PhotoPicker({
    required this.photo,
    required this.onPickCamera,
    required this.onPickGallery,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    if (photo != null) {
      return Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.file(
              photo!,
              width: double.infinity,
              height: 180,
              fit: BoxFit.cover,
            ),
          ),
          Positioned(
            top: 6,
            right: 6,
            child: Material(
              color: Colors.black.withOpacity(0.55),
              shape: const CircleBorder(),
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 18),
                tooltip: 'Remove photo',
                onPressed: onRemove,
              ),
            ),
          ),
        ],
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextButton.icon(
              icon: Icon(Icons.photo_camera_outlined,
                  color: kColorOrange.withOpacity(0.85)),
              label: Text('Camera',
                  style: GoogleFonts.outfit(
                      color: kColorCream, fontSize: 13)),
              onPressed: onPickCamera,
            ),
          ),
          Container(
              width: 1,
              height: 28,
              color: Colors.white.withOpacity(0.08)),
          Expanded(
            child: TextButton.icon(
              icon: Icon(Icons.photo_library_outlined,
                  color: kColorOrange.withOpacity(0.85)),
              label: Text('Gallery',
                  style: GoogleFonts.outfit(
                      color: kColorCream, fontSize: 13)),
              onPressed: onPickGallery,
            ),
          ),
        ],
      ),
    );
  }
}
