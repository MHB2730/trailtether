import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import '../../core/constants.dart';
import '../../models/incident.dart';
import '../../models/team.dart';
import '../../providers/team_provider.dart';
import '../../services/incident_service.dart';
import 'package:intl/intl.dart';

class AdminSafetyTab extends StatefulWidget {
  const AdminSafetyTab({super.key});

  @override
  State<AdminSafetyTab> createState() => _AdminSafetyTabState();
}

class _AdminSafetyTabState extends State<AdminSafetyTab> {
  final _supabase = Supabase.instance.client;
  List<Incident> _incidents = [];
  bool _loading = true;
  StreamSubscription? _sub;

  @override
  void initState() {
    super.initState();
    _startListening();
  }

  void _startListening() {
    _sub = IncidentService.allIncidents().listen(
      (list) {
        if (!mounted) return;
        setState(() {
          _incidents = list.where((i) => i.id != 'error').toList();
          _loading = false;
        });
      },
      onError: (e) {
        debugPrint('AdminSafetyTab stream error: $e');
        if (mounted) setState(() => _loading = false);
      },
    );
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _deleteIncident(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: kColorBg,
        title: const Text('Delete Incident?',
            style: TextStyle(color: Colors.white)),
        content: const Text(
            'This will permanently remove this incident record.',
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

    if (confirm != true) return;

    try {
      await IncidentService.deleteIncident(id);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Incident deleted')));
      }
    } catch (e) {
      debugPrint('Error deleting incident: $e');
    }
  }

  Future<void> _resolveIncident(String id) async {
    try {
      await _supabase
          .from(kColIncidents)
          .update({'status': 'resolved'}).eq('id', id);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Incident resolved')));
      }
    } catch (e) {
      debugPrint('Error resolving incident: $e');
    }
  }

  Future<void> _showAssignDialog(Incident inc) async {
    final teamProv = context.read<TeamProvider>();
    final team = teamProv.selectedTeam;
    if (team == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Select a team first (Teams Tab).')));
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
      } catch (e) {
        debugPrint('Error assigning incident: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 32),
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: kColorOrange))
                : _buildIncidentList(),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.security, color: Colors.redAccent, size: 32),
                const SizedBox(width: 16),
                Text(
                  'Safety & Emergency Command',
                  style: GoogleFonts.outfit(
                    color: kColorCream,
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            Text(
              'Live feed — updates automatically when incidents are reported.',
              style: GoogleFonts.outfit(
                color: kColorCream.withOpacity(0.5),
                fontSize: 16,
              ),
            ),
          ],
        ),
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                  color: Colors.greenAccent, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Text('LIVE',
                style: GoogleFonts.outfit(
                    color: Colors.greenAccent,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2)),
          ],
        ),
      ],
    );
  }

  Widget _buildIncidentList() {
    if (_incidents.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_outline,
                color: Colors.greenAccent.withOpacity(0.2), size: 64),
            const SizedBox(height: 16),
            Text('No Active Incidents',
                style: TextStyle(
                    color: kColorCream.withOpacity(0.3), fontSize: 18)),
          ],
        ),
      );
    }

    return ListView.separated(
      itemCount: _incidents.length,
      separatorBuilder: (_, __) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        final incident = _incidents[index];
        final isSOS = incident.type == IncidentType.medicalEmergency ||
            incident.isEmergency;

        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: kColorGlass,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color:
                    isSOS ? Colors.redAccent.withOpacity(0.3) : kColorBorder),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: incident.type.color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Text(incident.type.emoji,
                    style: const TextStyle(fontSize: 20)),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          incident.type.label,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: incident.severity.color.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(incident.severity.label,
                              style: TextStyle(
                                  color: incident.severity.color,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                    if (incident.description.isNotEmpty)
                      Text(
                        incident.description,
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.6), fontSize: 14),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.location_on,
                            size: 14, color: Colors.white24),
                        const SizedBox(width: 4),
                        Text(
                          '${incident.lat.toStringAsFixed(5)}, ${incident.lon.toStringAsFixed(5)}',
                          style: const TextStyle(
                              color: Colors.white24, fontSize: 12),
                        ),
                        const SizedBox(width: 16),
                        const Icon(Icons.access_time,
                            size: 14, color: Colors.white24),
                        const SizedBox(width: 4),
                        Text(
                          _formatTime(incident.reportedAt),
                          style: const TextStyle(
                              color: Colors.white24, fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                children: [
                  if (incident.status != 'resolved') ...[
                    ElevatedButton(
                      onPressed: () => _resolveIncident(incident.id),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.greenAccent.withOpacity(0.1),
                          foregroundColor: Colors.greenAccent),
                      child: const Text('Resolve'),
                    ),
                    const SizedBox(height: 8),
                    if (incident.status != 'assigned')
                      OutlinedButton(
                        onPressed: () => _showAssignDialog(incident),
                        style: OutlinedButton.styleFrom(
                            foregroundColor: kColorOrange,
                            side: const BorderSide(color: kColorOrange)),
                        child: const Text('Assign'),
                      )
                    else
                      Text('Assigned to: ${incident.assignedToName}',
                          style: const TextStyle(
                              color: kColorOrange,
                              fontSize: 10,
                              fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                  ],
                  IconButton(
                    onPressed: () => _deleteIncident(incident.id),
                    icon: const Icon(Icons.delete_outline,
                        size: 18, color: Colors.redAccent),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return DateFormat('MMM dd HH:mm').format(dt);
  }
}
