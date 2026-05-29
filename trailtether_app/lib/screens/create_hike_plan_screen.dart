// Trailtether 3.0 — Plan-a-Hike composer, reskinned to TT tokens.
//
// All logic (CRUD against TeamService, gear list with custom items, RSVP
// seeding, GPX attachment, custom-route toggle, member invites) is
// preserved unchanged. The screen now uses the TT ambient backdrop,
// TTPageAppBar, TTCard fields, TTPill chips, ember primary button and
// JetBrains-Mono date / time pickers themed to the ember palette.
//
// The save action calls TeamService.createPlan exactly as before so the
// Supabase row layout and HikePlanExtras serialization are untouched.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../core/design_tokens.dart';
import '../models/team.dart';
import '../providers/auth_provider.dart' as ap;
import '../providers/gpx_provider.dart';
import '../providers/routing_provider.dart';
import '../providers/static_data_provider.dart';
import '../services/team_service.dart';
import '../widgets/common/user_avatar.dart';
import '../widgets/design/tt_ambient.dart';
import '../widgets/design/tt_app_bar.dart';
import '../widgets/design/tt_glass_card.dart';
import '../widgets/design/tt_topo.dart';

class CreateHikePlanScreen extends StatefulWidget {
  final Team team;
  final DateTime? initialDate;
  const CreateHikePlanScreen({super.key, required this.team, this.initialDate});

  @override
  State<CreateHikePlanScreen> createState() => _CreateHikePlanScreenState();
}

class _CreateHikePlanScreenState extends State<CreateHikePlanScreen> {
  String? _selectedTrailId;
  String? _selectedTrailName;
  late DateTime _hikeDate;
  DateTime? _endDate;
  TimeOfDay? _hikeTime;
  String? _gpxId;

  final _meetCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _weatherCtrl = TextEditingController();
  final _emergencyCtrl = TextEditingController();

