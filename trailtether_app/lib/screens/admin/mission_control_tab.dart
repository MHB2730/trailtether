import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../providers/gpx_provider.dart';
import '../../providers/units_provider.dart';
import '../../core/constants.dart';
import '../../models/team.dart';
import '../../models/trail.dart';
import '../../models/gpx_track.dart';
import '../../widgets/map/trail_map_widget.dart';
import '../../widgets/trail/elevation_chart.dart';
import '../../models/incident.dart';
import '../../models/cave_waypoint.dart';
import '../../providers/team_provider.dart';
import '../../services/gpx_service.dart';
import '../../services/incident_service.dart';
import '../../services/logger_service.dart';
import '../../widgets/map/trail_map_3d_widget.dart';
import '../../providers/static_data_provider.dart';
import '../../providers/safety_provider.dart';
import '../trail_detail_screen.dart';
import '../incident_detail_sheet.dart';
import '../cave_detail_sheet.dart';

class MissionControlTab extends StatefulWidget {
  const MissionControlTab({super.key});

  @override
  State<MissionControlTab> createState() => _MissionControlTabState();
}

class _MissionControlTabState extends State<MissionControlTab> {
  final _supabase = Supabase.instance.client;
  final _mapController = MapController();

  RealtimeChannel? _trackingChannel;
  RealtimeChannel? _incidentChannel;

  Map<String, TeamMemberLocation> _locations = {};
  bool _loading = true;
  bool _showHeatmap = false;
  bool _showIncidentsList = false;
  bool _drawingZone = false;
  bool _plottingRoute = false;
  List<LatLng> _zonePoints = [];
  List<LatLng> _routePoints = [];
  List<Map<String, dynamic>> _existingZones = [];
  dynamic _selectedObject;
  bool _filterByTeam = false;
  bool _show3D = false;
  int _tileStyleIndex = 0; // 0=Outdoor 1=Standard 2=Topo 3=Satellite

  StreamSubscription? _gpxSub;
  // Periodic rebuild so "Xm ago" labels and live/recent/stale colors stay accurate
  // even when no new Realtime update has arrived.
  Timer? _tickTimer;
  // Safety-net polling timer. If the Realtime websocket drops, takes a long
  // time to negotiate after a fresh auth token, or silently misses an event,
  // the map would otherwise sit stale until the user navigates away and back.
  // Re-running the team_member_locations query every 15s catches every miss
  // without flooding the DB.
  Timer? _safetyRefreshTimer;

