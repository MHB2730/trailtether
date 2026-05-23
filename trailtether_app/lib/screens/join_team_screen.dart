// Trailtether 3.0 — Join Team screen.
//
// Reskin notes:
//   * UI rewritten on top of TT v3 design tokens — TTAmbient + TTTopoBackdrop
//     backdrop, TTPageAppBar with chevron back, TTCard panels for the code
//     entry + how-to footer, ember pill primary CTA, outline secondary
//     scan-QR CTA. The QR scanner sheet is restyled to match the dark
//     graphite/ember palette.
//   * Logic is preserved verbatim: invite code is uppercased and 8 chars
//     auto-hyphenated, `TeamProvider.joinTeamByCode` is invoked with the
//     same user payload as before, QR scanning gates on camera permission
//     and is suppressed on desktop platforms, and the success / error
//     handling matches the previous behaviour.
//
// Owns only this file.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../core/design_tokens.dart';
import '../providers/auth_provider.dart' as ap;
import '../providers/team_provider.dart';
import '../widgets/design/tt_ambient.dart';
import '../widgets/design/tt_app_bar.dart';
import '../widgets/design/tt_glass_card.dart';
import '../widgets/design/tt_pill.dart';
import '../widgets/design/tt_topo.dart';

class JoinTeamScreen extends StatefulWidget {
  const JoinTeamScreen({super.key});

  @override
  State<JoinTeamScreen> createState() => _JoinTeamScreenState();
}

