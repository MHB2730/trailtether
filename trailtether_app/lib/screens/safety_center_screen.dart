import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/constants.dart';
import '../providers/app_state_provider.dart';
import '../providers/profile_provider.dart';

class SafetyCenterScreen extends StatefulWidget {
  const SafetyCenterScreen({super.key});

  @override
  State<SafetyCenterScreen> createState() => _SafetyCenterScreenState();
}

class _SafetyCenterScreenState extends State<SafetyCenterScreen> {
  final _trailCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _backpackCtrl = TextEditingController();
  final _tentCtrl = TextEditingController();
  DateTime _expectedReturn = DateTime.now().add(const Duration(hours: 8));
  bool _planLoaded = false; // ensures we only pre-fill once

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
      const SnackBar(content: Text('Safety plan saved locally.')),
    );
  }

  Future<void> _callEmergency(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<ProfileProvider>().profile;
    final appState = context.watch<AppStateProvider>();
    final activePlan = appState.activeSafetyPlan;
    final returnLabel =
        '${_expectedReturn.day}/${_expectedReturn.month} ${_expectedReturn.hour.toString().padLeft(2, '0')}:${_expectedReturn.minute.toString().padLeft(2, '0')}';

    return Scaffold(
      backgroundColor: kColorBg,
      appBar: AppBar(
        backgroundColor: kColorBg,
        foregroundColor: kColorCream,
        elevation: 0,
        title: Text(
          'Safety Center',
          style: GoogleFonts.outfit(
            color: kColorCream,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          _SectionCard(
            title: 'Trip Check-In',
            icon: Icons.shield_outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Field(controller: _trailCtrl, label: 'Trail or plan name'),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: _pickReturnTime,
                  child: _InfoTile(
                    icon: Icons.schedule_outlined,
                    title: 'Expected return',
                    subtitle: returnLabel,
                  ),
                ),
                const SizedBox(height: 12),
                _Field(
                  controller: _notesCtrl,
                  label: 'Notes for your contact',
                  maxLines: 3,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                        child: _Field(
                            controller: _backpackCtrl,
                            label: 'Backpack color')),
                    const SizedBox(width: 12),
                    Expanded(
                        child:
                            _Field(controller: _tentCtrl, label: 'Tent color')),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _savePlan,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kColorOrange,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Save Safety Plan'),
                  ),
                ),
                if (activePlan != null) ...[
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: () =>
                        context.read<AppStateProvider>().setSafetyPlan(null),
                    child: const Text('Clear active plan'),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: 'Emergency Contacts',
            icon: Icons.emergency_outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (profile.contacts.isEmpty)
                  Text(
                    'No emergency contacts saved yet. Add them in your profile before you head out.',
                    style: GoogleFonts.outfit(
                      color: kColorCream.withOpacity(0.55),
                      fontSize: 12,
                    ),
                  )
                else
                  ...profile.contacts.map((c) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Column(
                          children: [
                            _InfoTile(
                              icon: Icons.person_outline,
                              title: c.name.isEmpty ? 'Contact' : c.name,
                              subtitle: c.relation.isEmpty
                                  ? 'Primary contact'
                                  : c.relation,
                            ),
                            if (c.phone.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  onPressed: () => _callEmergency(c.phone),
                                  icon:
                                      const Icon(Icons.call_outlined, size: 16),
                                  label: Text(c.phone,
                                      style: const TextStyle(fontSize: 12)),
                                ),
                              ),
                            ],
                          ],
                        ),
                      )),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: kColorPanel,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: kColorBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: kColorOrange, size: 18),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: GoogleFonts.outfit(
                    color: kColorCream,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            child,
          ],
        ),
      );
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final int maxLines;

  const _Field({
    required this.controller,
    required this.label,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) => TextField(
        controller: controller,
        maxLines: maxLines,
        style: GoogleFonts.outfit(color: kColorCream),
        decoration: InputDecoration(labelText: label),
      );
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _InfoTile({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: kColorBorder),
        ),
        child: Row(
          children: [
            Icon(icon, color: kColorOrange, size: 16),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.outfit(
                      color: kColorCream,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.outfit(
                      color: kColorCream.withOpacity(0.45),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}
