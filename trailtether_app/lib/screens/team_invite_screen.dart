import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/constants.dart';
import '../models/team.dart';
import '../services/team_service.dart';

/// Full-screen QR invite page for a team.
/// Shows the invite QR code, text code, copy + share buttons.
class TeamInviteScreen extends StatefulWidget {
  final Team team;

  const TeamInviteScreen({super.key, required this.team});

  @override
  State<TeamInviteScreen> createState() => _TeamInviteScreenState();
}

class _TeamInviteScreenState extends State<TeamInviteScreen> {
  String _code = '';
  bool _regenerating = false;

  @override
  void initState() {
    super.initState();
    _code = widget.team.inviteCode;
    if (_code.isEmpty) {
      _regenerate();
    }
  }

  Future<void> _regenerate() async {
    setState(() => _regenerating = true);
    try {
      await TeamService.regenerateInviteCode(widget.team.id);
      final row = await Supabase.instance.client
          .from(kColTeams)
          .select('invite_code')
          .eq('id', widget.team.id)
          .single();
      final newCode = (row['invite_code'] as String?) ?? '';
      if (mounted && newCode.isNotEmpty) {
        setState(() => _code = newCode);
      }
    } catch (_) {
      // Keep the current code on screen if regeneration fails.
    } finally {
      if (mounted) {
        setState(() => _regenerating = false);
      }
    }
  }

  void _copyCode() {
    Clipboard.setData(ClipboardData(text: _code));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Code copied!',
          style: GoogleFonts.outfit(color: Colors.white),
        ),
        backgroundColor: const Color(0xFF4CAF50).withOpacity(0.9),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _shareCode() {
    Share.share(
      'Join my Trailtether team "${widget.team.name}"!\n\n'
      'Open the app, go to Teams -> Join Team, and enter code:\n\n'
      '  $_code\n\n'
      'See you on the trail!',
      subject: 'Join ${widget.team.name} on Trailtether',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kColorBg,
      appBar: AppBar(
        backgroundColor: kColorBg,
        foregroundColor: kColorCream,
        elevation: 0,
        title: Text(
          'Invite to ${widget.team.name}',
          style: GoogleFonts.outfit(
            color: kColorCream,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                'Share this code with your team',
                style: GoogleFonts.outfit(
                  color: kColorCream.withOpacity(0.7),
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              if (_code.isEmpty || _regenerating)
                Container(
                  width: 220,
                  height: 220,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Center(
                    child: CircularProgressIndicator(
                      color: kColorOrange,
                      strokeWidth: 2,
                    ),
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.35),
                        blurRadius: 20,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: QrImageView(
                    data: _code,
                    version: QrVersions.auto,
                    size: 200,
                    backgroundColor: Colors.white,
                    eyeStyle: const QrEyeStyle(
                      eyeShape: QrEyeShape.square,
                      color: Color(0xFF0D0D0D),
                    ),
                    dataModuleStyle: const QrDataModuleStyle(
                      dataModuleShape: QrDataModuleShape.square,
                      color: Color(0xFF0D0D0D),
                    ),
                  ),
                ),
              const SizedBox(height: 28),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: kColorOrange.withOpacity(0.35)),
                ),
                child: Column(
                  children: [
                    Text(
                      'Invite Code',
                      style: GoogleFonts.outfit(
                        color: kColorCream.withOpacity(0.4),
                        fontSize: 11,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _code.isEmpty ? '------' : _code,
                      style: GoogleFonts.outfit(
                        color: kColorCream,
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _ActionButton(
                      icon: Icons.copy_rounded,
                      label: 'Copy Code',
                      onTap: _copyCode,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _ActionButton(
                      icon: Icons.share_outlined,
                      label: 'Share',
                      onTap: _shareCode,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.03),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withOpacity(0.08)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'How to join',
                      style: GoogleFonts.outfit(
                        color: kColorCream.withOpacity(0.6),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.4,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...[
                      '1. Share this code or screenshot the QR.',
                      '2. Your teammate opens Trailtether -> Teams tab.',
                      '3. They tap "Join Team" and enter the code.',
                      '4. They instantly join ${widget.team.name}!',
                    ].map(
                      (step) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          step,
                          style: GoogleFonts.outfit(
                            color: kColorCream.withOpacity(0.5),
                            fontSize: 13,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TextButton.icon(
                icon: Icon(
                  Icons.refresh,
                  color: kColorCream.withOpacity(0.4),
                  size: 15,
                ),
                label: Text(
                  'Regenerate code',
                  style: GoogleFonts.outfit(
                    color: kColorCream.withOpacity(0.4),
                    fontSize: 12,
                  ),
                ),
                onPressed: _regenerating ? null : _regenerate,
              ),
              Text(
                'Regenerating invalidates the old code.',
                style: GoogleFonts.outfit(
                  color: kColorCream.withOpacity(0.25),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: kColorOrange,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