  final List<GearItem> _gearItems = [
    const GearItem(id: 'tent', name: 'Tent', category: 'Group'),
    const GearItem(id: 'boots', name: 'Boots', category: 'Clothing'),
    const GearItem(id: 'first_aid', name: 'First Aid', category: 'Safety'),
    const GearItem(id: 'water', name: 'Water (3L+)', category: 'Nutrition'),
    const GearItem(id: 'food', name: 'Food (2 Days)', category: 'Nutrition'),
    const GearItem(id: 'rain_gear', name: 'Rain Gear', category: 'Clothing'),
  ];
  final Set<String> _invitedMembers = {};

  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _hikeDate =
        widget.initialDate ?? DateTime.now().add(const Duration(days: 7));
  }

  @override
  void dispose() {
    _meetCtrl.dispose();
    _notesCtrl.dispose();
    _weatherCtrl.dispose();
    _emergencyCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate({bool isEnd = false}) async {
    final initial = isEnd ? (_endDate ?? _hikeDate) : _hikeDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: isEnd ? _hikeDate : DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: TT.ember,
            onPrimary: TT.emberInk,
            surface: TT.surf,
            onSurface: TT.text,
          ),
          dialogBackgroundColor: TT.bg2,
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        if (isEnd) {
          _endDate = picked;
        } else {
          _hikeDate = picked;
          if (_endDate != null && _endDate!.isBefore(_hikeDate)) {
            _endDate = _hikeDate;
          }
        }
      });
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: TT.ember,
            onPrimary: TT.emberInk,
            surface: TT.surf,
            onSurface: TT.text,
          ),
          dialogBackgroundColor: TT.bg2,
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _hikeTime = picked);
  }

  void _addCustomGear() {
    final ctrl = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: TT.bg2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(TT.rLg),
          side: const BorderSide(color: TT.line2),
        ),
        title: Text('Add Gear Item', style: TT.title(17)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          cursorColor: TT.ember,
          style: TT.body(size: 14, color: TT.text),
          decoration: InputDecoration(
            hintText: 'Item name…',
            hintStyle: TT.body(size: 14, color: TT.text3),
            filled: true,
            fillColor: TT.surf,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(TT.rMd),
              borderSide: const BorderSide(color: TT.line2),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(TT.rMd),
              borderSide: const BorderSide(color: TT.line2),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(TT.rMd),
              borderSide: const BorderSide(color: TT.ember, width: 1.4),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel',
                style: TT.body(size: 13, w: FontWeight.w700, color: TT.text2)),
          ),
          TextButton(
            onPressed: () {
              if (ctrl.text.trim().isNotEmpty) {
                setState(() {
                  _gearItems.add(GearItem(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    name: ctrl.text.trim(),
                  ));
                });
              }
              Navigator.pop(ctx);
            },
            child: Text('Add',
                style: TT.body(size: 13, w: FontWeight.w800, color: TT.ember)),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    if (_selectedTrailId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: TT.surf,
          behavior: SnackBarBehavior.floating,
          content: Text('Please select a trail.',
              style: TT.body(size: 13, color: TT.text)),
        ),
      );
      return;
    }

    setState(() => _busy = true);

    final uid = context.read<ap.AuthProvider>().uid ?? '';

    final extras = HikePlanExtras(
      userNotes: _notesCtrl.text.trim(),
      time: _hikeTime?.format(context) ?? '',
      gpxId: _gpxId ?? '',
      weather: _weatherCtrl.text.trim(),
      endDate: _endDate,
      emergencyContacts: _emergencyCtrl.text.trim().isNotEmpty
          ? [_emergencyCtrl.text.trim()]
          : [],
      gearList: _gearItems,
      invitedMembers: _invitedMembers.toList(),
      rsvp: {uid: 'going'},
    );

    final plan = HikePlan(
      id: '',
      teamId: widget.team.id,
      trailId: _selectedTrailId!,
      trailName: _selectedTrailName!,
      hikeDate: _hikeDate,
      meetingPoint: _meetCtrl.text.trim(),
      notes: extras.toJsonString(),
      createdBy: uid,
      createdAt: DateTime.now(),
    );

    try {
      await TeamService.createPlan(plan);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: TT.surf,
            behavior: SnackBarBehavior.floating,
            content: Text('Failed to save plan: $e',
                style: TT.body(size: 13, color: TT.text)),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final trails = context.watch<StaticDataProvider>().allTrails;
    final gpxTracks = context.watch<GpxProvider>().tracks;
    final routingProv = context.watch<RoutingProvider>();

    final dateStr = DateFormat('EEE, d MMM yyyy').format(_hikeDate);

    return Scaffold(
      backgroundColor: TT.bg,
      body: Stack(
        children: [
          const Positioned.fill(child: TTAmbient()),
          const Positioned.fill(child: TTTopoBackdrop()),
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                _AppBar(
                  title: 'Plan a Hike',
                  onBack: () => Navigator.of(context).pop(),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(18, 6, 18, 32),
                    children: [
                      // ── Trail picker ────────────────────────────────────
                      const _SectionLabel('SELECT TRAIL'),
                      const SizedBox(height: 8),
                      _TrailDropdown(
                        trails: trails,
                        value: _selectedTrailId,
                        onChanged: (id) {
                          if (id == null) return;
                          final t = trails.firstWhere((t) => t.id == id);
                          setState(() {
                            _selectedTrailId = id;
                            _selectedTrailName = t.name;
                          });
                        },
                      ),

                      if (routingProv.calculatedPath.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        _CustomRouteCard(
                          distanceKm: routingProv.totalDistanceKm,
                          active: _selectedTrailId == 'custom_route',
                          onToggle: (val) {
                            setState(() {
                              if (val) {
                                _selectedTrailId = 'custom_route';
                                _selectedTrailName =
                                    'Custom Route (${routingProv.totalDistanceKm.toStringAsFixed(1)}km)';
                              } else {
                                _selectedTrailId = null;
                                _selectedTrailName = null;
                              }
                            });
                          },
                        ),
                      ],

                      const SizedBox(height: 20),

                      // ── Date & Time picker ─────────────────────────────
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: _DateTimeField(
                              label: 'START DATE',
                              icon: Icons.calendar_today,
                              text: dateStr,
                              filled: true,
                              onTap: () => _pickDate(isEnd: false),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 2,
                            child: _DateTimeField(
                              label: 'END DATE',
                              icon: Icons.calendar_today_outlined,
                              text: _endDate != null
                                  ? DateFormat('EEE, d MMM').format(_endDate!)
                                  : 'Add End',
                              filled: _endDate != null,
                              onTap: () => _pickDate(isEnd: true),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _DateTimeField(
                              label: 'TIME',
                              icon: Icons.schedule,
                              text: _hikeTime
                                      ?.format(context)
                                      .replaceAll(' ', '') ??
                                  '--:--',
                              filled: _hikeTime != null,
                              compact: true,
                              onTap: _pickTime,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // ── GPX Selector ───────────────────────────────────
                      if (gpxTracks.isNotEmpty) ...[
                        const _SectionLabel('ATTACH GPX TRACK (OPTIONAL)'),
                        const SizedBox(height: 8),
                        _GpxDropdown(
                          tracks: gpxTracks,
                          value: _gpxId,
                          onChanged: (id) {
                            setState(() {
                              _gpxId = id == '' ? null : id;
                            });
                          },
                        ),
                        const SizedBox(height: 20),
                      ],

                      // ── Meeting point ──────────────────────────────────
                      const _SectionLabel('MEETING POINT (OPTIONAL)'),
                      const SizedBox(height: 8),
                      _TTField(
                        controller: _meetCtrl,
                        hint: 'e.g. Monk\'s Cowl parking, 06:00',
                        maxLength: 80,
                      ),

                      const SizedBox(height: 16),

                      // ── Weather ────────────────────────────────────────
                      const _SectionLabel('WEATHER REPORT (OPTIONAL)'),
                      const SizedBox(height: 8),
                      _TTField(
                        controller: _weatherCtrl,
                        hint: 'e.g. Sunny, 22C. No rain expected.',
                        maxLength: 100,
                      ),

                      const SizedBox(height: 16),

                      // ── Emergency Contacts ─────────────────────────────
                      const _SectionLabel(
                          'EMERGENCY CONTACT FOR THIS HIKE (OPTIONAL)'),
                      const SizedBox(height: 8),
                      _TTField(
                        controller: _emergencyCtrl,
                        hint: 'e.g. KZN Mountain Rescue: 0800 11 22 33',
                        maxLength: 100,
                      ),

                      const SizedBox(height: 20),

                      // ── Pack List ──────────────────────────────────────
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const _SectionLabel('REQUIRED EQUIPMENT'),
                          GestureDetector(
                            onTap: _addCustomGear,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.add,
                                    size: 14, color: TT.ember),
                                const SizedBox(width: 4),
                                Text('Add Item',
                                    style: TT.body(
                                        size: 12,
                                        w: FontWeight.w700,
                                        color: TT.ember)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _GearList(
                        gearItems: _gearItems,
                        onRemove: (i) => setState(() => _gearItems.removeAt(i)),
                      ),

                      const SizedBox(height: 24),

                      // ── Invites ────────────────────────────────────────
                      const _SectionLabel('INVITE TEAM MEMBERS'),
                      const SizedBox(height: 10),
                      _MemberInviteList(
                        team: widget.team,
                        currentUid: context.read<ap.AuthProvider>().uid ?? '',
                        invited: _invitedMembers,
                        onToggle: (uid, value) {
                          setState(() {
                            if (value) {
                              _invitedMembers.add(uid);
                            } else {
                              _invitedMembers.remove(uid);
                            }
                          });
                        },
                      ),

                      const SizedBox(height: 20),

                      // ── Notes ──────────────────────────────────────────
                      const _SectionLabel('ADDITIONAL NOTES (OPTIONAL)'),
                      const SizedBox(height: 8),
                      _TTField(
                        controller: _notesCtrl,
                        hint: 'Any extra info for the group…',
                        maxLines: 3,
                        maxLength: 200,
                      ),

                      const SizedBox(height: 28),

                      _SaveButton(busy: _busy, onTap: _save),
                      const SizedBox(height: 28),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Top app bar ───────────────────────────────────────────────────────────

class _AppBar extends StatelessWidget {
  final String title;
  final VoidCallback onBack;
  const _AppBar({required this.title, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 6),
      child: Row(
        children: [
          TTIconBtn(icon: Icons.chevron_left, size: 38, onTap: onBack),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TT.title(20, letterSpacing: -0.01 * 20),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Section label ─────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: TT.label(size: 10.5, color: TT.ember, letterSpacing: 1.4),
      );
}

// ── Trail dropdown card ───────────────────────────────────────────────────

class _TrailDropdown extends StatelessWidget {
  final List trails;
  final String? value;
  final ValueChanged<String?> onChanged;
  const _TrailDropdown({
    required this.trails,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: TT.surf,
        borderRadius: BorderRadius.circular(TT.rMd),
        border: Border.all(color: TT.line2),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          dropdownColor: TT.bg2,
          borderRadius: BorderRadius.circular(TT.rMd),
          hint: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Text(
              'Choose a trail…',
              style: TT.body(size: 14, color: TT.text3),
            ),
          ),
          icon: const Padding(
            padding: EdgeInsets.only(right: 10),
            child: Icon(Icons.expand_more, color: TT.text2),
          ),
          items: trails
              .map<DropdownMenuItem<String>>((t) => DropdownMenuItem<String>(
                    value: t.id as String,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: Text(
                        t.name as String,
                        style: TT.body(size: 14, color: TT.text),
                      ),
                    ),
                  ))
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

// ── Custom route toggle card ──────────────────────────────────────────────

class _CustomRouteCard extends StatelessWidget {
  final double distanceKm;
  final bool active;
  final ValueChanged<bool> onToggle;
  const _CustomRouteCard({
    required this.distanceKm,
    required this.active,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: TT.emberSoft,
        borderRadius: BorderRadius.circular(TT.rMd),
        border: Border.all(color: const Color(0x52FF6A2C)),
      ),
      child: Row(
        children: [
          const Icon(Icons.route, color: TT.ember, size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Use Planned Route',
                  style: TT.body(size: 13, w: FontWeight.w700, color: TT.text),
                ),
                const SizedBox(height: 2),
                Text(
                  '${distanceKm.toStringAsFixed(1)} km custom path',
                  style: TT.mono(size: 11, color: TT.text3),
                ),
              ],
            ),
          ),
          Switch(
            value: active,
            onChanged: onToggle,
            activeColor: TT.emberInk,
            activeTrackColor: TT.ember,
            inactiveThumbColor: TT.text3,
            inactiveTrackColor: TT.surf2,
          ),
        ],
      ),
    );
  }
}

// ── Date / time field tile ────────────────────────────────────────────────

class _DateTimeField extends StatelessWidget {
  final String label;
  final IconData icon;
  final String text;
  final bool filled;
  final bool compact;
  final VoidCallback onTap;
  const _DateTimeField({
    required this.label,
    required this.icon,
    required this.text,
    required this.filled,
    required this.onTap,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel(label),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            decoration: BoxDecoration(
              color: TT.surf,
              borderRadius: BorderRadius.circular(TT.rMd),
              border: Border.all(color: TT.line2),
            ),
            child: compact
                ? Center(
                    child: Text(
                      text,
                      style: TT.mono(
                        size: 12,
                        color: filled ? TT.text : TT.text3,
                        w: FontWeight.w700,
                      ),
                    ),
                  )
                : Row(
                    children: [
                      Icon(icon, size: 14, color: filled ? TT.ember : TT.text3),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          text,
                          overflow: TextOverflow.ellipsis,
                          style: TT.body(
                            size: 12.5,
                            color: filled ? TT.text : TT.text3,
                            w: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}

// ── GPX dropdown card ─────────────────────────────────────────────────────

class _GpxDropdown extends StatelessWidget {
  final List tracks;
  final String? value;
  final ValueChanged<String?> onChanged;
  const _GpxDropdown({
    required this.tracks,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: TT.surf,
        borderRadius: BorderRadius.circular(TT.rMd),
        border: Border.all(color: TT.line2),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          dropdownColor: TT.bg2,
          borderRadius: BorderRadius.circular(TT.rMd),
          hint: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Text(
              'Select a GPX file…',
              style: TT.body(size: 14, color: TT.text3),
            ),
          ),
          icon: const Padding(
            padding: EdgeInsets.only(right: 10),
            child: Icon(Icons.expand_more, color: TT.text2),
          ),
          items: [
            DropdownMenuItem<String>(
              value: '',
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Text('None', style: TT.body(size: 14, color: TT.text3)),
              ),
            ),
            ...tracks.map<DropdownMenuItem<String>>(
              (t) => DropdownMenuItem<String>(
                value: t.id as String,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Text(
                    t.label as String,
                    style: TT.body(size: 14, color: TT.text),
                  ),
                ),
              ),
            ),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }
}

// ── Text field ────────────────────────────────────────────────────────────

class _TTField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final int maxLines;
  final int? maxLength;

  const _TTField({
    required this.controller,
    required this.hint,
    this.maxLines = 1,
    this.maxLength,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: TT.surf,
        borderRadius: BorderRadius.circular(TT.rMd),
        border: Border.all(color: TT.line2),
      ),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        maxLength: maxLength,
        cursorColor: TT.ember,
        style: TT.body(size: 14, color: TT.text),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TT.body(size: 14, color: TT.text3),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          counterStyle: TT.mono(size: 10, color: TT.text3),
        ),
      ),
    );
  }
}

// ── Gear list ─────────────────────────────────────────────────────────────

class _GearList extends StatelessWidget {
  final List<GearItem> gearItems;
  final ValueChanged<int> onRemove;
  const _GearList({required this.gearItems, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return TTCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          if (gearItems.isEmpty)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                'No gear items added.',
                style: TT.body(size: 13, color: TT.text3),
              ),
            ),
          for (var i = 0; i < gearItems.length; i++) ...[
            _GearRow(
              item: gearItems[i],
              onRemove: () => onRemove(i),
            ),
            if (i < gearItems.length - 1)
              Padding(
                padding: const EdgeInsets.only(left: 52),
                child: Container(height: 1, color: TT.line),
              ),
          ],
        ],
      ),
    );
  }
}

class _GearRow extends StatelessWidget {
  final GearItem item;
  final VoidCallback onRemove;
  const _GearRow({required this.item, required this.onRemove});

  IconData get _icon {
    switch (item.category) {
      case 'Safety':
        return Icons.health_and_safety_outlined;
      case 'Nutrition':
        return Icons.restaurant_outlined;
      case 'Group':
        return Icons.groups_outlined;
      case 'Clothing':
        return Icons.checkroom_outlined;
      default:
        return Icons.backpack_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: TT.emberDim,
              borderRadius: BorderRadius.circular(TT.rSm),
              border: Border.all(color: const Color(0x52FF6A2C)),
            ),
            child: Icon(_icon, size: 16, color: TT.ember),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.name,
                    style: TT.body(
                        size: 13.5, w: FontWeight.w700, color: TT.text)),
                const SizedBox(height: 2),
                Text(item.category.toUpperCase(),
                    style: TT.label(size: 9.5, color: TT.text3)),
              ],
            ),
          ),
          GestureDetector(
            onTap: onRemove,
            behavior: HitTestBehavior.opaque,
            child: const Padding(
              padding: EdgeInsets.all(4),
              child: Icon(Icons.remove_circle_outline, size: 18, color: TT.red),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Member invite list ────────────────────────────────────────────────────

class _MemberInviteList extends StatelessWidget {
  final Team team;
  final String currentUid;
  final Set<String> invited;
  final void Function(String uid, bool value) onToggle;
  const _MemberInviteList({
    required this.team,
    required this.currentUid,
    required this.invited,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final candidates = team.members.where((m) => m.uid != currentUid).toList();
    if (candidates.isEmpty) {
      return TTCard(
        padding: const EdgeInsets.all(14),
        child: Text(
          'No other members in this team yet. You can invite people from the "Members" tab on the Team screen.',
          style: TT
              .body(size: 12.5, color: TT.text2, w: FontWeight.w600)
              .copyWith(height: 1.4),
        ),
      );
    }
    return TTCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var i = 0; i < candidates.length; i++) ...[
            _MemberRow(
              member: candidates[i],
              checked: invited.contains(candidates[i].uid),
              onChanged: (val) => onToggle(candidates[i].uid, val),
            ),
            if (i < candidates.length - 1)
              Padding(
                padding: const EdgeInsets.only(left: 60),
                child: Container(height: 1, color: TT.line),
              ),
          ],
        ],
      ),
    );
  }
}

class _MemberRow extends StatelessWidget {
  final TeamMember member;
  final bool checked;
  final ValueChanged<bool> onChanged;
  const _MemberRow({
    required this.member,
    required this.checked,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onChanged(!checked),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            UserAvatar(
              radius: 16,
              photoUrl: member.photoUrl,
              displayName: member.displayName,
              backgroundColor: TT.surf2,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(member.displayName,
                      style: TT.body(
                          size: 13.5, w: FontWeight.w700, color: TT.text)),
                  const SizedBox(height: 2),
                  Text(member.email,
                      style: TT.mono(size: 10.5, color: TT.text3)),
                ],
              ),
            ),
            _CheckBox(checked: checked),
          ],
        ),
      ),
    );
  }
}

