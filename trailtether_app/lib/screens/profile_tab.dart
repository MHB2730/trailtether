import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../core/constants.dart';
import '../core/utils.dart';
import '../models/achievement.dart';
import '../models/hiker_profile.dart';
import '../providers/profile_provider.dart';
import '../providers/auth_provider.dart' as ap;
import '../widgets/common/user_avatar.dart';
import 'admin/diagnostic_console.dart';

// ══════════════════════════════════════════════════════════════════════════════
// Profile Tab
// ══════════════════════════════════════════════════════════════════════════════
class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key});
  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  bool _editing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<ProfileProvider>().refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ProfileProvider>(
      builder: (_, pp, __) {
        if (pp.loading) {
          return const Center(
            child: CircularProgressIndicator(
              color: kColorOrange,
              strokeWidth: 2,
            ),
          );
        }

        return Scaffold(
          backgroundColor: kColorBg,
          body: SafeArea(
            child: _editing
                ? _EditForm(
                    profile: pp.profile,
                    saving: pp.saving,
                    onSave: (updated) async {
                      final ok = await pp.save(updated);
                      if (ok && mounted) setState(() => _editing = false);
                    },
                    onCancel: () => setState(() => _editing = false),
                  )
                : _ProfileView(
                    profile: pp.profile,
                    onEdit: () => setState(() => _editing = true),
                  ),
          ),
        );
      },
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Profile View (read mode)
// ══════════════════════════════════════════════════════════════════════════════
class _ProfileView extends StatelessWidget {
  final HikerProfile profile;
  final VoidCallback onEdit;
  const _ProfileView({required this.profile, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final pp = context.watch<ProfileProvider>();
    final auth = context.read<ap.AuthProvider>();
    final hasAuth = auth.user != null;
    final name = profile.displayName.isNotEmpty
        ? profile.displayName
        : (auth.displayName ?? 'Explorer');
    final email =
        profile.email.isNotEmpty ? profile.email : (auth.user?.email ?? '');
    const expColors = {
      'beginner': Color(0xFF4CAF50),
      'intermediate': Color(0xFF2196F3),
      'advanced': Color(0xFFFF9800),
      'expert': Color(0xFFE53935),
    };
    final lvlColor = expColors[profile.experienceLevel] ?? kColorOrange;

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // ── Avatar + identity ──────────────────────────────────
                Row(
                  children: [
                    // Avatar — tap to upload a profile photo
                    _AvatarPhoto(profile: profile, fallbackInitial: name),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name,
                              style: GoogleFonts.outfit(
                                  color: kColorCream,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800)),
                          if (email.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(email,
                                style: GoogleFonts.outfit(
                                    color: kColorCream.withOpacity(0.45),
                                    fontSize: 13)),
                          ],
                          const SizedBox(height: 6),
                          // Experience badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 3),
                            decoration: BoxDecoration(
                              color: lvlColor.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(20),
                              border:
                                  Border.all(color: lvlColor.withOpacity(0.4)),
                            ),
                            child: Text(
                              profile.experienceLevel.toUpperCase(),
                              style: GoogleFonts.outfit(
                                  color: lvlColor,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.8),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Edit button
                    GestureDetector(
                      onTap: onEdit,
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: kColorPanel,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: kColorBorder),
                        ),
                        child: const Icon(Icons.edit_outlined,
                            color: kColorOrange, size: 18),
                      ),
                    ),
                  ],
                ),

                // ── Bio ───────────────────────────────────────────────
                if (profile.bio.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: kColorPanel,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: kColorBorder),
                    ),
                    child: Text(profile.bio,
                        style: GoogleFonts.outfit(
                            color: kColorCream.withOpacity(0.7),
                            fontSize: 13,
                            height: 1.5)),
                  ),
                ],

                const SizedBox(height: 20),

                // ── Stats ──────────────────────────────────────────────
                _StatsGrid(
                  dist: pp.totalDistance,
                  ascent: pp.totalAscent,
                  count: pp.hikeCount,
                ),

                const SizedBox(height: 20),

                // ── Achievements ───────────────────────────────────────
                _AchievementSection(
                    achievements:
                        context.watch<ProfileProvider>().achievements),

                const SizedBox(height: 24),

                // ── Contact ────────────────────────────────────────────
                if (profile.phone.isNotEmpty)
                  _Section(
                    icon: Icons.phone_outlined,
                    title: 'Contact',
                    children: [
                      _InfoRow(
                        label: 'Phone',
                        value: profile.phone,
                        onTap: () =>
                            TrailUtils.launchUrlSafe('tel:${profile.phone}'),
                      ),
                      if (email.isNotEmpty)
                        _InfoRow(
                          label: 'Email',
                          value: email,
                          onTap: () =>
                              TrailUtils.launchUrlSafe('mailto:$email'),
                        ),
                    ],
                  ),

                const SizedBox(height: 14),

                // ── Emergency contact ──────────────────────────────────
                _EmergencyCard(profile: profile),

                const SizedBox(height: 14),

                // ── Medical ────────────────────────────────────────────
                _MedicalCard(profile: profile),

                const SizedBox(height: 14),

                // ── Auth info ──────────────────────────────────────────
                if (hasAuth)
                  _Section(
                    icon: Icons.security_outlined,
                    title: 'Account',
                    children: [
                      const _InfoRow(label: 'Status', value: 'Signed in'),
                      _InfoRow(
                          label: 'UID',
                          value: '${(auth.uid ?? '').substring(0, 12)}…'),
                    ],
                  ),

                if (!hasAuth)
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: kColorPanel,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: kColorBorder),
                    ),
                    child: Row(children: [
                      const Icon(Icons.info_outline,
                          color: kColorOrange, size: 16),
                      const SizedBox(width: 10),
                      Expanded(
                          child: Text(
                        'Sign in to sync your profile across devices',
                        style: GoogleFonts.outfit(
                            color: kColorCream.withOpacity(0.55), fontSize: 12),
                      )),
                    ]),
                  ),

                // ── Diagnostics ───────────────────────────────────────
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: kColorOrange,
                      side: const BorderSide(color: kColorOrange, width: 1),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                    ),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const DiagnosticConsole()),
                    ),
                    icon: const Icon(Icons.bug_report_outlined, size: 16),
                    label: Text('System Diagnostics',
                        style: GoogleFonts.outfit(
                            fontWeight: FontWeight.w600, fontSize: 13)),
                  ),
                ),

                // ── Logout ─────────────────────────────────────────────
                if (hasAuth) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFE53935),
                        side: const BorderSide(
                            color: Color(0xFFE53935), width: 1),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                      ),
                      onPressed: () async {
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (_) => AlertDialog(
                            backgroundColor: const Color(0xFF1A1A1A),
                            title: Text('Sign out?',
                                style: GoogleFonts.outfit(
                                    color: kColorCream,
                                    fontWeight: FontWeight.w700)),
                            content: Text(
                                'You will be signed out of Trailtether.',
                                style: GoogleFonts.outfit(
                                    color: kColorCream.withOpacity(0.7),
                                    fontSize: 13)),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: Text('Cancel',
                                    style: GoogleFonts.outfit(
                                        color: kColorCream.withOpacity(0.5))),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: Text('Sign out',
                                    style: GoogleFonts.outfit(
                                        color: const Color(0xFFE53935),
                                        fontWeight: FontWeight.w700)),
                              ),
                            ],
                          ),
                        );
                        if (confirmed == true && context.mounted) {
                          await context.read<ap.AuthProvider>().signOut();
                        }
                      },
                      icon: const Icon(Icons.logout, size: 16),
                      label: Text('Sign Out',
                          style: GoogleFonts.outfit(
                              fontWeight: FontWeight.w600, fontSize: 13)),
                    ),
                  ),
                ],

                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── Avatar with photo upload ───────────────────────────────────────────────────
