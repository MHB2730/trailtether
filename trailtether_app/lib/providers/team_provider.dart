import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/team.dart';
import '../services/auth_service.dart' show SupabaseUserX;
import '../services/team_service.dart';
import '../services/logger_service.dart';

class TeamProvider extends ChangeNotifier {
  List<Team> _teams = [];
  Team? _selectedTeam;
  bool _loading = false;
  String? _error;

  List<Team> get teams => _teams;
  Team? get selectedTeam => _selectedTeam;
  bool get loading => _loading;
  String? get error => _error;

  String? _currentUid;

  /// Start watching teams for [user].  Safe to call multiple times.
  void listenForUser(User user) {
    if (_currentUid == user.uid) return; // already watching
    _currentUid = user.uid;
    refresh();
  }

  /// Re-fetch teams (called after create / join / delete).
  Future<void> refresh() async {
    if (_currentUid == null) return;
    _loading = true;
    notifyListeners();
    try {
      _teams = await TeamService.fetchTeamsForUser(_currentUid!);

      // Auto-select first team if none selected
      if (_selectedTeam == null && _teams.isNotEmpty) {
        _selectedTeam = _teams.first;
      } else if (_selectedTeam != null) {
        // Refresh selected team data if it still exists
        final updated = _teams.where((t) => t.id == _selectedTeam!.id);
        if (updated.isNotEmpty) {
          _selectedTeam = updated.first;
        } else {
          _selectedTeam = _teams.isNotEmpty ? _teams.first : null;
        }
      }

      _loading = false;
      _error = null;
      LoggerService.currentTeamId = _selectedTeam?.id;
    } catch (e) {
      _error = e.toString();
      _loading = false;
    }
    notifyListeners();
  }

  void clear() {
    _currentUid = null;
    _teams = [];
    _selectedTeam = null;
    _error = null;
    LoggerService.currentTeamId = null;
    notifyListeners();
  }

  void selectTeam(Team? team) {
    _selectedTeam = team;
    LoggerService.currentTeamId = team?.id;
    notifyListeners();
  }

  Future<String?> createTeam({
    required String name,
    required String description,
    required User currentUser,
  }) async {
    try {
      final creator = TeamMember(
        uid: currentUser.uid,
        email: currentUser.email ?? '',
        displayName: currentUser.displayName ?? currentUser.email ?? 'Hiker',
        photoUrl: currentUser.photoUrl ?? '',
      );
      final id = await TeamService.createTeam(
        name: name,
        description: description,
        creator: creator,
      );
      unawaited(refresh().catchError(
          (e) => debugPrint('TeamProvider.createTeam refresh: $e')));
      return id;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }

  Future<bool> addMember(String teamId, TeamMember member) async {
    try {
      await TeamService.addMember(teamId, member);
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> removeMember(String teamId, TeamMember member) async {
    try {
      await TeamService.removeMember(teamId, member);
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteTeam(String teamId) async {
    try {
      await TeamService.deleteTeam(teamId);
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Join a team using its invite code.
  /// Returns the team name on success, or throws a user-visible message.
  Future<String> joinTeamByCode(String code, User currentUser) async {
    final member = TeamMember(
      uid: currentUser.uid,
      email: currentUser.email ?? '',
      displayName: currentUser.displayName ?? currentUser.email ?? 'Hiker',
      photoUrl: currentUser.photoUrl ?? '',
    );
    final teamId = await TeamService.joinTeamByCode(code, member);
    await refresh();
    final t = _teams.firstWhere(
      (t) => t.id == teamId,
      orElse: () => throw 'Joined team not found in list.',
    );
    return t.name;
  }
}
