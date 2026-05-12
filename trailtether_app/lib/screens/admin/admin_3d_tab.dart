import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants.dart';
import '../../providers/static_data_provider.dart';
import '../../widgets/map/trail_map_3d_widget.dart';
import '../../models/team.dart';

class Admin3DTab extends StatefulWidget {
  const Admin3DTab({super.key});

  @override
  State<Admin3DTab> createState() => _Admin3DTabState();
}

class _Admin3DTabState extends State<Admin3DTab> {
  final _supabase = Supabase.instance.client;
  List<TeamMemberLocation> _teamLocations = [];
  RealtimeChannel? _trackingChannel;

  @override
  void initState() {
    super.initState();
    _setupTracking();
  }

  void _setupTracking() {
    _trackingChannel = _supabase.channel('public:team_member_locations');
    _trackingChannel!
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'team_member_locations',
          callback: (payload) {
            _loadLocations();
          },
        )
        .subscribe();
    _loadLocations();
  }

  Future<void> _loadLocations() async {
    try {
      final res = await _supabase.from('team_member_locations').select().gt(
          'timestamp',
          DateTime.now().subtract(const Duration(hours: 4)).toIso8601String());

      final locs =
          (res as List).map((d) => TeamMemberLocation.fromMap(d)).toList();

      // Deduplicate by UID
      final Map<String, TeamMemberLocation> unique = {};
      for (var l in locs) {
        if (!unique.containsKey(l.uid)) unique[l.uid] = l;
      }

      if (mounted) {
        setState(() {
          _teamLocations = unique.values.toList();
        });
      }
    } catch (e) {
      debugPrint('Admin3DTab error loading locations: $e');
    }
  }

  @override
  void dispose() {
    _trackingChannel?.unsubscribe();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dataProv = Provider.of<StaticDataProvider>(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Tactical 3D Command',
                style: GoogleFonts.outfit(
                  color: kColorCream,
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                'High-fidelity terrain visualization with live team tracking.',
                style: GoogleFonts.outfit(
                  color: kColorCream.withOpacity(0.5),
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Container(
            margin: const EdgeInsets.fromLTRB(32, 0, 32, 32),
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: kColorBorder),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 20),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(32),
              child: TrailMap3DWindowsWidget(
                trails: dataProv.allTrails,
                caves: dataProv.caves,
                teamLocations: _teamLocations,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