class _CheckBox extends StatelessWidget {
  final bool checked;
  const _CheckBox({required this.checked});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: checked ? TT.ember : TT.surf2,
        borderRadius: BorderRadius.circular(TT.rSm),
        border: Border.all(color: checked ? TT.ember : TT.line2, width: 1),
      ),
      child: checked
          ? const Icon(Icons.check, size: 14, color: TT.emberInk)
          : null,
    );
  }
}

// ── Save button ───────────────────────────────────────────────────────────

class _SaveButton extends StatelessWidget {
  final bool busy;
  final VoidCallback onTap;
  const _SaveButton({required this.busy, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: busy ? null : onTap,
      child: Container(
        height: 54,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: busy ? TT.emberDim : TT.ember,
          borderRadius: BorderRadius.circular(TT.rMd),
          boxShadow: busy ? null : TT.shadowEmber,
        ),
        child: busy
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  color: TT.emberInk,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.event_available,
                      size: 18, color: TT.emberInk),
                  const SizedBox(width: 10),
                  Text('SAVE HIKE PLAN',
                      style: TT
                          .body(
                              size: 13, w: FontWeight.w900, color: TT.emberInk)
                          .copyWith(letterSpacing: 0.16 * 13)),
                ],
              ),
      ),
    );
  }
}
