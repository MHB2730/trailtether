// Trailtether 2.0 — Edit Profile screen.
//
// Reached from TTProfileScreen's Settings gear, Edit-profile row, and bio tap.
// This is a focused EDIT surface — the identity header, stats, achievements
// and account/preferences sections live on TTProfileScreen. Here we only show
// the fields the user can actually mutate: avatar, display name, bio, phone,
// experience level, emergency contacts and medical info. Save propagates
// through ProfileProvider.save(), which mirrors to Supabase user metadata and
// the `profiles` table (so display_name reaches AuthProvider on next refresh).

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../core/design_tokens.dart';
import '../models/hiker_profile.dart';
import '../providers/profile_provider.dart';
import '../widgets/design/tt_ambient.dart';
import '../widgets/design/tt_glass_card.dart';
import '../widgets/design/tt_topo.dart';

// ══════════════════════════════════════════════════════════════════════════════
// Edit Profile screen
// ══════════════════════════════════════════════════════════════════════════════

class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _bio;
  late final TextEditingController _bloodType;
  late final TextEditingController _meds;
  late final TextEditingController _conditions;
  late final TextEditingController _docName;
  late final TextEditingController _docPhone;
  final _allergiesCtrl = TextEditingController();

  late String _experienceLevel;
  late List<String> _allergies;
  final List<_ContactControllers> _contactCtrls = [];

  bool _initialised = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController();
    _phone = TextEditingController();
    _bio = TextEditingController();
    _bloodType = TextEditingController();
    _meds = TextEditingController();
    _conditions = TextEditingController();
    _docName = TextEditingController();
    _docPhone = TextEditingController();
    _experienceLevel = 'beginner';
    _allergies = [];
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<ProfileProvider>().refresh();
      }
    });
  }

  void _seedFromProfile(HikerProfile p) {
    if (_initialised) return;
    _initialised = true;
    _name.text = p.displayName;
    _phone.text = p.phone;
    _bio.text = p.bio;
    _bloodType.text = p.bloodType;
    _meds.text = p.medications;
    _conditions.text = p.medicalConditions;
    _docName.text = p.doctorName;
    _docPhone.text = p.doctorPhone;
    _experienceLevel = p.experienceLevel;
    _allergies = List<String>.from(p.allergies);

    if (p.contacts.isEmpty) {
      _contactCtrls.add(_ContactControllers.empty());
    } else {
      for (final c in p.contacts) {
        _contactCtrls.add(_ContactControllers.fromContact(c));
      }
    }
  }

  void _addContact() {
    setState(() => _contactCtrls.add(_ContactControllers.empty()));
  }

  void _removeContact(int i) {
    setState(() {
      final ctrl = _contactCtrls.removeAt(i);
      ctrl.dispose();
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _bio.dispose();
    _bloodType.dispose();
    _meds.dispose();
    _conditions.dispose();
    _docName.dispose();
    _docPhone.dispose();
    _allergiesCtrl.dispose();
    for (final cc in _contactCtrls) {
      cc.dispose();
    }
    super.dispose();
  }

  HikerProfile _buildProfile(HikerProfile base) => base.copyWith(
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

  Future<void> _save() async {
    final pp = context.read<ProfileProvider>();
    final ok = await pp.save(_buildProfile(pp.profile));
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('Profile saved', style: TT.body(size: 13, color: TT.text)),
          backgroundColor: TT.surf,
          behavior: SnackBarBehavior.floating,
        ),
      );
      await Navigator.of(context).maybePop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(pp.error ?? 'Could not save profile',
              style: TT.body(size: 13, color: TT.red)),
          backgroundColor: TT.surf,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TT.bg,
      body: Consumer<ProfileProvider>(
        builder: (_, pp, __) {
          _seedFromProfile(pp.profile);
          return Stack(
            children: [
              const Positioned.fill(child: TTAmbient()),
              const Positioned.fill(child: TTTopoBackdrop(opacity: 0.45)),
              SafeArea(
                child: Column(
                  children: [
                    _TopBar(onBack: () => Navigator.of(context).maybePop()),
                    Expanded(
                      child: pp.loading
                          ? const Center(
                              child: SizedBox(
                                width: 28,
                                height: 28,
                                child: CircularProgressIndicator(
                                  color: TT.ember,
                                  strokeWidth: 2,
                                ),
                              ),
                            )
                          : ListView(
                              padding: const EdgeInsets.fromLTRB(
                                  TT.s4, TT.s2, TT.s4, TT.s5),
                              children: [
                                _AvatarEditorCard(profile: pp.profile),
                                const SizedBox(height: TT.s3),
                                _FormSection(
                                  title: 'IDENTITY',
                                  children: [
                                    _TTField(
                                      controller: _name,
                                      label: 'DISPLAY NAME',
                                      icon: Icons.badge_outlined,
                                      hint: 'How others see you',
                                    ),
                                    const SizedBox(height: TT.s3),
                                    _TTField(
                                      controller: _bio,
                                      label: 'BIO',
                                      icon: Icons.notes_outlined,
                                      hint: 'A few words about your trail life',
                                      maxLines: 4,
                                    ),
                                    const SizedBox(height: TT.s3),
                                    _TTField(
                                      controller: _phone,
                                      label: 'PHONE',
                                      icon: Icons.phone_outlined,
                                      hint: '+27 …',
                                      keyboardType: TextInputType.phone,
                                    ),
                                    const SizedBox(height: TT.s3),
                                    _ExperienceSelector(
                                      value: _experienceLevel,
                                      onChanged: (v) =>
                                          setState(() => _experienceLevel = v),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: TT.s3),
                                _FormSection(
                                  title: 'EMERGENCY CONTACTS',
                                  accent: TT.red,
                                  children: [
                                    for (var i = 0;
                                        i < _contactCtrls.length;
                                        i++)
                                      _ContactBlock(
                                        index: i,
                                        controllers: _contactCtrls[i],
                                        showRemove: _contactCtrls.length > 1,
                                        onRemove: () => _removeContact(i),
                                        isLast: i == _contactCtrls.length - 1,
                                      ),
                                    const SizedBox(height: TT.s2),
                                    _AddContactButton(onTap: _addContact),
                                  ],
                                ),
                                const SizedBox(height: TT.s3),
                                _FormSection(
                                  title: 'MEDICAL',
                                  accent: TT.blue,
                                  children: [
                                    _BloodTypeSelector(
                                      value: _bloodType.text,
                                      onChanged: (v) =>
                                          setState(() => _bloodType.text = v),
                                    ),
                                    const SizedBox(height: TT.s3),
                                    _AllergyChips(
                                      allergies: _allergies,
                                      onRemove: (a) =>
                                          setState(() => _allergies.remove(a)),
                                      onAdd: _showAllergyDialog,
                                    ),
                                    const SizedBox(height: TT.s3),
                                    _TTField(
                                      controller: _meds,
                                      label: 'MEDICATIONS',
                                      icon: Icons.medication_outlined,
                                      hint: 'Current medications',
                                      maxLines: 2,
                                    ),
                                    const SizedBox(height: TT.s3),
                                    _TTField(
                                      controller: _conditions,
                                      label: 'CONDITIONS',
                                      icon: Icons.healing_outlined,
                                      hint: 'e.g. Asthma, Diabetes',
                                      maxLines: 2,
                                    ),
                                    const SizedBox(height: TT.s3),
                                    _TTField(
                                      controller: _docName,
                                      label: 'DOCTOR / GP',
                                      icon: Icons.person_pin_outlined,
                                      hint: 'Name',
                                    ),
                                    const SizedBox(height: TT.s3),
                                    _TTField(
                                      controller: _docPhone,
                                      label: 'DOCTOR PHONE',
                                      icon: Icons.phone_in_talk_outlined,
                                      hint: '+27 …',
                                      keyboardType: TextInputType.phone,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: TT.s5),
                                _SaveButton(
                                  busy: pp.saving,
                                  onTap: pp.saving ? null : _save,
                                ),
                                const SizedBox(height: TT.s2),
                                _CancelButton(
                                  enabled: !pp.saving,
                                  onTap: () => Navigator.of(context).maybePop(),
                                ),
                                const SizedBox(height: TT.s5),
                              ],
                            ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showAllergyDialog() {
    _allergiesCtrl.clear();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: TT.surf,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(TT.rLg),
          side: const BorderSide(color: TT.line2),
        ),
        title: Text('Add allergy', style: TT.title(17)),
        content: TextField(
          controller: _allergiesCtrl,
          autofocus: true,
          style: TT.body(size: 14, color: TT.text),
          cursorColor: TT.ember,
          decoration: InputDecoration(
            hintText: 'Penicillin, bee stings, nuts…',
            hintStyle: TT.body(size: 13, color: TT.text3),
            filled: true,
            fillColor: TT.bg3,
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
              borderSide: const BorderSide(color: TT.ember),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TT.body(size: 13, color: TT.text2)),
          ),
          TextButton(
            onPressed: () {
              final v = _allergiesCtrl.text.trim();
              if (v.isNotEmpty) setState(() => _allergies.add(v));
              Navigator.pop(ctx);
            },
            child: Text('Add',
                style: TT.body(size: 13, w: FontWeight.w800, color: TT.ember)),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Top bar
// ══════════════════════════════════════════════════════════════════════════════

class _TopBar extends StatelessWidget {
  final VoidCallback onBack;
  const _TopBar({required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(TT.s3, TT.s3, TT.s3, TT.s2),
      child: Row(
        children: [
          _ChevronBackButton(onTap: onBack),
          const SizedBox(width: TT.s3),
          Expanded(
            child: Text(
              'Edit Profile',
              style: TT.title(22, letterSpacing: -0.01 * 22),
            ),
          ),
          const SizedBox(width: 38),
        ],
      ),
    );
  }
}

class _ChevronBackButton extends StatelessWidget {
  final VoidCallback onTap;
  const _ChevronBackButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0x08FFFFFF),
          borderRadius: BorderRadius.circular(TT.rMd),
          border: Border.all(color: TT.line, width: 1),
        ),
        child: const Icon(Icons.chevron_left, size: 22, color: TT.text2),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Avatar editor
// ══════════════════════════════════════════════════════════════════════════════

class _AvatarEditorCard extends StatelessWidget {
  final HikerProfile profile;
  const _AvatarEditorCard({required this.profile});

  Future<void> _pickPhoto(BuildContext context) async {
    final pp = context.read<ProfileProvider>();
    final hasPhoto = profile.photoUrl.isNotEmpty;
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: TT.surf,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(TT.rLg)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: TT.s2),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: TT.line3,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: TT.s2),
            _SheetRow(
              icon: Icons.photo_library_outlined,
              label: 'Choose from gallery',
              onTap: () => Navigator.pop(ctx, 'gallery'),
            ),
            _SheetRow(
              icon: Icons.camera_alt_outlined,
              label: 'Take a photo',
              onTap: () => Navigator.pop(ctx, 'camera'),
            ),
            if (hasPhoto)
              _SheetRow(
                icon: Icons.delete_outline,
                label: 'Remove photo',
                danger: true,
                onTap: () => Navigator.pop(ctx, 'remove'),
              ),
            const SizedBox(height: TT.s2),
          ],
        ),
      ),
    );
    if (choice == null) return;
    if (!context.mounted) return;
    if (choice == 'remove') {
      await pp.removePhoto();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('Photo removed', style: TT.body(size: 13, color: TT.text)),
          backgroundColor: TT.surf,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    final source =
        choice == 'camera' ? ImageSource.camera : ImageSource.gallery;
    final result = await pp.pickAndUploadPhoto(source: source);
    if (!context.mounted) return;
    if (result == 'ok') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('Photo updated', style: TT.body(size: 13, color: TT.text)),
          backgroundColor: TT.surf,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    if (result == 'cancelled') return;
    if (result == 'no-auth') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sign in to upload a profile photo',
              style: TT.body(size: 13, color: TT.amber)),
          backgroundColor: TT.surf,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Photo upload failed',
            style: TT.body(size: 13, color: TT.red)),
        backgroundColor: TT.surf,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uploading = context.watch<ProfileProvider>().uploadingPhoto;
    final name = profile.displayName.trim();
    final initials = _initialsOf(name);
    final photoUrl = profile.photoUrl.trim();
    final hasRemote =
        photoUrl.startsWith('http://') || photoUrl.startsWith('https://');

    return TTCard(
      padding: const EdgeInsets.fromLTRB(TT.s4, TT.s4, TT.s4, TT.s4),
      child: Row(
        children: [
          _AvatarThumb(
            initials: initials,
            photoUrl: hasRemote ? photoUrl : '',
            uploading: uploading,
          ),
          const SizedBox(width: TT.s4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('PHOTO',
                    style: TT.label(
                        size: 10.5, color: TT.text3, letterSpacing: 0.16 * 11)),
                const SizedBox(height: 4),
                Text(
                  hasRemote ? 'Profile photo synced' : 'No photo yet',
                  style: TT.body(size: 13, w: FontWeight.w700, color: TT.text),
                ),
                const SizedBox(height: 2),
                Text(
                  'JPG/PNG · up to 1024px',
                  style: TT.mono(
                      size: 10, color: TT.text3, letterSpacing: 0.02 * 10),
                ),
                const SizedBox(height: TT.s3),
                _ChangePhotoButton(
                  busy: uploading,
                  onTap: uploading ? null : () => _pickPhoto(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _initialsOf(String name) {
    final s = name.trim();
    if (s.isEmpty) return '?';
    final parts = s.split(RegExp(r'\s+'));
    if (parts.length == 1) {
      return parts.first
          .substring(0, parts.first.length >= 2 ? 2 : 1)
          .toUpperCase();
    }
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }
}

class _AvatarThumb extends StatelessWidget {
  final String initials;
  final String photoUrl;
  final bool uploading;
  const _AvatarThumb({
    required this.initials,
    required this.photoUrl,
    required this.uploading,
  });

  @override
  Widget build(BuildContext context) {
    final hasPhoto = photoUrl.isNotEmpty;
    return SizedBox(
      width: 72,
      height: 72,
      child: Stack(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: hasPhoto
                  ? null
                  : const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF6B3A1A), TT.ember2],
                    ),
              image: hasPhoto
                  ? DecorationImage(
                      image: NetworkImage(photoUrl),
                      fit: BoxFit.cover,
                    )
                  : null,
              border: Border.all(color: TT.ember, width: 2),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x59FF6A2C),
                  blurRadius: 18,
                ),
              ],
            ),
            alignment: Alignment.center,
            child: hasPhoto
                ? null
                : Text(
                    initials,
                    style: TT
                        .body(size: 24, w: FontWeight.w900, color: Colors.white)
                        .copyWith(letterSpacing: -0.02 * 24),
                  ),
          ),
          if (uploading)
            Positioned.fill(
              child: Container(
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xAA000000),
                ),
                alignment: Alignment.center,
                child: const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    color: TT.ember,
                    strokeWidth: 2,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ChangePhotoButton extends StatelessWidget {
  final bool busy;
  final VoidCallback? onTap;
  const _ChangePhotoButton({required this.busy, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: TT.emberDim,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: const Color(0x59FF6A2C), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.camera_alt_outlined, size: 13, color: TT.ember),
            const SizedBox(width: 6),
            Text(
              busy ? 'UPLOADING…' : 'CHANGE PHOTO',
              style: TT
                  .body(size: 11, w: FontWeight.w800, color: TT.ember)
                  .copyWith(letterSpacing: 0.12 * 11),
            ),
          ],
        ),
      ),
    );
  }
}

class _SheetRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool danger;
  final VoidCallback onTap;
  const _SheetRow({
    required this.icon,
    required this.label,
    this.danger = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = danger ? TT.red : TT.ember;
    return ListTile(
      leading: Icon(icon, color: color, size: 20),
      title: Text(
        label,
        style: TT.body(
          size: 14,
          w: FontWeight.w700,
          color: danger ? TT.red : TT.text,
        ),
      ),
      onTap: onTap,
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Form section card
// ══════════════════════════════════════════════════════════════════════════════

class _FormSection extends StatelessWidget {
  final String title;
  final Color accent;
  final List<Widget> children;
  const _FormSection({
    required this.title,
    required this.children,
    this.accent = TT.ember,
  });

  @override
  Widget build(BuildContext context) {
    return TTCard(
      padding: const EdgeInsets.fromLTRB(TT.s4, TT.s4, TT.s4, TT.s4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: TT.label(
              size: 11,
              color: accent,
              letterSpacing: 0.16 * 11,
            ),
          ),
          const SizedBox(height: TT.s3),
          ...children,
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Field
// ══════════════════════════════════════════════════════════════════════════════

class _TTField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final String? hint;
  final int maxLines;
  final TextInputType keyboardType;

  const _TTField({
    required this.controller,
    required this.label,
    required this.icon,
    this.hint,
    this.maxLines = 1,
    this.keyboardType = TextInputType.text,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 13, color: TT.text3),
            const SizedBox(width: 6),
            Text(
              label,
              style: TT.label(
                size: 10.5,
                color: TT.text3,
                letterSpacing: 0.16 * 11,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: TT.surf2,
            borderRadius: BorderRadius.circular(TT.rMd),
            border: Border.all(color: TT.line2, width: 1),
          ),
          child: TextField(
            controller: controller,
            maxLines: maxLines,
            keyboardType: keyboardType,
            cursorColor: TT.ember,
            style: TT.body(size: 14, color: TT.text),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TT.body(size: 13, color: TT.text3),
              isDense: true,
              border: InputBorder.none,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
          ),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Experience selector
// ══════════════════════════════════════════════════════════════════════════════

class _ExperienceSelector extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;
  const _ExperienceSelector({required this.value, required this.onChanged});

  static const _levels = ['beginner', 'intermediate', 'advanced', 'expert'];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.trending_up, size: 13, color: TT.text3),
            const SizedBox(width: 6),
            Text(
              'EXPERIENCE',
              style: TT.label(
                size: 10.5,
                color: TT.text3,
                letterSpacing: 0.16 * 11,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _levels.map((lvl) {
            final selected = lvl == value;
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onChanged(lvl),
              child: AnimatedContainer(
                duration: TT.dFast,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: selected ? TT.emberDim : TT.surf2,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: selected ? const Color(0x59FF6A2C) : TT.line2,
                    width: 1,
                  ),
                ),
                child: Text(
                  lvl.toUpperCase(),
                  style: TT
                      .body(
                        size: 11,
                        w: FontWeight.w800,
                        color: selected ? TT.ember : TT.text2,
                      )
                      .copyWith(letterSpacing: 0.12 * 11),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Emergency contacts
// ══════════════════════════════════════════════════════════════════════════════

class _ContactBlock extends StatelessWidget {
  final int index;
  final _ContactControllers controllers;
  final bool showRemove;
  final VoidCallback onRemove;
  final bool isLast;

  const _ContactBlock({
    required this.index,
    required this.controllers,
    required this.showRemove,
    required this.onRemove,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              'CONTACT ${index + 1}',
              style: TT.label(
                size: 10,
                color: TT.red,
                letterSpacing: 0.16 * 10,
              ),
            ),
            const Spacer(),
            if (showRemove)
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onRemove,
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: Icon(Icons.delete_outline, size: 16, color: TT.red),
                ),
              ),
          ],
        ),
        const SizedBox(height: TT.s2),
        _TTField(
          controller: controllers.name,
          label: 'FULL NAME',
          icon: Icons.person_outline,
          hint: 'Their name',
        ),
        const SizedBox(height: TT.s3),
        _TTField(
          controller: controllers.relation,
          label: 'RELATIONSHIP',
          icon: Icons.favorite_outline,
          hint: 'e.g. Wife, Father, Partner',
        ),
        const SizedBox(height: TT.s3),
        _TTField(
          controller: controllers.phone,
          label: 'PHONE',
          icon: Icons.phone_outlined,
          hint: '+27 …',
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: TT.s3),
        _TTField(
          controller: controllers.email,
          label: 'EMAIL',
          icon: Icons.email_outlined,
          hint: 'name@example.com',
          keyboardType: TextInputType.emailAddress,
        ),
        if (!isLast)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: TT.s3),
            child: Container(height: 1, color: TT.line),
          )
        else
          const SizedBox(height: TT.s3),
      ],
    );
  }
}

class _AddContactButton extends StatelessWidget {
  final VoidCallback onTap;
  const _AddContactButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          color: const Color(0x1AE63D2E),
          borderRadius: BorderRadius.circular(TT.rMd),
          border: Border.all(color: const Color(0x59E63D2E), width: 1),
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.add, size: 16, color: TT.red),
            const SizedBox(width: 6),
            Text(
              'ADD ANOTHER CONTACT',
              style: TT
                  .body(size: 11, w: FontWeight.w800, color: TT.red)
                  .copyWith(letterSpacing: 0.12 * 11),
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

  factory _ContactControllers.empty() => _ContactControllers(
        name: TextEditingController(),
        email: TextEditingController(),
        phone: TextEditingController(),
        relation: TextEditingController(),
      );

  factory _ContactControllers.fromContact(EmergencyContact c) =>
      _ContactControllers(
        name: TextEditingController(text: c.name),
        email: TextEditingController(text: c.email),
        phone: TextEditingController(text: c.phone),
        relation: TextEditingController(text: c.relation),
      );

  void dispose() {
    name.dispose();
    email.dispose();
    phone.dispose();
    relation.dispose();
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Blood type + allergies
// ══════════════════════════════════════════════════════════════════════════════

class _BloodTypeSelector extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;
  const _BloodTypeSelector({required this.value, required this.onChanged});

  static const _types = ['A+', 'A−', 'B+', 'B−', 'AB+', 'AB−', 'O+', 'O−'];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.bloodtype_outlined, size: 13, color: TT.text3),
            const SizedBox(width: 6),
            Text(
              'BLOOD TYPE',
              style: TT.label(
                size: 10.5,
                color: TT.text3,
                letterSpacing: 0.16 * 11,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _types.map((t) {
            final selected = t == value;
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onChanged(selected ? '' : t),
              child: AnimatedContainer(
                duration: TT.dFast,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: selected ? const Color(0x1A5AA1D6) : TT.surf2,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: selected ? const Color(0x595AA1D6) : TT.line2,
                    width: 1,
                  ),
                ),
                child: Text(
                  t,
                  style: TT
                      .body(
                        size: 11,
                        w: FontWeight.w800,
                        color: selected ? TT.blue : TT.text2,
                      )
                      .copyWith(letterSpacing: 0.04 * 11),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _AllergyChips extends StatelessWidget {
  final List<String> allergies;
  final ValueChanged<String> onRemove;
  final VoidCallback onAdd;

  const _AllergyChips({
    required this.allergies,
    required this.onRemove,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.warning_amber_outlined, size: 13, color: TT.text3),
            const SizedBox(width: 6),
            Text(
              'ALLERGIES',
              style: TT.label(
                size: 10.5,
                color: TT.text3,
                letterSpacing: 0.16 * 11,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final a in allergies)
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onRemove(a),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0x1AF2A93B),
                    borderRadius: BorderRadius.circular(999),
                    border:
                        Border.all(color: const Color(0x59F2A93B), width: 1),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        a,
                        style: TT.body(
                            size: 11, w: FontWeight.w700, color: TT.amber),
                      ),
                      const SizedBox(width: 5),
                      const Icon(Icons.close, size: 11, color: TT.amber),
                    ],
                  ),
                ),
              ),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onAdd,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: TT.surf2,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: TT.line2, width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.add, size: 12, color: TT.text2),
                    const SizedBox(width: 5),
                    Text(
                      'ADD',
                      style: TT
                          .body(size: 11, w: FontWeight.w800, color: TT.text2)
                          .copyWith(letterSpacing: 0.12 * 11),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Save / Cancel
// ══════════════════════════════════════════════════════════════════════════════

class _SaveButton extends StatelessWidget {
  final bool busy;
  final VoidCallback? onTap;
  const _SaveButton({required this.busy, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Opacity(
        opacity: enabled ? 1.0 : 0.6,
        child: Container(
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: TT.ember,
            borderRadius: BorderRadius.circular(999),
            boxShadow: TT.shadowEmber,
          ),
          child: busy
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    color: TT.emberInk,
                    strokeWidth: 2,
                  ),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check, size: 16, color: TT.emberInk),
                    const SizedBox(width: 8),
                    Text(
                      'SAVE CHANGES',
                      style: TT
                          .body(
                              size: 13, w: FontWeight.w900, color: TT.emberInk)
                          .copyWith(letterSpacing: 0.16 * 13),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _CancelButton extends StatelessWidget {
  final bool enabled;
  final VoidCallback onTap;
  const _CancelButton({required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: enabled ? onTap : null,
      child: Opacity(
        opacity: enabled ? 1.0 : 0.6,
        child: Container(
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: TT.line2, width: 1),
          ),
          child: Text(
            'CANCEL',
            style: TT
                .body(size: 12, w: FontWeight.w800, color: TT.text2)
                .copyWith(letterSpacing: 0.16 * 12),
          ),
        ),
      ),
    );
  }
}
