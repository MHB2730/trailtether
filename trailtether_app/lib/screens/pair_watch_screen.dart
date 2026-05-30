import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/design_tokens.dart';
import '../services/watch_service.dart';

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
          const Icon(Icons.watch_outlined, color: TT.ember, size: 40),
          const SizedBox(height: TT.s3),
          Text('Connect your Instinct', style: TT.title(22)),
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
                  child: Text(steps[i], style: TT.body(size: 13, color: TT.text2)),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
