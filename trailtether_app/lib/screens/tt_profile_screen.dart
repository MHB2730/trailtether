// Trailtether 2.0 — Profile screen.
//
// Recreates project/screens/profile.jsx from the design bundle: gradient avatar
// header, four count-up stat tiles, an 8-badge achievements grid, and grouped
// settings sections. Wired to live AuthProvider / ProfileProvider /
// HikeHistoryProvider data — every row, tile, badge and toggle performs a real
// action: tapping the avatar opens the photo picker, tapping the bio opens an
// inline editor, the stat tiles push the Activity screen, the badges show
// detail or "how-to-unlock" dialogs, and all four preference toggles persist
// to SharedPreferences (live tracking, trail weather, off-trail alerts, haptic).

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/design_tokens.dart';
import '../models/achievement.dart';
import '../models/saved_hike.dart';
import '../providers/auth_provider.dart' as ap;
import '../providers/hike_history_provider.dart';
import '../providers/profile_provider.dart';
import '../providers/units_provider.dart';
import '../services/auth_service.dart';
import '../widgets/design/tt_achievement_medallion.dart';
import '../widgets/design/tt_ambient.dart';
import '../widgets/design/tt_app_bar.dart';
import 'privacy_policy_screen.dart';
import 'profile_tab.dart' as legacy;
import 'safety_center_screen.dart';
import 'tt_activity_screen.dart';
import '../widgets/design/tt_count_up.dart';
import '../widgets/design/tt_glass_card.dart';
import '../widgets/design/tt_pill.dart';
import '../widgets/design/tt_topo.dart';

// ──────────────────────────── HELPERS ───────────────────────────────────────

/// Derive uppercase initials (max 2 chars) from a display name. Falls back to
/// the first letter of the email local-part, then to "HK" (for "Hiker").
String _initialsFor({String? displayName, String? email}) {
  final name = (displayName ?? '').trim();
  if (name.isNotEmpty) {
    final parts = name.split(RegExp(r'\s+'));
    if (parts.length == 1) {
      final s = parts.first;
      return s.substring(0, s.length >= 2 ? 2 : 1).toUpperCase();
    }
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }
  final mail = (email ?? '').trim();
  if (mail.contains('@')) {
    final local = mail.split('@').first;
    if (local.isNotEmpty) {
      return local
          .substring(0, local.length >= 2 ? 2 : 1)
          .toUpperCase();
    }
  }
  return 'HK';
}

/// Tier label from lifetime hike count. Matches the design's "TRAILBLAZER ·
/// TIER III" cadence — uppercase rank, dot separator, tier numeral.
String _tierFor(int hikes) {
  if (hikes < 10) return 'NOVICE';
  if (hikes < 25) return 'EXPLORER · TIER I';
  if (hikes < 50) return 'TRAILBLAZER · TIER II';
  if (hikes < 100) return 'TRAILBLAZER · TIER III';
  if (hikes < 250) return 'SUMMITEER · TIER IV';
  return 'LEGEND · TIER V';
}

String _handleFromEmail(String? email) {
  if (email == null || !email.contains('@')) return '';
  return '@${email.split('@').first.toLowerCase()}';
}

// ──────────────────────────── SCREEN ────────────────────────────────────────

class TTProfileScreen extends StatefulWidget {
  final bool embedded;
  const TTProfileScreen({super.key, this.embedded = false});

  @override
  State<TTProfileScreen> createState() => _TTProfileScreenState();
}