class _AvatarPhoto extends StatelessWidget {
  final HikerProfile profile;
  final String fallbackInitial;
  const _AvatarPhoto({required this.profile, required this.fallbackInitial});

  Future<void> _showPickerSheet(BuildContext context) async {
    final pp = context.read<ProfileProvider>();
    final hasPhoto = profile.photoUrl.isNotEmpty;
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: kColorPanel,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: kColorBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            ListTile(
              leading:
                  const Icon(Icons.photo_library_outlined, color: kColorOrange),
              title: Text('Choose from gallery',
                  style: GoogleFonts.outfit(color: kColorCream)),
              onTap: () => Navigator.pop(context, 'gallery'),
            ),
            ListTile(
              leading:
                  const Icon(Icons.camera_alt_outlined, color: kColorOrange),
              title: Text('Take a photo',
                  style: GoogleFonts.outfit(color: kColorCream)),
              onTap: () => Navigator.pop(context, 'camera'),
            ),
            if (hasPhoto)
              ListTile(
                leading:
                    const Icon(Icons.delete_outline, color: Colors.redAccent),
                title: Text('Remove photo',
                    style: GoogleFonts.outfit(color: Colors.redAccent)),
                onTap: () => Navigator.pop(context, 'remove'),
              ),
            const SizedBox(height: 6),
          ],
        ),
      ),
    );
    if (choice == null) return;
    if (choice == 'remove') {
      await pp.removePhoto();
      return;
    }
    final source =
        choice == 'camera' ? ImageSource.camera : ImageSource.gallery;
    final result = await pp.pickAndUploadPhoto(source: source);
    if (!context.mounted) return;
    if (result == 'ok' || result == 'cancelled') return;
    if (result == 'no-auth') {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sign in to upload a profile photo')));
      return;
    }
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('Photo upload failed: $result')));
  }

  @override
  Widget build(BuildContext context) {
    final uploading = context.watch<ProfileProvider>().uploadingPhoto;
    return GestureDetector(
      onTap: uploading ? null : () => _showPickerSheet(context),
      child: Stack(
        children: [
          UserAvatar(
            photoUrl: profile.photoUrl,
            displayName: fallbackInitial,
            radius: 37,
            backgroundColor: kColorOrange.withOpacity(0.15),
          ),
          // Edit camera badge
          if (!uploading)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: kColorOrange,
                  border: Border.all(color: kColorBg, width: 2),
                ),
                child:
                    const Icon(Icons.camera_alt, color: Colors.white, size: 13),
              ),
            ),
          // Uploading overlay
          if (uploading)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black.withOpacity(0.5),
                ),
                child: const Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Emergency card ─────────────────────────────────────────────────────────────