  @override
  void initState() {
    super.initState();
    // Order matters: subscribe to live updates BEFORE the initial fetch so that any
    // location row inserted between fetch-start and subscription-active is not lost.
    _setupRealtime();
    _loadInitialData();
    _fetchExistingZones();
    _tickTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) setState(() {});
    });
    _safetyRefreshTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (!mounted) return;
      _loadInitialData();
    });
  }

  void _setupRealtime() {
    _trackingChannel?.unsubscribe();
    _incidentChannel?.unsubscribe();

    _trackingChannel = _supabase
        .channel('live-tracking')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'team_member_locations',
          callback: (payload) {
            final loc = TeamMemberLocation.fromMap(payload.newRecord);
            _updateLocalLocation(loc);
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'team_member_locations',
          callback: (payload) {
            final loc = TeamMemberLocation.fromMap(payload.newRecord);
            _updateLocalLocation(loc);
          },
        )
        .subscribe();

    _incidentChannel = _supabase
        .channel('live-incidents')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'incidents',
          callback: (payload) {
            // SafetyProvider already listens to this table,
            // but we can trigger a refresh if we want to be extra sure.
            context.read<SafetyProvider>().refresh();
          },
        )
        .subscribe();

    _gpxSub?.cancel();
    _gpxSub = _supabase
        .from(kColGpxUploads)
        .stream(primaryKey: ['id']).listen((list) {
      LoggerService.log('LIVE_GPX', 'Library updated via realtime');
      if (mounted) {
        context.read<GpxProvider>().syncWithCloud();
      }
    });
  }

  @override
  void dispose() {
    _tickTimer?.cancel();
    _safetyRefreshTimer?.cancel();
    _trackingChannel?.unsubscribe();
    _incidentChannel?.unsubscribe();
    _gpxSub?.cancel();
    _mapController.dispose();
    super.dispose();
  }


  void _updateLocalLocation(TeamMemberLocation loc) {
    if (!mounted) return;

    // Apply team filter if active
    if (_filterByTeam) {
      final teamId = context.read<TeamProvider>().selectedTeam?.id;
      if (loc.teamId != teamId) return;
    }

    setState(() {
      _locations[loc.uid] = loc;
    });
  }

  Future<void> _loadInitialData() async {
    final teamId = context.read<TeamProvider>().selectedTeam?.id;
    try {
      // Show anyone who has reported in the last 2 hours. Anything older is treated as
      // "offline" — they'll be re-added live if they come back online.
      var query = _supabase.from('team_member_locations').select().gt(
          'timestamp',
          DateTime.now()
              .toUtc()
              .subtract(const Duration(hours: 2))
              .toIso8601String());

      if (_filterByTeam && teamId != null) {
        query = query.eq('team_id', teamId);
      }

      final locData = await query.order('timestamp', ascending: false);
      LoggerService.log(
          'ADMIN_LIVE', 'Fetched ${locData.length} raw locations from DB');

      final List<TeamMemberLocation> newLocs =
          (locData as List).map((d) => TeamMemberLocation.fromMap(d)).toList();

      // Deduplicate by UID (show only most recent for each person)
      final Map<String, TeamMemberLocation> uniqueLocs = {};
      for (var loc in newLocs) {
        if (!uniqueLocs.containsKey(loc.uid)) {
          uniqueLocs[loc.uid] = loc;
        }
      }

      if (mounted) {
        setState(() {
          _locations = uniqueLocs;
          _loading = false;
        });
        LoggerService.log(
            'ADMIN_LIVE', 'Showing ${_locations.length} unique hiker markers');
      }
    } catch (e, stack) {
      LoggerService.error(
          'ADMIN_LIVE', 'Error loading initial data: $e', stack);
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _fetchExistingZones() async {
    try {
      final res = await _supabase
          .from(kColIncidents)
          .select()
          .eq('type', 'hazard_zone')
          .eq('status', 'open');
      if (mounted) {
        setState(() {
          _existingZones = List<Map<String, dynamic>>.from(res);
        });
      }
    } catch (e) {
      debugPrint('Error fetching zones: $e');
    }
  }

  Future<void> _sendBroadcast() async {
    final controller = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: kColorBg,
        title: const Text('Send System Broadcast',
            style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          maxLines: 3,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Enter message for all active hikers...',
            hintStyle: TextStyle(color: Colors.white24),
            enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.white24)),
            focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: kColorOrange)),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Send Broadcast',
                style: TextStyle(color: kColorOrange)),
          ),
        ],
      ),
    );

    if (result == true && controller.text.isNotEmpty) {
      try {
        // The incidents_insert RLS policy requires auth.uid() = created_by.
        // Without this the broadcast insert was being rejected with 42501.
        final uid = Supabase.instance.client.auth.currentUser?.id ?? '';
        final broadcast = Incident(
          id: '',
          lat: _locations.isNotEmpty ? _locations.values.first.lat : 0.0,
          lon: _locations.isNotEmpty ? _locations.values.first.lon : 0.0,
          type: IncidentType.broadcast,
          severity: IncidentSeverity.critical,
          description: controller.text,
          incidentDate: DateTime.now(),
          reportedAt: DateTime.now(),
          deviceId: 'ADMIN_CONSOLE',
          createdBy: uid,
          isEmergency: true,
          status: 'open',
        );

        await IncidentService.addIncident(broadcast);
        LoggerService.log('BROADCAST', 'Broadcast sent: ${controller.text}');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Broadcast sent successfully')));
        }
      } catch (e, stack) {
        LoggerService.error('BROADCAST', 'Failed to send broadcast: $e', stack);
      }
    }
  }

  Future<void> _savePlottedRoute() async {
    if (_routePoints.isEmpty) return;

    final nameController = TextEditingController(
        text: 'Route ${DateTime.now().hour}:${DateTime.now().minute}');
    final descController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => _MetadataDialog(
        title: 'Save Plotted Route',
        nameController: nameController,
        descController: descController,
        nameHint: 'Route Name (e.g. Primary Search Path)',
        descHint: 'Details for field teams...',
      ),
    );

    if (result == true && nameController.text.isNotEmpty) {
      try {
        final track = UserGpxTrack(
          id: '',
          filename: '${nameController.text.replaceAll(' ', '_')}.gpx',
          displayName: nameController.text,
          description: descController.text,
          points: _routePoints,
          elevations: List.filled(_routePoints.length, 0.0),
          distanceKm: 0,
          elevationGainM: 0,
          color: kColorOrange,
        );

        await GpxService.upload(track);

        LoggerService.log('PLOT_ROUTE', 'Route saved: ${nameController.text}');
        setState(() {
          _plottingRoute = false;
          _routePoints = [];
        });

        if (mounted) {
          unawaited(
              Provider.of<GpxProvider>(context, listen: false).syncWithCloud());
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Route Saved and Published to Fleet')));
        }
      } catch (e, stack) {
        LoggerService.error('PLOT_ROUTE', 'Failed to save route: $e', stack);
      }
    }
  }

  Future<void> _saveHazardZone() async {
    if (_zonePoints.isEmpty) return;

    final nameController = TextEditingController(
        text: 'Hazard Zone ${DateTime.now().hour}:${DateTime.now().minute}');
    final descController = TextEditingController(
        text: 'Admin-defined hazardous area. Avoid entering.');

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => _MetadataDialog(
        title: 'Save Hazard Zone',
        nameController: nameController,
        descController: descController,
        nameHint: 'Zone Name (e.g. Flood Area)',
        descHint: 'Tactical details or warnings...',
      ),
    );

    if (result != true) return;

    try {
      final zone = Incident(
        id: '',
        lat: _zonePoints.first.latitude,
        lon: _zonePoints.first.longitude,
        type: IncidentType.hazardZone,
        severity: IncidentSeverity.serious,
        description: descController.text,
        incidentDate: DateTime.now(),
        reportedAt: DateTime.now(),
        deviceId: 'ADMIN_CONSOLE',
        status: 'open',
      );

      final insertData = zone.toInsertMap();
      insertData['metadata'] = {
        'name': nameController.text,
        'polygon': _zonePoints.map((p) => [p.latitude, p.longitude]).toList(),
      };

      await _supabase.from(kColIncidents).insert(insertData);
      LoggerService.log(
          'HAZARD_ZONE', 'Hazard zone created: ${nameController.text}');
      setState(() {
        _drawingZone = false;
        _zonePoints = [];
      });
      if (mounted) {
        unawaited(_fetchExistingZones());
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Zone Saved and Published to Fleet')));
      }
    } catch (e, stack) {
      LoggerService.error('SAVE_ZONE', 'Failed to save zone: $e', stack);
    }
  }

  void _handleMapTap(LatLng pos) {
    const distCalc = Distance();
    for (var zone in _existingZones) {
      final meta = zone['metadata'] as Map<String, dynamic>?;
      if (meta != null && meta['polygon'] != null) {
        final pts = (meta['polygon'] as List)
            .map((p) =>
                LatLng((p[0] as num).toDouble(), (p[1] as num).toDouble()))
            .toList();
        for (var pt in pts) {
          if (distCalc.as(LengthUnit.Meter, pos, pt) < 60) {
            _editHazardZone(zone);
            return;
          }
        }
      }
    }
  }

  void _editHazardZone(Map<String, dynamic> zone) async {
    final meta = zone['metadata'] as Map<String, dynamic>?;
    final nameController =
        TextEditingController(text: meta?['name'] ?? 'Hazard Zone');
    final descController =
        TextEditingController(text: zone['description'] ?? '');

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: kColorBg,
        title: const Text('Edit Hazard Zone',
            style: TextStyle(color: Colors.white)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                  controller: nameController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                      labelText: 'Name',
                      labelStyle: TextStyle(color: Colors.white54))),
              TextField(
                  controller: descController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                      labelText: 'Description',
                      labelStyle: TextStyle(color: Colors.white54))),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'delete'),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'cancel'),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'save'),
            child: const Text('Save', style: TextStyle(color: kColorOrange)),
          ),
        ],
      ),
    );

    if (result == 'delete') {
      await _supabase
          .from(kColIncidents)
          .update({'status': 'resolved'}).eq('id', zone['id']);
      unawaited(_fetchExistingZones());
    } else if (result == 'save') {
      final updatedMeta = Map<String, dynamic>.from(meta ?? {});
      updatedMeta['name'] = nameController.text;
      await _supabase.from(kColIncidents).update({
        'description': descController.text,
        'metadata': updatedMeta,
      }).eq('id', zone['id']);
      unawaited(_fetchExistingZones());
    }
  }

  @override
  Widget build(BuildContext context) {
    final markers = _locations.values.map((loc) {
      // Tri-state liveness: green = within 30s, amber = within 5min, red = older.
      final Color pinColor = loc.isLive
          ? const Color(0xFF22C55E)
          : loc.isRecent
              ? const Color(0xFFEAB308)
              : const Color(0xFFEF4444);
      final String ageLabel = loc.isLive
          ? 'LIVE'
          : loc.isRecent
              ? '${(loc.ageSeconds / 60).floor()}m'
              : '${(loc.ageSeconds / 60).floor()}m ago';
      return Marker(
        point: LatLng(loc.lat, loc.lon),
        width: 90,
        height: 90,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Only badge non-default statuses. 'active' is the baseline
            // live-sharing state and doesn't need a banner; 'recording'
            // (currently hiking) gets the brand orange so it pops on the
            // map; sos/help stay red; arrived shows green.
            if (loc.status != null &&
                loc.status != 'active' &&
                loc.status != 'Tracking')
              Container(
                margin: const EdgeInsets.only(bottom: 2),
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: (loc.status == 'sos' || loc.status == 'help')
                      ? Colors.red
                      : loc.status == 'recording'
                          ? kColorOrange
                          : Colors.green,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  loc.status!.toUpperCase(),
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 8,
                      fontWeight: FontWeight.bold),
                ),
              ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: pinColor, width: 1),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    margin: const EdgeInsets.only(right: 4),
                    decoration:
                        BoxDecoration(color: pinColor, shape: BoxShape.circle),
                  ),
                  Text(
                    '${loc.displayName} · $ageLabel',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 8,
                        fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(
              Icons.person_pin_circle,
              color: pinColor,
              size: 34,
              shadows: const [Shadow(color: Colors.black45, blurRadius: 4)],
            ),
          ],
        ),
      );
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      body: Row(
        children: [
          // Map Area
          Expanded(
            child: Stack(
              children: [
                if (_show3D)
                  TrailMap3DWindowsWidget(
                    trails: context.watch<StaticDataProvider>().allTrails,
                    caves: context.watch<StaticDataProvider>().caves,
                    incidents: context.watch<SafetyProvider>().incidents,
                    teamLocations: _locations.values.toList(),
                    onTrailTap: (trailId) {
                      final trails = context.read<StaticDataProvider>().allTrails;
                      final trail = trails.firstWhere((t) => t.id == trailId, orElse: () => trails.first);
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (_) => TrailDetailScreen(trail: trail, onNavigateToMap: () {}),
                      );
                    },
                    onIncidentTap: (incident) {
                      IncidentDetailSheet.show(context, incident);
                    },
                    onCaveTap: (CaveWaypoint cave) {
                      CaveDetailSheet.show(context, cave);
                    },
                  )
                else
                  TrailMapWidget(
                    controller: _mapController,
                    onTrailTap: (trail) {
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (_) => TrailDetailScreen(trail: trail, onNavigateToMap: () {}),
                      );
                    },
                    onGpxTap: (track) {
                      setState(() => _selectedObject = track);
                      if (track.points.isNotEmpty) {
                        _mapController.move(track.points.first, 13);
                      }
                    },
                    onIncidentTap: (incident) {
                      IncidentDetailSheet.show(context, incident);
                    },
                    onCaveTap: (CaveWaypoint cave) {
                      CaveDetailSheet.show(context, cave);
                    },
                    tileStyleIndex: _tileStyleIndex,
                    selectedTrailId: _selectedObject is Trail
                        ? (_selectedObject as Trail).id
                        : null,
                    gpsActive: false,
                    extraMarkers: _showHeatmap ? [] : markers,
                    incidentMode: _drawingZone || _plottingRoute,
                    onMapTapForIncident: (pos) {
                      if (_drawingZone) {
                        setState(() => _zonePoints.add(pos));
                      } else if (_plottingRoute) {
                        setState(() => _routePoints.add(pos));
                      } else {
                        _handleMapTap(pos);
                      }
                    },
                    onMapTap: (pos) {
                      if (!_drawingZone && !_plottingRoute) {
                        _handleMapTap(pos);
                      }
                    },
                    children: [
                      if (_showHeatmap) _buildHeatmapLayer(),
                      _buildExistingZonesLayer(),
                      if (_drawingZone && _zonePoints.isNotEmpty)
                        _buildZoneDrawingLayer(),
                      if (_plottingRoute && _routePoints.isNotEmpty)
                        _buildRouteDrawingLayer(),
                    ],
                  ),

                // Map Controls Overlay
                Positioned(
                  top: 24,
                  left: 24,
                  child: _buildMapOverlay(),
                ),

                // Selection Info Panel
                if (_selectedObject != null)
                  Positioned(
                    bottom: 24,
                    left: 24,
                    child: _buildTrailInfoPanel(),
                  ),
              ],
            ),
          ),

          // Sidebar
          ClipRRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
              child: Container(
                width: 320,
                decoration: BoxDecoration(
                  color: kColorBg.withOpacity(0.8),
                  border: const Border(left: BorderSide(color: kColorBorder, width: 1)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSidebarHeader(),
                Expanded(
                  child: _loading
                      ? const Center(
                          child: CircularProgressIndicator(color: kColorOrange))
                      : _showIncidentsList
                          ? Consumer<SafetyProvider>(
                              builder: (context, safety, child) {
                                final incidents = safety.incidents;
                                if (incidents.isEmpty) {
                                  return _buildEmptyState('No active incidents.');
                                }
                                return ListView.separated(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16),
                                  itemCount: incidents.length,
                                  separatorBuilder: (_, __) =>
                                      const SizedBox(height: 8),
                                  itemBuilder: (context, index) =>
                                      _buildIncidentCard(incidents[index]),
                                );
                              },
                            )
                          : _locations.isEmpty
                              ? _buildEmptyState('No active tracking data.')
                              : Builder(builder: (_) {
                                  // Sort roster: SOS/help first, then live, recent, lost.
                                  // Within each band, most recent timestamp first.
                                  final sorted = _locations.values.toList()
                                    ..sort((a, b) {
                                      int rank(TeamMemberLocation l) {
                                        if (l.status == 'sos' ||
                                            l.status == 'help') return 0;
                                        if (l.isLive) return 1;
                                        if (l.isRecent) return 2;
                                        return 3;
                                      }
                                      final r = rank(a).compareTo(rank(b));
                                      if (r != 0) return r;
                                      return b.timestamp.compareTo(a.timestamp);
                                    });
                                  return ListView.separated(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16),
                                    itemCount: sorted.length,
                                    separatorBuilder: (_, __) =>
                                        const SizedBox(height: 8),
                                    itemBuilder: (context, index) =>
                                        _buildHikerCard(sorted[index]),
                                  );
                                }),
                ),
                _buildAdminActions(),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSidebarHeader() {
    // Roster summary — at-a-glance state of the whole group.
    // recordingCount = live AND status='recording' (actively in a hike right
    // now, not just leaving the app open). This is what the user actually
    // wants to see in the command centre header.
    int liveCount = 0, recentCount = 0, lostCount = 0, recordingCount = 0;
    bool anyEmergency = false;
    for (final loc in _locations.values) {
      if (loc.isLive) {
        liveCount++;
        if (loc.status == 'recording') recordingCount++;
      } else if (loc.isRecent) {
        recentCount++;
      } else {
        lostCount++;
      }
      if (loc.status == 'sos' || loc.status == 'help') anyEmergency = true;
    }

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'ACTIVE HIKERS (${_locations.length})',
                style: GoogleFonts.outfit(
                  color: kColorOrange,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
              if (anyEmergency) ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.redAccent),
                  ),
                  child: Text('SOS',
                      style: GoogleFonts.outfit(
                          color: Colors.redAccent,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1)),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Command Centre',
            style: GoogleFonts.outfit(
              color: kColorCream,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _statusPill('Recording', recordingCount, kColorOrange),
              _statusPill('Live', liveCount, const Color(0xFF22C55E)),
              _statusPill('Recent', recentCount, const Color(0xFFEAB308)),
              _statusPill('Lost', lostCount, const Color(0xFFEF4444)),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _tabButton('HIKERS', !_showIncidentsList,
                  () => setState(() => _showIncidentsList = false)),
              _tabButton('INCIDENTS', _showIncidentsList,
                  () => setState(() => _showIncidentsList = true)),
              _tabButton(_filterByTeam ? 'MY TEAM' : 'ALL TEAMS', true, () {
                setState(() => _filterByTeam = !_filterByTeam);
                _loadInitialData();
              }),
              _tabButton(_show3D ? '2D VIEW' : '3D VIEW', true, () {
                setState(() => _show3D = !_show3D);
              }),
            ],
          ),
        ],
      ),
    );
  }

  Widget _tabButton(String label, bool active, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: active ? kColorOrange.withOpacity(0.2) : Colors.white.withOpacity(0.03),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: active ? kColorOrange.withOpacity(0.5) : Colors.white.withOpacity(0.05)),
          boxShadow: active ? [
            BoxShadow(color: kColorOrange.withOpacity(0.1), blurRadius: 10, spreadRadius: 1)
          ] : null,
        ),
        child: Text(
          label,
          style: GoogleFonts.outfit(
            color: active ? kColorOrange : Colors.white38,
            fontSize: 10,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.satellite_alt,
              size: 48, color: kColorCream.withOpacity(0.1)),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(color: kColorCream.withOpacity(0.3), fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildHikerCard(TeamMemberLocation loc) {
    final units = Provider.of<UnitsProvider>(context);
    final Color dotColor = loc.isLive
        ? const Color(0xFF22C55E)
        : loc.isRecent
            ? const Color(0xFFEAB308)
            : const Color(0xFFEF4444);
    final String ageLabel = loc.isLive
        ? 'LIVE'
        : loc.isRecent
            ? '${(loc.ageSeconds / 60).floor()}m'
            : '${(loc.ageSeconds / 60).floor()}m lost';
    final speedKmh = loc.speed * 3.6;
    final hasStatusBadge =
        loc.status != null && loc.status!.isNotEmpty && loc.status != 'Tracking';
    final bool emergencyStatus =
        loc.status == 'help' || loc.status == 'sos';

    return InkWell(
      onTap: () => _mapController.move(LatLng(loc.lat, loc.lon), 15),
      onLongPress: () => _showHikerActions(loc),
      borderRadius: BorderRadius.circular(kRadiusCard),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: emergencyStatus
                ? [
                    Colors.red.withOpacity(0.18),
                    Colors.red.withOpacity(0.04),
                  ]
                : [
                    Colors.white.withOpacity(0.05),
                    Colors.white.withOpacity(0.01),
                  ],
          ),
          borderRadius: BorderRadius.circular(kRadiusCard),
          border: Border.all(
            color: emergencyStatus
                ? Colors.redAccent.withOpacity(0.5)
                : dotColor.withOpacity(0.3),
            width: emergencyStatus ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration:
                      BoxDecoration(color: dotColor, shape: BoxShape.circle),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    loc.displayName.toUpperCase(),
                    style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        letterSpacing: 0.5),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: dotColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    ageLabel,
                    style: GoogleFonts.outfit(
                        color: dotColor,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _miniStat(
                    Icons.speed, units.formatSpeed(speedKmh)),
                const SizedBox(width: 12),
                _miniStat(Icons.terrain, '${loc.altitude.round()}m'),
                const SizedBox(width: 12),
                _miniStat(
                    Icons.explore, '${loc.heading.round()}°'),
              ],
            ),
            if (hasStatusBadge) ...[
              const SizedBox(height: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: emergencyStatus
                      ? Colors.redAccent.withOpacity(0.2)
                      : Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  loc.status!.toUpperCase(),
                  style: GoogleFonts.outfit(
                      color:
                          emergencyStatus ? Colors.redAccent : Colors.white70,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _statusPill(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text('$count $label',
              style: GoogleFonts.outfit(
                  color: color,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5)),
        ],
      ),
    );
  }

  Widget _miniStat(IconData icon, String value) {
    return Row(
      children: [
        Icon(icon, size: 11, color: Colors.white38),
        const SizedBox(width: 3),
        Text(value,
            style:
                TextStyle(color: Colors.white.withOpacity(0.55), fontSize: 11)),
      ],
    );
  }

  /// Long-press actions on a hiker card. Centre map, copy coords, send broadcast.
  void _showHikerActions(TeamMemberLocation loc) {
    showModalBottomSheet(
      context: context,
      backgroundColor: kColorBg,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(loc.displayName,
                  style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700)),
            ),
            ListTile(
              leading: const Icon(Icons.center_focus_strong,
                  color: kColorOrange),
              title: const Text('Focus on map',
                  style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _mapController.move(LatLng(loc.lat, loc.lon), 16);
              },
            ),
            ListTile(
              leading: const Icon(Icons.copy, color: kColorOrange),
              title: const Text('Copy coordinates',
                  style: TextStyle(color: Colors.white)),
              onTap: () {
                Clipboard.setData(ClipboardData(
                    text:
                        '${loc.lat.toStringAsFixed(6)}, ${loc.lon.toStringAsFixed(6)}'));
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Coordinates copied')));
              },
            ),
            ListTile(
              leading:
                  const Icon(Icons.campaign, color: kColorOrange),
              title: const Text('Send broadcast to all',
                  style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _sendBroadcast();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildIncidentCard(Incident inc) {
    return InkWell(
      onTap: () {
        _mapController.move(LatLng(inc.lat, inc.lon), 15);
        setState(() => _selectedObject = inc);
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: kColorGlass,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color:
                  inc.isEmergency ? Colors.red.withOpacity(0.3) : kColorBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(inc.type.emoji, style: const TextStyle(fontSize: 16)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    inc.type.label,
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: inc.severity.color.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                    border:
                        Border.all(color: inc.severity.color.withOpacity(0.5)),
                  ),
                  child: Text(
                    inc.severity.label.toUpperCase(),
                    style: TextStyle(
                        color: inc.severity.color,
                        fontSize: 8,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              inc.description,
              style:
                  TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.access_time, size: 10, color: Colors.white24),
                const SizedBox(width: 4),
                Text(inc.ageString,
                    style:
                        const TextStyle(color: Colors.white24, fontSize: 10)),
                const Spacer(),
                if (inc.status == 'assigned') ...[
                  const Icon(Icons.person, size: 10, color: kColorOrange),
                  const SizedBox(width: 4),
                  Text(inc.assignedToName ?? 'Assigned',
                      style:
                          const TextStyle(color: kColorOrange, fontSize: 10)),
                ] else
                  TextButton(
                    onPressed: () => _showAssignDialog(inc),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text('ASSIGN',
                        style: TextStyle(
                            color: kColorOrange,
                            fontSize: 10,
                            fontWeight: FontWeight.bold)),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showAssignDialog(Incident inc) async {
    final teamProv = context.read<TeamProvider>();
    final team = teamProv.selectedTeam;
    if (team == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Select a team first.')));
      return;
    }

    final result = await showDialog<TeamMember>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: kColorBg,
        title: const Text('Assign Incident',
            style: TextStyle(color: Colors.white)),
        content: SizedBox(
          width: 300,
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: team.members.length,
            separatorBuilder: (_, __) => const Divider(color: Colors.white10),
            itemBuilder: (context, index) {
              final m = team.members[index];
              return ListTile(
                leading: CircleAvatar(
                    backgroundColor: kColorOrange.withOpacity(0.1),
                    child: const Icon(Icons.person,
                        color: kColorOrange, size: 16)),
                title: Text(m.displayName,
                    style: const TextStyle(color: Colors.white, fontSize: 14)),
                onTap: () => Navigator.pop(context, m),
              );
            },
          ),
        ),
      ),
    );

    if (result != null) {
      try {
        await _supabase.from(kColIncidents).update({
          'status': 'assigned',
          'assigned_to_uid': result.uid,
          'assigned_to_name': result.displayName,
        }).eq('id', inc.id);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Assigned to ${result.displayName}')));
        }
      } catch (e, stack) {
        LoggerService.error(
            'ASSIGN_INCIDENT', 'Failed to assign incident: $e', stack);
      }
    }
  }

  Widget _buildAdminActions() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Color(0xFF050505),
        border: Border(top: BorderSide(color: kColorBorder)),
      ),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _sendBroadcast,
              icon: const Icon(Icons.broadcast_on_personal, size: 16),
              label: const Text('BROADCAST'),
              style: ElevatedButton.styleFrom(
                backgroundColor: kColorOrange.withOpacity(0.15),
                foregroundColor: kColorOrange,
                side: const BorderSide(color: kColorOrange),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () {
                final logs = LoggerService.getFullLogs();
                Clipboard.setData(ClipboardData(text: logs));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Logs copied to clipboard')),
                );
              },
              icon: const Icon(Icons.copy_all, size: 16),
              label: const Text('COPY LOGS'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white.withOpacity(0.05),
                foregroundColor: Colors.white70,
                side: const BorderSide(color: Colors.white10),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapOverlay() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(kRadiusCard),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: kColorBg.withOpacity(0.7),
            borderRadius: BorderRadius.circular(kRadiusCard),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 20)
            ],
          ),
          child: Row(
            children: [
              _overlayButton(
                icon: Icons.layers,
                label: _showHeatmap ? 'Standard' : 'Heatmap',
                onTap: () => setState(() => _showHeatmap = !_showHeatmap),
                active: _showHeatmap,
              ),
              const SizedBox(width: 8),
              _overlayButton(
                icon: Icons.satellite_alt,
                label: _tileStyleIndex == 3 ? 'Standard' : 'Satellite',
                onTap: () => setState(
                  () => _tileStyleIndex = _tileStyleIndex == 3 ? 0 : 3,
                ),
                active: _tileStyleIndex == 3,
              ),
              const SizedBox(width: 8),
              _overlayButton(
                icon: _drawingZone ? Icons.check : Icons.polyline_outlined,
                label: _drawingZone ? 'Save Zone' : 'Draw Zone',
                onTap: () {
                  if (_drawingZone) {
                    _saveHazardZone();
                  } else {
                    setState(() {
                      _drawingZone = true;
                      _plottingRoute = false;
                      _zonePoints = [];
                    });
                  }
                },
                active: _drawingZone,
              ),
              const SizedBox(width: 8),
              _overlayButton(
                icon: _plottingRoute ? Icons.check : Icons.route_outlined,
                label: _plottingRoute ? 'Save Route' : 'Plot Route',
                onTap: () {
                  if (_plottingRoute) {
                    _savePlottedRoute();
                  } else {
                    setState(() {
                      _plottingRoute = true;
                      _drawingZone = false;
                      _routePoints = [];
                    });
                  }
                },
                active: _plottingRoute,
              ),
              if (_drawingZone || _plottingRoute) ...[
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () => setState(() {
                    _drawingZone = false;
                    _plottingRoute = false;
                    _zonePoints = [];
                    _routePoints = [];
                  }),
                  icon: const Icon(Icons.close, color: Colors.redAccent, size: 18),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _overlayButton(
      {required IconData icon,
      required String label,
      required VoidCallback onTap,
      bool active = false}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: active ? kColorOrange : kColorOrange.withOpacity(0.05),
          borderRadius: BorderRadius.circular(8),
          border:
              Border.all(color: kColorOrange.withOpacity(active ? 0.8 : 0.2)),
        ),
        child: Row(
          children: [
            Icon(icon, color: active ? Colors.black : kColorOrange, size: 14),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: active ? Colors.black : kColorOrange,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeatmapLayer() {
    return MarkerLayer(
      markers: _locations.values.map((loc) {
        return Marker(
          point: LatLng(loc.lat, loc.lon),
          width: 150,
          height: 150,
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  Colors.redAccent.withOpacity(0.4),
                  Colors.orangeAccent.withOpacity(0.2),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildExistingZonesLayer() {
    return PolygonLayer(
      polygons: _existingZones
          .map((zone) {
            final meta = zone['metadata'] as Map<String, dynamic>?;
            if (meta == null || meta['polygon'] == null) return null;
            final pts = (meta['polygon'] as List).map((p) {
              return LatLng((p[0] as num).toDouble(), (p[1] as num).toDouble());
            }).toList();

            return Polygon(
              points: pts,
              color: Colors.redAccent.withOpacity(0.15),
              borderColor: Colors.redAccent.withOpacity(0.5),
              borderStrokeWidth: 1.5,
              label: meta['name'] ?? 'RESTRICTED HAZARD',
              labelStyle: const TextStyle(
                  color: Colors.redAccent,
                  fontSize: 8,
                  fontWeight: FontWeight.bold),
            );
          })
          .whereType<Polygon>()
          .toList(),
    );
  }

  Widget _buildZoneDrawingLayer() {
    return PolygonLayer(
      polygons: [
        Polygon(
          points: _zonePoints,
          color: Colors.redAccent.withOpacity(0.3),
          borderColor: Colors.redAccent,
          borderStrokeWidth: 2,
        ),
      ],
    );
  }

  Widget _buildRouteDrawingLayer() {
    return PolylineLayer(
      polylines: [
        Polyline(
          points: _routePoints,
          color: kColorOrange,
          strokeWidth: 4,
        ),
      ],
    );
  }

  Widget _buildTrailInfoPanel() {
    final List<LatLng> points;
    final List<double> elevations;
    final String name;
    final String type;
    final String distance;
    final String ascent;
    final bool isTrail = _selectedObject is Trail;

    if (isTrail) {
      final t = _selectedObject as Trail;
      name = t.name;
      type = t.isCave ? 'Cave System' : 'Standard Trail';
      distance = t.distanceKm.toStringAsFixed(2);
      ascent = t.elevationGainM.toString();
      points = t.coords.map((c) => LatLng(c.lat, c.lon)).toList();
      elevations = t.coords.map((c) => c.elevation.toDouble()).toList();
    } else if (_selectedObject is UserGpxTrack) {
      final g = _selectedObject as UserGpxTrack;
      name = g.label;
      type = 'Uploaded Route (GPX)';
      distance = g.distanceKm.toStringAsFixed(2);
      ascent = g.elevationGainM.toString();
      points = List<LatLng>.from(g.points);
      elevations = List<double>.from(g.elevations);
    } else if (_selectedObject is Incident) {
      final inc = _selectedObject as Incident;
      name = '${inc.type.emoji} ${inc.type.label}';
      type = 'Field Incident • ${inc.status.toUpperCase()}';
      distance = '--';
      ascent = '--';
      points = [];
      elevations = [];
    } else {
      return const SizedBox.shrink();
    }

    if (points.isEmpty && _selectedObject is! Incident) {
      return const SizedBox.shrink();
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(kRadiusPremium),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          width: 380,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: kColorBg.withOpacity(0.75),
            borderRadius: BorderRadius.circular(kRadiusPremium),
            border: Border.all(color: kColorOrange.withOpacity(0.3), width: 1.5),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 40)
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name,
                            style: kStyleHeader.copyWith(fontSize: 18),
                            overflow: TextOverflow.ellipsis),
                        Text(type,
                            style: kStyleMeta.copyWith(color: kColorOrange)),
                      ],
                    ),
                  ),
                  IconButton(
                    icon:
                        const Icon(Icons.close, color: Colors.white54, size: 20),
                    onPressed: () => setState(() => _selectedObject = null),
                  ),
                ],
              ),
              if (_selectedObject is Incident) ...[
                const SizedBox(height: 16),
                Text(
                  (_selectedObject as Incident).description,
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 16),
              if (_selectedObject is! Incident) ...[
                _statRow(Icons.straighten, 'Distance', '$distance km'),
                _statRow(Icons.trending_up, 'Ascent', '$ascent m'),
                const Divider(color: Colors.white10, height: 24),
                const Text('ELEVATION PROFILE',
                    style: TextStyle(
                        color: Colors.white38,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2)),
                const SizedBox(height: 12),
                SizedBox(
                  height: 100,
                  child: elevations.isEmpty
                      ? const Center(
                          child: Text('No elevation data',
                              style: TextStyle(
                                  color: Colors.white24, fontSize: 10)))
                      : ElevationChart.fromPoints(
                          points: points,
                          elevations: elevations,
                          color: kColorOrange,
                        ),
                ),
              ],
              if (!isTrail && _selectedObject is UserGpxTrack) ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () =>
                            _deleteGpxRoute(_selectedObject as UserGpxTrack),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.redAccent,
                          side: const BorderSide(color: Colors.redAccent),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                        child: const Text('Delete'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () =>
                            _editGpxRoute(_selectedObject as UserGpxTrack),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kColorOrange,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                        child: const Text('Edit'),
                      ),
                    ),
                  ],
                ),
              ],
              if (_selectedObject is Incident) ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () =>
                            _resolveIncident(_selectedObject as Incident),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                        child: const Text('Resolve Incident',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _resolveIncident(Incident inc) async {
    try {
      await _supabase
          .from(kColIncidents)
          .update({'status': 'resolved'}).eq('id', inc.id);
      if (mounted) {
        setState(() => _selectedObject = null);
        // No need to call refresh manually, SafetyProvider listens to realtime changes
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Incident Resolved')));
      }
    } catch (e, stack) {
      LoggerService.error(
          'RESOLVE_INCIDENT', 'Failed to resolve incident: $e', stack);
    }
  }

  void _editGpxRoute(UserGpxTrack track) async {
    final nameController = TextEditingController(text: track.label);
    final descController = TextEditingController(text: track.description);

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: kColorBg,
        title: const Text('Edit Route', style: TextStyle(color: Colors.white)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                  controller: nameController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                      labelText: 'Name',
                      labelStyle: TextStyle(color: Colors.white54))),
              TextField(
                  controller: descController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                      labelText: 'Description',
                      labelStyle: TextStyle(color: Colors.white54))),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, 'cancel'),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, 'save'),
              child: const Text('Save', style: TextStyle(color: kColorOrange))),
        ],
      ),
    );

    if (result == 'save') {
      try {
        await _supabase.from('gpx_uploads').update({
          'display_name': nameController.text,
          'description': descController.text,
        }).eq('id', track.id);

        if (mounted) {
          unawaited(
              Provider.of<GpxProvider>(context, listen: false).syncWithCloud());
          setState(() => _selectedObject = null);
        }
      } catch (e, stack) {
        LoggerService.error(
            'EDIT_GPX_ROUTE', 'Failed to update GPX route: $e', stack);
      }
    }
  }

  void _deleteGpxRoute(UserGpxTrack track) async {
    try {
      await _supabase.from('gpx_uploads').delete().eq('id', track.id);
      if (mounted) {
        unawaited(
            Provider.of<GpxProvider>(context, listen: false).syncWithCloud());
        setState(() => _selectedObject = null);
      }
    } catch (e, stack) {
      LoggerService.error(
          'DELETE_GPX_ROUTE', 'Failed to delete GPX route: $e', stack);
    }
  }

  Widget _statRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, color: kColorOrange.withOpacity(0.6), size: 14),
          const SizedBox(width: 8),
          Text(label,
              style:
                  TextStyle(color: kColorCream.withOpacity(0.4), fontSize: 12)),
          const Spacer(),
          Text(value,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class _MetadataDialog extends StatelessWidget {
  final String title;
  final TextEditingController nameController;
  final TextEditingController descController;
  final String nameHint;
  final String descHint;

  const _MetadataDialog({
    required this.title,
    required this.nameController,
    required this.descController,
    required this.nameHint,
    required this.descHint,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: kColorBg,
      title: Text(title, style: const TextStyle(color: Colors.white)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: nameHint,
                hintStyle: const TextStyle(color: Colors.white24),
                enabledBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.white24)),
                focusedBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(color: kColorOrange)),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: descController,
              maxLines: 3,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: descHint,
                hintStyle: const TextStyle(color: Colors.white24),
                enabledBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.white24)),
                focusedBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(color: kColorOrange)),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel')),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Save', style: TextStyle(color: kColorOrange)),
        ),
      ],
    );
  }
}
