import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants.dart';

/// Slim destructive "clear chat" action surfaced above a message list.
/// Caller is responsible for permission gating — render this widget only
/// when the current user is allowed to wipe the room.
class ClearChatBar extends StatefulWidget {
  final String label;
  final Future<void> Function() onConfirm;

  const ClearChatBar({
    super.key,
    required this.label,
    required this.onConfirm,
  });

  @override
  State<ClearChatBar> createState() => _ClearChatBarState();
}

class _ClearChatBarState extends State<ClearChatBar> {
  bool _busy = false;

  Future<void> _handleTap() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kColorPanel,
        title: Text('Clear chat?',
            style: GoogleFonts.outfit(
                color: kColorCream, fontWeight: FontWeight.w700)),
        content: Text(
          'This permanently deletes every message in this chat for all members. This cannot be undone.',
          style: GoogleFonts.outfit(color: kColorCream.withOpacity(0.75)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel',
                style: GoogleFonts.outfit(color: kColorCream.withOpacity(0.7))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete all',
                style: GoogleFonts.outfit(
                    color: const Color(0xFFE53935),
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _busy = true);
    try {
      await widget.onConfirm();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chat cleared.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Clear failed: $e'),
        backgroundColor: const Color(0xFFE53935),
      ));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _busy ? null : _handleTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: kColorPanel.withOpacity(0.6),
            border: const Border(bottom: BorderSide(color: kColorBorder)),
          ),
          child: Row(
            children: [
              Icon(
                _busy ? Icons.hourglass_top : Icons.delete_sweep_outlined,
                size: 18,
                color: const Color(0xFFE53935).withOpacity(0.85),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.label,
                  style: GoogleFonts.outfit(
                    color: kColorCream.withOpacity(0.75),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Icon(Icons.chevron_right,
                  size: 18, color: kColorCream.withOpacity(0.3)),
            ],
          ),
        ),
      ),
    );
  }
}
