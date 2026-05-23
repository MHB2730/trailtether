import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/design_tokens.dart';
import '../models/incident.dart';
import '../models/trail.dart';
import '../providers/safety_provider.dart';
import '../providers/team_provider.dart';
import '../services/device_service.dart';
import '../services/incident_service.dart';
import '../widgets/design/tt_pill.dart';

/// Bottom sheet form invoked when the hiker taps the map (or the 3D-map
/// equivalent) to file a new field-intel report. Submits an [Incident] to
/// Supabase via [IncidentService] and refreshes the [SafetyProvider] so the
/// new marker appears immediately.
class FieldIntelSheet extends StatefulWidget {
  final LatLng position;
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

  @override
  void dispose() {
    _descCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

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
            primary: TT.ember,
            surface: TT.bg2,
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
            primary: TT.ember,
            surface: TT.bg2,
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

      // Upload the photo (if any) first so the URL can land on the row in a
      // single insert. Upload failure doesn't block the report -- the text
      // content is the safety-critical part; the photo is supporting.
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
      // Refresh provider so the new marker appears immediately.
      context.read<SafetyProvider>().refresh();
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = 'Could not submit report. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      decoration: const BoxDecoration(
        color: TT.bg2,
        borderRadius: BorderRadius.vertical(top: Radius.circular(TT.rLg)),
      ),
      padding: EdgeInsets.fromLTRB(18, 8, 18, 18 + bottom),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const _SheetHandle(),

            // ── Title ────────────────────────────────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: TT.emberDim,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: TT.line3, width: 1.2),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(Icons.warning_amber_rounded,
                      color: TT.ember, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Report Field Intel', style: TT.title(18)),
                      const SizedBox(height: 4),
                      Text(
                        '${widget.position.latitude.toStringAsFixed(5)}, '
                        '${widget.position.longitude.toStringAsFixed(5)}',
                        style: TT.mono(size: 11.5, color: TT.text2),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            if (widget.nearestTrail != null) ...[
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: TTPill(
                  label: 'NEAR · ${widget.nearestTrail!.name}'.toUpperCase(),
                  variant: TTPillVariant.ember,
                  leadingIcon: Icons.terrain_outlined,
                ),
              ),
            ],

            const SizedBox(height: 18),
            const _TTDivider(),
            const SizedBox(height: 16),

