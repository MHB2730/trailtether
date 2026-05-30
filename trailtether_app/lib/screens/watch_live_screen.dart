import 'package:flutter/material.dart';

import '../core/design_tokens.dart';
import '../providers/watch_live_provider.dart';

/// Mirrors a hike that's recording on the Garmin watch, in real time, over the
/// Connect IQ Mobile SDK. No sensor pairing — it uses the device already known
/// to Garmin Connect Mobile. The screen owns its own provider so the live link
/// is only active while this screen is open.
///
/// Until the native Connect IQ Mobile SDK plugin is wired (see
/// `trailtether_watch/HANDOFF_live_link.md`) this shows the waiting state.
class WatchLiveScreen extends StatefulWidget {
  const WatchLiveScreen({super.key});

  @override
  State<WatchLiveScreen> createState() => _WatchLiveScreenState();
}

class _WatchLiveScreenState extends State<WatchLiveScreen> {
  final WatchLiveProvider _live = WatchLiveProvider();

  @override
  void initState() {
    super.initState();
    _live.start();
  }

  @override
  void dispose() {
    _live.dispose();
    super.dispose();
  }

  String _fmtDur(int? s) {
    if (s == null) return '--';
    final h = s ~/ 3600, m = (s % 3600) ~/ 60, sec = s % 60;
    final mm = m.toString().padLeft(2, '0');
    final ss = sec.toString().padLeft(2, '0');
    return h > 0 ? '$h:$mm:$ss' : '$mm:$ss';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TT.bg,
      appBar: AppBar(title: const Text('Watch Live')),
      body: ListenableBuilder(
        listenable: _live,
        builder: (context, _) {
          final receiving =
              _live.state == WatchLinkState.receiving && _live.isLive;
          return ListView(
            padding: const EdgeInsets.all(TT.s4),
            children: [
              _statusRow(receiving),
              const SizedBox(height: TT.s4),
              if (receiving) ..._liveBody() else _waiting(),
            ],
          );
        },
      ),
    );
  }

  Widget _statusRow(bool receiving) {
    final color = receiving ? const Color(0xFF4CC38A) : TT.text2;
    final label = receiving
        ? 'LIVE FROM WATCH'
        : (_live.state == WatchLinkState.listening
            ? 'WAITING FOR WATCH'
            : 'NOT CONNECTED');
    return Row(
      children: [
        Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Text(label, style: TT.mono(size: 11, color: color)),
        const Spacer(),
        if (_live.activity != null)
          Text(_live.activity!.toUpperCase(),
              style: TT.mono(size: 11, color: TT.ember)),
      ],
    );
  }

  List<Widget> _liveBody() {
    return [
      // Big heart rate
      Container(
        padding: const EdgeInsets.symmetric(vertical: 22),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: TT.surf,
          borderRadius: BorderRadius.circular(TT.rLg),
          border: Border.all(color: TT.ember.withOpacity(0.35)),
        ),
        child: Column(
          children: [
            const Icon(Icons.favorite, color: TT.red, size: 22),
            const SizedBox(height: 6),
            Text(
              _live.hr != null ? '${_live.hr}' : '--',
              style: const TextStyle(
                  fontSize: 64, fontWeight: FontWeight.w800, color: TT.ember),
            ),
            Text('BPM  ·  avg ${_live.avgHr ?? '--'}',
                style: TT.body(size: 12, color: TT.text2)),
          ],
        ),
      ),
      const SizedBox(height: TT.s3),
      Row(children: [
        Expanded(child: _tile('TIME', _fmtDur(_live.durationSec))),
        const SizedBox(width: TT.s2),
        Expanded(
            child: _tile(
                'DISTANCE',
                _live.distanceM != null
                    ? '${(_live.distanceM! / 1000).toStringAsFixed(2)} km'
                    : '--')),
      ]),
      const SizedBox(height: TT.s2),
      Row(children: [
        Expanded(
            child: _tile(
                'ALTITUDE',
                _live.altitudeM != null
                    ? '${_live.altitudeM!.toStringAsFixed(0)} m'
                    : '--')),
        const SizedBox(width: TT.s2),
        Expanded(
            child: _tile(
                'PACE',
                _live.speedMps != null
                    ? '${(_live.speedMps! * 3.6).toStringAsFixed(1)} km/h'
                    : '--')),
      ]),
    ];
  }

  Widget _tile(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: TT.surf,
        borderRadius: BorderRadius.circular(TT.rMd),
        border: Border.all(color: TT.line2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TT.label()),
          const SizedBox(height: 4),
          Text(value, style: TT.title(18)),
        ],
      ),
    );
  }

  Widget _waiting() {
    return Container(
      padding: const EdgeInsets.all(TT.s5),
      decoration: BoxDecoration(
        color: TT.surf,
        borderRadius: BorderRadius.circular(TT.rLg),
        border: Border.all(color: TT.line2),
      ),
      child: Column(
        children: [
          const Icon(Icons.watch_outlined, color: TT.ember, size: 36),
          const SizedBox(height: TT.s3),
          Text('Start a hike on your watch', style: TT.title(18)),
          const SizedBox(height: TT.s2),
          Text(
            'Open Trailtether on your Instinct and begin recording — the hike '
            'mirrors here in real time, no sensor pairing. Uses the device '
            'already paired in Garmin Connect Mobile.',
            textAlign: TextAlign.center,
            style: TT.body(size: 13, color: TT.text2),
          ),
          const SizedBox(height: TT.s3),
          Text(
            'Requires the Connect IQ live link in this build.',
            textAlign: TextAlign.center,
            style: TT.mono(size: 10.5, color: TT.text3),
          ),
        ],
      ),
    );
  }
}
