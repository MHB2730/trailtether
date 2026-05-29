// Trailtether 3.0 — Safety Center.
//
// Consolidates pre-hike planning into a single TT-design surface:
//   • Active hike plan card (or empty state) sourced from AppStateProvider
//   • Trip check-in form (preserved from v2): trail name / expected return /
//     notes / backpack & tent colour / save & clear
//   • Emergency contacts CRUD wired to ProfileProvider.contacts
//   • Gear checklist persisted to SharedPreferences (tt_gear_<item>) with an
//     animated progress bar
//   • Base-camp tether deep-dive pushed as a TTCard page
//
// All safety-critical functions from the legacy screen are preserved.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/design_tokens.dart';
import '../models/hiker_profile.dart';
import '../providers/app_state_provider.dart';
import '../providers/profile_provider.dart';
import '../widgets/design/tt_ambient.dart';
import '../widgets/design/tt_app_bar.dart';
import '../widgets/design/tt_glass_card.dart';
import '../widgets/design/tt_pill.dart';
import '../widgets/design/tt_topo.dart';

class SafetyCenterScreen extends StatefulWidget {
  const SafetyCenterScreen({super.key});

  @override
  State<SafetyCenterScreen> createState() => _SafetyCenterScreenState();
}

class _SafetyCenterScreenState extends State<SafetyCenterScreen> {
  // Seed values used on first launch. After that the user's actual
  // list lives in SharedPreferences under `tt_gear_items` and they can
  // freely add / remove from it.
  static const List<String> _kGearSeed = <String>[
    'Headlamp',
    'Water',
    'Map',
    'First-aid',
    'Whistle',
    'Layers',
    'Compass',
    'Spare batteries',
  ];
  static const String _kGearListKey = 'tt_gear_items';
  static String _gearKey(String item) =>
      'tt_gear_${item.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_')}';

  // ── Trip check-in form ──────────────────────────────────────────────────
  final _trailCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _backpackCtrl = TextEditingController();
  final _tentCtrl = TextEditingController();
  DateTime _expectedReturn = DateTime.now().add(const Duration(hours: 8));
  bool _planLoaded = false;

  // ── Gear checklist state ────────────────────────────────────────────────
  // List of items + ticked state. Both persisted in SharedPreferences;
  // the list itself is editable via the Add/Delete actions in the UI.
  List<String> _gearItems = const <String>[];
  final Map<String, bool> _gear = <String, bool>{};
  bool _gearLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadGear();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_planLoaded) return;
    final activePlan = context.read<AppStateProvider>().activeSafetyPlan;
    if (activePlan != null) {
      _trailCtrl.text = activePlan.trailName;
      _notesCtrl.text = activePlan.notes;
      _backpackCtrl.text = activePlan.backpackColor;
      _tentCtrl.text = activePlan.tentColor;
      _expectedReturn = activePlan.expectedReturn;
    }
    _planLoaded = true;
  }

  @override
  void dispose() {
    _trailCtrl.dispose();
    _notesCtrl.dispose();
    _backpackCtrl.dispose();
    _tentCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadGear() async {
    final prefs = await SharedPreferences.getInstance();
    // List of items: persisted custom list, or seed defaults on first run.
    final stored = prefs.getStringList(_kGearListKey);
    _gearItems = stored != null
        ? List<String>.from(stored)
        : List<String>.from(_kGearSeed);
    _gear.clear();
    for (final item in _gearItems) {
      _gear[item] = prefs.getBool(_gearKey(item)) ?? false;
    }
    if (!mounted) return;
    setState(() => _gearLoaded = true);
  }

  Future<void> _toggleGear(String item) async {
    final next = !(_gear[item] ?? false);
    setState(() => _gear[item] = next);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_gearKey(item), next);
  }

  Future<void> _addGear(String raw) async {
    final item = raw.trim();
    if (item.isEmpty) return;
    // De-dupe case-insensitive — "Headlamp" and "headlamp" are the same.
    final lower = item.toLowerCase();
    if (_gearItems.any((g) => g.toLowerCase() == lower)) return;
    setState(() {
      _gearItems = [..._gearItems, item];
      _gear[item] = false;
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_kGearListKey, _gearItems);
  }

  Future<void> _removeGear(String item) async {
    setState(() {
      _gearItems = _gearItems.where((g) => g != item).toList(growable: false);
      _gear.remove(item);
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_kGearListKey, _gearItems);
    await prefs.remove(_gearKey(item));
  }

  Future<void> _pickReturnTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _expectedReturn,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 14)),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_expectedReturn),
    );
    if (time == null || !mounted) return;

    setState(() {
      _expectedReturn = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  Future<void> _savePlan() async {
    final provider = context.read<AppStateProvider>();
    await provider.setSafetyPlan(
      SafetyPlan(
        trailId: _trailCtrl.text.trim().toLowerCase().replaceAll(' ', '_'),
        trailName: _trailCtrl.text.trim().isEmpty
            ? 'Planned hike'
            : _trailCtrl.text.trim(),
        expectedReturn: _expectedReturn,
        notes: _notesCtrl.text.trim(),
        backpackColor: _backpackCtrl.text.trim(),
        tentColor: _tentCtrl.text.trim(),
        createdAt: DateTime.now(),
      ),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Safety plan saved locally.',
            style: TT.body(size: 13, color: TT.text)),
        backgroundColor: TT.surf,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _callEmergency(String phone) async {
    if (phone.trim().isEmpty) return;
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _addContactDialog() async {
    final nameCtrl = TextEditingController();
    final relCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final emailCtrl = TextEditingController();

    final added = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: TT.surf,
        title: Text('Add emergency contact',
            style: TT.body(size: 16, w: FontWeight.w800)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _DialogField(controller: nameCtrl, label: 'Name'),
              const SizedBox(height: 10),
              _DialogField(controller: relCtrl, label: 'Relationship'),
              const SizedBox(height: 10),
              _DialogField(
                controller: phoneCtrl,
                label: 'Phone',
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 10),
              _DialogField(
                controller: emailCtrl,
                label: 'Email (optional)',
                keyboardType: TextInputType.emailAddress,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancel', style: TT.body(size: 13, color: TT.text2)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Save',
                style: TT.body(size: 13, w: FontWeight.w800, color: TT.ember)),
          ),
        ],
      ),
    );

    final name = nameCtrl.text.trim();
    final relation = relCtrl.text.trim();
    final phone = phoneCtrl.text.trim();
    final email = emailCtrl.text.trim();
    nameCtrl.dispose();
    relCtrl.dispose();
    phoneCtrl.dispose();
    emailCtrl.dispose();

    if (added != true || !mounted) return;
    if (name.isEmpty && phone.isEmpty && email.isEmpty) return;

    final pp = context.read<ProfileProvider>();
    final next = List<EmergencyContact>.from(pp.profile.contacts)
      ..add(EmergencyContact(
        name: name,
        relation: relation,
        phone: phone,
        email: email,
      ));
    await pp.save(pp.profile.copyWith(contacts: next));
  }

  Future<void> _editContactDialog(int index) async {
    final pp = context.read<ProfileProvider>();
    final c = pp.profile.contacts[index];
    final nameCtrl = TextEditingController(text: c.name);
    final relCtrl = TextEditingController(text: c.relation);
    final phoneCtrl = TextEditingController(text: c.phone);
    final emailCtrl = TextEditingController(text: c.email);

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: TT.surf,
        title:
            Text('Edit contact', style: TT.body(size: 16, w: FontWeight.w800)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _DialogField(controller: nameCtrl, label: 'Name'),
              const SizedBox(height: 10),
              _DialogField(controller: relCtrl, label: 'Relationship'),
              const SizedBox(height: 10),
              _DialogField(
                controller: phoneCtrl,
                label: 'Phone',
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 10),
              _DialogField(
                controller: emailCtrl,
                label: 'Email (optional)',
                keyboardType: TextInputType.emailAddress,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancel', style: TT.body(size: 13, color: TT.text2)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Save',
                style: TT.body(size: 13, w: FontWeight.w800, color: TT.ember)),
          ),
        ],
      ),
    );

    final name = nameCtrl.text.trim();
    final relation = relCtrl.text.trim();
    final phone = phoneCtrl.text.trim();
    final email = emailCtrl.text.trim();
    nameCtrl.dispose();
    relCtrl.dispose();
    phoneCtrl.dispose();
    emailCtrl.dispose();

    if (saved != true || !mounted) return;
    final next = List<EmergencyContact>.from(pp.profile.contacts);
    next[index] = EmergencyContact(
      name: name,
      relation: relation,
      phone: phone,
      email: email,
    );
    await pp.save(pp.profile.copyWith(contacts: next));
  }

  Future<void> _removeContact(int index) async {
    final pp = context.read<ProfileProvider>();
    final name = pp.profile.contacts[index].name;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: TT.surf,
        title: Text('Remove contact?',
            style: TT.body(size: 16, w: FontWeight.w800)),
        content: Text(
          name.isEmpty
              ? 'This contact will be removed from your profile.'
              : 'Remove $name from your emergency contacts?',
          style: TT.body(size: 13, color: TT.text2).copyWith(height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancel', style: TT.body(size: 13, color: TT.text2)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Remove',
                style: TT.body(size: 13, w: FontWeight.w800, color: TT.red)),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    final next = List<EmergencyContact>.from(pp.profile.contacts)
      ..removeAt(index);
    await pp.save(pp.profile.copyWith(contacts: next));
  }

  void _openBaseCampTether() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const _BaseCampTetherScreen(),
      ),
    );
  }

  String get _returnLabel {
    final r = _expectedReturn;
    return '${r.day}/${r.month} '
        '${r.hour.toString().padLeft(2, '0')}:${r.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<ProfileProvider>().profile;
    final activePlan = context.watch<AppStateProvider>().activeSafetyPlan;
    final gearChecked = _gear.values.where((v) => v).length;

    return Scaffold(
      backgroundColor: TT.bg,
      body: Stack(
        children: [
          const Positioned.fill(child: TTAmbient()),
          const Positioned.fill(child: TTTopoBackdrop(opacity: 0.4)),
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                _SubPageAppBar(
                  title: 'Safety Center',
                  onBack: () => Navigator.of(context).pop(),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(18, 4, 18, 32),
                    children: [
                      _ActivePlanCard(
                        plan: activePlan,
                        onClear: () => context
                            .read<AppStateProvider>()
                            .setSafetyPlan(null),
                      ),
                      const SizedBox(height: 14),
                      _TripCheckInCard(
                        trailCtrl: _trailCtrl,
                        notesCtrl: _notesCtrl,
                        backpackCtrl: _backpackCtrl,
                        tentCtrl: _tentCtrl,
                        returnLabel: _returnLabel,
                        onPickReturn: _pickReturnTime,
                        onSave: _savePlan,
                      ),
                      const SizedBox(height: 14),
                      _ContactsCard(
                        contacts: profile.contacts,
                        onAdd: _addContactDialog,
                        onEdit: _editContactDialog,
                        onRemove: _removeContact,
                        onCall: _callEmergency,
                      ),
                      const SizedBox(height: 14),
                      _GearChecklistCard(
                        items: _gearItems,
                        gear: _gear,
                        loaded: _gearLoaded,
                        checked: gearChecked,
                        onToggle: _toggleGear,
                        onAdd: _addGear,
                        onRemove: _removeGear,
                      ),
                      const SizedBox(height: 14),
                      _BaseCampTetherLink(onTap: _openBaseCampTether),
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

// ─────────────────────────────────── APP BAR ─────────────────────────────────

class _SubPageAppBar extends StatelessWidget {
  final String title;
  final VoidCallback onBack;
  const _SubPageAppBar({required this.title, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 18, 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          TTIconBtn(icon: Icons.chevron_left, onTap: onBack),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const TTBrandMark(),
                const SizedBox(height: 4),
                Text(title, style: TT.title(22)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────── ACTIVE PLAN ─────────────────────────────────

class _ActivePlanCard extends StatelessWidget {
  final SafetyPlan? plan;
  final VoidCallback onClear;
  const _ActivePlanCard({required this.plan, required this.onClear});

  @override
  Widget build(BuildContext context) {
    final plan = this.plan;
    if (plan == null) {
      return TTCard(
        padding: const EdgeInsets.fromLTRB(18, 20, 18, 20),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: TT.emberSoft,
                borderRadius: BorderRadius.circular(TT.rMd),
                border: Border.all(color: const Color(0x33FF6A2C), width: 1),
              ),
              alignment: Alignment.center,
              child:
                  const Icon(Icons.shield_outlined, color: TT.ember, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('ACTIVE HIKE PLAN', style: TT.label(color: TT.text3)),
                  const SizedBox(height: 6),
                  Text('No active hike plan',
                      style: TT.title(16, color: TT.text)),
                  const SizedBox(height: 4),
                  Text('Start one from the Map tab.',
                      style: TT.body(size: 12, color: TT.text3)),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final r = plan.expectedReturn;
    final returnLabel = '${r.day}/${r.month} '
        '${r.hour.toString().padLeft(2, '0')}:${r.minute.toString().padLeft(2, '0')}';

    return TTCard(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child:
                    Text('ACTIVE HIKE PLAN', style: TT.label(color: TT.text3)),
              ),
              const TTPill(label: 'ACTIVE', variant: TTPillVariant.ember),
            ],
          ),
          const SizedBox(height: 10),
          Text(plan.trailName, style: TT.title(20)),
          const SizedBox(height: 14),
          const Divider(height: 1, thickness: 1, color: TT.line),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _MiniStat(
                  label: 'EXPECTED RETURN',
                  value: returnLabel,
                  icon: Icons.schedule_outlined,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MiniStat(
                  label: 'GEAR COLOURS',
                  value: [
                    if (plan.backpackColor.isNotEmpty)
                      'Pack ${plan.backpackColor}',
                    if (plan.tentColor.isNotEmpty) 'Tent ${plan.tentColor}',
                  ].join(' · ').ifEmpty('Not set'),
                  icon: Icons.color_lens_outlined,
                ),
              ),
            ],
          ),
          if (plan.notes.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0x07FFFFFF),
                borderRadius: BorderRadius.circular(TT.rMd),
                border: Border.all(color: TT.line, width: 1),
              ),
              child: Text(
                plan.notes,
                style: TT
                    .body(size: 12, color: TT.text2, w: FontWeight.w500)
                    .copyWith(height: 1.5),
              ),
            ),
          ],
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: onClear,
              icon: const Icon(Icons.close_rounded, size: 16, color: TT.text2),
              label: Text('Clear active plan',
                  style: TT.body(size: 12, color: TT.text2)),
            ),
          ),
        ],
      ),
    );
  }
}