            // ── Category ─────────────────────────────────────────────────
            const _SectionLabel('CATEGORY'),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: IncidentType.values.map((t) {
                final sel = t == _type;
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => setState(() => _type = t),
                  child: AnimatedContainer(
                    duration: TT.dFast,
                    curve: TT.easeOut,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: sel ? TT.emberDim : const Color(0x07FFFFFF),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: sel ? TT.ember : TT.line2,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(t.emoji, style: const TextStyle(fontSize: 14)),
                        const SizedBox(width: 6),
                        Text(
                          t.label,
                          style: TT.body(
                            size: 12,
                            color: sel ? TT.ember : TT.text2,
                            w: sel ? FontWeight.w800 : FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 20),

            // ── Severity ─────────────────────────────────────────────────
            const _SectionLabel('SEVERITY'),
            const SizedBox(height: 10),
            Row(
              children: IncidentSeverity.values.map((s) {
                final sel = s == _severity;
                final last = s == IncidentSeverity.critical;
                return Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => setState(() => _severity = s),
                    child: AnimatedContainer(
                      duration: TT.dFast,
                      curve: TT.easeOut,
                      margin: EdgeInsets.only(right: last ? 0 : 6),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: sel
                            ? s.color.withOpacity(0.18)
                            : const Color(0x07FFFFFF),
                        borderRadius: BorderRadius.circular(TT.rMd),
                        border: Border.all(
                          color: sel ? s.color.withOpacity(0.7) : TT.line2,
                          width: 1,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        s.label,
                        style: TT.body(
                          size: 12,
                          color: sel ? s.color : TT.text2,
                          w: sel ? FontWeight.w800 : FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 20),

            if (_type == IncidentType.hazardZone) ...[
              const _SectionLabel('ZONE NAME (OPTIONAL)'),
              const SizedBox(height: 10),
              _TTField(
                controller: _nameCtrl,
                hint: 'e.g. Loose Rock, Wasp Nest, Slippery Slope',
              ),
              const SizedBox(height: 20),
            ],

            // ── Date & time ──────────────────────────────────────────────
            const _SectionLabel('TIME OF OBSERVATION'),
            const SizedBox(height: 10),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _pickDate,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 13),
                decoration: BoxDecoration(
                  color: const Color(0x07FFFFFF),
                  borderRadius: BorderRadius.circular(TT.rMd),
                  border: Border.all(color: TT.line2, width: 1),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today_outlined,
                        color: TT.ember, size: 15),
                    const SizedBox(width: 10),
                    Text(
                      _formatDate(_date),
                      style: TT.mono(size: 12.5, color: TT.text),
                    ),
                    const Spacer(),
                    const Icon(Icons.edit_outlined,
                        color: TT.text3, size: 14),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // ── Description ──────────────────────────────────────────────
            const _SectionLabel('DETAILS'),
            const SizedBox(height: 10),
            _TTField(
              controller: _descCtrl,
              hint: 'Describe what happened, where exactly, '
                  'and any important details for other hikers…',
              maxLines: 5,
              maxLength: 800,
              borderColor: _error != null ? TT.ember : null,
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
            ),

            const SizedBox(height: 20),

            // ── Photo ────────────────────────────────────────────────────
            const _SectionLabel('PHOTO (OPTIONAL)'),
            const SizedBox(height: 10),
            _PhotoPicker(
              photo: _photo,
              onPickCamera: () => _pickPhoto(ImageSource.camera),
              onPickGallery: () => _pickPhoto(ImageSource.gallery),
              onRemove: () => setState(() => _photo = null),
            ),

            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!,
                  style: TT.body(size: 12, color: TT.red, w: FontWeight.w700)),
            ],

            const SizedBox(height: 18),
            const _TTDivider(),
            const SizedBox(height: 12),

            // ── Disclaimer ───────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0x07FFFFFF),
                borderRadius: BorderRadius.circular(TT.rMd),
                border: Border.all(color: TT.line, width: 1),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      color: TT.amber, size: 14),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'For life-threatening emergencies, call emergency '
                      'services first (SA Mountain Rescue: 10111). This '
                      'report is for community awareness only.',
                      style: TT
                          .body(size: 11, color: TT.text2, w: FontWeight.w600)
                          .copyWith(height: 1.55),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ── Submit (ember pill) ──────────────────────────────────────
            _EmberPillButton(
              label: _submitting ? 'Submitting…' : 'Submit field intel',
              icon: Icons.send_outlined,
              busy: _submitting,
              onTap: _submitting ? null : _submit,
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

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);
  @override
  Widget build(BuildContext context) =>
      Text(text, style: TT.label(size: 10.5, color: TT.text2, letterSpacing: 1.6));
}

class _TTField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final int maxLines;
  final int? maxLength;
  final Color? borderColor;
  final ValueChanged<String>? onChanged;

  const _TTField({
    required this.controller,
    required this.hint,
    this.maxLines = 1,
    this.maxLength,
    this.borderColor,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0x07FFFFFF),
        borderRadius: BorderRadius.circular(TT.rMd),
        border: Border.all(color: borderColor ?? TT.line2, width: 1),
      ),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        maxLength: maxLength,
        onChanged: onChanged,
        cursorColor: TT.ember,
        style: TT.body(size: 13, color: TT.text),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TT.body(size: 13, color: TT.text3, w: FontWeight.w500),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(
              horizontal: 14, vertical: maxLines > 1 ? 12 : 13),
          counterStyle: TT.mono(size: 10.5, color: TT.text3),
        ),
      ),
    );
  }
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
            borderRadius: BorderRadius.circular(TT.rMd),
            child: Image.file(
              photo!,
              width: double.infinity,
              height: 180,
              fit: BoxFit.cover,
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: Material(
              color: const Color(0xCC000000),
              shape: const CircleBorder(),
              child: IconButton(
                icon: const Icon(Icons.close, color: TT.text, size: 18),
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
        color: const Color(0x07FFFFFF),
        borderRadius: BorderRadius.circular(TT.rMd),
        border: Border.all(color: TT.line2, width: 1),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextButton.icon(
              icon: const Icon(Icons.photo_camera_outlined,
                  color: TT.ember, size: 16),
              label: Text('Camera',
                  style: TT.body(size: 13, color: TT.text, w: FontWeight.w700)),
              onPressed: onPickCamera,
            ),
          ),
          Container(width: 1, height: 28, color: TT.line2),
          Expanded(
            child: TextButton.icon(
              icon: const Icon(Icons.photo_library_outlined,
                  color: TT.ember, size: 16),
              label: Text('Gallery',
                  style: TT.body(size: 13, color: TT.text, w: FontWeight.w700)),
              onPressed: onPickGallery,
            ),
          ),
        ],
      ),
    );
  }
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
    return SizedBox(
      width: double.infinity,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: TT.dFast,
          curve: TT.easeOut,
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: disabled ? TT.emberDim : TT.ember,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
                color: disabled ? const Color(0x33FF6A2C) : TT.ember,
                width: 1),
            boxShadow: disabled ? null : TT.shadowEmber,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (busy)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: TT.emberInk),
                )
              else
                Icon(icon, color: TT.emberInk, size: 16),
              const SizedBox(width: 10),
              Text(
                label,
                style: TT
                    .body(size: 14, color: TT.emberInk, w: FontWeight.w800)
                    .copyWith(letterSpacing: 0.04 * 14),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
