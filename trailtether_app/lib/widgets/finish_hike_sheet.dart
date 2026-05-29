// Shared "Finish hike" save sheet.
//
// Single source of truth for the Save / Discard / Resume flow. Pauses the
// GPS, presents an activity-name + type + context + (optional) team + peaks
// form, and on Save promotes the recording to SavedHike via
// HikeHistoryProvider — which also handles the recorded_trails upload.
//
// Used by both the Map tab's recording sheet (in place, no navigation) and
// the standalone LiveTrackingScreen route. The sheet itself never pops the
// parent screen — callers decide what to do via onSaved / onDiscarded.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/design_tokens.dart';
import '../models/saved_hike.dart';
import '../providers/app_state_provider.dart';
import '../providers/auth_provider.dart' as ap;
import '../providers/hike_history_provider.dart';
import '../providers/recording_provider.dart';
import '../providers/team_provider.dart';

class FinishHikeSheet extends StatefulWidget {
  final RecordingProvider rec;
  final VoidCallback? onSaved;
  final VoidCallback? onDiscarded;

  const FinishHikeSheet({
    super.key,
    required this.rec,
    this.onSaved,
    this.onDiscarded,
  });

  /// Pause the recording and present the sheet. The sheet is intentionally
  /// non-dismissable: tapping FINISH must resolve to Save, Discard, or
  /// Keep Recording — anything else leaves the hike in a paused-but-
  /// undecided limbo state.
  static Future<void> show(
    BuildContext context,
    RecordingProvider rec, {
    VoidCallback? onSaved,
    VoidCallback? onDiscarded,
  }) async {
    unawaited(HapticFeedback.heavyImpact());
    rec.pause();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(TT.rXl)),
      ),
      builder: (ctx) => PopScope(
        canPop: false,
        child: FinishHikeSheet(
          rec: rec,
          onSaved: onSaved,
          onDiscarded: onDiscarded,
        ),
      ),
    );
  }

  @override
  State<FinishHikeSheet> createState() => _FinishHikeSheetState();
}

class _FinishHikeSheetState extends State<FinishHikeSheet> {
  late String _type = widget.rec.activityType;
  late String _contextStr = widget.rec.activityContext;
  late String? _teamId = widget.rec.toSavedHike().teamId;
  late final TextEditingController _nameCtrl = TextEditingController(
    text: widget.rec.customName ?? widget.rec.targetTrail?.name,
  );
  int _peaks = 0;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ctx = context;
    final rec = widget.rec;

