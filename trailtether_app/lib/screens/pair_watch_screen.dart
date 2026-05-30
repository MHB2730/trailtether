import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/design_tokens.dart';
import '../providers/heart_rate_provider.dart';
import '../services/watch_service.dart';
import 'watch_live_screen.dart';

/// Issues a pairing token for the Garmin Instinct companion app. The user pastes
/// it into the watch app's settings in Garmin Connect Mobile, after which the
/// watch syncs hikes to this account via the `watch-ingest` function.
class PairWatchScreen extends StatefulWidget {
  const PairWatchScreen({super.key});

  @override
  State<PairWatchScreen> createState() => _PairWatchScreenState();
}

class _PairWatchScreenState extends State<PairWatchScreen> {
  String? _token;
  bool _loading = false;

  Future<void> _mint() async {
    setState(() => _loading = true);
    final token = await WatchService.mintToken();
    if (!mounted) return;
    setState(() {
      _token = token;
      _loading = false;
    });
    if (token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not create a pairing token')),
      );
    }
  }

  void _copy() {
    final t = _token;
    if (t == null) return;
    Clipboard.setData(ClipboardData(text: t));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Token copied')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TT.bg,
      appBar: AppBar(title: const Text('Pair Garmin Watch')),
      body: ListView(
        padding: const EdgeInsets.all(TT.s4),
        children: [
          const _LiveHeartRateCard(),
          const SizedBox(height: TT.s3),
          OutlinedButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const WatchLiveScreen()),
            ),
            icon: const Icon(Icons.sensors, size: 18),
            label: const Text('Watch live — mirror a hike from your watch'),
          ),
          const SizedBox(height: TT.s5),
          const Divider(color: TT.line2, height: 1),
          const SizedBox(height: TT.s5),
          const Icon(Icons.watch_outlined, color: TT.ember, size: 40),
          const SizedBox(height: TT.s3),
          Text('Sync hikes from your Instinct', style: TT.title(22)),
          const SizedBox(height: TT.s2),
          Text(
            'Generate a one-time token, then paste it into the Trailtether watch '
            'app settings in Garmin Connect Mobile. Hikes recorded on the watch '
            'will then sync to this account.',
            style: TT.body(size: 13, color: TT.text2),
          ),
          const SizedBox(height: TT.s5),
          if (_token != null) _tokenBox() else _generateButton(),
          const SizedBox(height: TT.s5),
          _steps(),
        ],
      ),
    );
  }

  Widget _generateButton() {
    return FilledButton.icon(
      onPressed: _loading ? null : _mint,
      icon: _loading
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.vpn_key_outlined),
      label: Text(_loading ? 'Generating…' : 'Generate pairing token'),
    );
  }

  Widget _tokenBox() {
    return Container(
      padding: const EdgeInsets.all(TT.s4),
      decoration: BoxDecoration(
        color: TT.surf,
        borderRadius: BorderRadius.circular(TT.rLg),
        border: Border.all(color: TT.line2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('PAIRING TOKEN', style: TT.label()),
          const SizedBox(height: TT.s2),
          SelectableText(_token!, style: TT.mono(size: 13, color: TT.ember)),
          const SizedBox(height: TT.s3),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: _copy,
                icon: const Icon(Icons.copy, size: 16),
                label: const Text('Copy'),
              ),
              const SizedBox(width: TT.s2),
              TextButton(
                onPressed: _loading ? null : _mint,
                child: const Text('Regenerate'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _steps() {
    const steps = [
      'Open Garmin Connect Mobile on your phone.',
      'Go to the Connect IQ store → My Device → Trailtether → Settings.',
      'Paste the token into "Pairing Token" and save.',
      'Open the Trailtether app on your watch — it now syncs here.',
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('HOW TO PAIR', style: TT.label()),
        const SizedBox(height: TT.s3),
        for (var i = 0; i < steps.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: TT.s3),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${i + 1}', style: TT.mono(size: 13, color: TT.ember)),
                const SizedBox(width: TT.s3),
                Expanded(
                  child:
                      Text(steps[i], style: TT.body(size: 13, color: TT.text2)),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

// ───────────────────────── Live heart rate (BLE) ─────────────────────────

const Color _liveGreen = Color(0xFF4CC38A);

/// Connection + live BPM card for a BLE heart-rate broadcaster. Reads the
/// [HeartRateProvider]; the BLE link is the connected/disconnected source.
class _LiveHeartRateCard extends StatelessWidget {
  const _LiveHeartRateCard();

  @override
  Widget build(BuildContext context) {
    final hr = context.watch<HeartRateProvider>();
    final connected = hr.isConnected;
    final live = connected && !hr.isStale && hr.bpm != null;

    return Container(
      padding: const EdgeInsets.all(TT.s4),
      decoration: BoxDecoration(
        color: TT.surf,
        borderRadius: BorderRadius.circular(TT.rLg),
        border:
            Border.all(color: connected ? TT.ember.withOpacity(0.4) : TT.line2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.favorite, color: live ? TT.ember : TT.text2, size: 18),
              const SizedBox(width: TT.s2),
              Text('LIVE HEART RATE', style: TT.label()),
              const Spacer(),
              _chip(hr),
            ],
          ),
          const SizedBox(height: TT.s3),
          if (connected)
            ..._connectedBody(context, hr, live)
          else
            ..._idleBody(context, hr),
        ],
      ),
    );
  }

  List<Widget> _connectedBody(
      BuildContext context, HeartRateProvider hr, bool live) {
    return [
      Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(
            live ? '${hr.bpm}' : '--',
            style: const TextStyle(
                fontSize: 54,
                height: 1.0,
                fontWeight: FontWeight.w800,
                color: TT.ember),
          ),
          const SizedBox(width: 8),
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text('BPM', style: TT.label()),
          ),
        ],
      ),
      const SizedBox(height: TT.s2),
      Text(
        [
          hr.deviceName ?? 'HR sensor',
          if (hr.battery != null) 'battery ${hr.battery}%',
          if (!live) 'waiting for signal…',
        ].join('  ·  '),
        style: TT.body(size: 12, color: TT.text2),
      ),
      const SizedBox(height: TT.s3),
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: () => context.read<HeartRateProvider>().disconnect(),
          icon: const Icon(Icons.bluetooth_disabled, size: 16),
          label: const Text('Disconnect'),
        ),
      ),
    ];
  }

  List<Widget> _idleBody(BuildContext context, HeartRateProvider hr) {
    final isError = hr.status == HrStatus.error;
    return [
      Text(
        hr.error ??
            (hr.hasSavedDevice
                ? 'Saved: ${hr.deviceName}. Tap to reconnect.'
                : 'Put your watch in Broadcast Heart Rate mode (or use a chest strap) to see live BPM here.'),
        style: TT.body(size: 13, color: isError ? TT.red : TT.text2),
      ),
      const SizedBox(height: TT.s3),
      Wrap(
        spacing: TT.s2,
        runSpacing: TT.s2,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          FilledButton.icon(
            onPressed: hr.isBusy
                ? null
                : () {
                    if (hr.hasSavedDevice) {
                      context.read<HeartRateProvider>().reconnect();
                    } else {
                      _showHrScanSheet(context);
                    }
                  },
            icon: hr.isBusy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : Icon(
                    hr.hasSavedDevice
                        ? Icons.bluetooth_connected
                        : Icons.bluetooth_searching,
                    size: 18),
            label: Text(_primaryLabel(hr)),
          ),
          if (hr.hasSavedDevice && !hr.isBusy)
            TextButton(
              onPressed: () => context.read<HeartRateProvider>().forget(),
              child: const Text('Forget'),
            ),
          if (!hr.hasSavedDevice && !hr.isBusy && isError)
            TextButton(
              onPressed: () => _showHrScanSheet(context),
              child: const Text('Scan'),
            ),
        ],
      ),
    ];
  }

  String _primaryLabel(HeartRateProvider hr) {
    if (hr.status == HrStatus.connecting) return 'Connecting…';
    if (hr.status == HrStatus.scanning) return 'Scanning…';
    if (hr.hasSavedDevice) return 'Reconnect';
    return 'Connect a sensor';
  }

  Widget _chip(HeartRateProvider hr) {
    Color c;
    String t;
    switch (hr.status) {
      case HrStatus.connected:
        c = hr.isStale ? TT.text2 : _liveGreen;
        t = hr.isStale ? 'No signal' : 'Connected';
        break;
      case HrStatus.connecting:
        c = TT.ember;
        t = 'Connecting';
        break;
      case HrStatus.scanning:
        c = TT.ember;
        t = 'Scanning';
        break;
      case HrStatus.off:
        c = TT.text2;
        t = 'Bluetooth off';
        break;
      case HrStatus.error:
        c = TT.red;
        t = 'Disconnected';
        break;
      case HrStatus.idle:
        c = TT.text2;
        t = 'Not connected';
        break;
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(t, style: TT.mono(size: 11, color: c)),
      ],
    );
  }
}