class _EmergencyCard extends StatelessWidget {
  final HikerProfile profile;
  const _EmergencyCard({required this.profile});

  Future<void> _call(String phone) async {
    await TrailUtils.launchUrlSafe('tel:$phone');
  }

  @override
  Widget build(BuildContext context) {
    final contacts = profile.contacts;
    final hasContacts = contacts.isNotEmpty;

    return Column(
      children: [
        if (!hasContacts)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.06),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.redAccent.withOpacity(0.35)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Icon(Icons.emergency,
                      color: Colors.redAccent, size: 16),
                  const SizedBox(width: 8),
                  Text('Emergency Contacts',
                      style: GoogleFonts.outfit(
                          color: Colors.redAccent,
                          fontSize: 13,
                          fontWeight: FontWeight.w700)),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text(
                                'Tap "Edit" at the top to add your emergency contacts'))),
                    child: Text('Add now →',
                        style: GoogleFonts.outfit(
                            color: Colors.redAccent.withOpacity(0.7),
                            fontSize: 12)),
                  ),
                ]),
                const SizedBox(height: 8),
                Text(
                    'No emergency contacts saved. Add them for safety on the trail.',
                    style: GoogleFonts.outfit(
                        color: kColorCream.withOpacity(0.35), fontSize: 12)),
              ],
            ),
          )
        else
          ...contacts.map((c) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(14),
                    border:
                        Border.all(color: Colors.redAccent.withOpacity(0.35)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        const Icon(Icons.emergency,
                            color: Colors.redAccent, size: 16),
                        const SizedBox(width: 8),
                        Text(
                            c.relation.isNotEmpty
                                ? c.relation.toUpperCase()
                                : 'CONTACT',
                            style: GoogleFonts.outfit(
                                color: Colors.redAccent,
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.1)),
                      ]),
                      const SizedBox(height: 12),
                      _InfoRow(
                          label: 'Name',
                          value: c.name,
                          valueColor: kColorCream),
                      if (c.phone.isNotEmpty)
                        _InfoRow(
                          label: 'Phone',
                          value: c.phone,
                          valueColor: kColorCream,
                          trailing: GestureDetector(
                            onTap: () => _call(c.phone),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: Colors.redAccent.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                    color: Colors.redAccent.withOpacity(0.4)),
                              ),
                              child: const Icon(Icons.phone,
                                  color: Colors.redAccent, size: 14),
                            ),
                          ),
                        ),
                      if (c.email.isNotEmpty)
                        _InfoRow(
                          label: 'Email',
                          value: c.email,
                          valueColor: kColorCream,
                          onTap: () =>
                              TrailUtils.launchUrlSafe('mailto:${c.email}'),
                        ),
                    ],
                  ),
                ),
              )),
      ],
    );
  }
}