    return Container(
      decoration: const BoxDecoration(
        color: TT.bg2,
        borderRadius: BorderRadius.vertical(top: Radius.circular(TT.rXl)),
        border: Border(top: BorderSide(color: TT.line2)),
      ),
      padding: EdgeInsets.fromLTRB(
        22,
        22,
        22,
        MediaQuery.of(ctx).viewInsets.bottom + 22,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: TT.line3,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'FINISH HIKE',
                      style: TT.label(
                          size: 12, color: TT.ember, letterSpacing: 1.4),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Save this hike or discard it — you’ve got to pick one.',
                      style: TT.body(size: 12.5, color: TT.text2),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () async {
                  await rec.start();
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                child: Padding(
                  padding: const EdgeInsets.only(left: 12, top: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.arrow_back_rounded,
                          size: 14, color: TT.text2),
                      const SizedBox(width: 4),
                      Text(
                        'KEEP RECORDING',
                        style: TT.label(
                            size: 10, color: TT.text2, letterSpacing: 1.2),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _SheetField(controller: _nameCtrl, label: 'ACTIVITY NAME'),
          const SizedBox(height: 18),
          Text(
            'ACTIVITY TYPE',
            style: TT.label(size: 10.5, color: TT.text3, letterSpacing: 1.4),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _TypeButton(
                  label: 'HIKE',
                  icon: Icons.hiking,
                  active: _type == 'hike',
                  onTap: () => setState(() => _type = 'hike')),
              const SizedBox(width: 8),
              _TypeButton(
                  label: 'WALK',
                  icon: Icons.directions_walk,
                  active: _type == 'walk',
                  onTap: () => setState(() => _type = 'walk')),
              const SizedBox(width: 8),
              _TypeButton(
                  label: 'RUN',
                  icon: Icons.directions_run,
                  active: _type == 'run',
                  onTap: () => setState(() => _type = 'run')),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            'CONTEXT',
            style: TT.label(size: 10.5, color: TT.text3, letterSpacing: 1.4),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _TypeButton(
                  label: 'PERSONAL',
                  icon: Icons.person,
                  active: _contextStr == 'personal',
                  onTap: () => setState(() => _contextStr = 'personal')),
              const SizedBox(width: 8),
              _TypeButton(
                  label: 'TEAM',
                  icon: Icons.groups,
                  active: _contextStr == 'team',
                  onTap: () => setState(() => _contextStr = 'team')),
              const SizedBox(width: 8),
              _TypeButton(
                  label: 'TRAINING',
                  icon: Icons.fitness_center,
                  active: _contextStr == 'training',
                  onTap: () => setState(() => _contextStr = 'training')),
            ],
          ),
          if (_contextStr == 'team') ...[
            const SizedBox(height: 18),
            Text(
              'SELECT TEAM',
              style: TT.label(size: 10.5, color: TT.text3, letterSpacing: 1.4),
            ),
            const SizedBox(height: 8),
            Consumer<TeamProvider>(
              builder: (_, tp, __) => _TeamDropdown(
                value: _teamId,
                teams: tp.teams,
                onChanged: (v) => setState(() => _teamId = v),
              ),
            ),
          ],
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'PEAKS RECORDED',
                      style: TT.label(
                          size: 10.5, color: TT.text3, letterSpacing: 1.4),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _StepperButton(
                          icon: Icons.remove,
                          onTap: () => setState(
                              () => _peaks = (_peaks - 1).clamp(0, 10)),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            '$_peaks',
                            style: TT.numStyle(size: 20, color: TT.text),
                          ),
                        ),
                        _StepperButton(
                          icon: Icons.add,
                          onTap: () => setState(() => _peaks = _peaks + 1),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                child: _DangerButton(
                  label: 'DISCARD',
                  icon: Icons.delete_outline,
                  onTap: () {
                    rec.clear();
                    Navigator.pop(ctx);
                    widget.onDiscarded?.call();
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: _PrimaryButton(
                  label: 'SAVE ACTIVITY',
                  onTap: () async {
                    rec.setActivityMetadata(
                      type: _type,
                      context: _contextStr,
                      name: _nameCtrl.text,
                    );
                    await _saveActivity(
                      ctx,
                      rec,
                      peaks: _peaks,
                      teamId: _teamId,
                    );
                    rec.clear();
                    if (!mounted) return;
                    if (ctx.mounted) Navigator.pop(ctx);
                    widget.onSaved?.call();
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Future<void> _saveActivity(
    BuildContext ctx,
    RecordingProvider rec, {
    int peaks = 0,
    String? teamId,
  }) async {
    if (rec.points.isEmpty) {
      _showSaveSnack(
        ctx,
        message: 'No GPS fixes recorded — nothing to save.',
        color: const Color(0xFFE0A847),
      );
      return;
    }
    final auth = ctx.read<ap.AuthProvider>();

    final baseHike = rec.toSavedHike();
    final finalHike = SavedHike(
      id: baseHike.id,
      name: baseHike.name,
      startedAt: baseHike.startedAt,
      endedAt: baseHike.endedAt,
      points: baseHike.points,
      distanceKm: baseHike.distanceKm,
      durationSeconds: baseHike.durationSeconds,
      movingSeconds: baseHike.movingSeconds,
      averageSpeedKmh: baseHike.averageSpeedKmh,
      movingSpeedKmh: baseHike.movingSpeedKmh,
      maxSpeedKmh: baseHike.maxSpeedKmh,
      ascentM: baseHike.ascentM,
      descentM: baseHike.descentM,
      minElevationM: baseHike.minElevationM,
      maxElevationM: baseHike.maxElevationM,
      averageAccuracyM: baseHike.averageAccuracyM,
      bestAccuracyM: baseHike.bestAccuracyM,
      worstAccuracyM: baseHike.worstAccuracyM,
      acceptedFixes: baseHike.acceptedFixes,
      rejectedFixes: baseHike.rejectedFixes,
      poorAccuracyRejects: baseHike.poorAccuracyRejects,
      jumpRejects: baseHike.jumpRejects,
      staleRejects: baseHike.staleRejects,
      gapWarnings: baseHike.gapWarnings,
      activityType: baseHike.activityType,
      activityContext: baseHike.activityContext,
      benchmarkRouteId: baseHike.benchmarkRouteId,
      teamId: teamId ?? baseHike.teamId,
      peaksClimbed: peaks,
    );

    final result =
        await ctx.read<HikeHistoryProvider>().add(finalHike, userId: auth.uid);

    if (!mounted || !ctx.mounted) return;

    if (!result.localSaved) {
      _showSaveSnack(
        ctx,
        message: 'Could not save hike: ${result.error ?? "unknown error"}',
        color: const Color(0xFFFF6B6B),
      );
    } else if (result.offlineOnly) {
      _showSaveSnack(
        ctx,
        message:
            'Saved on device only — sign in to sync your hikes to the cloud.',
        color: const Color(0xFFE0A847),
      );
    } else if (result.isFullSuccess) {
      _showSaveSnack(
        ctx,
        message: 'Hike saved & synced.',
        color: const Color(0xFF5AC26D),
      );
    } else if (result.supabaseSynced && !result.trailUploaded) {
      _showSaveSnack(
        ctx,
        message:
            'Synced to your account, but trail file failed to upload. The hourly recovery job will retry.',
        color: const Color(0xFFE0A847),
      );
    } else {
      _showSaveSnack(
        ctx,
        message:
            'Saved locally. Sync failed: ${result.error ?? "check connection"}',
        color: const Color(0xFFFF6B6B),
      );
    }

    if (finalHike.benchmarkRouteId != null &&
        finalHike.benchmarkRouteId!.isNotEmpty) {
      if (ctx.mounted) {
        final appState = ctx.read<AppStateProvider>();
        if (!appState.isCompleted(finalHike.benchmarkRouteId!)) {
          await appState.toggleCompleted(finalHike.benchmarkRouteId!);
        }
      }
    }
  }

  void _showSaveSnack(
    BuildContext ctx, {
    required String message,
    required Color color,
  }) {
    final messenger = ScaffoldMessenger.maybeOf(ctx);
    messenger?.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 5),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

// ── Form widgets ───────────────────────────────────────────────────────────

class _SheetField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  const _SheetField({required this.controller, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TT.label(size: 10.5, color: TT.ember, letterSpacing: 1.4),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: TT.surf,
            borderRadius: BorderRadius.circular(TT.rMd),
            border: Border.all(color: TT.line2),
          ),
          child: TextField(
            controller: controller,
            cursorColor: TT.ember,
            style: TT.body(size: 14, color: TT.text),
            decoration: InputDecoration(
              border: InputBorder.none,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              hintText: 'Untitled activity',
              hintStyle: TT.body(size: 14, color: TT.text3),
            ),
          ),
        ),
      ],
    );
  }
}

class _TypeButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;
  const _TypeButton({
    required this.label,
    required this.icon,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Expanded(
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: active ? TT.emberDim : const Color(0x08FFFFFF),
              borderRadius: BorderRadius.circular(TT.rMd),
              border: Border.all(
                  color: active ? const Color(0x52FF6A2C) : TT.line2),
            ),
            child: Column(
              children: [
                Icon(icon, color: active ? TT.ember : TT.text3, size: 18),
                const SizedBox(height: 6),
                Text(
                  label,
                  style: TT.body(
                      size: 10.5,
                      w: FontWeight.w800,
                      color: active ? TT.ember : TT.text3),
                ),
              ],
            ),
          ),
        ),
      );
}

class _TeamDropdown extends StatelessWidget {
  final String? value;
  final List teams;
  final ValueChanged<String?> onChanged;
  const _TeamDropdown({
    required this.value,
    required this.teams,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: TT.surf,
        borderRadius: BorderRadius.circular(TT.rMd),
        border: Border.all(color: TT.line2),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          dropdownColor: TT.bg2,
          borderRadius: BorderRadius.circular(TT.rMd),
          hint: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Text('Choose a team',
                style: TT.body(size: 14, color: TT.text3)),
          ),
          icon: const Padding(
            padding: EdgeInsets.only(right: 10),
            child: Icon(Icons.expand_more, color: TT.text2),
          ),
          items: teams
              .map<DropdownMenuItem<String>>(
                (t) => DropdownMenuItem<String>(
                  value: t.id as String,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Text(
                      t.name as String,
                      style: TT.body(size: 14, color: TT.text),
                    ),
                  ),
                ),
              )
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _StepperButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _StepperButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: TT.emberDim,
          borderRadius: BorderRadius.circular(TT.rSm),
          border: Border.all(color: const Color(0x52FF6A2C)),
        ),
        child: Icon(icon, size: 16, color: TT.ember),
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _PrimaryButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 54,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: TT.ember,
          borderRadius: BorderRadius.circular(TT.rMd),
          boxShadow: TT.shadowEmber,
        ),
        child: Text(
          label,
          style: TT
              .body(
                size: 13,
                w: FontWeight.w900,
                color: TT.emberInk,
              )
              .copyWith(letterSpacing: 0.16 * 13),
        ),
      ),
    );
  }
}

class _DangerButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _DangerButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 54,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0x1AE63D2E),
          borderRadius: BorderRadius.circular(TT.rMd),
          border: Border.all(color: TT.red, width: 1),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: TT.red, size: 18),
            const SizedBox(width: 8),
            Text(
              label,
              style: TT
                  .body(
                    size: 13,
                    w: FontWeight.w900,
                    color: TT.red,
                  )
                  .copyWith(letterSpacing: 0.16 * 13),
            ),
          ],
        ),
      ),
    );
  }
}
