// Trailtether 3.0 — Create Team screen.
//
// Reskin notes:
//   * UI rewritten on top of TT v3 design tokens — TTAmbient + TTTopoBackdrop
//     backdrop, TTPageAppBar with chevron back, TTCard form panel, ember pill
//     primary CTA, outline secondary cancel.
//   * Logic is preserved verbatim: `TeamProvider.createTeam` is invoked with
//     the exact same name / description / current user payload as before, and
//     the screen still pops on success / shows a snack-bar on failure.
//
// Owns only this file.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/design_tokens.dart';
import '../providers/auth_provider.dart' as ap;
import '../providers/team_provider.dart';
import '../widgets/design/tt_ambient.dart';
import '../widgets/design/tt_app_bar.dart';
import '../widgets/design/tt_glass_card.dart';
import '../widgets/design/tt_pill.dart';
import '../widgets/design/tt_topo.dart';

class CreateTeamScreen extends StatefulWidget {
  const CreateTeamScreen({super.key});

  @override
  State<CreateTeamScreen> createState() => _CreateTeamScreenState();
}

class _CreateTeamScreenState extends State<CreateTeamScreen> {
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl.addListener(_onNameChanged);
  }

  @override
  void dispose() {
    _nameCtrl
      ..removeListener(_onNameChanged)
      ..dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  void _onNameChanged() => setState(() {});

  Future<void> _create() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;

    setState(() => _busy = true);

    final user = context.read<ap.AuthProvider>().user!;
    final id = await context.read<TeamProvider>().createTeam(
          name: name,
          description: _descCtrl.text.trim(),
          currentUser: user,
        );

    if (!mounted) return;
    setState(() => _busy = false);

    if (id != null) {
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to create team. Try again.',
              style: TT.body(size: 13, color: TT.text)),
          backgroundColor: TT.surf2,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasName = _nameCtrl.text.trim().isNotEmpty;
    final descChars = _descCtrl.text.characters.length;

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
                TTPageAppBar(
                  title: 'Create Team',
                  trailing: [
                    TTIconBtn(
                      icon: Icons.chevron_left,
                      onTap: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(18, 8, 18, 32),
                    children: [
                      _IntroCard(hasName: hasName),
                      const SizedBox(height: 14),
                      TTCard(
                        padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('TEAM NAME', style: TT.label(color: TT.ember)),
                            const SizedBox(height: 8),
                            _Field(
                              controller: _nameCtrl,
                              hint: 'e.g. Weekend Wanderers',
                              maxLength: 40,
                              onChanged: (_) {},
                            ),
                            const SizedBox(height: 22),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('DESCRIPTION',
                                    style: TT.label(color: TT.ember)),
                                Text('$descChars / 120',
                                    style: TT.mono(size: 10, color: TT.text3)),
                              ],
                            ),
                            const SizedBox(height: 8),
                            _Field(
                              controller: _descCtrl,
                              hint: 'What brings your group together?',
                              maxLength: 120,
                              maxLines: 3,
                              onChanged: (_) {},
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 22),
                      _PrimaryCta(
                        label: 'CREATE TEAM',
                        icon: Icons.flag_outlined,
                        busy: _busy,
                        enabled: hasName && !_busy,
                        onTap: _create,
                      ),
                      const SizedBox(height: 12),
                      _SecondaryCta(
                        label: 'CANCEL',
                        onTap: _busy ? null : () => Navigator.of(context).pop(),
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

// ─────────────────────────────────── INTRO ──────────────────────────────────

class _IntroCard extends StatelessWidget {
  final bool hasName;
  const _IntroCard({required this.hasName});

  @override
  Widget build(BuildContext context) {
    return TTCard(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: TT.emberDim,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0x52FF6A2C), width: 1),
            ),
            child: const Icon(Icons.flag_outlined, color: TT.ember, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('NEW TEAM', style: TT.label(color: TT.ember)),
                    const SizedBox(width: 8),
                    TTPill(
                      label: hasName ? 'READY' : 'DRAFT',
                      variant: hasName
                          ? TTPillVariant.ember
                          : TTPillVariant.neutral,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Form a crew, share live locations, and plan hikes together.',
                  style: TT.body(size: 12.5, color: TT.text2, w: FontWeight.w500)
                      .copyWith(height: 1.45),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────── FIELD ──────────────────────────────────

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final int maxLines;
  final int? maxLength;
  final ValueChanged<String> onChanged;

  const _Field({
    required this.controller,
    required this.hint,
    required this.onChanged,
    this.maxLines = 1,
    this.maxLength,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: TT.surf,
        borderRadius: BorderRadius.circular(TT.rMd),
        border: Border.all(color: TT.line2, width: 1),
      ),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        maxLength: maxLength,
        cursorColor: TT.ember,
        style: TT.body(size: 14, color: TT.text, w: FontWeight.w500),
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle:
              TT.body(size: 14, color: TT.text3, w: FontWeight.w500),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          counterText: '',
          contentPadding: const EdgeInsets.symmetric(
              horizontal: 14, vertical: 14),
        ),
      ),
    );
  }
}

// ─────────────────────────────────── CTAS ───────────────────────────────────

class _PrimaryCta extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool busy;
  final bool enabled;
  final VoidCallback onTap;

  const _PrimaryCta({
    required this.label,
    required this.icon,
    required this.busy,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = !enabled;
    return Opacity(
      opacity: disabled ? 0.55 : 1,
      child: Material(
        color: TT.ember,
        borderRadius: BorderRadius.circular(TT.rMd),
        child: InkWell(
          borderRadius: BorderRadius.circular(TT.rMd),
          onTap: disabled ? null : onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(TT.rMd),
              boxShadow: disabled ? null : TT.shadowEmber,
            ),
            alignment: Alignment.center,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (busy)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(TT.emberInk),
                    ),
                  )
                else
                  Icon(icon, color: TT.emberInk, size: 16),
                const SizedBox(width: 8),
                Text(label,
                    style: TT.body(
                            size: 13, w: FontWeight.w900, color: TT.emberInk)
                        .copyWith(letterSpacing: 0.14 * 13)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SecondaryCta extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  const _SecondaryCta({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    return Opacity(
      opacity: disabled ? 0.55 : 1,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(TT.rMd),
        child: InkWell(
          borderRadius: BorderRadius.circular(TT.rMd),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(TT.rMd),
              border: Border.all(color: TT.line, width: 1),
              color: const Color(0x08FFFFFF),
            ),
            alignment: Alignment.center,
            child: Text(label,
                style: TT.body(size: 13, w: FontWeight.w800, color: TT.text2)
                    .copyWith(letterSpacing: 0.14 * 13)),
          ),
        ),
      ),
    );
  }
}