extension on String {
  String ifEmpty(String fallback) => isEmpty ? fallback : this;
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  const _MiniStat(
      {required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0x07FFFFFF),
        borderRadius: BorderRadius.circular(TT.rMd),
        border: Border.all(color: TT.line, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 12, color: TT.ember),
              const SizedBox(width: 6),
              Expanded(child: Text(label, style: TT.label(color: TT.text3))),
            ],
          ),
          const SizedBox(height: 6),
          Text(value,
              style: TT.body(size: 13, w: FontWeight.w800, color: TT.text)),
        ],
      ),
    );
  }
}

// ──────────────────────────────── TRIP CHECK-IN ──────────────────────────────

class _TripCheckInCard extends StatelessWidget {
  final TextEditingController trailCtrl;
  final TextEditingController notesCtrl;
  final TextEditingController backpackCtrl;
  final TextEditingController tentCtrl;
  final String returnLabel;
  final VoidCallback onPickReturn;
  final VoidCallback onSave;

  const _TripCheckInCard({
    required this.trailCtrl,
    required this.notesCtrl,
    required this.backpackCtrl,
    required this.tentCtrl,
    required this.returnLabel,
    required this.onPickReturn,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return TTCard(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.assignment_turned_in_outlined,
                  color: TT.ember, size: 18),
              const SizedBox(width: 8),
              Text('Trip check-in', style: TT.title(16)),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(height: 1, thickness: 1, color: TT.line),
          const SizedBox(height: 14),
          _TTField(controller: trailCtrl, label: 'Trail or plan name'),
          const SizedBox(height: 12),
          _ReturnRow(label: returnLabel, onTap: onPickReturn),
          const SizedBox(height: 12),
          _TTField(
              controller: notesCtrl,
              label: 'Notes for your contact',
              maxLines: 3),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _TTField(
                    controller: backpackCtrl, label: 'Backpack colour'),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _TTField(controller: tentCtrl, label: 'Tent colour'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: _EmberButton(
                icon: Icons.save_outlined,
                label: 'Save safety plan',
                onTap: onSave),
          ),
        ],
      ),
    );
  }
}

