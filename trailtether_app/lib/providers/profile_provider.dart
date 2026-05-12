import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/runtime_config.dart';
import '../models/hiker_profile.dart';
import '../models/achievement.dart';
import '../models/saved_hike.dart';
import '../services/logger_service.dart';

class ProfileProvider extends ChangeNotifier {
  HikerProfile _profile = const HikerProfile();
  final List<Achievement> _achievements = getDefaultAchievements();

  // Stats
  double _totalDistance = 0.0;
  int _totalAscent = 0;
  int _hikeCount = 0;

  bool _loading = true;
  bool _saving = false;
  bool _uploadingPhoto = false;
  String? _error;

  HikerProfile get profile => _profile;
  List<Achievement> get achievements => _achievements;
  double get totalDistance => _totalDistance;
  int get totalAscent => _totalAscent;
  int get hikeCount => _hikeCount;
  bool get loading => _loading;
  bool get saving => _saving;
  bool get uploadingPhoto => _uploadingPhoto;
  String? get error => _error;

  ProfileProvider() {
    _load();
  }

  void refresh() => _load();

  Future<void> _load() async {
    _loading = true;
    notifyListeners();
    try {
      _profile = await HikerProfile.loadLocal();

      if (kSupabaseAvailable) {
        final supabase = Supabase.instance.client;
        final user = supabase.auth.currentUser;
        if (user != null) {
          final meta = Map<String, dynamic>.from(user.userMetadata ?? {});
          meta['uid'] = user.id;

          try {
            final row = await supabase
                .from('profiles')
                .select('photo_url, display_name')
                .eq('id', user.id)
                .maybeSingle();
            if (row != null) {
              if (row['photo_url'] != null) meta['photoUrl'] = row['photo_url'];
              if (row['display_name'] != null) {
                meta['displayName'] = row['display_name'];
              }
            }
          } catch (e, stack) {
            LoggerService.error(
                'PROFILE_PROVIDER',
                'Failed to fetch profile photo/name from cloud: $e',
                stack);
          }

          final remoteProfile = HikerProfile.fromMap(meta);
          await remoteProfile.saveLocal();
          _profile = remoteProfile;
        }
      }

      // Sync achievements from profile
      for (int i = 0; i < _achievements.length; i++) {
        if (_profile.unlockedAchievementIds.contains(_achievements[i].id)) {
          _achievements[i] = _achievements[i]
              .copyWith(unlocked: true, dateUnlocked: DateTime.now());
        }
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  void updateStats(List<SavedHike> tracks) {
    _totalDistance =
        tracks.fold<double>(0.0, (sum, SavedHike t) => sum + t.distanceKm);
    _totalAscent = tracks.fold<int>(0, (sum, SavedHike t) => sum + t.ascentM);
    _hikeCount = tracks.length;

    // Check achievements
    bool changed = false;

    for (int i = 0; i < _achievements.length; i++) {
      final a = _achievements[i];
      if (a.unlocked) continue;

      bool shouldUnlock = false;
      final id = a.id;

      // 1. Milestone Hikes
      if (id == 'first_hike' && _hikeCount >= 1) shouldUnlock = true;
      if (id == 'hike_5' && _hikeCount >= 5) shouldUnlock = true;
      if (id == 'hike_10' && _hikeCount >= 10) shouldUnlock = true;
      if (id == 'hike_25' && _hikeCount >= 25) shouldUnlock = true;
      if (id == 'hike_50' && _hikeCount >= 50) shouldUnlock = true;
      if (id == 'hike_100' && _hikeCount >= 100) shouldUnlock = true;

      // 2. Distance
      if (id == 'dist_10' && _totalDistance >= 10) shouldUnlock = true;
      if (id == 'dist_42' && _totalDistance >= 42.2) shouldUnlock = true;
      if (id == 'dist_100' && _totalDistance >= 100) shouldUnlock = true;
      if (id == 'dist_250' && _totalDistance >= 250) shouldUnlock = true;
      if (id == 'dist_500' && _totalDistance >= 500) shouldUnlock = true;
      if (id == 'dist_1000' && _totalDistance >= 1000) shouldUnlock = true;

      // 3. Elevation
      if (id == 'elev_500' && _totalAscent >= 500) shouldUnlock = true;
      if (id == 'elev_1000' && _totalAscent >= 1000) shouldUnlock = true;
      if (id == 'elev_2500' && _totalAscent >= 2500) shouldUnlock = true;
      if (id == 'elev_5000' && _totalAscent >= 5000) shouldUnlock = true;
      if (id == 'elev_10000' && _totalAscent >= 10000) shouldUnlock = true;
      if (id == 'elev_20000' && _totalAscent >= 20000) shouldUnlock = true;

      // 4. Peak Altitudes & Unique Peaks
      final maxAlt = tracks.fold<double>(
          0.0, (m, SavedHike t) => t.maxElevationM > m ? t.maxElevationM : m);
      if (id == 'peak_1' && maxAlt >= 3000) shouldUnlock = true;

      final totalPeaks = tracks.fold<int>(0, (sum, t) => sum + t.peaksClimbed);
      if (id == 'peak_5' && totalPeaks >= 5) shouldUnlock = true;
      if (id == 'peak_10' && totalPeaks >= 10) shouldUnlock = true;
      if (id == 'peak_25' && totalPeaks >= 25) shouldUnlock = true;

      // 5. Time & Weather
      if (id == 'early_bird' && tracks.any((t) => t.startedAt.hour < 5)) {
        shouldUnlock = true;
      }
      if (id == 'night_owl' && tracks.any((t) => t.endedAt.hour >= 20)) {
        shouldUnlock = true;
      }

      // 6. Team & Social
      final teamHikes = tracks.where((t) => t.teamId != null);
      if (id == 'team_join' && teamHikes.isNotEmpty) shouldUnlock = true;
      if (id == 'social_hiker' && teamHikes.length >= 5) shouldUnlock = true;

      final teamDist =
          teamHikes.fold<double>(0, (sum, t) => sum + t.distanceKm);
      if (id == 'team_mvp' && teamDist >= 50) shouldUnlock = true;

      // 7. Exploration & Safety
      if (id == 'safety_first' && tracks.any((t) => t.durationSeconds > 86400)) {
        shouldUnlock = true; // Multi-day
      }

      // 8. Specific Challenges (Keywords in name)
      final names = tracks.map((t) => t.name.toLowerCase()).toList();
      if (id == 'sentinel_climb' && names.any((n) => n.contains('sentinel'))) {
        shouldUnlock = true;
      }
      if (id == 'tugela_fall' && names.any((n) => n.contains('tugela'))) {
        shouldUnlock = true;
      }
      if (id == 'cathedral_peak' && names.any((n) => n.contains('cathedral'))) {
        shouldUnlock = true;
      }
      if (id == 'grand_traverse' && tracks.any((t) => t.distanceKm >= 100)) {
        shouldUnlock = true;
      }

      if (shouldUnlock) {
        _achievements[i] = a.unlock();
        changed = true;
      }
    }

    if (changed) {
      final unlockedIds =
          _achievements.where((a) => a.unlocked).map((a) => a.id).toList();
      _profile = _profile.copyWith(unlockedAchievementIds: unlockedIds);
      _profile.saveLocal();
    }

    notifyListeners();
  }

  Future<bool> save(HikerProfile updated) async {
    _saving = true;
    notifyListeners();
    try {
      await updated.saveLocal();
      _profile = updated;
      _error = null;

      if (kSupabaseAvailable) {
        final supabase = Supabase.instance.client;
        final uid = supabase.auth.currentUser?.id;
        if (uid != null) {
          try {
            // Update user metadata
            final meta = updated.toMap()
              ..remove('uid')
              ..remove('photoUrl');
            await supabase.auth.updateUser(UserAttributes(data: meta));

            // Update profiles table for photo and name (used by team features)
            await supabase.from('profiles').upsert({
              'id': uid,
              'display_name': updated.displayName,
              'photo_url': updated.photoUrl,
            });
          } catch (e) {
            debugPrint('Error syncing profile to Supabase: $e');
          }
        }
      }

      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _saving = false;
      notifyListeners();
    }
  }

  void updateFromData(Map<String, dynamic> data, String uid) {
    _profile = HikerProfile.fromMap({...data, 'uid': uid});
    notifyListeners();
  }

  /// Pick a profile photo from the gallery, compress and upload to
  /// Supabase Storage bucket "profile-photos".
  Future<String> pickAndUploadPhoto(
      {ImageSource source = ImageSource.gallery}) async {
    if (_uploadingPhoto) return 'busy';
    final picker = ImagePicker();
    final XFile? picked;
    try {
      picked = await picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 82,
      );
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return 'pick-error: $e';
    }
    if (picked == null) return 'cancelled';

    if (!kSupabaseAvailable) {
      // Demo mode â€” store local file path so user still sees their photo
      final updated = _profile.copyWith(photoUrl: 'file://${picked.path}');
      await updated.saveLocal();
      _profile = updated;
      notifyListeners();
      return 'ok';
    }

    final supabase = Supabase.instance.client;
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return 'no-auth';

    _uploadingPhoto = true;
    _error = null;
    notifyListeners();
    try {
      final storagePath = '$uid/profile.jpg';
      final file = File(picked.path);

      // Remove any existing photo first (Supabase Storage doesn't auto-overwrite)
      try {
        await supabase.storage.from('profile-photos').remove([storagePath]);
      } catch (_) {/* may not exist yet â€” ignore */}

      if (kIsWeb) {
        final bytes = await picked.readAsBytes();
        await supabase.storage.from('profile-photos').uploadBinary(
              storagePath,
              bytes,
              fileOptions:
                  const FileOptions(contentType: 'image/jpeg', upsert: true),
            );
      } else {
        await supabase.storage.from('profile-photos').upload(
              storagePath,
              file,
              fileOptions:
                  const FileOptions(contentType: 'image/jpeg', upsert: true),
            );
      }

      final url =
          supabase.storage.from('profile-photos').getPublicUrl(storagePath);

      // Bust the CDN cache by appending a timestamp
      final urlWithBust = '$url?t=${DateTime.now().millisecondsSinceEpoch}';

      final updated = _profile.copyWith(photoUrl: urlWithBust);
      await updated.saveLocal();
      _profile = updated;

      // Also update the profiles table
      try {
        await supabase
            .from('profiles')
            .upsert({'id': uid, 'photo_url': urlWithBust});
      } catch (_) {/* best-effort */}

      return 'ok';
    } catch (e) {
      _error = e.toString();
      return 'upload-error: $e';
    } finally {
      _uploadingPhoto = false;
      notifyListeners();
    }
  }

  /// Remove the stored profile photo (local + remote best-effort).
  Future<void> removePhoto() async {
    if (_profile.photoUrl.isEmpty) return;
    final updated = _profile.copyWith(photoUrl: '');
    _profile = updated;
    await updated.saveLocal();
    notifyListeners();
    if (kSupabaseAvailable) {
      final supabase = Supabase.instance.client;
      final uid = supabase.auth.currentUser?.id;
      if (uid != null) {
        try {
          await supabase.storage
              .from('profile-photos')
              .remove(['$uid/profile.jpg']);
        } catch (_) {/* photo may not exist remotely â€” ignore */}
      }
    }
  }
}