// ── Medical card ───────────────────────────────────────────────────────────────
class _MedicalCard extends StatelessWidget {
  final HikerProfile profile;
  const _MedicalCard({required this.profile});

  @override
  Widget build(BuildContext context) {
    final hasInfo = profile.bloodType.isNotEmpty ||
        profile.allergies.isNotEmpty ||
        profile.medications.isNotEmpty ||
        profile.medicalConditions.isNotEmpty;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kColorPanel,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kColorBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.medical_services_outlined,
                color: Color(0xFF2196F3), size: 16),
            const SizedBox(width: 8),
            Text('Medical Information',
                style: GoogleFonts.outfit(
                    color: const Color(0xFF2196F3),
                    fontSize: 13,
                    fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 12),
          if (!hasInfo)
            Text(
                'No medical info saved. This helps first responders in an emergency.',
                style: GoogleFonts.outfit(
                    color: kColorCream.withOpacity(0.35), fontSize: 12))
          else ...[
            if (profile.bloodType.isNotEmpty)
              _InfoRow(label: 'Blood Type', value: profile.bloodType),
            if (profile.allergies.isNotEmpty)
              _InfoRow(
                  label: 'Allergies',
                  value: profile.allergies.join(', '),
                  valueColor: const Color(0xFFFF9800)),
            if (profile.medications.isNotEmpty)
              _InfoRow(label: 'Medications', value: profile.medications),
            if (profile.medicalConditions.isNotEmpty)
              _InfoRow(label: 'Conditions', value: profile.medicalConditions),
            if (profile.doctorName.isNotEmpty)
              _InfoRow(label: 'Doctor', value: profile.doctorName),
            if (profile.doctorPhone.isNotEmpty)
              _InfoRow(label: 'Dr Phone', value: profile.doctorPhone),
          ],
        ],
      ),
    );
  }
}

// ── Section wrapper ────────────────────────────────────────────────────────────
class _Section extends StatelessWidget {
  final IconData icon;
  final String title;
  final List<Widget> children;
  const _Section(
      {required this.icon, required this.title, required this.children});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: kColorPanel,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: kColorBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon, color: kColorOrange, size: 16),
              const SizedBox(width: 8),
              Text(title,
                  style: GoogleFonts.outfit(
                      color: kColorOrange,
                      fontSize: 13,
                      fontWeight: FontWeight.w700)),
            ]),
            const SizedBox(height: 10),
            ...children,
          ],
        ),
      );
}