class _JoinTeamScreenState extends State<JoinTeamScreen> {
  final _codeCtrl = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _codeCtrl.addListener(_onCodeChanged);
  }

  @override
  void dispose() {
    _codeCtrl
      ..removeListener(_onCodeChanged)
      ..dispose();
    super.dispose();
  }

  void _onCodeChanged() => setState(() {});

  Future<void> _join() async {
    final code = _codeCtrl.text.trim().toUpperCase();
    if (code.isEmpty) {
      setState(() => _error = 'Please enter an invite code.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final user = context.read<ap.AuthProvider>().user!;
      final teamName =
          await context.read<TeamProvider>().joinTeamByCode(code, user);

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('You joined $teamName!',
              style: TT.body(size: 13, color: TT.text)),
          backgroundColor: TT.surf2,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  Future<void> _scanQR() async {
    if (defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'QR scanning is not supported on desktop. Please enter the code manually.',
              style: TT.body(size: 13, color: TT.text),
            ),
            backgroundColor: TT.surf2,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    final status = await Permission.camera.request();
    if (!status.isGranted) {
      if (mounted) {
        setState(
            () => _error = 'Camera permission is required to scan QR codes.');
      }
      return;
    }

    if (!mounted) return;

    final code = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: TT.bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SizedBox(
        height: MediaQuery.of(ctx).size.height * 0.7,
        child: Stack(
          children: [
            MobileScanner(
              onDetect: (capture) {
                final List<Barcode> barcodes = capture.barcodes;
                for (final barcode in barcodes) {
                  if (barcode.rawValue != null) {
                    Navigator.pop(ctx, barcode.rawValue);
                    break;
                  }
                }
              },
            ),
            Positioned(
              top: 16,
              right: 16,
              child: TTIconBtn(
                icon: Icons.close,
                onTap: () => Navigator.pop(ctx),
              ),
            ),
            Center(
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  border: Border.all(color: TT.ember, width: 2),
                  borderRadius: BorderRadius.circular(TT.rLg),
                  boxShadow: const [
                    BoxShadow(
                        color: Color(0x66FF6A2C),
                        blurRadius: 24,
                        spreadRadius: -4),
                  ],
                ),
              ),
            ),
            Positioned(
              bottom: 28,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: TT.surf,
                    border: Border.all(color: TT.line, width: 1),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'Center the QR code in the box',
                    style: TT.body(
                        size: 12, w: FontWeight.w600, color: TT.text),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (code != null && code.isNotEmpty) {
      _codeCtrl.text = code;
      unawaited(_join());
    }
  }

  @override
  Widget build(BuildContext context) {
    final cleaned = _codeCtrl.text.replaceAll('-', '');
    final ready = cleaned.length == 8;

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
                  title: 'Join a Team',
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
                      _IntroCard(ready: ready),
                      const SizedBox(height: 14),
                      _CodeCard(
                        controller: _codeCtrl,
                        error: _error,
                        onSubmitted: (_) => _join(),
                      ),
                      const SizedBox(height: 22),
                      _PrimaryCta(
                        label: 'JOIN TEAM',
                        icon: Icons.flag_outlined,
                        busy: _busy,
                        enabled: !_busy && cleaned.isNotEmpty,
                        onTap: _join,
                      ),
                      const SizedBox(height: 12),
                      _SecondaryCta(
                        label: 'SCAN QR CODE',
                        icon: Icons.qr_code_scanner,
                        onTap: _busy ? null : _scanQR,
                      ),
                      const SizedBox(height: 22),
                      _FooterNote(),
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
  final bool ready;
  const _IntroCard({required this.ready});

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
            child: const Icon(Icons.group_add, color: TT.ember, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('INVITE CODE', style: TT.label(color: TT.ember)),
                    const SizedBox(width: 8),
                    TTPill(
                      label: ready ? 'READY' : 'WAITING',
                      variant: ready
                          ? TTPillVariant.ember
                          : TTPillVariant.neutral,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Enter the 8-character code from your team admin, or scan their QR.',
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

// ─────────────────────────────────── CODE CARD ──────────────────────────────

class _CodeCard extends StatelessWidget {
  final TextEditingController controller;
  final String? error;
  final ValueChanged<String> onSubmitted;

  const _CodeCard({
    required this.controller,
    required this.error,
    required this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return TTCard(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('TEAM CODE', style: TT.label(color: TT.ember)),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: TT.surf,
              borderRadius: BorderRadius.circular(TT.rMd),
              border: Border.all(
                color: error != null
                    ? const Color(0x80E63D2E)
                    : TT.line2,
                width: 1,
              ),
            ),
            child: TextField(
              controller: controller,
              textAlign: TextAlign.center,
              textCapitalization: TextCapitalization.characters,
              inputFormatters: [_CodeFormatter()],
              maxLength: 9, // "ABCD-EFGH"
              cursorColor: TT.ember,
              style: TT.numStyle(
                size: 26,
                color: TT.text,
                letterSpacing: 4,
              ),
              decoration: InputDecoration(
                hintText: 'XXXX-XXXX',
                hintStyle: TT.numStyle(
                  size: 26,
                  color: TT.text4,
                  letterSpacing: 4,
                ),
                border: InputBorder.none,
                counterText: '',
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 18),
              ),
              onSubmitted: onSubmitted,
            ),
          ),
          if (error != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.error_outline, color: TT.red, size: 14),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    error!,
                    style: TT.body(
                        size: 12.5, color: TT.red, w: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────── FOOTER ─────────────────────────────────

class _FooterNote extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0x08FFFFFF),
        borderRadius: BorderRadius.circular(TT.rMd),
        border: Border.all(color: TT.line, width: 1),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: TT.text3, size: 14),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Codes are case-insensitive and never expire unless the team admin '
              'regenerates one.',
              style: TT.body(size: 12, color: TT.text3, w: FontWeight.w500)
                  .copyWith(height: 1.45),
            ),
          ),
        ],
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
  final IconData icon;
  final VoidCallback? onTap;
  const _SecondaryCta(
      {required this.label, required this.icon, required this.onTap});

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
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: TT.text2, size: 15),
                const SizedBox(width: 8),
                Text(label,
                    style: TT.body(
                            size: 13, w: FontWeight.w800, color: TT.text2)
                        .copyWith(letterSpacing: 0.14 * 13)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Auto-format helper: inserts "-" after position 4 ────────────────────────

class _CodeFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue old, TextEditingValue value) {
    var text = value.text.replaceAll('-', '').toUpperCase();
    if (text.length > 8) text = text.substring(0, 8);
    final buf = StringBuffer();
    for (var i = 0; i < text.length; i++) {
      if (i == 4) buf.write('-');
      buf.write(text[i]);
    }
    final result = buf.toString();
    return TextEditingValue(
      text: result,
      selection: TextSelection.collapsed(offset: result.length),
    );
  }
}
