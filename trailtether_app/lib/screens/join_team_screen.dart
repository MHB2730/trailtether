import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../core/constants.dart';
import '../providers/auth_provider.dart' as ap;
import '../providers/team_provider.dart';

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
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

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
              style: GoogleFonts.outfit(color: Colors.white)),
          backgroundColor: const Color(0xFF4CAF50).withOpacity(0.9),
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
            content: Text('QR scanning is not supported on desktop. Please enter the code manually.',
                style: GoogleFonts.outfit(color: Colors.white)),
            backgroundColor: const Color(0xFFE53935).withOpacity(0.9),
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
      backgroundColor: Colors.black,
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
              top: 20,
              right: 20,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: () => Navigator.pop(ctx),
              ),
            ),
            Center(
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  border: Border.all(color: kColorOrange, width: 2),
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            Positioned(
              bottom: 40,
              left: 0,
              right: 0,
              child: Text(
                'Center the QR code in the box',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(color: Colors.white, fontSize: 14),
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
    return Scaffold(
      backgroundColor: kColorBg,
      appBar: AppBar(
        backgroundColor: kColorBg,
        foregroundColor: kColorCream,
        elevation: 0,
        title: Text('Join a Team',
            style: GoogleFonts.outfit(
                color: kColorCream, fontWeight: FontWeight.w700)),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Illustration ─────────────────────────────────────────
              Center(
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: kColorOrange.withOpacity(0.12),
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: kColorOrange.withOpacity(0.3), width: 1.5),
                  ),
                  child: const Icon(Icons.group_add,
                      color: kColorOrange, size: 36),
                ),
              ),

              const SizedBox(height: 20),

              Center(
                child: Text(
                  'Enter your invite code',
                  style: GoogleFonts.outfit(
                      color: kColorCream,
                      fontSize: 18,
                      fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  'Ask your team admin for the code, or copy it\nfrom the invite message they sent you.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                      color: kColorCream.withOpacity(0.45),
                      fontSize: 13,
                      height: 1.5),
                ),
              ),

              const SizedBox(height: 32),

              // ── Code field ───────────────────────────────────────────
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _error != null
                        ? const Color(0xFFE53935).withOpacity(0.6)
                        : kColorOrange.withOpacity(0.35),
                    width: 1.5,
                  ),
                ),
                child: TextField(
                  controller: _codeCtrl,
                  textAlign: TextAlign.center,
                  textCapitalization: TextCapitalization.characters,
                  inputFormatters: [
                    // Auto-insert hyphen after 4 chars
                    _CodeFormatter(),
                  ],
                  maxLength: 9, // "ABCD-EFGH"
                  style: GoogleFonts.outfit(
                    color: kColorCream,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 3,
                  ),
                  decoration: InputDecoration(
                    hintText: 'XXXX-XXXX',
                    hintStyle: GoogleFonts.outfit(
                      color: kColorCream.withOpacity(0.2),
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 3,
                    ),
                    border: InputBorder.none,
                    counterText: '',
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 20),
                  ),
                  onChanged: (_) {
                    if (_error != null) setState(() => _error = null);
                  },
                  onSubmitted: (_) => _join(),
                ),
              ),

              if (_error != null) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(Icons.error_outline,
                        color: Color(0xFFE53935), size: 15),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(_error!,
                          style: GoogleFonts.outfit(
                              color: const Color(0xFFE53935), fontSize: 13)),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 24),

              // ── Join button ──────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                child: GestureDetector(
                  onTap: _busy ? null : _join,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color:
                          _busy ? kColorOrange.withOpacity(0.4) : kColorOrange,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Center(
                      child: _busy
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2),
                            )
                          : Text('Join Team',
                              style: GoogleFonts.outfit(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700)),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // ── Scan QR button ──────────────────────────────────────
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : _scanQR,
                  icon: const Icon(Icons.qr_code_scanner, size: 18),
                  label: Text('Scan QR Code',
                      style: GoogleFonts.outfit(
                          fontSize: 15, fontWeight: FontWeight.w700)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: kColorCream,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: BorderSide(color: kColorCream.withOpacity(0.2)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),

              const Spacer(),

              // ── Footer ───────────────────────────────────────────────
              Center(
                child: Text(
                  'Codes are case-insensitive and never expire\n'
                  'unless the team admin regenerates one.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                      color: kColorCream.withOpacity(0.25),
                      fontSize: 11,
                      height: 1.5),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Auto-format helper: inserts "-" after position 4 ──────────────────────────

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
