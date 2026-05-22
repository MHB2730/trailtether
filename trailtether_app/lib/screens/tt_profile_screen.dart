// Trailtether 2.0 — Profile screen.
//
// Recreates project/screens/profile.jsx from the design bundle: gradient avatar
// header, four count-up stat tiles, an 8-badge achievements grid, and grouped
// settings sections. Placeholder data only — no provider/service wiring.

import 'package:flutter/material.dart';

import '../core/design_tokens.dart';
import '../widgets/design/tt_ambient.dart';
import '../widgets/design/tt_app_bar.dart';
import '../widgets/design/tt_count_up.dart';
import '../widgets/design/tt_glass_card.dart';
import '../widgets/design/tt_pill.dart';
import '../widgets/design/tt_topo.dart';

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

  // Placeholder toggle state — purely visual, no service writes.
  bool _liveTracking = true;
  bool _hapticFeedback = true;
  bool _trailWeather = true;
  bool _offTrailAlerts = false;

  @override
  void dispose() {
    _headerCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                  TTIconBtn(icon: Icons.settings_outlined, onTap: () {}),
                ],
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(18, 4, 18, 28),
                  children: [
                    _ProfileHeader(animation: _headerCtl),
                    const SizedBox(height: 14),
                    const _StatTilesRow(),
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
                        ),
                        _SettingRowData(
                          icon: Icons.shield_outlined,
                          label: 'Privacy & data',
                          sub: 'No data sold · No ads',
                          trailing: _SettingTrailing.chevron(),
                        ),
                        _SettingRowData(
                          icon: Icons.phone_outlined,
                          label: 'Emergency contacts',
                          sub: '3 contacts saved',
                          trailing: _SettingTrailing.value('3'),
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
                            onChanged: (v) => setState(() => _liveTracking = v),
                          ),
                        ),
                        _SettingRowData(
                          icon: Icons.cloud_outlined,
                          label: 'Trail weather alerts',
                          sub: 'Storms, wind, visibility',
                          trailing: _SettingTrailing.toggle(
                            value: _trailWeather,
                            onChanged: (v) => setState(() => _trailWeather = v),
                          ),
                        ),
                        _SettingRowData(
                          icon: Icons.warning_amber_outlined,
                          label: 'Off-trail alerts',
                          sub: 'Get nudged when drifting',
                          trailing: _SettingTrailing.toggle(
                            value: _offTrailAlerts,
                            onChanged: (v) => setState(() => _offTrailAlerts = v),
                          ),
                        ),
                        _SettingRowData(
                          icon: Icons.vibration,
                          label: 'Haptic feedback',
                          sub: 'Pings on alerts',
                          trailing: _SettingTrailing.toggle(
                            value: _hapticFeedback,
                            onChanged: (v) => setState(() => _hapticFeedback = v),
                          ),
                        ),
                        _SettingRowData(
                          icon: Icons.straighten,
                          label: 'Units',
                          sub: 'Imperial · ft / mi',
                          trailing: _SettingTrailing.value('Imperial'),
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
                          sub: '47 hikes · 12.4 MB',
                          danger: true,
                          trailing: _SettingTrailing.chevron(),
                        ),
                        _SettingRowData(
                          icon: Icons.logout,
                          label: 'Sign out',
                          sub: 'john@trailtether.app',
                          danger: true,
                          isSignOut: true,
                          trailing: _SettingTrailing.signOut(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _FadeUp(
                      delay: const Duration(milliseconds: 1600),
                      child: Center(
                        child: Text(
                          'TRAILTETHER v2.0',
                          style: TT.mono(
                            size: 9.5,
                            color: TT.text4,
                            letterSpacing: 0.16 * 9.5,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    _FadeUp(
                      delay: const Duration(milliseconds: 1660),
                      child: Center(
                        child: Text(
                          'BUILT IN CAPE TOWN',
                          style: TT.mono(
                            size: 9.5,
                            color: TT.text4,
                            letterSpacing: 0.16 * 9.5,
                          ),
                        ),
                      ),
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
}

// ──────────────────────────── HEADER ────────────────────────────────────────

class _ProfileHeader extends StatelessWidget {
  final AnimationController animation;
  const _ProfileHeader({required this.animation});

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
            child: _buildCard(),
          ),
        );
      },
    );
  }

  Widget _buildCard() {
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
                      const _GradientAvatar(initials: 'JD'),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('John Davies',
                                style: TT.title(22, letterSpacing: -0.01 * 22)),
                            const SizedBox(height: 4),
                            Text('@johndavies',
                                style: TT.mono(
                                    size: 11,
                                    color: TT.text3,
                                    letterSpacing: 0.04 * 11)),
                            const SizedBox(height: 8),
                            const TTPill(
                              label: 'TRAILBLAZER · TIER III',
                              variant: TTPillVariant.ember,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                    decoration: BoxDecoration(
                      color: const Color(0x05FFFFFF),
                      border: Border.all(color: TT.line, width: 1),
                      borderRadius: BorderRadius.circular(TT.rSm + 2),
                    ),
                    child: Text(
                      'Cape Town based. Drakensberg regular. Slow ascents, long descents, dawn starts.',
                      style: TT.body(size: 12, w: FontWeight.w500, color: TT.text2)
                          .copyWith(height: 1.5),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GradientAvatar extends StatelessWidget {
  final String initials;
  const _GradientAvatar({required this.initials});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
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
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF6B3A1A), TT.ember2],
              ),
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
            child: Text(
              initials,
              style: TT.body(size: 26, w: FontWeight.w900, color: Colors.white)
                  .copyWith(letterSpacing: -0.02 * 26),
            ),
          ),
          Positioned(
            right: 1,
            bottom: 1,
            child: Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: TT.green,
                border: Border.all(color: TT.bg3, width: 3),
                boxShadow: const [
                  BoxShadow(color: Color(0xAA4CC38A), blurRadius: 8),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────── STAT TILES ────────────────────────────────────

class _StatTilesRow extends StatelessWidget {
  const _StatTilesRow();

  @override
  Widget build(BuildContext context) {
    const tiles = <_StatTile>[
      _StatTile(
        icon: Icons.terrain_outlined,
        label: 'Hikes',
        value: '47',
        unit: null,
        ember: false,
      ),
      _StatTile(
        icon: Icons.navigation_outlined,
        label: 'Distance',
        value: '284',
        unit: 'mi',
        ember: true,
      ),
      _StatTile(
        icon: Icons.arrow_upward,
        label: 'Ascent',
        value: '62,418',
        unit: 'ft',
        ember: false,
      ),
      _StatTile(
        icon: Icons.flag_outlined,
        label: 'Peaks',
        value: '12',
        unit: null,
        ember: false,
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
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String? unit;
  final bool ember;

  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.unit,
    required this.ember,
  });

  @override
  Widget build(BuildContext context) {
    return TTCard(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      onTap: () {},
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

  @override
  Widget build(BuildContext context) {
    const badges = <_AchievementData>[
      _AchievementData(
        icon: Icons.play_arrow,
        label: 'First Steps',
        date: 'JAN 14',
        color: TT.ember,
        unlocked: true,
      ),
      _AchievementData(
        icon: Icons.terrain,
        label: '4K Club',
        date: 'MAR 02',
        color: TT.ember2,
        unlocked: true,
      ),
      _AchievementData(
        icon: Icons.link,
        label: 'Tethered',
        date: 'MAR 19',
        color: TT.blue,
        unlocked: true,
      ),
      _AchievementData(
        icon: Icons.route,
        label: 'Plan Maker',
        date: 'APR 06',
        color: TT.green,
        unlocked: true,
      ),
      _AchievementData(
        icon: Icons.air,
        label: 'Storm Survivor',
        date: 'MAY 11',
        color: TT.amber,
        unlocked: true,
      ),
      _AchievementData(
        icon: Icons.flag_outlined,
        label: 'Summit X12',
        date: 'LOCKED',
        color: TT.text3,
        unlocked: false,
      ),
      _AchievementData(
        icon: Icons.shield_outlined,
        label: 'First Responder',
        date: 'LOCKED',
        color: TT.text3,
        unlocked: false,
      ),
      _AchievementData(
        icon: Icons.nights_stay_outlined,
        label: 'Night Owl',
        date: 'LOCKED',
        color: TT.text3,
        unlocked: false,
      ),
    ];

    final unlockedCount = badges.where((b) => b.unlocked).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(2, 0, 2, 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'ACHIEVEMENTS · $unlockedCount OF ${badges.length}',
                style: TT.label(
                    size: 11, color: TT.text2, letterSpacing: 0.16 * 11),
              ),
              Text(
                'VIEW ALL →',
                style: TT
                    .body(size: 10, w: FontWeight.w800, color: TT.ember)
                    .copyWith(letterSpacing: 0.1 * 10),
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
  }
}

class _AchievementData {
  final IconData icon;
  final String label;
  final String date;
  final Color color;
  final bool unlocked;

  const _AchievementData({
    required this.icon,
    required this.label,
    required this.date,
    required this.color,
    required this.unlocked,
  });
}

class _AchievementBadge extends StatelessWidget {
  final _AchievementData data;
  const _AchievementBadge({required this.data});

  @override
  Widget build(BuildContext context) {
    final card = TTCard(
      padding: const EdgeInsets.fromLTRB(6, 12, 6, 10),
      onTap: () {},
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: data.unlocked
                      ? data.color.withOpacity(0.12)
                      : TT.bg3,
                  border: Border.all(
                    color: data.unlocked ? data.color : TT.line2,
                    width: 2,
                  ),
                  boxShadow: data.unlocked
                      ? [
                          BoxShadow(
                            color: data.color.withOpacity(0.22),
                            blurRadius: 12,
                          ),
                        ]
                      : null,
                ),
                child: Icon(
                  data.icon,
                  size: 18,
                  color: data.unlocked ? data.color : TT.text3,
                ),
              ),
              if (!data.unlocked)
                Positioned(
                  right: -2,
                  bottom: -2,
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: TT.bg2,
                      border: Border.all(color: TT.line2, width: 1),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(Icons.lock, size: 9, color: TT.text3),
                  ),
                ),
            ],
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

  const _SettingRowData({
    required this.icon,
    required this.label,
    this.sub,
    required this.trailing,
    this.danger = false,
    this.isSignOut = false,
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
      onTap: () {},
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