class _InfoRow extends StatelessWidget {
  final String label, value;
  final Color? valueColor;
  final VoidCallback? onTap;
  final Widget? trailing;
  const _InfoRow({
    required this.label,
    required this.value,
    this.valueColor,
    this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(label,
                style: GoogleFonts.outfit(
                    color: kColorCream.withOpacity(0.4), fontSize: 12)),
          ),
          Expanded(
            child: GestureDetector(
              onTap: onTap,
              child: Text(value,
                  style: GoogleFonts.outfit(
                      color: valueColor ?? kColorCream,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      decoration:
                          onTap != null ? TextDecoration.underline : null)),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Edit Form
// ══════════════════════════════════════════════════════════════════════════════
class _EditForm extends StatefulWidget {
  final HikerProfile profile;
  final bool saving;
  final Future<void> Function(HikerProfile) onSave;
  final VoidCallback onCancel;

  const _EditForm({
    required this.profile,
    required this.saving,
    required this.onSave,
    required this.onCancel,
  });

  @override
  State<_EditForm> createState() => _EditFormState();
}

class _EditFormState extends State<_EditForm> {
  late final TextEditingController _name,
      _phone,
      _bio,
      _bloodType,
      _meds,
      _conditions,
      _docName,
      _docPhone;
  final _allergiesCtrl = TextEditingController();
  late String _experienceLevel;
  late List<String> _allergies;

  // Dynamic list of contacts
  final List<_ContactControllers> _contactCtrls = [];

  @override
  void initState() {
    super.initState();
    final p = widget.profile;
    _name = TextEditingController(text: p.displayName);
    _phone = TextEditingController(text: p.phone);
    _bio = TextEditingController(text: p.bio);
    _bloodType = TextEditingController(text: p.bloodType);
    _meds = TextEditingController(text: p.medications);
    _conditions = TextEditingController(text: p.medicalConditions);
    _docName = TextEditingController(text: p.doctorName);
    _docPhone = TextEditingController(text: p.doctorPhone);
    _experienceLevel = p.experienceLevel;
    _allergies = List.from(p.allergies);

    if (p.contacts.isEmpty) {
      _addContact();
    } else {
      for (final c in p.contacts) {
        _contactCtrls.add(_ContactControllers(
          name: TextEditingController(text: c.name),
          email: TextEditingController(text: c.email),
          phone: TextEditingController(text: c.phone),
          relation: TextEditingController(text: c.relation),
        ));
      }
    }
  }

  void _addContact() {
    setState(() {
      _contactCtrls.add(_ContactControllers(
        name: TextEditingController(),
        email: TextEditingController(),
        phone: TextEditingController(),
        relation: TextEditingController(),
      ));
    });
  }

  void _removeContact(int i) {
    setState(() {
      final ctrl = _contactCtrls.removeAt(i);
      ctrl.dispose();
    });
  }

  @override
  void dispose() {
    for (final c in [
      _name,
      _phone,
      _bio,
      _bloodType,
      _meds,
      _conditions,
      _docName,
      _docPhone,
      _allergiesCtrl
    ]) {
      c.dispose();
    }
    for (final cc in _contactCtrls) {
      cc.dispose();
    }
    super.dispose();
  }

  HikerProfile _buildProfile() => widget.profile.copyWith(
        displayName: _name.text.trim(),
        phone: _phone.text.trim(),
        bio: _bio.text.trim(),
        experienceLevel: _experienceLevel,
        contacts: _contactCtrls
            .map((c) => EmergencyContact(
                  name: c.name.text.trim(),
                  email: c.email.text.trim(),
                  phone: c.phone.text.trim(),
                  relation: c.relation.text.trim(),
                ))
            .where((c) => c.name.isNotEmpty || c.phone.isNotEmpty)
            .toList(),
        bloodType: _bloodType.text.trim(),
        allergies: _allergies,
        medications: _meds.text.trim(),
        medicalConditions: _conditions.text.trim(),
        doctorName: _docName.text.trim(),
        doctorPhone: _docPhone.text.trim(),
      );

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Top bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(
            children: [
              GestureDetector(
                onTap: widget.onCancel,
                child: Text('Cancel',
                    style: GoogleFonts.outfit(
                        color: kColorCream.withOpacity(0.5), fontSize: 15)),
              ),
              const Spacer(),
              Text('Edit Profile',
                  style: GoogleFonts.outfit(
                      color: kColorCream,
                      fontSize: 17,
                      fontWeight: FontWeight.w700)),
              const Spacer(),
              widget.saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          color: kColorOrange, strokeWidth: 2))
                  : GestureDetector(
                      onTap: () => widget.onSave(_buildProfile()),
                      child: Text('Save',
                          style: GoogleFonts.outfit(
                              color: kColorOrange,
                              fontSize: 15,
                              fontWeight: FontWeight.w700)),
                    ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _FormSection('Personal Info', Icons.person_outline, [
                _Field(_name, 'Display Name', Icons.badge_outlined),
                _Field(_phone, 'Phone number', Icons.phone_outlined,
                    type: TextInputType.phone),
                _Field(_bio, 'About me / bio', Icons.notes, maxLines: 3),
                // Experience level
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Experience Level',
                          style: GoogleFonts.outfit(
                              color: kColorCream.withOpacity(0.55),
                              fontSize: 12)),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        children: [
                          'beginner',
                          'intermediate',
                          'advanced',
                          'expert'
                        ]
                            .map((lvl) => GestureDetector(
                                  onTap: () =>
                                      setState(() => _experienceLevel = lvl),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 150),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: _experienceLevel == lvl
                                          ? kColorOrange.withOpacity(0.15)
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                          color: _experienceLevel == lvl
                                              ? kColorOrange
                                              : kColorBorder),
                                    ),
                                    child: Text(lvl,
                                        style: GoogleFonts.outfit(
                                            color: _experienceLevel == lvl
                                                ? kColorOrange
                                                : kColorCream.withOpacity(0.5),
                                            fontSize: 12)),
                                  ),
                                ))
                            .toList(),
                      ),
                    ],
                  ),
                ),
              ]),
              _FormSection(
                '🆘  Emergency Contacts',
                Icons.emergency,
                [
                  ...List.generate(_contactCtrls.length, (i) {
                    final ctrl = _contactCtrls[i];
                    return Column(
                      children: [
                        Row(
                          children: [
                            Text('CONTACT #${i + 1}',
                                style: GoogleFonts.outfit(
                                    color: Colors.redAccent.withOpacity(0.5),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900)),
                            const Spacer(),
                            if (_contactCtrls.length > 1)
                              GestureDetector(
                                onTap: () => _removeContact(i),
                                child: const Icon(Icons.delete_outline,
                                    color: Colors.redAccent, size: 16),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        _Field(ctrl.name, 'Full name', Icons.person),
                        _Field(ctrl.relation, 'Relationship',
                            Icons.favorite_outline,
                            hint: 'e.g. Wife, Father, Partner'),
                        _Field(ctrl.phone, 'Phone number', Icons.phone,
                            type: TextInputType.phone),
                        _Field(
                            ctrl.email, 'Email address', Icons.email_outlined,
                            type: TextInputType.emailAddress),
                        if (i < _contactCtrls.length - 1)
                          const Divider(color: kColorBorder, height: 24),
                      ],
                    );
                  }),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: _addContact,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: Colors.redAccent.withOpacity(0.3),
                            style: BorderStyle.solid),
                      ),
                      child: Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.add,
                                color: Colors.redAccent, size: 18),
                            const SizedBox(width: 8),
                            Text('ADD ANOTHER CONTACT',
                                style: GoogleFonts.outfit(
                                    color: Colors.redAccent,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
                borderColor: Colors.redAccent.withOpacity(0.4),
              ),
              _FormSection(
                  '🩺  Medical Information', Icons.medical_services_outlined, [
                // Blood type dropdown
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: DropdownButtonFormField<String>(
                    value: _bloodType.text.isNotEmpty ? _bloodType.text : null,
                    decoration: InputDecoration(
                      hintText: 'Blood type',
                      prefixIcon: Icon(Icons.bloodtype,
                          color: kColorCream.withOpacity(0.4), size: 18),
                    ),
                    dropdownColor: kColorPanel,
                    style: GoogleFonts.outfit(color: kColorCream),
                    items: ['A+', 'A−', 'B+', 'B−', 'AB+', 'AB−', 'O+', 'O−']
                        .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                        .toList(),
                    onChanged: (v) => setState(() => _bloodType.text = v ?? ''),
                  ),
                ),
                // Allergies
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Allergies',
                          style: GoogleFonts.outfit(
                              color: kColorCream.withOpacity(0.55),
                              fontSize: 12)),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          ..._allergies.map((a) => GestureDetector(
                                onTap: () =>
                                    setState(() => _allergies.remove(a)),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFF9800)
                                        .withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                        color: const Color(0xFFFF9800)
                                            .withOpacity(0.4)),
                                  ),
                                  child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(a,
                                            style: GoogleFonts.outfit(
                                                color: const Color(0xFFFF9800),
                                                fontSize: 12)),
                                        const SizedBox(width: 4),
                                        const Icon(Icons.close,
                                            color: Color(0xFFFF9800), size: 12),
                                      ]),
                                ),
                              )),
                          // Add allergy
                          GestureDetector(
                            onTap: _showAllergyDialog,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: kColorBorder),
                              ),
                              child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.add,
                                        color: kColorCream.withOpacity(0.4),
                                        size: 14),
                                    const SizedBox(width: 4),
                                    Text('Add',
                                        style: GoogleFonts.outfit(
                                            color: kColorCream.withOpacity(0.4),
                                            fontSize: 12)),
                                  ]),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                _Field(_meds, 'Current medications', Icons.medication_outlined,
                    maxLines: 2),
                _Field(
                    _conditions, 'Medical conditions', Icons.healing_outlined,
                    maxLines: 2, hint: 'e.g. Asthma, Diabetes'),
                _Field(_docName, 'Doctor / GP name', Icons.person_pin_outlined),
                _Field(_docPhone, 'Doctor phone', Icons.phone_in_talk_outlined,
                    type: TextInputType.phone),
              ]),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ],
    );
  }

  void _showAllergyDialog() {
    _allergiesCtrl.clear();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: kColorPanel,
        title:
            Text('Add Allergy', style: GoogleFonts.outfit(color: kColorCream)),
        content: TextField(
          controller: _allergiesCtrl,
          autofocus: true,
          style: GoogleFonts.outfit(color: kColorCream),
          decoration: InputDecoration(
            hintText: 'e.g. Penicillin, Bee stings, Nuts…',
            hintStyle: GoogleFonts.outfit(color: kColorCream.withOpacity(0.3)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child:
                Text('Cancel', style: GoogleFonts.outfit(color: kColorCream)),
          ),
          TextButton(
            onPressed: () {
              final v = _allergiesCtrl.text.trim();
              if (v.isNotEmpty) setState(() => _allergies.add(v));
              Navigator.pop(context);
            },
            child: Text('Add', style: GoogleFonts.outfit(color: kColorOrange)),
          ),
        ],
      ),
    );
  }
}