class _ReturnRow extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _ReturnRow({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0x07FFFFFF),
          borderRadius: BorderRadius.circular(TT.rMd),
          border: Border.all(color: TT.line, width: 1),
        ),
        child: Row(
          children: [
            const Icon(Icons.schedule_outlined, color: TT.ember, size: 16),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('EXPECTED RETURN', style: TT.label(color: TT.text3)),
                  const SizedBox(height: 4),
                  Text(label,
                      style: TT.body(
                          size: 13, w: FontWeight.w800, color: TT.text)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: TT.text3, size: 18),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────── CONTACTS ────────────────────────────────

class _ContactsCard extends StatelessWidget {
  final List<EmergencyContact> contacts;
  final VoidCallback onAdd;
  final ValueChanged<int> onEdit;
  final ValueChanged<int> onRemove;
  final ValueChanged<String> onCall;

  const _ContactsCard({
    required this.contacts,
    required this.onAdd,
    required this.onEdit,
    required this.onRemove,
    required this.onCall,
  });

  @override
  Widget build(BuildContext context) {
    return TTCard(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.contact_emergency_outlined,
                  color: TT.ember, size: 18),
              const SizedBox(width: 8),
              Expanded(child: Text('Emergency contacts', style: TT.title(16))),
              _SmallChipBtn(
                icon: Icons.add_rounded,
                label: 'ADD',
                onTap: onAdd,
                ember: true,
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(height: 1, thickness: 1, color: TT.line),
          const SizedBox(height: 14),
          if (contacts.isEmpty)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0x07FFFFFF),
                borderRadius: BorderRadius.circular(TT.rMd),
                border: Border.all(color: TT.line, width: 1),
              ),
              child: Text(
                'No emergency contacts saved yet. Add one before you head out so a trusted person knows your plan.',
                style: TT
                    .body(size: 12, color: TT.text2, w: FontWeight.w500)
                    .copyWith(height: 1.5),
              ),
            )
          else
            for (var i = 0; i < contacts.length; i++) ...[
              _ContactRow(
                contact: contacts[i],
                onEdit: () => onEdit(i),
                onRemove: () => onRemove(i),
                onCall: onCall,
              ),
              if (i < contacts.length - 1) ...[
                const SizedBox(height: 10),
                const Divider(height: 1, thickness: 1, color: TT.line),
                const SizedBox(height: 10),
              ],
            ],
        ],
      ),
    );
  }
}

