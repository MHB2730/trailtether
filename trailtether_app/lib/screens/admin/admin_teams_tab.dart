import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants.dart';

class AdminTeamsTab extends StatefulWidget {
  const AdminTeamsTab({super.key});

  @override
  State<AdminTeamsTab> createState() => _AdminTeamsTabState();
}

class _AdminTeamsTabState extends State<AdminTeamsTab> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _teams = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchTeams();
  }

  Future<void> _fetchTeams() async {
    setState(() => _loading = true);
    try {
      final response = await _supabase.from(kColTeams).select().order('name');

      if (mounted) {
        setState(() {
          _teams = List<Map<String, dynamic>>.from(response);
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching teams: $e');
      if (mounted) setState(() => _loading = false);
    }
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
                    'Team Logistics',
                    style: GoogleFonts.outfit(
                      color: kColorCream,
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    'Monitor and coordinate field teams globally.',
                    style: GoogleFonts.outfit(
                      color: kColorCream.withOpacity(0.5),
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  IconButton(
                    onPressed: _fetchTeams,
                    icon: const Icon(Icons.refresh, color: kColorOrange),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton.icon(
                    onPressed: _showCreateTeamDialog,
                    icon: const Icon(Icons.add),
                    label: const Text('Deploy New Team'),
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
          const SizedBox(height: 32),
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: kColorOrange))
                : _teams.isEmpty
                    ? Center(
                        child: Text('No teams found.',
                            style:
                                TextStyle(color: kColorCream.withOpacity(0.3))))
                    : _buildTeamsGrid(),
          ),
        ],
      ),
    );
  }

  Widget _buildTeamsGrid() {
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 24,
        mainAxisSpacing: 24,
        childAspectRatio: 1.4,
      ),
      itemCount: _teams.length,
      itemBuilder: (context, index) {
        final team = _teams[index];
        final membersList = team['members'] as List? ?? [];
        final description = team['description'] ?? 'No description provided.';

        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: kColorGlass,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: kColorBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: kColorOrange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.groups, color: kColorOrange),
                  ),
                  _buildStatusBadge('Active'),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                team['name'] ?? 'Untitled Team',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.outfit(
                  color: kColorCream,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Expanded(
                child: Text(
                  description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: kColorCream.withOpacity(0.5), fontSize: 12),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.person, size: 14, color: kColorCream),
                  const SizedBox(width: 4),
                  Text('${membersList.length} Members',
                      style: TextStyle(
                          color: kColorCream.withOpacity(0.7), fontSize: 12)),
                  const Spacer(),
                  Text(
                    'Code: ${team['invite_code'] ?? 'N/A'}',
                    style: TextStyle(
                        color: kColorOrange.withOpacity(0.8),
                        fontSize: 10,
                        fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () => _deleteTeam(team['id']),
                    icon: const Icon(Icons.delete_outline,
                        size: 18, color: Colors.redAccent),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    tooltip: 'Retire Team',
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _deleteTeam(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: kColorBg,
        title:
            const Text('Retire Team?', style: TextStyle(color: Colors.white)),
        content: const Text(
            'This will disband the team and remove all member associations.',
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child:
                const Text('Retire', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _loading = true);
      try {
        await _supabase.from(kColTeams).delete().eq('id', id);
        await _fetchTeams();
      } catch (e) {
        debugPrint('Error deleting team: $e');
      } finally {
        if (mounted) setState(() => _loading = false);
      }
    }
  }

  Future<void> _showCreateTeamDialog() async {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: kColorBg,
        title: const Text('Deploy New Team',
            style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                  labelText: 'Team Name',
                  labelStyle: TextStyle(color: kColorOrange)),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: descCtrl,
              maxLines: 3,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                  labelText: 'Mission Description',
                  labelStyle: TextStyle(color: kColorOrange)),
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
            child: const Text('Deploy'),
          ),
        ],
      ),
    );

    if (result == true && nameCtrl.text.isNotEmpty) {
      setState(() => _loading = true);
      try {
        final user = _supabase.auth.currentUser;
        if (user == null) {
          throw Exception('Admin must be signed in to deploy teams.');
        }

        final inviteCode = (DateTime.now().millisecondsSinceEpoch % 1000000)
            .toString()
            .padLeft(6, '0');
        await _supabase.from(kColTeams).insert({
          'name': nameCtrl.text,
          'description': descCtrl.text,
          'invite_code': inviteCode,
          'created_by': user.id,
          'members': [],
          'member_uids': [],
        });
        await _fetchTeams();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('New team deployed to field')));
        }
      } catch (e) {
        debugPrint('Error creating team: $e');
      } finally {
        if (mounted) setState(() => _loading = false);
      }
    }
  }

  Widget _buildStatusBadge(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.greenAccent.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.greenAccent.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
                color: Colors.greenAccent, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
                color: Colors.greenAccent,
                fontSize: 10,
                fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