class _FormSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> items;
  final Color? borderColor;

  const _FormSection(this.title, this.icon, this.items, {this.borderColor});

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: kColorPanel,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor ?? kColorBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon, color: kColorOrange, size: 15),
              const SizedBox(width: 8),
              Text(title,
                  style: GoogleFonts.outfit(
                      color: kColorOrange,
                      fontSize: 13,
                      fontWeight: FontWeight.w700)),
            ]),
            const SizedBox(height: 14),
            ...items,
          ],
        ),
      );
}

class _Field extends StatelessWidget {
  final TextEditingController ctrl;
  final String label;
  final IconData icon;
  final TextInputType type;
  final int maxLines;
  final String? hint;

  const _Field(
    this.ctrl,
    this.label,
    this.icon, {
    this.type = TextInputType.text,
    this.maxLines = 1,
    this.hint,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: TextField(
          controller: ctrl,
          keyboardType: type,
          maxLines: maxLines,
          style: GoogleFonts.outfit(color: kColorCream, fontSize: 14),
          decoration: InputDecoration(
            labelText: label,
            hintText: hint,
            hintStyle: GoogleFonts.outfit(
                color: kColorCream.withOpacity(0.25), fontSize: 13),
            prefixIcon:
                Icon(icon, color: kColorCream.withOpacity(0.4), size: 18),
          ),
        ),
      );
}

// ── Achievement Section ───────────────────────────────────────────────────
class _AchievementSection extends StatelessWidget {
  final List<Achievement> achievements;
  const _AchievementSection({required this.achievements});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.workspace_premium_outlined,
                color: kColorOrange, size: 18),
            const SizedBox(width: 8),
            Text('ACHIEVEMENTS',
                style: GoogleFonts.outfit(
                    color: kColorOrange,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2)),
            const Spacer(),
            Text(
                '${achievements.where((a) => a.unlocked).length}/${achievements.length}',
                style: GoogleFonts.outfit(
                    color: kColorCream.withOpacity(0.5), fontSize: 11)),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 110,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: achievements.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (_, i) =>
                _AchievementBadge(achievement: achievements[i]),
          ),
        ),
      ],
    );
  }
}

