import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants.dart';
import 'package:intl/intl.dart';

class AdminUsersTab extends StatefulWidget {
  const AdminUsersTab({super.key});

  @override
  State<AdminUsersTab> createState() => _AdminUsersTabState();
}

class _AdminUsersTabState extends State<AdminUsersTab> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _users = [];
  bool _loading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  Future<void> _fetchUsers() async {
    setState(() => _loading = true);
    try {
      final response = await _supabase
          .from(kColProfiles)
          .select()
          .order('username', ascending: true);

      setState(() {
        _users = List<Map<String, dynamic>>.from(response);
        _loading = false;
      });
    } catch (e) {
      debugPrint('Error fetching users: $e');
      setState(() => _loading = false);
    }
  }

  Future<void> _deleteUser(String uid) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: kColorBg,
        title:
            const Text('Remove User?', style: TextStyle(color: Colors.white)),
        content: const Text(
            'This will permanently delete the user profile. This action cannot be undone.',
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

    setState(() => _loading = true);
    try {
      await _supabase.from(kColProfiles).delete().eq('id', uid);
      await _fetchUsers();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('User removed successfully')));
      }
    } catch (e) {
      debugPrint('Error deleting user: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleAdminStatus(String uid, bool currentStatus) async {
    setState(() => _loading = true);
    try {
      await _supabase
          .from(kColProfiles)
          .update({'is_admin': !currentStatus}).eq('id', uid);
      await _fetchUsers();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(currentStatus
                ? 'Admin privileges revoked'
                : 'User promoted to Admin')));
      }
    } catch (e) {
      debugPrint('Error toggling admin status: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredUsers = _users.where((u) {
      final name = (u['username'] ?? '').toString().toLowerCase();
      final displayName = (u['display_name'] ?? '').toString().toLowerCase();
      return name.contains(_searchQuery.toLowerCase()) ||
          displayName.contains(_searchQuery.toLowerCase());
    }).toList();

    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 32),
          _buildControls(),
          const SizedBox(height: 24),
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: kColorOrange))
                : filteredUsers.isEmpty
                    ? Center(
                        child: Text('No users found.',
                            style:
                                TextStyle(color: kColorCream.withOpacity(0.3))))
                    : _buildUserTable(filteredUsers),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'User Management',
          style: GoogleFonts.outfit(
            color: kColorCream,
            fontSize: 32,
            fontWeight: FontWeight.w900,
          ),
        ),
        Text(
          'Manage all system users, permissions, and profiles.',
          style: GoogleFonts.outfit(
            color: kColorCream.withOpacity(0.5),
            fontSize: 16,
          ),
        ),
      ],
    );
  }

  Widget _buildControls() {
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: kColorGlass,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: kColorBorder),
            ),
            child: TextField(
              onChanged: (val) => setState(() => _searchQuery = val),
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: 'Search by username or display name...',
                hintStyle: TextStyle(color: Colors.white24),
                border: InputBorder.none,
                icon: Icon(Icons.search, color: Colors.white24, size: 20),
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        ElevatedButton.icon(
          onPressed: _fetchUsers,
          icon: const Icon(Icons.refresh, size: 18),
          label: const Text('Refresh'),
          style: ElevatedButton.styleFrom(
            backgroundColor: kColorOrange.withOpacity(0.1),
            foregroundColor: kColorOrange,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: kColorOrange.withOpacity(0.3)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildUserTable(List<Map<String, dynamic>> users) {
    return Container(
      decoration: BoxDecoration(
        color: kColorGlass,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: kColorBorder),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: SingleChildScrollView(
          scrollDirection: Axis.vertical,
          child: DataTable(
            headingRowColor:
                WidgetStateProperty.all(kColorOrange.withOpacity(0.05)),
            columns: [
              DataColumn(label: _headerText('User')),
              DataColumn(label: _headerText('Experience')),
              DataColumn(label: _headerText('Achievements')),
              DataColumn(label: _headerText('Joined')),
              DataColumn(label: _headerText('Actions')),
            ],
            rows: users.map((user) {
              final username = user['username'] ?? 'Anonymous';
              final displayName = user['display_name'] ?? 'No Name';
              final level = (user['experience_level'] ?? 'Beginner')
                  .toString()
                  .toUpperCase();
              final achievements =
                  (user['unlocked_achievement_ids'] as List?)?.length ?? 0;
              final createdAt =
                  DateTime.tryParse(user['created_at'] ?? '') ?? DateTime.now();

              return DataRow(cells: [
                DataCell(Row(
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundImage: user['avatar_url'] != null
                          ? NetworkImage(user['avatar_url'])
                          : null,
                      backgroundColor: kColorOrange.withOpacity(0.2),
                      child: user['avatar_url'] == null
                          ? const Icon(Icons.person,
                              size: 14, color: kColorOrange)
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(username,
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold)),
                        Text(displayName,
                            style: TextStyle(
                                color: Colors.white.withOpacity(0.5),
                                fontSize: 10)),
                      ],
                    ),
                  ],
                )),
                DataCell(Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: kColorCyan.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(level,
                      style: const TextStyle(
                          color: kColorCyan,
                          fontSize: 10,
                          fontWeight: FontWeight.bold)),
                )),
                DataCell(Text('$achievements Unlocked',
                    style: const TextStyle(color: Colors.white70))),
                DataCell(Text(DateFormat('MMM dd, yyyy').format(createdAt),
                    style: const TextStyle(color: Colors.white70))),
                DataCell(Row(
                  children: [
                    IconButton(
                        icon: Icon(
                            user['is_admin'] == true
                                ? Icons.shield
                                : Icons.shield_outlined,
                            size: 16,
                            color: user['is_admin'] == true
                                ? kColorOrange
                                : Colors.white24),
                        onPressed: () => _toggleAdminStatus(
                            user['id'], user['is_admin'] == true),
                        tooltip: user['is_admin'] == true
                            ? 'Revoke Admin'
                            : 'Make Admin'),
                    IconButton(
                      icon: const Icon(Icons.delete_outline,
                          size: 16, color: Colors.redAccent),
                      onPressed: () => _deleteUser(user['id']),
                      tooltip: 'Remove User',
                    ),
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
        color: kColorCream,
        fontWeight: FontWeight.bold,
        fontSize: 14,
      ),
    );
  }
}