Future<void> _showHrScanSheet(BuildContext context) async {
  final hr = context.read<HeartRateProvider>();
  unawaited(hr.startScan());
  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: TT.surf,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
    builder: (_) => const _HrScanSheet(),
  );
  await hr.stopScan();
}

class _HrScanSheet extends StatelessWidget {
  const _HrScanSheet();

  @override
  Widget build(BuildContext context) {
    final hr = context.watch<HeartRateProvider>();
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(TT.s4, TT.s4, TT.s4, TT.s5),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Heart-rate sensors', style: TT.title(18)),
                const Spacer(),
                if (hr.status == HrStatus.scanning)
                  const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: TT.ember)),
              ],
            ),
            const SizedBox(height: TT.s2),
            Text(
              'On the watch: Broadcast Heart Rate → start. Then pick it below.',
              style: TT.body(size: 12.5, color: TT.text2),
            ),
            const SizedBox(height: TT.s3),
            if (hr.found.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: TT.s5),
                child: Center(
                  child: Text(
                    hr.status == HrStatus.scanning
                        ? 'Searching…'
                        : 'Nothing found yet.',
                    style: TT.body(size: 13, color: TT.text2),
                  ),
                ),
              ),
            for (final d in hr.found)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.favorite_border, color: TT.ember),
                title:
                    Text(d.name, style: TT.body(size: 14, w: FontWeight.w600)),
                subtitle: Text('Signal ${d.rssi} dBm',
                    style: TT.body(size: 11.5, color: TT.text2)),
                trailing: const Icon(Icons.chevron_right, color: TT.text2),
                onTap: () {
                  context.read<HeartRateProvider>().connectTo(d);
                  Navigator.of(context).pop();
                },
              ),
            const SizedBox(height: TT.s2),
            TextButton.icon(
              onPressed: hr.status == HrStatus.scanning
                  ? null
                  : () => context.read<HeartRateProvider>().startScan(),
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Scan again'),
            ),
          ],
        ),
      ),
    );
  }
}