class _AchievementBadge extends StatelessWidget {
  final Achievement achievement;
  const _AchievementBadge({required this.achievement});

  void _showDetail(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: kColorBg,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: achievement.unlocked
                    ? kColorOrange.withOpacity(0.1)
                    : kColorPanel,
                border: Border.all(
                    color: achievement.unlocked ? kColorOrange : kColorBorder,
                    width: 2),
              ),
              child: Icon(achievement.icon,
                  color: achievement.unlocked
                      ? kColorOrange
                      : kColorCream.withOpacity(0.2),
                  size: 40),
            ),
            const SizedBox(height: 20),
            Text(achievement.title.toUpperCase(),
                style: GoogleFonts.outfit(
                    color: kColorCream,
                    fontSize: 18,
                    fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            Text(achievement.description,
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                    color: kColorCream.withOpacity(0.7), fontSize: 14)),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                  color: kColorPanel, borderRadius: BorderRadius.circular(12)),
              child: Row(
                children: [
                  Icon(achievement.unlocked ? Icons.check_circle : Icons.lock,
                      color:
                          achievement.unlocked ? Colors.green : Colors.white24,
                      size: 18),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      achievement.unlocked
                          ? 'Achievement Unlocked!'
                          : 'Requirement: ${achievement.requirement}',
                      style: GoogleFonts.outfit(
                          color: achievement.unlocked
                              ? Colors.green
                              : kColorCream.withOpacity(0.5),
                          fontSize: 13,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final unlocked = achievement.unlocked;
    return GestureDetector(
      onTap: () => _showDetail(context),
      child: Column(
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: unlocked ? kColorOrange.withOpacity(0.1) : kColorPanel,
              border: Border.all(
                color: unlocked ? kColorOrange : kColorBorder,
                width: 2,
              ),
              boxShadow: unlocked
                  ? [
                      BoxShadow(
                        color: kColorOrange.withOpacity(0.2),
                        blurRadius: 8,
                        spreadRadius: 1,
                      )
                    ]
                  : null,
            ),
            child: ColorFiltered(
              colorFilter: unlocked
                  ? const ColorFilter.mode(
                      Colors.transparent, BlendMode.multiply)
                  : const ColorFilter.matrix([
                      0.2126,
                      0.7152,
                      0.0722,
                      0,
                      0,
                      0.2126,
                      0.7152,
                      0.0722,
                      0,
                      0,
                      0.2126,
                      0.7152,
                      0.0722,
                      0,
                      0,
                      0,
                      0,
                      0,
                      1,
                      0,
                    ]),
              child: Center(
                child: Icon(
                  achievement.icon,
                  color:
                      unlocked ? kColorOrange : kColorCream.withOpacity(0.25),
                  size: 32,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: 80,
            child: Text(
              achievement.title.toUpperCase(),
              textAlign: TextAlign.center,
              maxLines: 2,
              style: GoogleFonts.outfit(
                color: unlocked ? kColorCream : kColorCream.withOpacity(0.3),
                fontSize: 9,
                fontWeight: FontWeight.w700,
                height: 1.1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  final double dist;
  final int ascent;
  final int count;
  const _StatsGrid(
      {required this.dist, required this.ascent, required this.count});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _StatItem(
            label: 'DISTANCE', value: dist.toStringAsFixed(1), unit: 'km'),
        const SizedBox(width: 12),
        _StatItem(label: 'ASCENT', value: '$ascent', unit: 'm'),
        const SizedBox(width: 12),
        _StatItem(label: 'HIKES', value: '$count', unit: ''),
      ],
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label, value, unit;
  const _StatItem(
      {required this.label, required this.value, required this.unit});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: kColorPanel,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: kColorBorder),
        ),
        child: Column(
          children: [
            Text(label,
                style: GoogleFonts.outfit(
                    color: kColorCream.withOpacity(0.4),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.1)),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(value,
                    style: GoogleFonts.outfit(
                        color: kColorCream,
                        fontSize: 18,
                        fontWeight: FontWeight.w800)),
                if (unit.isNotEmpty) ...[
                  const SizedBox(width: 2),
                  Text(unit,
                      style: GoogleFonts.outfit(
                          color: kColorCream.withOpacity(0.4),
                          fontSize: 10,
                          fontWeight: FontWeight.w600)),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ContactControllers {
  final TextEditingController name;
  final TextEditingController email;
  final TextEditingController phone;
  final TextEditingController relation;

  _ContactControllers({
    required this.name,
    required this.email,
    required this.phone,
    required this.relation,
  });

  void dispose() {
    name.dispose();
    email.dispose();
    phone.dispose();
    relation.dispose();
  }
}
