import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../core/constants.dart';
import '../models/team.dart';
import '../providers/auth_provider.dart' as ap;
import '../providers/static_data_provider.dart';
import '../providers/gpx_provider.dart';
import '../providers/routing_provider.dart';
import '../services/team_service.dart';
import '../widgets/common/user_avatar.dart';

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
            primary: kColorOrange,
            surface: kColorPanel,
            onSurface: kColorCream,
          ),
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
            primary: kColorOrange,
            surface: kColorPanel,
            onSurface: kColorCream,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _hikeTime = picked);
  }

  void _addCustomGear() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kColorPanel,
        title: Text('Add Gear Item',
            style: GoogleFonts.outfit(color: kColorCream, fontSize: 18)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: GoogleFonts.outfit(color: kColorCream),
          decoration: InputDecoration(
            hintText: 'Item name...',
            hintStyle: TextStyle(color: kColorCream.withOpacity(0.3)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: kColorCream)),
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
            child: const Text('Add', style: TextStyle(color: kColorOrange)),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    if (_selectedTrailId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a trail.')),
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
          SnackBar(content: Text('Failed to save plan: $e')),
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
      backgroundColor: kColorBg,
      appBar: AppBar(
        backgroundColor: kColorBg,
        foregroundColor: kColorCream,
        elevation: 0,
        title: Text(
          'Plan a Hike',
          style: GoogleFonts.outfit(
              color: kColorCream, fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            // ── Trail picker ────────────────────────────────────────
            const _Label('Select Trail'),
            const SizedBox(height: 6),
            Container(
              decoration: BoxDecoration(
                color: kColorPanel,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: kColorBorder),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedTrailId,
                  isExpanded: true,
                  dropdownColor: kColorPanel,
                  hint: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      'Choose a trail…',
                      style: GoogleFonts.outfit(
                          color: kColorCream.withOpacity(0.3), fontSize: 14),
                    ),
                  ),
                  icon: Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Icon(Icons.expand_more,
                        color: kColorCream.withOpacity(0.4)),
                  ),
                  items: trails
                      .map((t) => DropdownMenuItem(
                            value: t.id,
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 12),
                              child: Text(
                                t.name,
                                style: GoogleFonts.outfit(
                                    color: kColorCream, fontSize: 14),
                              ),
                            ),
                          ))
                      .toList(),
                  onChanged: (id) {
                    if (id == null) return;
                    final t = trails.firstWhere((t) => t.id == id);
                    setState(() {
                      _selectedTrailId = id;
                      _selectedTrailName = t.name;
                    });
                  },
                ),
              ),
            ),

            if (routingProv.calculatedPath.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: kColorOrange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: kColorOrange.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.route, color: kColorOrange, size: 18),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Use Planned Route',
                              style: GoogleFonts.outfit(
                                  color: kColorCream,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600)),
                          Text(
                              '${routingProv.totalDistanceKm.toStringAsFixed(1)} km custom path',
                              style: GoogleFonts.outfit(
                                  color: kColorCream.withOpacity(0.5),
                                  fontSize: 11)),
                        ],
                      ),
                    ),
                    Switch(
                      value: _selectedTrailId == 'custom_route',
                      onChanged: (val) {
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
                      activeColor: kColorOrange,
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 20),

            // ── Date & Time picker ─────────────────────────────────────────
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _Label('Start Date'),
                      const SizedBox(height: 6),
                      GestureDetector(
                        onTap: () => _pickDate(isEnd: false),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: kColorPanel,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: kColorBorder),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.calendar_today,
                                  color: kColorOrange, size: 16),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  dateStr,
                                  style: GoogleFonts.outfit(
                                      color: kColorCream, fontSize: 13),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _Label('End Date'),
                      const SizedBox(height: 6),
                      GestureDetector(
                        onTap: () => _pickDate(isEnd: true),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: kColorPanel,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: kColorBorder),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.calendar_today,
                                  color: kColorCream.withOpacity(0.3),
                                  size: 16),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _endDate != null
                                      ? DateFormat('EEE, d MMM')
                                          .format(_endDate!)
                                      : 'Add End',
                                  style: GoogleFonts.outfit(
                                      color: _endDate != null
                                          ? kColorCream
                                          : kColorCream.withOpacity(0.3),
                                      fontSize: 13),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 1,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _Label('Time'),
                      const SizedBox(height: 6),
                      GestureDetector(
                        onTap: _pickTime,
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: kColorPanel,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: kColorBorder),
                          ),
                          child: Center(
                            child: Text(
                              _hikeTime?.format(context).replaceAll(' ', '') ??
                                  '--:--',
                              style: GoogleFonts.outfit(
                                  color: kColorCream, fontSize: 13),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // ── GPX Selector ───────────────────────────────────────
            if (gpxTracks.isNotEmpty) ...[
              const _Label('Attach GPX Track (optional)'),
              const SizedBox(height: 6),
              Container(
                decoration: BoxDecoration(
                  color: kColorPanel,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: kColorBorder),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _gpxId,
                    isExpanded: true,
                    dropdownColor: kColorPanel,
                    hint: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        'Select a GPX file…',
                        style: GoogleFonts.outfit(
                            color: kColorCream.withOpacity(0.3), fontSize: 14),
                      ),
                    ),
                    icon: Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Icon(Icons.expand_more,
                          color: kColorCream.withOpacity(0.4)),
                    ),
                    items: [
                      DropdownMenuItem<String>(
                        value: '',
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text('None',
                              style: GoogleFonts.outfit(
                                  color: kColorCream.withOpacity(0.5),
                                  fontSize: 14)),
                        ),
                      ),
                      ...gpxTracks.map((t) => DropdownMenuItem(
                            value: t.id,
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 12),
                              child: Text(
                                t.label,
                                style: GoogleFonts.outfit(
                                    color: kColorCream, fontSize: 14),
                              ),
                            ),
                          ))
                    ],
                    onChanged: (id) {
                      setState(() {
                        _gpxId = id == '' ? null : id;
                      });
                    },
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],

            // ── Meeting point ───────────────────────────────────────
            const _Label('Meeting Point (optional)'),
            const SizedBox(height: 6),
            _Field(
              controller: _meetCtrl,
              hint: 'e.g. Monk\'s Cowl parking, 06:00',
              maxLength: 80,
            ),

            const SizedBox(height: 10),

            // ── Weather ───────────────────────────────────────
            const _Label('Weather Report (optional)'),
            const SizedBox(height: 6),
            _Field(
              controller: _weatherCtrl,
              hint: 'e.g. Sunny, 22°C. No rain expected.',
              maxLength: 100,
            ),

            const SizedBox(height: 10),

            // ── Emergency Contacts ───────────────────────────────────────
            const _Label('Emergency Contact for this hike (optional)'),
            const SizedBox(height: 6),
            _Field(
              controller: _emergencyCtrl,
              hint: 'e.g. KZN Mountain Rescue: 0800 11 22 33',
              maxLength: 100,
            ),

            const SizedBox(height: 20),

            // ── Pack List ───────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const _Label('Required Equipment'),
                GestureDetector(
                  onTap: _addCustomGear,
                  child: Text('+ Add Item',
                      style: GoogleFonts.outfit(
                          color: kColorOrange,
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: kColorPanel,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: kColorBorder),
              ),
              child: Column(
                children: [
                  if (_gearItems.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text('No gear items added.',
                          style: GoogleFonts.outfit(
                              color: kColorCream.withOpacity(0.3),
                              fontSize: 13)),
                    ),
                  ..._gearItems.asMap().entries.map((entry) {
                    final i = entry.key;
                    final item = entry.value;
                    return Column(
                      children: [
                        ListTile(
                          dense: true,
                          leading: Icon(
                            item.category == 'Safety'
                                ? Icons.emergency
                                : item.category == 'Nutrition'
                                    ? Icons.restaurant
                                    : item.category == 'Group'
                                        ? Icons.groups
                                        : Icons.backpack,
                            size: 16,
                            color: kColorOrange.withOpacity(0.5),
                          ),
                          title: Text(item.name,
                              style: GoogleFonts.outfit(
                                  color: kColorCream, fontSize: 14)),
                          subtitle: Text(item.category,
                              style: GoogleFonts.outfit(
                                  color: kColorCream.withOpacity(0.4),
                                  fontSize: 11)),
                          trailing: IconButton(
                            icon: const Icon(Icons.remove_circle_outline,
                                size: 18, color: Colors.redAccent),
                            onPressed: () =>
                                setState(() => _gearItems.removeAt(i)),
                          ),
                        ),
                        if (i < _gearItems.length - 1)
                          const Divider(
                              height: 1, color: kColorBorder, indent: 40),
                      ],
                    );
                  }),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ── Invites ───────────────────────────────────────
            const _Label('Invite Team Members'),
            const SizedBox(height: 8),
            if (widget.team.members.length > 1)
              Container(
                decoration: BoxDecoration(
                  color: kColorPanel,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: kColorBorder),
                ),
                child: Column(
                  children: widget.team.members
                      .where((m) =>
                          m.uid != (context.read<ap.AuthProvider>().uid ?? ''))
                      .map((m) {
                    final isInvited = _invitedMembers.contains(m.uid);
                    return CheckboxListTile(
                      title: Text(m.displayName,
                          style: GoogleFonts.outfit(
                              color: kColorCream,
                              fontSize: 14,
                              fontWeight: FontWeight.w600)),
                      subtitle: Text(m.email,
                          style: GoogleFonts.outfit(
                              color: kColorCream.withOpacity(0.5),
                              fontSize: 11)),
                      value: isInvited,
                      activeColor: kColorOrange,
                      checkColor: Colors.white,
                      secondary: UserAvatar(
                        radius: 16,
                        photoUrl: m.photoUrl,
                        displayName: m.displayName,
                        backgroundColor: kColorBg,
                      ),
                      onChanged: (val) {
                        setState(() {
                          if (val == true) {
                            _invitedMembers.add(m.uid);
                          } else {
                            _invitedMembers.remove(m.uid);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
              )
            else
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: kColorPanel,
                  borderRadius: BorderRadius.circular(10),
                  border:
                      Border.all(color: kColorBorder, style: BorderStyle.none),
                ),
                child: Text(
                  'No other members in this team yet. You can invite people from the "Members" tab on the Team screen.',
                  style: GoogleFonts.outfit(
                      color: kColorCream.withOpacity(0.4),
                      fontSize: 12,
                      height: 1.4),
                ),
              ),
            const SizedBox(height: 20),

            // ── Notes ───────────────────────────────────────────────
            const _Label('Additional Notes (optional)'),
            const SizedBox(height: 6),
            _Field(
              controller: _notesCtrl,
              hint: 'Any extra info for the group…',
              maxLines: 3,
              maxLength: 200,
            ),

            const SizedBox(height: 32),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _busy ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: kColorOrange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                ),
                child: _busy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : Text('Save Hike Plan',
                        style: GoogleFonts.outfit(
                            fontWeight: FontWeight.w600, fontSize: 14)),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);
  @override
  Widget build(BuildContext context) => Text(
        text,
        style: GoogleFonts.outfit(
          color: kColorCream.withOpacity(0.6),
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.4,
        ),
      );
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final int maxLines;
  final int? maxLength;
  const _Field({
    required this.controller,
    required this.hint,
    this.maxLines = 1,
    this.maxLength,
  });
  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: kColorPanel,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: kColorBorder),
        ),
        child: TextField(
          controller: controller,
          maxLines: maxLines,
          maxLength: maxLength,
          style: GoogleFonts.outfit(color: kColorCream, fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.outfit(
                color: kColorCream.withOpacity(0.3), fontSize: 14),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.all(12),
            counterStyle: GoogleFonts.outfit(
                color: kColorCream.withOpacity(0.3), fontSize: 11),
          ),
        ),
      );
}