class _ContactRow extends StatelessWidget {
  final EmergencyContact contact;
  final VoidCallback onEdit;
  final VoidCallback onRemove;
  final ValueChanged<String> onCall;

  const _ContactRow({
    required this.contact,
    required this.onEdit,
    required this.onRemove,
    required this.onCall,
  });

  String get _initials {
    final n = contact.name.trim();
    if (n.isEmpty) return '?';
    final parts = n.split(RegExp(r'\s+'));
    final a = parts.first.characters.firstOrNull ?? '?';
    final b = parts.length > 1 ? (parts.last.characters.firstOrNull ?? '') : '';
    return (a + b).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onLongPress: onRemove,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _GradientAvatar(initials: _initials),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  contact.name.isEmpty ? 'Unnamed contact' : contact.name,
                  style: TT.body(size: 14, w: FontWeight.w800, color: TT.text),
                ),
                const SizedBox(height: 2),
                Text(
                  contact.relation.isEmpty
                      ? 'Primary contact'
                      : contact.relation,
                  style: TT.body(size: 11, color: TT.text3),
                ),
                if (contact.phone.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: () => onCall(contact.phone),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.call_outlined,
                            size: 13, color: TT.ember),
                        const SizedBox(width: 5),
                        Text(
                          contact.phone,
                          style: TT.body(
                              size: 12, w: FontWeight.w700, color: TT.ember),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          _SmallChipBtn(
            icon: Icons.edit_outlined,
            label: 'EDIT',
            onTap: onEdit,
          ),
          const SizedBox(width: 6),
          _SmallChipBtn(
            icon: Icons.delete_outline_rounded,
            label: 'REMOVE',
            onTap: onRemove,
            danger: true,
          ),
        ],
      ),
    );
  }
}