class _TTProfileScreenState extends State<TTProfileScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _headerCtl =
      AnimationController(vsync: this, duration: TT.dSlow)..forward();

  // Preference keys — every toggle here persists across launches.
  // The units preference lives in UnitsProvider; everything else is local.
  static const _kLiveTrackingKey = 'tt_live_tracking';
  static const _kTrailWeatherKey = 'tt_trail_weather';
  static const _kOffTrailAlertsKey = 'tt_off_trail_alerts';
  static const _kHapticKey = 'tt_haptic';

  bool _liveTracking = true;
  bool _hapticFeedback = true;
  bool _trailWeather = true;
  bool _offTrailAlerts = false;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final live = prefs.getBool(_kLiveTrackingKey);
      final weather = prefs.getBool(_kTrailWeatherKey);
      final offTrail = prefs.getBool(_kOffTrailAlertsKey);
      final haptic = prefs.getBool(_kHapticKey);
      if (!mounted) return;
      setState(() {
        if (live != null) _liveTracking = live;
        if (weather != null) _trailWeather = weather;
        if (offTrail != null) _offTrailAlerts = offTrail;
        if (haptic != null) _hapticFeedback = haptic;
      });
    } catch (_) {
      // SharedPreferences unavailable — keep defaults.
    }
  }

  Future<void> _persistBool(String key, bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(key, value);
    } catch (_) {
      // Best effort — in-memory state already updated.
    }
  }

  Future<void> _setLiveTracking(bool v) async {
    setState(() => _liveTracking = v);
    await _persistBool(_kLiveTrackingKey, v);
  }

  Future<void> _setTrailWeather(bool v) async {
    setState(() => _trailWeather = v);
    await _persistBool(_kTrailWeatherKey, v);
  }

  Future<void> _setOffTrailAlerts(bool v) async {
    setState(() => _offTrailAlerts = v);
    await _persistBool(_kOffTrailAlertsKey, v);
  }

  Future<void> _setHaptic(bool v) async {
    setState(() => _hapticFeedback = v);
    await _persistBool(_kHapticKey, v);
  }

  @override
  void dispose() {
    _headerCtl.dispose();
    super.dispose();
  }

  Future<void> _confirmAndSignOut(BuildContext context) async {
    final email = context.read<ap.AuthProvider>().email ?? '';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: TT.surf,
        title: Text('Sign out?',
            style: TT.body(size: 16, w: FontWeight.w800)),
        content: Text(
          email.isNotEmpty
              ? 'You will be signed out of $email.'
              : 'You will be signed out of Trailtether.',
          style: TT.body(size: 13, color: TT.text2),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel',
                style: TT.body(size: 13, color: TT.text2)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Sign out',
                style: TT.body(size: 13, w: FontWeight.w800, color: TT.red)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await AuthService.signOut();
      // AuthGate observes the auth-state stream and redirects to LoginScreen
      // once the session clears; no manual navigation required here.
    }
  }

  void _pushScreen(Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  Future<void> _openUnitsPicker() async {
    final units = context.read<UnitsProvider>();
    final picked = await showModalBottomSheet<UnitSystem>(
      context: context,
      backgroundColor: TT.surf,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (sheetCtx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: TT.line3,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text('Choose unit system',
                    style: TT.body(size: 16, w: FontWeight.w800)),
                const SizedBox(height: 4),
                Text('Distance, elevation, temperature and speed throughout '
                    'the app will use the units you pick here.',
                    style: TT.body(size: 12, color: TT.text3).copyWith(height: 1.4)),
                const SizedBox(height: 14),
                _UnitsOptionTile(
                  selected: units.isMetric,
                  title: 'Metric',
                  subtitle: 'km · m · °C · km/h',
                  onTap: () => Navigator.pop(sheetCtx, UnitSystem.metric),
                ),
                const SizedBox(height: 8),
                _UnitsOptionTile(
                  selected: units.isImperial,
                  title: 'Imperial',
                  subtitle: 'mi · ft · °F · mph',
                  onTap: () => Navigator.pop(sheetCtx, UnitSystem.imperial),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (picked == null || !mounted) return;
    await context.read<UnitsProvider>().setSystem(picked);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Units: ${picked == UnitSystem.imperial ? 'Imperial (ft / mi / °F)' : 'Metric (m / km / °C)'}',
          style: TT.body(size: 13, color: TT.text),
        ),
        backgroundColor: TT.surf,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _confirmDeleteHistory() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: TT.surf,
        title: Text('Delete all hike history?', style: TT.title(17)),
        content: Text(
            'This wipes every recorded hike on this device. Cannot be undone.',
            style: TT.body(size: 13, color: TT.text2)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancel', style: TT.body(size: 13, color: TT.text2)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Delete',
                style: TT.body(size: 13, color: TT.red, w: FontWeight.w800)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await context.read<HikeHistoryProvider>().clear();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Hike history cleared',
            style: TT.body(size: 13, color: TT.text)),
        backgroundColor: TT.surf,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ── Avatar photo picker ────────────────────────────────────────────────
  Future<void> _pickAvatarPhoto() async {
    final pp = context.read<ProfileProvider>();
    final hasPhoto = pp.profile.photoUrl.trim().isNotEmpty;
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: TT.surf,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: TT.line3,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 14),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined,
                  color: TT.ember, size: 20),
              title: Text('Choose from gallery',
                  style: TT.body(size: 14, w: FontWeight.w700)),
              onTap: () => Navigator.pop(context, 'gallery'),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined,
                  color: TT.ember, size: 20),
              title: Text('Take a photo',
                  style: TT.body(size: 14, w: FontWeight.w700)),
              onTap: () => Navigator.pop(context, 'camera'),
            ),
            if (hasPhoto)
              ListTile(
                leading:
                    const Icon(Icons.delete_outline, color: TT.red, size: 20),
                title: Text('Remove photo',
                    style: TT.body(size: 14, w: FontWeight.w700, color: TT.red)),
                onTap: () => Navigator.pop(context, 'remove'),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (choice == null || !mounted) return;
    if (choice == 'remove') {
      await pp.removePhoto();
      return;
    }
    final source =
        choice == 'camera' ? ImageSource.camera : ImageSource.gallery;
    final result = await pp.pickAndUploadPhoto(source: source);
    if (!mounted) return;
    if (result == 'ok' || result == 'cancelled') return;
    final message = result == 'no-auth'
        ? 'Sign in to upload a profile photo'
        : 'Photo update failed: $result';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: TT.body(size: 13, color: TT.text)),
        backgroundColor: TT.surf,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ── Bio inline editor ─────────────────────────────────────────────────
  Future<void> _editBio() async {
    final pp = context.read<ProfileProvider>();
    final controller = TextEditingController(text: pp.profile.bio);
    final saved = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: TT.surf,
        title: Text('Edit bio',
            style: TT.body(size: 16, w: FontWeight.w800)),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 4,
          maxLength: 240,
          style: TT.body(size: 13, color: TT.text).copyWith(height: 1.4),
          decoration: InputDecoration(
            hintText: 'Tell other hikers about yourself…',
            hintStyle: TT.body(size: 13, color: TT.text3),
            counterStyle: TT.mono(size: 10, color: TT.text3),
            filled: true,
            fillColor: TT.bg3,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(TT.rSm),
              borderSide: const BorderSide(color: TT.line),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(TT.rSm),
              borderSide: const BorderSide(color: TT.line),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(TT.rSm),
              borderSide: const BorderSide(color: TT.ember, width: 1.5),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Cancel', style: TT.body(size: 13, color: TT.text2)),
          ),
          TextButton(
            onPressed: () =>
                Navigator.of(ctx).pop(controller.text.trim()),
            child: Text('Save',
                style: TT.body(size: 13, w: FontWeight.w800, color: TT.ember)),
          ),
        ],
      ),
    );
    controller.dispose();
    if (saved == null || !mounted) return;
    final updated = pp.profile.copyWith(bio: saved);
    final ok = await pp.save(updated);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? 'Bio updated' : 'Could not save bio',
            style: TT.body(size: 13, color: TT.text)),
        backgroundColor: TT.surf,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final units = context.watch<UnitsProvider>();
    final unitsLabel = units.isImperial ? 'Imperial' : 'Metric';
    final unitsSub = units.isImperial
        ? 'Imperial · ft / mi / °F'
        : 'Metric · m / km / °C';

    final body = Stack(
      children: [
        const Positioned.fill(child: TTAmbient()),
        const Positioned.fill(child: TTTopoBackdrop(opacity: 0.45)),
        SafeArea(
          top: !widget.embedded,
          bottom: false,
          child: Column(
            children: [
              TTPageAppBar(
                title: 'Profile',
                trailing: [
                  TTIconBtn(
                      icon: Icons.settings_outlined,
                      onTap: () => _pushScreen(const legacy.ProfileTab())),
                ],
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(18, 4, 18, 28),
                  children: [
                    _ProfileHeader(
                      animation: _headerCtl,
                      onTapAvatar: _pickAvatarPhoto,
                      onEditBio: _editBio,
                    ),
                    const SizedBox(height: 14),
                    _StatTilesRow(
                      onTapTile: () =>
                          _pushScreen(const TTActivityScreen()),
                    ),
                    const SizedBox(height: 22),
                    const _AchievementsSection(),
                    const SizedBox(height: 22),
                    _SettingsGroup(
                      title: 'ACCOUNT',
                      baseDelayMs: 1100,
                      rows: [
                        _SettingRowData(
                          icon: Icons.person_outline,
                          label: 'Edit profile',
                          sub: 'Name, bio, photo',
                          trailing: _SettingTrailing.chevron(),
                          onTap: () => _pushScreen(const legacy.ProfileTab()),
                        ),
                        _SettingRowData(
                          icon: Icons.shield_outlined,
                          label: 'Privacy & data',
                          sub: 'No data sold · No ads',
                          trailing: _SettingTrailing.chevron(),
                          onTap: () => _pushScreen(const PrivacyPolicyScreen()),
                        ),
                        _SettingRowData(
                          icon: Icons.phone_outlined,
                          label: 'Emergency contacts',
                          sub: _emergencyContactsSub(context),
                          trailing: _SettingTrailing.value(
                              '${context.watch<ProfileProvider>().profile.contacts.length}'),
                          onTap: () => _pushScreen(const SafetyCenterScreen()),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    _SettingsGroup(
                      title: 'PREFERENCES',
                      baseDelayMs: 1280,
                      rows: [
                        _SettingRowData(
                          icon: Icons.visibility_outlined,
                          label: 'Live tracking',
                          sub: 'Always-on when hiking',
                          trailing: _SettingTrailing.toggle(
                            value: _liveTracking,
                            onChanged: _setLiveTracking,
                          ),
                        ),
                        _SettingRowData(
                          icon: Icons.cloud_outlined,
                          label: 'Trail weather alerts',
                          sub: 'Storms, wind, visibility',
                          trailing: _SettingTrailing.toggle(
                            value: _trailWeather,
                            onChanged: _setTrailWeather,
                          ),
                        ),
                        _SettingRowData(
                          icon: Icons.warning_amber_outlined,
                          label: 'Off-trail alerts',
                          sub: 'Get nudged when drifting',
                          trailing: _SettingTrailing.toggle(
                            value: _offTrailAlerts,
                            onChanged: _setOffTrailAlerts,
                          ),
                        ),
                        _SettingRowData(
                          icon: Icons.vibration,
                          label: 'Haptic feedback',
                          sub: 'Pings on alerts',
                          trailing: _SettingTrailing.toggle(
                            value: _hapticFeedback,
                            onChanged: _setHaptic,
                          ),
                        ),
                        _SettingRowData(
                          icon: Icons.straighten,
                          label: 'Units',
                          sub: unitsSub,
                          trailing: _SettingTrailing.value(unitsLabel),
                          onTap: _openUnitsPicker,
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    _SettingsGroup(
                      title: 'DANGER ZONE',
                      baseDelayMs: 1460,
                      rows: [
                        _SettingRowData(
                          icon: Icons.delete_outline,
                          label: 'Delete hike history',
                          sub: _hikeHistorySub(context),
                          danger: true,
                          trailing: _SettingTrailing.chevron(),
                          onTap: _confirmDeleteHistory,
                        ),
                        _SettingRowData(
                          icon: Icons.logout,
                          label: 'Sign out',
                          sub: context.watch<ap.AuthProvider>().email ??
                              'Not signed in',
                          danger: true,
                          isSignOut: true,
                          trailing: _SettingTrailing.signOut(),
                          onTap: () => _confirmAndSignOut(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _FadeUp(
                      delay: const Duration(milliseconds: 1600),
                      child: const Center(child: _AppVersionLabel()),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );

    if (widget.embedded) return Material(color: TT.bg, child: body);
    return Scaffold(backgroundColor: TT.bg, body: body);
  }

  String _emergencyContactsSub(BuildContext context) {
    final n = context.watch<ProfileProvider>().profile.contacts.length;
    if (n == 0) return 'None saved · tap to add';
    return n == 1 ? '1 contact saved' : '$n contacts saved';
  }

  String _hikeHistorySub(BuildContext context) {
    final n = context.watch<HikeHistoryProvider>().hikes.length;
    if (n == 0) return 'No hikes recorded yet';
    return n == 1 ? '1 hike' : '$n hikes';
  }
}

// ──────────────────────────── HEADER ────────────────────────────────────────

class _ProfileHeader extends StatelessWidget {
  final AnimationController animation;
  final VoidCallback onTapAvatar;
  final VoidCallback onEditBio;
  const _ProfileHeader({
    required this.animation,
    required this.onTapAvatar,
    required this.onEditBio,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (_, __) {
        final t = TT.easeOut.transform(animation.value);
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, (1 - t) * 12),
            child: _buildCard(context),
          ),
        );
      },
    );
  }

  Widget _buildCard(BuildContext context) {
    return Consumer2<ap.AuthProvider, ProfileProvider>(
      builder: (_, auth, pp, __) {
        final fallbackHandleName = auth.email?.split('@').first;
        final name = (auth.displayName?.trim().isNotEmpty == true)
            ? auth.displayName!.trim()
            : (pp.profile.displayName.trim().isNotEmpty
                ? pp.profile.displayName.trim()
                : (fallbackHandleName ?? 'Hiker'));
        final handle = _handleFromEmail(auth.email);
        final hikes = context.watch<HikeHistoryProvider>().hikes.length;
        final tier = _tierFor(hikes);
        final bio = pp.profile.bio.trim();
        final photoUrl = (pp.profile.photoUrl.trim().isNotEmpty
                ? pp.profile.photoUrl.trim()
                : auth.photoUrl?.trim() ?? '');
        final initials = _initialsFor(
            displayName: name, email: auth.email);

        return ClipRRect(
          borderRadius: BorderRadius.circular(TT.rLg + 2),
          child: Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [TT.surf, TT.bg3],
              ),
              border: Border.all(color: TT.line, width: 1),
              borderRadius: BorderRadius.circular(TT.rLg + 2),
              boxShadow: TT.shadowCard,
            ),
            child: Stack(
              children: [
                // Ember glow corner
                Positioned(
                  top: -40,
                  right: -40,
                  child: Container(
                    width: 140,
                    height: 140,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [Color(0x38FF6A2C), Color(0x00FF6A2C)],
                        stops: [0.0, 0.7],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          _GradientAvatar(
                            initials: initials,
                            photoUrl: photoUrl,
                            uploading: pp.uploadingPhoto,
                            onTap: onTapAvatar,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(name,
                                    style: TT.title(22,
                                        letterSpacing: -0.01 * 22)),
                                if (handle.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(handle,
                                      style: TT.mono(
                                          size: 11,
                                          color: TT.text3,
                                          letterSpacing: 0.04 * 11)),
                                ],
                                const SizedBox(height: 8),
                                TTPill(
                                  label: tier,
                                  variant: TTPillVariant.ember,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      InkWell(
                        onTap: onEditBio,
                        borderRadius:
                            BorderRadius.circular(TT.rSm + 2),
                        child: Container(
                          padding:
                              const EdgeInsets.fromLTRB(12, 10, 12, 10),
                          decoration: BoxDecoration(
                            color: const Color(0x05FFFFFF),
                            border: Border.all(color: TT.line, width: 1),
                            borderRadius:
                                BorderRadius.circular(TT.rSm + 2),
                          ),
                          child: Text(
                            bio.isNotEmpty ? bio : 'Tap to add a bio',
                            style: TT
                                .body(
                                    size: 12,
                                    w: FontWeight.w500,
                                    color: bio.isNotEmpty
                                        ? TT.text2
                                        : TT.text3)
                                .copyWith(
                                    height: 1.5,
                                    fontStyle: bio.isNotEmpty
                                        ? FontStyle.normal
                                        : FontStyle.italic),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _GradientAvatar extends StatelessWidget {
  final String initials;
  final String photoUrl;
  final bool uploading;
  final VoidCallback onTap;
  const _GradientAvatar({
    required this.initials,
    required this.photoUrl,
    required this.uploading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasRemotePhoto =
        photoUrl.startsWith('http://') || photoUrl.startsWith('https://');
    return GestureDetector(
      onTap: uploading ? null : onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 72,
        height: 72,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: hasRemotePhoto
                    ? null
                    : const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF6B3A1A), TT.ember2],
                      ),
                image: hasRemotePhoto
                    ? DecorationImage(
                        image: NetworkImage(photoUrl),
                        fit: BoxFit.cover,
                      )
                    : null,
                border: Border.all(color: TT.ember, width: 3),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x73FF6A2C),
                    blurRadius: 22,
                    spreadRadius: 0,
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: hasRemotePhoto
                  ? null
                  : Text(
                      initials,
                      style: TT
                          .body(size: 26, w: FontWeight.w900, color: Colors.white)
                          .copyWith(letterSpacing: -0.02 * 26),
                    ),
            ),
            if (uploading)
              Positioned.fill(
                child: Container(
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0x99000000),
                  ),
                  child: const Center(
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    ),
                  ),
                ),
              ),
            // Camera badge — signals the avatar is tappable for upload.
            if (!uploading)
              Positioned(
                right: -2,
                bottom: -2,
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: TT.ember,
                    border: Border.all(color: TT.bg3, width: 2),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(Icons.camera_alt,
                      color: Colors.white, size: 11),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────── STAT TILES ────────────────────────────────────

class _StatTilesRow extends StatelessWidget {
  final VoidCallback onTapTile;
  const _StatTilesRow({required this.onTapTile});

  @override
  Widget build(BuildContext context) {
    return Consumer2<HikeHistoryProvider, UnitsProvider>(
      builder: (_, history, units, __) {
        final hikes = history.hikes;
        final hikeCount = hikes.length;
        final totKm = hikes.fold<double>(0, (a, SavedHike h) => a + h.distanceKm);
        final totAscentM = hikes.fold<int>(0, (a, SavedHike h) => a + h.ascentM).toDouble();
        final distVal = units.distanceFromKm(totKm).round();
        final ascentVal = units.elevationFromM(totAscentM).round();
        final peaks = hikes.fold<int>(0, (a, SavedHike h) => a + h.peaksClimbed);

        final tiles = <_StatTile>[
          _StatTile(
            icon: Icons.terrain_outlined,
            label: 'Hikes',
            value: hikeCount.toString(),
            unit: null,
            ember: false,
            onTap: onTapTile,
          ),
          _StatTile(
            icon: Icons.navigation_outlined,
            label: 'Distance',
            value: distVal.toString(),
            unit: units.distanceUnit,
            ember: true,
            onTap: onTapTile,
          ),
          _StatTile(
            icon: Icons.arrow_upward,
            label: 'Ascent',
            value: _formatThousands(ascentVal),
            unit: units.elevationUnit,
            ember: false,
            onTap: onTapTile,
          ),
          _StatTile(
            icon: Icons.flag_outlined,
            label: 'Peaks',
            value: peaks.toString(),
            unit: null,
            ember: false,
            onTap: onTapTile,
          ),
        ];

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: tiles.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1.55,
          ),
          itemBuilder: (_, i) {
            return _FadeUp(
              delay: Duration(milliseconds: 280 + i * 70),
              child: tiles[i],
            );
          },
        );
      },
    );
  }

  static String _formatThousands(int v) {
    final s = v.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      final remaining = s.length - i;
      buf.write(s[i]);
      if (remaining > 1 && remaining % 3 == 1) buf.write(',');
    }
    return buf.toString();
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String? unit;
  final bool ember;
  final VoidCallback onTap;

  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.unit,
    required this.ember,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return TTCard(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon,
                  size: 12, color: ember ? TT.ember : TT.text3),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  label.toUpperCase(),
                  style: TT.label(size: 10.5, color: TT.text3),
                ),
              ),
            ],
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              TTCountUp(
                text: value,
                style:
                    TT.numStyle(size: 22, color: ember ? TT.ember : TT.text),
                delay: const Duration(milliseconds: 500),
              ),
              if (unit != null) ...[
                const SizedBox(width: 5),
                Text(unit!, style: TT.mono(size: 11, color: TT.text2)),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────── ACHIEVEMENTS ──────────────────────────────────

class _AchievementsSection extends StatelessWidget {
  const _AchievementsSection();

  // Achievement catalog shown locked when none unlocked yet — these are real
  // achievement IDs.
  static const _mockGrid = <_AchievementData>[
    _AchievementData(
      id: 'first_hike',
      icon: Icons.play_arrow,
      label: 'First Steps',
      description: 'Record your very first hike.',
      requirement: 'Complete and save 1 hike recording.',
      date: 'LOCKED',
      color: TT.ember,
      unlocked: false,
    ),
    _AchievementData(
      id: 'peak_1',
      icon: Icons.terrain,
      label: '4K Club',
      description: 'Reach an altitude of 3,000m or higher.',
      requirement: 'Summit any 3,000m+ peak.',
      date: 'LOCKED',
      color: TT.ember2,
      unlocked: false,
    ),
    _AchievementData(
      id: 'team_join',
      icon: Icons.link,
      label: 'Tethered',
      description: 'Join your first team.',
      requirement: 'Join a team via invite code.',
      date: 'LOCKED',
      color: TT.blue,
      unlocked: false,
    ),
    _AchievementData(
      id: 'new_trail',
      icon: Icons.route,
      label: 'Plan Maker',
      description: 'Hike a new trail.',
      requirement: 'Complete a trail not in your history.',
      date: 'LOCKED',
      color: TT.green,
      unlocked: false,
    ),
    _AchievementData(
      id: 'storm_hiker',
      icon: Icons.air,
      label: 'Storm Survivor',
      description: 'Hike during a weather incident report.',
      requirement: 'Record a hike during active storm warnings.',
      date: 'LOCKED',
      color: TT.amber,
      unlocked: false,
    ),
    _AchievementData(
      id: 'peak_10',
      icon: Icons.flag_outlined,
      label: 'Summit X12',
      description: 'Summit 10 different peaks.',
      requirement: 'Log 10 unique peaks in the Drakensberg.',
      date: 'LOCKED',
      color: TT.text3,
      unlocked: false,
    ),
    _AchievementData(
      id: 'reporter',
      icon: Icons.shield_outlined,
      label: 'First Responder',
      description: 'Submit your first verified incident report.',
      requirement: 'Report your first trail incident.',
      date: 'LOCKED',
      color: TT.text3,
      unlocked: false,
    ),
    _AchievementData(
      id: 'night_owl',
      icon: Icons.nights_stay_outlined,
      label: 'Night Owl',
      description: 'Finish a hike after 7:00 PM.',
      requirement: 'Complete a hike recording after 19:00.',
      date: 'LOCKED',
      color: TT.text3,
      unlocked: false,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Consumer<ProfileProvider>(
      builder: (_, pp, __) {
        final unlockedAll = pp.achievements.where((a) => a.unlocked).toList();
        final List<_AchievementData> badges;
        final int total;
        final int unlockedCount;
        if (unlockedAll.isEmpty) {
          badges = _mockGrid;
          total = _mockGrid.length;
          unlockedCount = 0;
        } else {
          // Show up to 8 tiles: unlocked first, then a few locked stragglers
          // (so the grid stays balanced when the user has fewer than 8
          // unlocks). Order matches ProfileProvider's default list.
          final locked =
              pp.achievements.where((a) => !a.unlocked).toList();
          final picked = <Achievement>[
            ...unlockedAll.take(8),
            ...locked.take((8 - unlockedAll.length).clamp(0, 8)),
          ].take(8).toList();
          badges = picked.map(_fromAchievement).toList(growable: false);
          total = 8;
          unlockedCount = unlockedAll.length.clamp(0, 8);
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(2, 0, 2, 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'ACHIEVEMENTS · $unlockedCount OF $total',
                    style: TT.label(
                        size: 11,
                        color: TT.text2,
                        letterSpacing: 0.16 * 11),
                  ),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _showAllAchievements(context, pp),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 2),
                      child: Text(
                        'VIEW ALL →',
                        style: TT
                            .body(size: 10, w: FontWeight.w800, color: TT.ember)
                            .copyWith(letterSpacing: 0.1 * 10),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: badges.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 0.74,
              ),
              itemBuilder: (_, i) => _FadeUp(
                delay: Duration(milliseconds: 580 + i * 60),
                child: _AchievementBadge(data: badges[i]),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showAllAchievements(BuildContext context, ProfileProvider pp) {
    // Build the full list — unlocked first, then locked, mirroring the order
    // in ProfileProvider's catalog. If the user has no unlocked badges yet we
    // fall back to the on-screen mock grid so the sheet is never empty.
    final all = pp.achievements;
    final List<_AchievementData> rows;
    if (all.isEmpty) {
      rows = List<_AchievementData>.from(_mockGrid);
    } else {
      final unlocked = all.where((a) => a.unlocked).toList();
      final locked = all.where((a) => !a.unlocked).toList();
      rows = [
        ...unlocked.map(_fromAchievement),
        ...locked.map(_fromAchievement),
      ];
    }
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: TT.surf,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (sheetCtx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.85,
          minChildSize: 0.55,
          maxChildSize: 0.95,
          expand: false,
          builder: (_, scroll) => Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: TT.line3,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Text('All achievements',
                        style: TT.title(18, letterSpacing: -0.01 * 18)),
                    const Spacer(),
                    Text('${rows.where((r) => r.unlocked).length} / ${rows.length}',
                        style: TT.mono(size: 11, color: TT.text3)),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.separated(
                  controller: scroll,
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                  itemCount: rows.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final d = rows[i];
                    return TTCard(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                      child: Row(
                        children: [
                          TTAchievementMedallion(
                            icon: d.icon,
                            color: d.color,
                            unlocked: d.unlocked,
                            progress: d.unlocked ? 1.0 : 0.0,
                            size: 56,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(d.label,
                                    style: TT.body(
                                        size: 14,
                                        w: FontWeight.w800,
                                        color: d.unlocked ? TT.text : TT.text2)),
                                const SizedBox(height: 2),
                                Text(
                                    d.unlocked
                                        ? d.description
                                        : d.requirement,
                                    style: TT.body(
                                            size: 12, color: TT.text3)
                                        .copyWith(height: 1.35)),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            d.unlocked
                                ? Icons.check_circle
                                : Icons.lock_outline,
                            size: 16,
                            color: d.unlocked ? TT.green : TT.text3,
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  static _AchievementData _fromAchievement(Achievement a) {
    return _AchievementData(
      id: a.id,
      icon: a.icon,
      label: a.title,
      description: a.description,
      requirement: a.requirement,
      date: a.unlocked && a.dateUnlocked != null
          ? _shortDate(a.dateUnlocked!)
          : 'LOCKED',
      color: a.unlocked ? a.color : TT.text3,
      unlocked: a.unlocked,
    );
  }

  static const _months = [
    'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN',
    'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC',
  ];

  static String _shortDate(DateTime d) =>
      '${_months[d.month - 1]} ${d.day.toString().padLeft(2, '0')}';
}

class _AchievementData {
  final String id;
  final IconData icon;
  final String label;
  final String description;
  final String requirement;
  final String date;
  final Color color;
  final bool unlocked;

  const _AchievementData({
    required this.id,
    required this.icon,
    required this.label,
    required this.description,
    required this.requirement,
    required this.date,
    required this.color,
    required this.unlocked,
  });
}

class _AchievementBadge extends StatelessWidget {
  final _AchievementData data;
  const _AchievementBadge({required this.data});

  void _showDetail(BuildContext context) {
    final unlocked = data.unlocked;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: TT.surf,
        title: Row(
          children: [
            TTAchievementMedallion(
              icon: data.icon,
              color: data.color,
              unlocked: data.unlocked,
              progress: data.unlocked ? 1.0 : 0.0,
              size: 80,
              large: true,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                data.label,
                style: TT.body(size: 15, w: FontWeight.w800),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              unlocked ? data.description : 'How to unlock',
              style: TT.body(size: 13, color: TT.text2)
                  .copyWith(height: 1.4),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
              decoration: BoxDecoration(
                color: TT.bg3,
                border: Border.all(color: TT.line, width: 1),
                borderRadius: BorderRadius.circular(TT.rSm),
              ),
              child: Row(
                children: [
                  Icon(
                    unlocked ? Icons.check_circle : Icons.lock_outline,
                    size: 14,
                    color: unlocked ? TT.green : TT.text3,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      unlocked
                          ? 'Unlocked · ${data.date}'
                          : data.requirement,
                      style: TT.mono(
                        size: 11,
                        color: unlocked ? TT.green : TT.text2,
                        letterSpacing: 0.04 * 11,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Close',
                style: TT.body(size: 13, w: FontWeight.w800, color: TT.ember)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final card = TTCard(
      padding: const EdgeInsets.fromLTRB(6, 12, 6, 10),
      onTap: () => _showDetail(context),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Animated hex topo medallion — matches the design's
          // TopoMedallion (radar ping, switchback trail draw-in,
          // summit pulse, ember magma fill on locked-with-progress).
          TTAchievementMedallion(
            icon: data.icon,
            color: data.color,
            unlocked: data.unlocked,
            progress: data.unlocked ? 1.0 : 0.0,
            size: 56,
          ),
          const SizedBox(height: 8),
          Text(
            data.label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TT
                .body(
                  size: 9.5,
                  w: FontWeight.w800,
                  color: data.unlocked ? TT.text : TT.text3,
                )
                .copyWith(letterSpacing: 0.04 * 9.5, height: 1.2),
          ),
          const SizedBox(height: 3),
          Text(
            data.date,
            textAlign: TextAlign.center,
            style: TT.mono(
              size: 8.5,
              color: data.unlocked ? TT.text3 : TT.text4,
              letterSpacing: 0.08 * 8.5,
            ),
          ),
        ],
      ),
    );

    if (data.unlocked) return card;
    return Opacity(opacity: 0.35, child: card);
  }
}

// ──────────────────────────── SETTINGS GROUPS ───────────────────────────────

class _SettingsGroup extends StatelessWidget {
  final String title;
  final List<_SettingRowData> rows;
  final int baseDelayMs;

  const _SettingsGroup({
    required this.title,
    required this.rows,
    required this.baseDelayMs,
  });

  @override
  Widget build(BuildContext context) {
    return _FadeUp(
      delay: Duration(milliseconds: baseDelayMs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 2, bottom: 8),
            child: Text(
              title,
              style: TT.label(
                size: 11,
                color: TT.text2,
                letterSpacing: 0.16 * 11,
              ),
            ),
          ),
          TTCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (var i = 0; i < rows.length; i++) ...[
                  _SettingRow(
                    data: rows[i],
                  ),
                  if (i < rows.length - 1)
                    Container(
                      height: 1,
                      margin: const EdgeInsets.symmetric(horizontal: 14),
                      color: TT.line,
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

enum _TrailingKind { chevron, toggle, value, signOut }

class _SettingTrailing {
  final _TrailingKind kind;
  final bool? toggleValue;
  final ValueChanged<bool>? toggleChanged;
  final String? valueText;

  const _SettingTrailing._({
    required this.kind,
    this.toggleValue,
    this.toggleChanged,
    this.valueText,
  });

  factory _SettingTrailing.chevron() =>
      const _SettingTrailing._(kind: _TrailingKind.chevron);

  factory _SettingTrailing.toggle({
    required bool value,
    required ValueChanged<bool> onChanged,
  }) =>
      _SettingTrailing._(
        kind: _TrailingKind.toggle,
        toggleValue: value,
        toggleChanged: onChanged,
      );

  factory _SettingTrailing.value(String text) =>
      _SettingTrailing._(kind: _TrailingKind.value, valueText: text);

  factory _SettingTrailing.signOut() =>
      const _SettingTrailing._(kind: _TrailingKind.signOut);
}

class _SettingRowData {
  final IconData icon;
  final String label;
  final String? sub;
  final _SettingTrailing trailing;
  final bool danger;
  final bool isSignOut;
  final VoidCallback? onTap;

  const _SettingRowData({
    required this.icon,
    required this.label,
    this.sub,
    required this.trailing,
    this.danger = false,
    this.isSignOut = false,
    this.onTap,
  });
}

class _SettingRow extends StatelessWidget {
  final _SettingRowData data;
  const _SettingRow({required this.data});

  @override
  Widget build(BuildContext context) {
    final iconColor = data.danger ? TT.red : TT.ember;
    final iconBg = data.danger
        ? const Color(0x1AE63D2E)
        : const Color(0x08FFFFFF);
    final iconBorder = data.danger ? const Color(0x59E63D2E) : TT.line2;

    return InkWell(
      onTap: data.onTap,
      borderRadius: BorderRadius.circular(TT.rSm),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: iconBg,
                border: Border.all(color: iconBorder, width: 1),
                borderRadius: BorderRadius.circular(9),
              ),
              alignment: Alignment.center,
              child: Icon(data.icon, size: 14, color: iconColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data.label,
                    style: data.isSignOut
                        ? TT
                            .body(
                              size: 13,
                              w: FontWeight.w800,
                              color: TT.red,
                            )
                            .copyWith(letterSpacing: 0.16 * 13)
                        : TT.body(
                            size: 13,
                            w: FontWeight.w700,
                            color: data.danger ? TT.red : TT.text,
                          ),
                  ),
                  if (data.sub != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      data.sub!,
                      style: TT.mono(
                        size: 10,
                        color: TT.text3,
                        letterSpacing: 0.02 * 10,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            _buildTrailing(data.trailing, danger: data.danger),
          ],
        ),
      ),
    );
  }

  Widget _buildTrailing(_SettingTrailing trailing, {required bool danger}) {
    switch (trailing.kind) {
      case _TrailingKind.chevron:
        return Icon(Icons.chevron_right,
            size: 18, color: danger ? TT.red : TT.text3);
      case _TrailingKind.toggle:
        return Switch.adaptive(
          value: trailing.toggleValue ?? false,
          onChanged: trailing.toggleChanged,
          activeColor: Colors.white,
          activeTrackColor: TT.ember,
          inactiveThumbColor: Colors.white,
          inactiveTrackColor: TT.surf3,
          trackOutlineColor: WidgetStateProperty.resolveWith(
              (_) => Colors.transparent),
        );
      case _TrailingKind.value:
        return Text(
          trailing.valueText ?? '',
          style: TT.mono(
            size: 11,
            color: TT.ember,
            letterSpacing: 0.04 * 11,
          ),
        );
      case _TrailingKind.signOut:
        return const TTPill(
          label: 'SIGN OUT',
          variant: TTPillVariant.danger,
        );
    }
  }
}

// ──────────────────────────── ANIMATION HELPER ──────────────────────────────

class _FadeUp extends StatefulWidget {
  final Duration delay;
  final Widget child;
  const _FadeUp({required this.delay, required this.child});

  @override
  State<_FadeUp> createState() => _FadeUpState();
}

class _FadeUpState extends State<_FadeUp> with SingleTickerProviderStateMixin {
  late final AnimationController _ctl =
      AnimationController(vsync: this, duration: TT.dSlow);
  late final Animation<double> _anim =
      Tween<double>(begin: 0.0, end: 1.0).animate(
    CurvedAnimation(parent: _ctl, curve: TT.easeOut),
  );

  @override
  void initState() {
    super.initState();
    Future.delayed(widget.delay, () {
      if (mounted) _ctl.forward();
    });
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) {
        final t = _anim.value;
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, (1 - t) * 14),
            child: widget.child,
          ),
        );
      },
    );
  }
}

// ──────────────────────────── UNIT PICKER ROW ───────────────────────────────

class _UnitsOptionTile extends StatelessWidget {
  final bool selected;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _UnitsOptionTile({
    required this.selected,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: selected ? TT.emberSoft : TT.surf2,
          borderRadius: BorderRadius.circular(TT.rMd),
          border: Border.all(
            color: selected ? TT.ember : TT.line2,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              size: 20,
              color: selected ? TT.ember : TT.text3,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TT.body(
                          size: 14,
                          w: FontWeight.w800,
                          color: selected ? TT.text : TT.text2)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: TT.mono(size: 11, color: TT.text3)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Reads the live app version from pubspec via package_info_plus instead
/// of the old hardcoded "TRAILTETHER v2.0" label that was lying to users
/// (everything past v3.0.x still rendered as v2.0). Falls back gracefully
/// if package_info hasn't loaded yet so the footer never goes blank.
class _AppVersionLabel extends StatefulWidget {
  const _AppVersionLabel();

  @override
  State<_AppVersionLabel> createState() => _AppVersionLabelState();
}

class _AppVersionLabelState extends State<_AppVersionLabel> {
  String _label = 'TRAILTETHER';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (!mounted) return;
      setState(() => _label = 'TRAILTETHER v${info.version} · ${info.buildNumber}');
    } catch (_) {
      // Swallow — keep the bare "TRAILTETHER" if the platform channel
      // somehow fails. Never crash the profile footer over a label.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      _label,
      style: TT.mono(
        size: 9.5,
        color: TT.text4,
        letterSpacing: 0.16 * 9.5,
      ),
    );
  }
}
