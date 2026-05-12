import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/constants.dart';
import '../services/update_service.dart';

/// Wraps a child screen with two update affordances:
///  • a soft banner across the top when a non-critical update is available
///  • a full-screen blocking gate when the update is critical (the user can't
///    use the app until they install). Critical = `is_critical=true` on the
///    release row OR current build code is below `min_supported_version_code`.
class UpdateGate extends StatefulWidget {
  final Widget child;
  const UpdateGate({super.key, required this.child});

  @override
  State<UpdateGate> createState() => _UpdateGateState();
}

class _UpdateGateState extends State<UpdateGate> {
  late final Stream<UpdateStatus> _stream;
  UpdateStatus _status = const UpdateStatus.unknown();
  bool _dismissedBanner = false;

  @override
  void initState() {
    super.initState();
    _stream = UpdateService.instance.stream;
    _status = UpdateService.instance.status;
    _stream.listen((s) {
      if (mounted) setState(() => _status = s);
    });
    // Kick off the check as soon as the gate mounts.
    UpdateService.instance.check();
  }

  @override
  Widget build(BuildContext context) {
    final status = _status;

    // Critical update: block the app entirely.
    if (status.isCritical) {
      return _CriticalUpdateScreen(status: status);
    }

    // Soft banner above the child (non-critical update + user hasn't dismissed it).
    final showBanner = status.hasUpdate && !_dismissedBanner;
    if (!showBanner) return widget.child;

    return Column(
      children: [
        SafeArea(
          bottom: false,
          child: _UpdateBanner(
            versionName: status.latestVersionName ?? '',
            onDismiss: () => setState(() => _dismissedBanner = true),
            onUpdate: () => _showUpdateSheet(context),
          ),
        ),
        Expanded(child: widget.child),
      ],
    );
  }

  void _showUpdateSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: kColorBg,
      isScrollControlled: true,
      builder: (_) => _UpdateSheet(status: _status),
    );
  }
}

class _UpdateBanner extends StatelessWidget {
  final String versionName;
  final VoidCallback onUpdate;
  final VoidCallback onDismiss;
  const _UpdateBanner({
    required this.versionName,
    required this.onUpdate,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: kColorOrange.withOpacity(0.16),
      child: InkWell(
        onTap: onUpdate,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              const Icon(Icons.system_update,
                  color: kColorOrange, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Update available — v$versionName',
                  style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600),
                ),
              ),
              TextButton(
                onPressed: onUpdate,
                child: const Text('Update',
                    style: TextStyle(color: kColorOrange)),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 18, color: Colors.white54),
                onPressed: onDismiss,
                tooltip: 'Dismiss',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CriticalUpdateScreen extends StatelessWidget {
  final UpdateStatus status;
  const _CriticalUpdateScreen({required this.status});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: kColorBg,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.warning_amber_rounded,
                      color: Colors.redAccent, size: 32),
                ),
                const SizedBox(height: 24),
                Text(
                  'Critical update required',
                  style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 12),
                Text(
                  'Trailtether v${status.latestVersionName} fixes safety-critical issues. '
                  'You need to update before you can keep using the app.',
                  style: GoogleFonts.outfit(
                      color: Colors.white70, fontSize: 14, height: 1.4),
                ),
                if ((status.releaseNotes ?? '').isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(status.releaseNotes!,
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 13, height: 1.4)),
                  ),
                ],
                const SizedBox(height: 32),
                const _UpdateActionButton(label: 'Install update'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _UpdateSheet extends StatelessWidget {
  final UpdateStatus status;
  const _UpdateSheet({required this.status});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.system_update,
                    color: kColorOrange, size: 24),
                const SizedBox(width: 12),
                Text(
                  'Update to v${status.latestVersionName}',
                  style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if ((status.releaseNotes ?? '').isNotEmpty)
              Text(status.releaseNotes!,
                  style: const TextStyle(
                      color: Colors.white70, fontSize: 13, height: 1.4)),
            const SizedBox(height: 24),
            const _UpdateActionButton(label: 'Download & install'),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Later',
                  style: TextStyle(color: Colors.white54)),
            ),
          ],
        ),
      ),
    );
  }
}

class _UpdateActionButton extends StatefulWidget {
  final String label;
  const _UpdateActionButton({required this.label});

  @override
  State<_UpdateActionButton> createState() => _UpdateActionButtonState();
}

class _UpdateActionButtonState extends State<_UpdateActionButton> {
  bool _busy = false;
  double _progress = 0;
  late final StreamSubscription _sub;

  @override
  void initState() {
    super.initState();
    _sub = UpdateService.instance.stream.listen((_) {
      if (mounted) setState(() => _progress = UpdateService.instance.downloadProgress);
    });
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: kColorOrange,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
        onPressed: _busy
            ? null
            : () async {
                setState(() => _busy = true);
                await UpdateService.instance.downloadAndInstall();
                if (mounted) setState(() => _busy = false);
              },
        child: _busy
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    _progress > 0
                        ? 'Downloading ${(_progress * 100).round()}%'
                        : 'Preparing…',
                    style: GoogleFonts.outfit(
                        fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                ],
              )
            : Text(widget.label,
                style: GoogleFonts.outfit(
                    fontSize: 14, fontWeight: FontWeight.w700)),
      ),
    );
  }
}