class _GradientAvatar extends StatelessWidget {
  final String initials;
  const _GradientAvatar({required this.initials});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [TT.ember, Color(0xFFB94517)],
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
              color: Color(0x52FF6A2C),
              blurRadius: 14,
              spreadRadius: -4,
              offset: Offset(0, 4)),
        ],
      ),
      child: Text(
        initials,
        style: TT.body(size: 13, w: FontWeight.w900, color: TT.emberInk),
      ),
    );
  }
}

// ─────────────────────────────── GEAR CHECKLIST ──────────────────────────────

class _GearChecklistCard extends StatefulWidget {
  final List<String> items;
  final Map<String, bool> gear;
  final bool loaded;
  final int checked;
  final ValueChanged<String> onToggle;
  final ValueChanged<String> onAdd;
  final ValueChanged<String> onRemove;

  const _GearChecklistCard({
    required this.items,
    required this.gear,
    required this.loaded,
    required this.checked,
    required this.onToggle,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  State<_GearChecklistCard> createState() => _GearChecklistCardState();
}

class _GearChecklistCardState extends State<_GearChecklistCard> {
  final _addCtrl = TextEditingController();
  final _addFocus = FocusNode();

  @override
  void dispose() {
    _addCtrl.dispose();
    _addFocus.dispose();
    super.dispose();
  }

  void _submitAdd() {
    final text = _addCtrl.text;
    if (text.trim().isEmpty) return;
    widget.onAdd(text);
    _addCtrl.clear();
    _addFocus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.items;
    final gear = widget.gear;
    final total = items.length;
    final pct = total == 0 ? 0.0 : widget.checked / total;

    return TTCard(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.backpack_outlined, color: TT.ember, size: 18),
              const SizedBox(width: 8),
              Expanded(child: Text('Gear checklist', style: TT.title(16))),
              Text('${widget.checked} / $total',
                  style:
                      TT.mono(size: 12, color: TT.ember, letterSpacing: 0.8)),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Stack(
              children: [
                Container(height: 6, color: const Color(0x14FFFFFF)),
                LayoutBuilder(builder: (_, c) {
                  return AnimatedContainer(
                    duration: TT.dMed,
                    curve: TT.easeOut,
                    height: 6,
                    width: c.maxWidth * pct,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [TT.ember, TT.ember2],
                      ),
                      boxShadow: [
                        BoxShadow(
                            color: Color(0x73FF6A2C),
                            blurRadius: 10,
                            spreadRadius: -2),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, thickness: 1, color: TT.line),
          const SizedBox(height: 8),
          if (!widget.loaded)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Center(
                child: Text('Loading checklist…',
                    style: TT.body(size: 12, color: TT.text3)),
              ),
            )
          else ...[
            if (items.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Text(
                  'No gear yet. Add your first item below.',
                  style: TT.body(size: 12, color: TT.text3),
                ),
              )
            else
              for (final item in items)
                _GearRow(
                  label: item,
                  checked: gear[item] ?? false,
                  onToggle: () => widget.onToggle(item),
                  onRemove: () => widget.onRemove(item),
                ),
            const SizedBox(height: 6),
            const Divider(height: 1, thickness: 1, color: TT.line),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 22,
                  height: 22,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0x14FFFFFF),
                    border: Border.all(color: TT.line2, width: 1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child:
                      const Icon(Icons.add_rounded, size: 14, color: TT.ember),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _addCtrl,
                    focusNode: _addFocus,
                    style: TT.body(size: 13, w: FontWeight.w700),
                    cursorColor: TT.ember,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _submitAdd(),
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: 'Add gear (e.g. Sleeping bag, GPS, …)',
                      hintStyle: TT.body(
                          size: 13, color: TT.text3, w: FontWeight.w600),
                      border: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: _submitAdd,
                  style: TextButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    minimumSize: const Size(0, 32),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text('ADD',
                      style: TT.mono(
                          size: 11, color: TT.ember, letterSpacing: 1.4)),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _GearRow extends StatelessWidget {
  final String label;
  final bool checked;
  final VoidCallback onToggle;
  final VoidCallback onRemove;
  const _GearRow({
    required this.label,
    required this.checked,
    required this.onToggle,
    required this.onRemove,
  });

  void _confirmRemove(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: TT.surf,
        title: Text('Remove "$label"?', style: TT.title(15)),
        content: Text(
          'It will be removed from your checklist.',
          style: TT.body(size: 12, color: TT.text2),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: TT.red),
            child: const Text('REMOVE'),
          ),
        ],
      ),
    );
    if (ok == true) onRemove();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onToggle,
      onLongPress: () => _confirmRemove(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(
          children: [
            AnimatedContainer(
              duration: TT.dFast,
              curve: TT.easeOut,
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: checked ? TT.ember : const Color(0x07FFFFFF),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: checked ? const Color(0x66FF6A2C) : TT.line2,
                  width: 1,
                ),
                boxShadow: checked
                    ? const [
                        BoxShadow(
                            color: Color(0x52FF6A2C),
                            blurRadius: 10,
                            spreadRadius: -3,
                            offset: Offset(0, 3)),
                      ]
                    : null,
              ),
              alignment: Alignment.center,
              child: checked
                  ? const Icon(Icons.check_rounded,
                      size: 14, color: TT.emberInk)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AnimatedDefaultTextStyle(
                duration: TT.dFast,
                style: TT
                    .body(
                      size: 13,
                      w: FontWeight.w700,
                      color: checked ? TT.text3 : TT.text,
                    )
                    .copyWith(
                      decoration: checked
                          ? TextDecoration.lineThrough
                          : TextDecoration.none,
                      decorationColor: TT.text3,
                    ),
                child: Text(label),
              ),
            ),
            // Tappable trash chip — discoverable for users who don't
            // know about the long-press affordance.
            IconButton(
              onPressed: () => _confirmRemove(context),
              icon: const Icon(Icons.close_rounded, size: 16, color: TT.text3),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              tooltip: 'Remove',
              splashRadius: 18,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────── BASE-CAMP TETHER ────────────────────────────

class _BaseCampTetherLink extends StatelessWidget {
  final VoidCallback onTap;
  const _BaseCampTetherLink({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return TTCard(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: TT.emberSoft,
              borderRadius: BorderRadius.circular(TT.rMd),
              border: Border.all(color: const Color(0x33FF6A2C), width: 1),
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.desktop_windows_outlined,
                color: TT.ember, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('BASE-CAMP TETHER', style: TT.label(color: TT.ember)),
                const SizedBox(height: 4),
                Text('Live mobile → PC tracking',
                    style: TT.title(15, color: TT.text)),
                const SizedBox(height: 4),
                Text(
                  'Pair your phone with the desktop watcher so a trusted person can see your live position.',
                  style:
                      TT.body(size: 11, color: TT.text3).copyWith(height: 1.5),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.chevron_right, color: TT.text3, size: 22),
        ],
      ),
    );
  }
}

class _BaseCampTetherScreen extends StatelessWidget {
  const _BaseCampTetherScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TT.bg,
      body: Stack(
        children: [
          const Positioned.fill(child: TTAmbient()),
          const Positioned.fill(child: TTTopoBackdrop(opacity: 0.4)),
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                _SubPageAppBar(
                  title: 'Base-camp tether',
                  onBack: () => Navigator.of(context).pop(),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(18, 4, 18, 32),
                    children: [
                      TTCard(
                        padding: const EdgeInsets.fromLTRB(18, 20, 18, 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('LIVE TRACKING',
                                style: TT.label(color: TT.ember)),
                            const SizedBox(height: 8),
                            Text('Mobile → PC tether', style: TT.title(20)),
                            const SizedBox(height: 12),
                            Text(
                              'Base-camp tether streams your phone GPS to the Trailtether desktop watcher so a partner at home can follow your hike in real time.',
                              style: TT
                                  .body(
                                      size: 13,
                                      color: TT.text2,
                                      w: FontWeight.w500)
                                  .copyWith(height: 1.6),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      const _TetherBullet(
                        icon: Icons.qr_code_2_rounded,
                        title: 'Pair once with a QR',
                        body:
                            'Open Pair Device on the desktop watcher and follow its QR prompt. Pairing is end-to-end on a single Trailtether account.',
                      ),
                      const _TetherBullet(
                        icon: Icons.location_on_outlined,
                        title: 'Streams every fresh GPS fix',
                        body:
                            'While a hike is recording, each new location update is pushed to your paired desktop watcher within seconds.',
                      ),
                      const _TetherBullet(
                        icon: Icons.notifications_active_outlined,
                        title: 'Triggers alerts on missed check-ins',
                        body:
                            'If you blow past your expected return time without finishing the hike, the desktop watcher escalates a notification.',
                      ),
                      const _TetherBullet(
                        icon: Icons.lock_outline_rounded,
                        title: 'Visible only to your watcher',
                        body:
                            'Your live position is never shared publicly. Only the desktop watcher signed into your account can see it.',
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: TT.emberSoft,
                          borderRadius: BorderRadius.circular(TT.rMd),
                          border: Border.all(
                              color: const Color(0x52FF6A2C), width: 1),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline_rounded,
                                color: TT.ember, size: 18),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Set up pairing from the desktop watcher once it is running and signed into your account.',
                                style: TT
                                    .body(
                                        size: 12,
                                        color: TT.ember,
                                        w: FontWeight.w700)
                                    .copyWith(height: 1.5),
                              ),
                            ),
                          ],
                        ),
                      ),
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

class _TetherBullet extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  const _TetherBullet({
    required this.icon,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TTCard(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: TT.emberSoft,
                borderRadius: BorderRadius.circular(TT.rSm),
                border: Border.all(color: const Color(0x33FF6A2C), width: 1),
              ),
              alignment: Alignment.center,
              child: Icon(icon, color: TT.ember, size: 16),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TT.body(
                          size: 13, w: FontWeight.w800, color: TT.text)),
                  const SizedBox(height: 4),
                  Text(
                    body,
                    style: TT
                        .body(size: 12, color: TT.text2)
                        .copyWith(height: 1.5),
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

// ───────────────────────────────── SHARED BITS ───────────────────────────────

class _TTField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final int maxLines;
  const _TTField({
    required this.controller,
    required this.label,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: TT.body(size: 13, color: TT.text),
      cursorColor: TT.ember,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TT.body(size: 12, color: TT.text2),
        filled: true,
        fillColor: TT.bg3,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
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
    );
  }
}

class _DialogField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final TextInputType keyboardType;
  const _DialogField({
    required this.controller,
    required this.label,
    this.keyboardType = TextInputType.text,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: TT.body(size: 13, color: TT.text),
      cursorColor: TT.ember,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TT.body(size: 12, color: TT.text2),
        filled: true,
        fillColor: TT.bg3,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
    );
  }
}

class _EmberButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _EmberButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: TT.ember,
          borderRadius: BorderRadius.circular(TT.rMd),
          boxShadow: TT.shadowEmber,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: TT.emberInk, size: 16),
            const SizedBox(width: 8),
            Text(
              label,
              style: TT
                  .body(size: 13, w: FontWeight.w900, color: TT.emberInk)
                  .copyWith(letterSpacing: 0.6),
            ),
          ],
        ),
      ),
    );
  }
}

class _SmallChipBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool ember;
  final bool danger;
  const _SmallChipBtn({
    required this.icon,
    required this.label,
    required this.onTap,
    this.ember = false,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    Color bg, fg, border;
    if (danger) {
      bg = const Color(0x1AE63D2E);
      fg = TT.red;
      border = const Color(0x59E63D2E);
    } else if (ember) {
      bg = TT.emberDim;
      fg = TT.ember;
      border = const Color(0x52FF6A2C);
    } else {
      bg = const Color(0x07FFFFFF);
      fg = TT.text2;
      border = TT.line2;
    }
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: 26,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: border, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: fg),
            const SizedBox(width: 5),
            Text(
              label,
              style: TT.mono(size: 9.5, color: fg, letterSpacing: 1.0),
            ),
          ],
        ),
      ),
    );
  }
}
