import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../core/constants.dart';
import '../models/gpx_track.dart';
import '../providers/gpx_provider.dart';
import '../services/auth_service.dart';
import '../services/gpx_service.dart';

class GpxUploadScreen extends StatefulWidget {
  const GpxUploadScreen({super.key});

  @override
  State<GpxUploadScreen> createState() => _GpxUploadScreenState();
}

class _GpxUploadScreenState extends State<GpxUploadScreen> {
  bool _picking = false;
  bool _uploading = false;
  bool _shareToggle = false;

  @override
  Widget build(BuildContext context) {
    final gpxProv = context.watch<GpxProvider>();
    final track = gpxProv.tracks.isNotEmpty ? gpxProv.tracks.last : null;

    return Scaffold(
      backgroundColor: kColorBg,
      appBar: AppBar(
        title:
            Text('Add Trails', style: GoogleFonts.outfit(color: kColorCream)),
        backgroundColor: kColorBg,
        iconTheme: IconThemeData(color: kColorCream.withOpacity(0.7)),
        elevation: 0,
      ),
      body: Column(
        children: [
          // ── Track list ────────────────────────────────────────────────
          if (gpxProv.tracks.isNotEmpty)
            Expanded(
              flex: 3,
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                itemCount: gpxProv.tracks.length,
                itemBuilder: (_, i) {
                  final t = gpxProv.tracks[i];
                  return _TrackTile(
                    track: t,
                    onDelete: () => gpxProv.remove(t.id),
                    onEdit: () => _showMetadataSheet(context, t, gpxProv),
                  );
                },
              ),
            ),

          // ── Preview map for most-recent track ─────────────────────────
          if (track != null)
            Expanded(
              flex: 4,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: _TrackPreviewMap(track: track),
                ),
              ),
            ),

          // ── Empty state ───────────────────────────────────────────────
          if (gpxProv.tracks.isEmpty)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.route_outlined,
                        color: kColorCream.withOpacity(0.15), size: 52),
                    const SizedBox(height: 12),
                    Text(
                      'No GPX files loaded.',
                      style: GoogleFonts.outfit(
                          color: kColorCream.withOpacity(0.35), fontSize: 14),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Tap "Add GPX" to import a route.',
                      style: GoogleFonts.outfit(
                          color: kColorCream.withOpacity(0.2), fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),

          // ── Bottom action bar ─────────────────────────────────────────
          _BottomActions(
            hasTrack: track != null,
            picking: _picking,
            uploading: _uploading,
            shareToggle: _shareToggle,
            onLoad: _loadGpx,
            onToggleShare: () => setState(() => _shareToggle = !_shareToggle),
            onShare: _shareCommunity,
            onShowOnMap: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  // ── Pick + parse a GPX file ──────────────────────────────────────────────
  Future<void> _loadGpx() async {
    setState(() => _picking = true);
    try {
      final gpxProv = context.read<GpxProvider>();
      final result = await GpxService.pickAndParse(
        kGpxColors[gpxProv.tracks.length % kGpxColors.length],
      );
      if (result != null && mounted) {
        gpxProv.add(result.track, file: result.file, bytes: result.bytes);
        // Open metadata sheet immediately after picking
        await _showMetadataSheet(context, result.track, gpxProv,
            required: true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not read GPX file: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  // ── Metadata sheet ───────────────────────────────────────────────────────
  Future<void> _showMetadataSheet(
      BuildContext context, UserGpxTrack track, GpxProvider gpxProv,
      {bool required = false}) async {
    final nameCtrl = TextEditingController(
        text: track.displayName.isNotEmpty
            ? track.displayName
            : track.filename.replaceAll('.gpx', ''));
    final authorCtrl = TextEditingController(text: track.authorName);
    final descCtrl = TextEditingController(text: track.description);
    String difficulty = track.difficulty;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: !required,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.fromLTRB(
              0, 0, 0, MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            decoration: const BoxDecoration(
              color: Color(0xFF1A1A1A),
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: kColorCream.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Text('Trail Details',
                    style: GoogleFonts.outfit(
                        color: kColorCream,
                        fontSize: 17,
                        fontWeight: FontWeight.w700)),
                if (required)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Please fill in the trail name and your name before continuing.',
                      style: GoogleFonts.outfit(
                          color: kColorCream.withOpacity(0.45), fontSize: 12),
                    ),
                  ),
                const SizedBox(height: 16),

                // Trail name (required)
                _MetaField(
                    controller: nameCtrl,
                    label: 'Trail Name *',
                    hint: 'E.g. Dragon Peak Loop'),
                const SizedBox(height: 10),

                // Author
                _MetaField(
                    controller: authorCtrl,
                    label: 'Your Name',
                    hint: 'E.g. John Smith'),
                const SizedBox(height: 10),

                // Description
                _MetaField(
                    controller: descCtrl,
                    label: 'Description',
                    hint: 'Highlights, route notes…',
                    maxLines: 3),
                const SizedBox(height: 10),

                // Difficulty
                Text('Difficulty',
                    style: GoogleFonts.outfit(
                        color: kColorCream.withOpacity(0.5),
                        fontSize: 11,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  children: ['Easy', 'Moderate', 'Hard', 'Extreme'].map((d) {
                    final sel = difficulty == d;
                    return ChoiceChip(
                      label: Text(d, style: GoogleFonts.outfit(fontSize: 11)),
                      selected: sel,
                      onSelected: (_) =>
                          setModalState(() => difficulty = sel ? '' : d),
                      selectedColor: kColorOrange.withOpacity(0.22),
                      backgroundColor: Colors.transparent,
                      side:
                          BorderSide(color: sel ? kColorOrange : kColorBorder),
                      labelStyle: TextStyle(
                          color: sel
                              ? kColorOrange
                              : kColorCream.withOpacity(0.6)),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),

                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {
                      final name = nameCtrl.text.trim();
                      if (name.isEmpty) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(
                              content: Text('Trail name is required')),
                        );
                        return;
                      }
                      final updated = track.copyWith(
                        displayName: name,
                        authorName: authorCtrl.text.trim(),
                        description: descCtrl.text.trim(),
                        difficulty: difficulty,
                      );
                      gpxProv.update(updated);
                      Navigator.pop(ctx);
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: kColorOrange,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: Text('Save',
                        style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    nameCtrl.dispose();
    authorCtrl.dispose();
    descCtrl.dispose();
  }

  // ── Upload to Supabase (community share) ─────────────────────────────────
  Future<void> _shareCommunity() async {
    final gpxProv = context.read<GpxProvider>();
    if (gpxProv.tracks.isEmpty) return;

    setState(() => _uploading = true);
    try {
      final track = gpxProv.tracks.last;
      final uid = AuthService.currentUser?.uid;
      if (uid == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Sign in before sharing a route.')),
          );
        }
        return;
      }
      final file = gpxProv.fileForTrack(track.id);
      final bytes = gpxProv.bytesForTrack(track.id);
      final updated = await GpxService.upload(track, file: file, bytes: bytes);
      gpxProv.update(updated);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Track shared with the community!')),
        );
        setState(() => _shareToggle = false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }
}

// ── Single loaded-track tile ───────────────────────────────────────────────
class _TrackTile extends StatelessWidget {
  final UserGpxTrack track;
  final VoidCallback onDelete;
  final VoidCallback onEdit;
  const _TrackTile(
      {required this.track, required this.onDelete, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: kColorPanel,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: kColorBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 14,
            height: 14,
            decoration:
                BoxDecoration(color: track.color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(track.label,
                    style: GoogleFonts.outfit(
                        color: kColorCream,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
                Text(
                  [
                    '${track.distanceKm.toStringAsFixed(1)} km',
                    '${track.points.length} pts',
                    if (track.difficulty.isNotEmpty) track.difficulty,
                    if (track.authorName.isNotEmpty) '· ${track.authorName}',
                    if (track.sharedToCloud) '· ☁ shared',
                  ].join(' · '),
                  style: GoogleFonts.outfit(
                      color: kColorCream.withOpacity(0.45), fontSize: 11),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.edit_outlined,
                color: kColorOrange.withOpacity(0.6), size: 18),
            onPressed: onEdit,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
          IconButton(
            icon: Icon(Icons.delete_outline,
                color: kColorCream.withOpacity(0.3), size: 18),
            onPressed: onDelete,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
        ],
      ),
    );
  }
}

// ── Simple text field for metadata ────────────────────────────────────────
class _MetaField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final int maxLines;
  const _MetaField(
      {required this.controller,
      required this.label,
      required this.hint,
      this.maxLines = 1});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: GoogleFonts.outfit(
                color: kColorCream.withOpacity(0.5),
                fontSize: 11,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          maxLines: maxLines,
          style: GoogleFonts.outfit(color: kColorCream, fontSize: 13),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.outfit(
                color: kColorCream.withOpacity(0.25), fontSize: 13),
            filled: true,
            fillColor: Colors.white.withOpacity(0.05),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: kColorBorder)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: kColorBorder)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: kColorOrange, width: 1.5)),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            isDense: true,
          ),
        ),
      ],
    );
  }
}

// ── Preview map ────────────────────────────────────────────────────────────
class _TrackPreviewMap extends StatelessWidget {
  final UserGpxTrack track;
  const _TrackPreviewMap({required this.track});

  @override
  Widget build(BuildContext context) {
    if (track.points.isEmpty) return const SizedBox.shrink();

    final lats = track.points.map((p) => p.latitude).toList()..sort();
    final lons = track.points.map((p) => p.longitude).toList()..sort();
    final bounds = LatLngBounds(
      LatLng(lats.first, lons.first),
      LatLng(lats.last, lons.last),
    );

    return FlutterMap(
      options: MapOptions(
        initialCameraFit: CameraFit.bounds(
          bounds: bounds,
          padding: const EdgeInsets.all(24),
        ),
      ),
      children: [
        TileLayer(
          urlTemplate: kTileUrl,
          userAgentPackageName: kTileUserAgent,
          maxZoom: 19,
        ),
        PolylineLayer(
          polylines: [
            Polyline(
              points: track.points,
              color: track.color,
              strokeWidth: 3.0,
            ),
          ],
        ),
      ],
    );
  }
}

// ── Bottom actions bar ─────────────────────────────────────────────────────
class _BottomActions extends StatelessWidget {
  final bool hasTrack;
  final bool picking;
  final bool uploading;
  final bool shareToggle;
  final VoidCallback onLoad;
  final VoidCallback onToggleShare;
  final VoidCallback onShare;
  final VoidCallback onShowOnMap;

  const _BottomActions({
    required this.hasTrack,
    required this.picking,
    required this.uploading,
    required this.shareToggle,
    required this.onLoad,
    required this.onToggleShare,
    required this.onShare,
    required this.onShowOnMap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
          16, 12, 16, MediaQuery.of(context).viewInsets.bottom + 16),
      decoration: const BoxDecoration(
        color: kColorPanel,
        border: Border(top: BorderSide(color: kColorBorder)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (hasTrack) ...[
              GestureDetector(
                onTap: onToggleShare,
                behavior: HitTestBehavior.opaque,
                child: Row(
                  children: [
                    Icon(
                      shareToggle
                          ? Icons.check_circle
                          : Icons.check_circle_outline,
                      color: shareToggle
                          ? kColorOrange
                          : kColorCream.withOpacity(0.3),
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Share with the Trailtether community',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.outfit(
                            color: kColorCream.withOpacity(0.7), fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
            ],
            LayoutBuilder(
              builder: (context, constraints) {
                final buttons = <Widget>[
                  _actionSlot(
                    constraints,
                    _outlinedAction(
                      onPressed: picking ? null : onLoad,
                      icon: picking
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.folder_open_outlined, size: 16),
                      label: 'Add GPX',
                    ),
                  ),
                  if (hasTrack)
                    _actionSlot(
                      constraints,
                      _outlinedAction(
                        onPressed: onShowOnMap,
                        icon: const Icon(Icons.map_outlined, size: 16),
                        label: 'Show on map',
                      ),
                    ),
                  if (hasTrack && shareToggle)
                    _actionSlot(
                      constraints,
                      ElevatedButton.icon(
                        onPressed: uploading ? null : onShare,
                        icon: uploading
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.cloud_upload_outlined, size: 16),
                        label: _buttonLabel('Share'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kColorOrange,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(0, 44),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                ];

                final stackButtons =
                    buttons.length > 2 && constraints.maxWidth < 440;
                if (stackButtons) {
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var i = 0; i < buttons.length; i++) ...[
                        SizedBox(width: double.infinity, child: buttons[i]),
                        if (i < buttons.length - 1) const SizedBox(height: 8),
                      ],
                    ],
                  );
                }

                return Row(
                  children: [
                    for (var i = 0; i < buttons.length; i++) ...[
                      Expanded(child: buttons[i]),
                      if (i < buttons.length - 1) const SizedBox(width: 8),
                    ],
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionSlot(BoxConstraints constraints, Widget child) => child;

  Widget _outlinedAction({
    required VoidCallback? onPressed,
    required Widget icon,
    required String label,
  }) =>
      OutlinedButton.icon(
        onPressed: onPressed,
        icon: icon,
        label: _buttonLabel(label),
        style: OutlinedButton.styleFrom(
          foregroundColor: kColorCream,
          side: const BorderSide(color: kColorBorder),
          minimumSize: const Size(0, 44),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );

  Widget _buttonLabel(String text) => Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: GoogleFonts.outfit(fontSize: 13),
      );
}
