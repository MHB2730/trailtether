import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants.dart';
import '../../models/gpx_track.dart';
import '../../models/trail.dart';
import '../../providers/static_data_provider.dart';
import '../../providers/gpx_provider.dart';
import '../../services/gpx_service.dart';
import '../../services/logger_service.dart';

class AdminTrailsTab extends StatefulWidget {
  const AdminTrailsTab({super.key});

  @override
  State<AdminTrailsTab> createState() => _AdminTrailsTabState();
}

class _AdminTrailsTabState extends State<AdminTrailsTab>
    with SingleTickerProviderStateMixin {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _gpxUploads = [];
  bool _loading = true;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchGpxUploads();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchGpxUploads() async {
    setState(() => _loading = true);
    try {
      dynamic response;
      try {
        response = await _supabase
            .from(kColGpxUploads)
            .select('*, profiles(username)')
            .order('created_at', ascending: false);
      } catch (e) {
        LoggerService.log(
            'GPX_FETCH', 'Join failed, falling back to simple query: $e');
        response = await _supabase
            .from(kColGpxUploads)
            .select('*')
            .order('created_at', ascending: false);
      }

      setState(() {
        _gpxUploads = List<Map<String, dynamic>>.from(response);
        _loading = false;
      });
    } catch (e) {
      debugPrint('Error fetching GPX uploads: $e');
      setState(() => _loading = false);
    }
  }

  Future<void> _handleUpload() async {
    LoggerService.log('GPX_UPLOAD', 'User initiated GPX file pick');

    ({UserGpxTrack track, File? file, Uint8List bytes})? result;
    try {
      result = await GpxService.pickAndParse(kColorOrange);
    } catch (e) {
      LoggerService.error('GPX_UPLOAD', 'File pick/parse failed: $e');
      if (mounted) _showErrorDialog('File Pick Failed', '$e');
      return;
    }

    if (result == null) {
      LoggerService.log('GPX_UPLOAD', 'User cancelled file picker');
      return;
    }

    LoggerService.log('GPX_UPLOAD',
        'Parsed ${result.track.points.length} points from ${result.track.filename}');

    setState(() => _loading = true);
    try {
      await GpxService.upload(
        result.track,
        file: result.file,
        bytes: result.bytes,
      );
      LoggerService.log(
          'GPX_UPLOAD', 'Upload successful: ${result.track.filename}');
      await _fetchGpxUploads();

      // Refresh the GpxProvider so the map reflects the new route immediately
      if (mounted) {
        unawaited(
            Provider.of<GpxProvider>(context, listen: false).syncWithCloud());
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('GPX Data Ingested and Published to Fleet')),
        );
      }
    } catch (e, stack) {
      LoggerService.error('GPX_UPLOAD', 'Upload failed: $e', stack);
      if (mounted) _showErrorDialog('Upload Failed', '$e');
    } finally {
      setState(() => _loading = false);
    }
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: kColorBg,
        title: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.redAccent),
            const SizedBox(width: 12),
            Text(title, style: const TextStyle(color: Colors.redAccent)),
          ],
        ),
        content: SelectableText(
          message,
          style: const TextStyle(color: Colors.white70, fontSize: 13),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close')),
        ],
      ),
    );
  }

  Future<void> _editGpxUpload(Map<String, dynamic> trail) async {
    final nameController =
        TextEditingController(text: trail['display_name'] ?? trail['filename']);
    final descController =
        TextEditingController(text: trail['description'] ?? '');
    String difficulty = trail['difficulty'] ?? 'Moderate';

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: kColorBg,
          title: const Text('Edit Trail Data',
              style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                    labelText: 'Display Name',
                    labelStyle: TextStyle(color: kColorOrange)),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descController,
                maxLines: 3,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                    labelText: 'Description',
                    labelStyle: TextStyle(color: kColorOrange)),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: ['Easy', 'Moderate', 'Challenging', 'Expert']
                        .contains(difficulty)
                    ? difficulty
                    : 'Moderate',
                dropdownColor: kColorBg,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                    labelText: 'Difficulty',
                    labelStyle: TextStyle(color: kColorOrange)),
                items: ['Easy', 'Moderate', 'Challenging', 'Expert']
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: (v) => setDialogState(() => difficulty = v!),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: kColorOrange),
              child: const Text('Save Changes'),
            ),
          ],
        ),
      ),
    );

    if (result == true) {
      setState(() => _loading = true);
      try {
        await _supabase.from(kColGpxUploads).update({
          'display_name': nameController.text,
          'description': descController.text,
          'difficulty': difficulty,
        }).eq('id', trail['id']);

        LoggerService.log(
            'GPX_LIBRARY', 'Successfully updated trail: ${trail['id']}');
        await _fetchGpxUploads();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Trail metadata updated')));
        }
      } catch (e, stack) {
        LoggerService.error(
            'GPX_LIBRARY', 'Error updating trail metadata: $e', stack);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('Update Failed: $e'), backgroundColor: Colors.red));
        }
      } finally {
        if (mounted) setState(() => _loading = false);
      }
    }
  }

  Future<void> _deleteGpxUpload(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: kColorBg,
        title:
            const Text('Delete Trail?', style: TextStyle(color: Colors.white)),
        content: const Text('This will remove the trail from all devices.',
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child:
                const Text('Delete', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _loading = true);
      try {
        await _supabase.from(kColGpxUploads).delete().eq('id', id);
        await _fetchGpxUploads();
      } catch (e) {
        debugPrint('Error deleting trail: $e');
      } finally {
        setState(() => _loading = false);
      }
    }
  }

  void _showTrailDetails(Trail trail) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: kColorBg,
        title: Row(
          children: [
            Icon(trail.isCave ? Icons.explore : Icons.terrain,
                color: kColorOrange),
            const SizedBox(width: 12),
            Expanded(
                child: Text(trail.name,
                    style: const TextStyle(color: Colors.white, fontSize: 18))),
          ],
        ),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _detailRow(
                  'Distance', '${trail.distanceKm.toStringAsFixed(2)} km'),
              _detailRow('Ascent', '+${trail.elevationGainM} m'),
              _detailRow('Descent', '-${trail.elevationDescentM} m'),
              _detailRow(
                  'Elevation Range', '${trail.minEle}m – ${trail.maxEle}m'),
              _detailRow('Difficulty', trail.difficulty),
              _detailRow('Est. Time (moderate)', trail.formattedTime(1.0)),
              _detailRow('Est. Time (fast)', trail.formattedTime(0.7)),
              _detailRow('Est. Time (slow)', trail.formattedTime(1.3)),
              _detailRow(
                  'Avg Gradient', '${trail.avgGradePct.toStringAsFixed(1)}%'),
              _detailRow('Coordinates', '${trail.coords.length} points'),
              _detailRow(
                  'Type', trail.isCave ? 'Cave System' : 'Standard Trail'),
              if (trail.description.isNotEmpty) ...[
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(trail.description,
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.5), fontSize: 12)),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close')),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  color: Colors.white.withOpacity(0.4), fontSize: 13)),
          Text(value,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Geospatial Library',
                    style: GoogleFonts.outfit(
                        color: kColorCream,
                        fontSize: 32,
                        fontWeight: FontWeight.w900),
                  ),
                  Text(
                    'All routes in the system — local assets and user-uploaded GPX.',
                    style: GoogleFonts.outfit(
                        color: kColorCream.withOpacity(0.5), fontSize: 16),
                  ),
                ],
              ),
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      final gpxProvider =
                          Provider.of<GpxProvider>(context, listen: false);
                      await _fetchGpxUploads();
                      await gpxProvider.syncWithCloud();
                      if (!mounted) return;
                      messenger.showSnackBar(
                        const SnackBar(
                            content:
                                Text('Map and Library Synced with Cloud')),
                      );
                    },
                    icon: const Icon(Icons.sync, size: 18),
                    label: const Text('Force Sync'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kColorOrange.withOpacity(0.1),
                      foregroundColor: kColorOrange,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: kColorOrange.withOpacity(0.3)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _handleUpload,
                    icon: const Icon(Icons.upload_file),
                    label: const Text('Ingest GPX Data'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kColorOrange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          TabBar(
            controller: _tabController,
            indicatorColor: kColorOrange,
            labelColor: kColorOrange,
            unselectedLabelColor: kColorCream.withOpacity(0.4),
            tabs: const [
              Tab(text: 'System Routes (Local)'),
              Tab(text: 'GPX Uploads (Cloud)'),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildLocalTrailsList(),
                _loading
                    ? const Center(
                        child: CircularProgressIndicator(color: kColorOrange))
                    : _buildGpxUploadsTable(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Tab 1: Shows all trails from the local JSON assets with full stats
  Widget _buildLocalTrailsList() {
    final dataProv = Provider.of<StaticDataProvider>(context);
    final trails = dataProv.allTrails;

    if (trails.isEmpty) {
      return Center(
          child: Text('No local trails loaded.',
              style: TextStyle(color: kColorCream.withOpacity(0.3))));
    }

    return Container(
      decoration: BoxDecoration(
        color: kColorGlass,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: kColorBorder),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: SingleChildScrollView(
          child: DataTable(
            columns: [
              DataColumn(label: _headerText('Route Name')),
              DataColumn(label: _headerText('Distance')),
              DataColumn(label: _headerText('Ascent')),
              DataColumn(label: _headerText('Descent')),
              DataColumn(label: _headerText('Range')),
              DataColumn(label: _headerText('Difficulty')),
              DataColumn(label: _headerText('Est. Time')),
              DataColumn(label: _headerText('Actions')),
            ],
            rows: trails.map<DataRow>((trail) {
              return DataRow(cells: [
                DataCell(
                  Text(trail.name,
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold)),
                ),
                DataCell(Text('${trail.distanceKm.toStringAsFixed(1)} km',
                    style: const TextStyle(color: Colors.white70))),
                DataCell(Text('+${trail.elevationGainM} m',
                    style: const TextStyle(
                        color: Colors.greenAccent, fontSize: 12))),
                DataCell(Text('-${trail.elevationDescentM} m',
                    style: const TextStyle(
                        color: Colors.redAccent, fontSize: 12))),
                DataCell(Text('${trail.minEle}–${trail.maxEle}m',
                    style:
                        const TextStyle(color: Colors.white70, fontSize: 12))),
                DataCell(Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: difficultyColor(trail.difficulty).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color:
                            difficultyColor(trail.difficulty).withOpacity(0.3)),
                  ),
                  child: Text(trail.difficulty,
                      style: TextStyle(
                          color: difficultyColor(trail.difficulty),
                          fontSize: 10,
                          fontWeight: FontWeight.bold)),
                )),
                DataCell(Text(trail.formattedTime(1.0),
                    style: const TextStyle(color: Colors.white70))),
                DataCell(
                  IconButton(
                    icon: const Icon(Icons.analytics_outlined,
                        size: 16, color: kColorCyan),
                    onPressed: () => _showTrailDetails(trail),
                    tooltip: 'View Full Analytics',
                  ),
                ),
              ]);
            }).toList(),
          ),
        ),
      ),
    );
  }

  /// Tab 2: Shows user-uploaded GPX files from Supabase
  Widget _buildGpxUploadsTable() {
    if (_gpxUploads.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off,
                color: kColorCream.withOpacity(0.15), size: 64),
            const SizedBox(height: 16),
            Text('No GPX uploads yet.',
                style: TextStyle(
                    color: kColorCream.withOpacity(0.3), fontSize: 16)),
            const SizedBox(height: 8),
            Text('Upload GPX files or Plot Routes from the Live Map.',
                style: TextStyle(
                    color: kColorCream.withOpacity(0.2), fontSize: 12)),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: kColorGlass,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: kColorBorder),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: SingleChildScrollView(
          child: DataTable(
            columns: [
              DataColumn(label: _headerText('File')),
              DataColumn(label: _headerText('Description')),
              DataColumn(label: _headerText('Uploader')),
              DataColumn(label: _headerText('Distance')),
              DataColumn(label: _headerText('Difficulty')),
              DataColumn(label: _headerText('Actions')),
            ],
            rows: _gpxUploads.map<DataRow>((trail) {
              final displayName =
                  trail['display_name'] ?? trail['filename'] ?? 'Untitled';
              return DataRow(cells: [
                DataCell(Text(displayName,
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold))),
                DataCell(SizedBox(
                  width: 200,
                  child: Text(trail['description'] ?? '—',
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 12),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                )),
                DataCell(Text(
                    trail['profiles']?['username'] ??
                        trail['author_name'] ??
                        'System',
                    style: const TextStyle(color: Colors.white70))),
                DataCell(Text('${trail['distance_km'] ?? 0} km',
                    style: const TextStyle(color: Colors.white70))),
                DataCell(Text(trail['difficulty'] ?? 'Moderate',
                    style: const TextStyle(color: Colors.white70))),
                DataCell(Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.analytics_outlined,
                          size: 16, color: kColorCyan),
                      onPressed: () {
                        final gpxProv =
                            Provider.of<GpxProvider>(context, listen: false);
                        final track = gpxProv.tracks.firstWhere(
                            (t) => t.id == trail['id'],
                            orElse: () => UserGpxTrack(
                                id: trail['id'],
                                filename: trail['filename'] ?? 'unknown.gpx',
                                points: [],
                                elevations: [],
                                distanceKm: 0,
                                elevationGainM: 0,
                                color: Colors.grey));
                        if (track.points.isNotEmpty) {
                          _showTrailDetails(Trail(
                            id: track.id,
                            name: track.label,
                            description: track.description,
                            coords: track.points
                                .map((p) =>
                                    TrailCoord(p.longitude, p.latitude, 0))
                                .toList(),
                            distanceKm: track.distanceKm,
                            elevationGainM: track.elevationGainM,
                            elevationDescentM: 0,
                            estTimeHours: track.distanceKm / 4.0,
                            minEle: 0,
                            maxEle: 0,
                            profile: [],
                            difficulty: track.difficulty.isNotEmpty
                                ? track.difficulty
                                : 'Moderate',
                          ));
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text(
                                      'GPX data still syncing or inaccessible.')));
                        }
                      },
                      tooltip: 'View Full Analytics',
                    ),
                    IconButton(
                        icon:
                            const Icon(Icons.edit, size: 16, color: kColorCyan),
                        onPressed: () => _editGpxUpload(trail)),
                    IconButton(
                        icon: const Icon(Icons.delete,
                            size: 16, color: Colors.redAccent),
                        onPressed: () => _deleteGpxUpload(trail['id'])),
                  ],
                )),
              ]);
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _headerText(String text) {
    return Text(
      text,
      style: GoogleFonts.outfit(
          color: kColorCream, fontWeight: FontWeight.bold, fontSize: 14),
    );
  }
}
