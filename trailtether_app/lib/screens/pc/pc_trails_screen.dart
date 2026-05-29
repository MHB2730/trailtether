// PC Trails — admin section for the curated trail catalogue.
//
// Reads from public.trails via TrailRepository. RLS gates the writes
// (admin-only); the screen surfaces results back to the user with
// snack feedback.
//
// What this screen lets you do:
//   • Search / filter trails by name, difficulty, category
//   • Edit name, difficulty, category, description, manual gain
//     override, published flag (inline dialog)
//   • Delete a trail (confirmation)
//   • Add a new trail by uploading a GPX (parses → bundle-shape →
//     upsertOne)
//   • Seed the entire catalogue from the bundled JSON (idempotent —
//     safe to re-run, used once on first admin migration)
//
// After every successful mutation we call
// StaticDataProvider.refreshTrails() so the change is visible across
// the rest of the app (map, list, search) immediately.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../core/design_tokens.dart';
import '../../models/trail.dart';
import '../../providers/static_data_provider.dart';
import '../../services/gpx_service.dart';
import '../../services/logger_service.dart';
import '../../services/trail_repository.dart';

class PcTrailsScreen extends StatefulWidget {
  const PcTrailsScreen({super.key});

  @override
  State<PcTrailsScreen> createState() => _PcTrailsScreenState();
}

class _PcTrailsScreenState extends State<PcTrailsScreen> {
  final _searchCtrl = TextEditingController();
  String _difficulty = 'All';
  String _category = 'All';
  bool _seeding = false;
  double _seedProgress = 0.0;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── Actions ─────────────────────────────────────────────────────────────

  Future<void> _seedFromBundle() async {
    final confirm = await _confirm(
      title: 'Seed catalogue from bundle?',
      body: 'Inserts the 239 bundled trails into Supabase. Idempotent — '
          'existing rows are replaced, so re-running is safe.',
      action: 'Seed',
    );
    if (confirm != true) return;

    setState(() {
      _seeding = true;
      _seedProgress = 0.0;
    });
    try {
      final result = await TrailRepository.seedFromBundle(
        onProgress: (done, total) {
          if (!mounted) return;
          setState(() => _seedProgress = done / total);
        },
      );
      if (!mounted) return;
      _snack(
        'Seeded ${result.inserted} trails'
        '${result.skipped > 0 ? " (${result.skipped} failed)" : ""}.',
        ok: result.skipped == 0,
      );
      await context.read<StaticDataProvider>().refreshTrails();
    } catch (e, stack) {
      LoggerService.error('TRAILS_SEED', 'seed failed: $e', stack);
      if (mounted) _snack('Seed failed: $e', ok: false);
    } finally {
      if (mounted) {
        setState(() {
          _seeding = false;
          _seedProgress = 0.0;
        });
      }
    }
  }

  Future<void> _refresh() async {
    await context.read<StaticDataProvider>().refreshTrails();
    if (mounted) _snack('Catalogue refreshed.', ok: true);
  }

  Future<void> _addViaGpx() async {
    final picked = await GpxService.pickAndParse(TT.ember);
    if (picked == null || !mounted) return;
    final defaultName = picked.track.filename
        .replaceAll(RegExp(r'\.gpx$', caseSensitive: false), '')
        .replaceAll('_', ' ')
        .replaceAll('-', ' ');

    final result = await showDialog<_TrailEditResult>(
      context: context,
      builder: (_) => _TrailEditDialog(
        title: 'Add Trail',
        initialName: defaultName,
        initialDifficulty: 'Moderate',
        initialCategory:
            defaultName.toLowerCase().contains('cave') ? 'cave' : 'hike',
        initialDescription: '',
        initialElevationGainM: picked.track.elevationGainM.round(),
        initialPublished: true,
      ),
    );
    if (result == null || !mounted) return;

    final id = _slugFromName(result.name);
    final coords = <List<num>>[];
    for (var i = 0; i < picked.track.points.length; i++) {
      final p = picked.track.points[i];
      final ele =
          i < picked.track.elevations.length ? picked.track.elevations[i] : 0.0;
      coords.add([p.longitude, p.latitude, ele]);
    }
    final bundle = <String, dynamic>{
      'id': id,
      'name': result.name,
      'description': result.description,
      'difficulty': result.difficulty,
      'category': result.category,
      'distanceKm': picked.track.distanceKm,
      'elevationGainM': result.elevationGainM,
      // Descent isn't parsed from the GPX; leave it 0 rather than mirroring
      // gain. Trail.fromJson recomputes it from the 3D coords on load.
      'elevationLossM': 0,
      'estTimeHours': 0,
      'minEle': 0,
      'maxEle': 0,
      'coords': coords,
      'published': result.published,
    };
    final ok = await TrailRepository.upsertOne(bundle);
    if (!mounted) return;
    _snack(
      ok ? 'Added "${result.name}".' : 'Failed to add trail.',
      ok: ok,
    );
    if (ok) await context.read<StaticDataProvider>().refreshTrails();
  }

  Future<void> _editTrail(Trail t) async {
    final result = await showDialog<_TrailEditResult>(
      context: context,
      builder: (_) => _TrailEditDialog(
        title: 'Edit Trail',
        initialName: t.name,
        initialDifficulty: t.difficulty,
        initialCategory: t.isCave ? 'cave' : 'hike',
        initialDescription: t.description,
        initialElevationGainM: t.elevationGainM,
        initialPublished: t.published,
      ),
    );
    if (result == null || !mounted) return;

    final ok = await TrailRepository.updateMeta(
      id: t.id,
      name: result.name,
      difficulty: result.difficulty,
      category: result.category,
      description: result.description,
      elevationGainM: result.elevationGainM,
      published: result.published,
    );
    if (!mounted) return;
    _snack(
      ok ? 'Saved "${result.name}".' : 'Update failed.',
      ok: ok,
    );
    if (ok) await context.read<StaticDataProvider>().refreshTrails();
  }

  Future<void> _deleteTrail(Trail t) async {
    final confirm = await _confirm(
      title: 'Delete "${t.name}"?',
      body: 'This removes the trail from the catalogue everywhere — '
          'mobile apps, PC, and the public site. This cannot be undone.',
      action: 'Delete',
      destructive: true,
    );
    if (confirm != true) return;

    final ok = await TrailRepository.delete(t.id);
    if (!mounted) return;
    _snack(
      ok ? 'Deleted "${t.name}".' : 'Delete failed.',
      ok: ok,
    );
    if (ok) await context.read<StaticDataProvider>().refreshTrails();
  }

  // ── Helpers ─────────────────────────────────────────────────────────────

  Future<bool?> _confirm({
    required String title,
    required String body,
    required String action,
    bool destructive = false,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: TT.bg2,
        title: Text(title, style: TT.body(size: 15, w: FontWeight.w800)),
        content: Text(body, style: TT.body(size: 13, color: TT.text2)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: TT.body(size: 13, color: TT.text2)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              action,
              style: TT.body(
                size: 13,
                w: FontWeight.w800,
                color: destructive ? TT.red : TT.ember,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _snack(String msg, {required bool ok}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: ok ? const Color(0xFF5AC26D) : const Color(0xFFFF6B6B),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  static String _slugFromName(String name) {
    final base = name
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    final stamp = DateTime.now().millisecondsSinceEpoch.toString();
    return base.isEmpty ? 'trail_$stamp' : '${base}_$stamp';
  }

  // ── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final data = context.watch<StaticDataProvider>();
    final query = _searchCtrl.text.toLowerCase().trim();
    final filtered = data.allTrails.where((t) {
      if (query.isNotEmpty && !t.name.toLowerCase().contains(query)) {
        return false;
      }
      if (_difficulty != 'All' && t.difficulty != _difficulty) return false;
      if (_category != 'All') {
        final isCave = t.isCave;
        if (_category == 'cave' && !isCave) return false;
        if (_category == 'hike' && isCave) return false;
      }
      return true;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Header(
          total: data.allTrails.length,
          showing: filtered.length,
          loading: data.loading,
          seeding: _seeding,
          seedProgress: _seedProgress,
          onSeed: _seedFromBundle,
          onRefresh: _refresh,
          onAdd: _addViaGpx,
        ),
        _Filters(
          searchCtrl: _searchCtrl,
          difficulty: _difficulty,
          category: _category,
          onChanged: (d, c) => setState(() {
            _difficulty = d;
            _category = c;
          }),
          onSearchChanged: () => setState(() {}),
        ),
        const Divider(height: 1, color: TT.line),
        Expanded(
          child: filtered.isEmpty
              ? _EmptyState(total: data.allTrails.length)
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final t = filtered[i];
                    return _TrailRow(
                      trail: t,
                      onEdit: () => _editTrail(t),
                      onDelete: () => _deleteTrail(t),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final int total;
  final int showing;
  final bool loading;
  final bool seeding;
  final double seedProgress;
  final VoidCallback onSeed;
  final VoidCallback onRefresh;
  final VoidCallback onAdd;
  const _Header({
    required this.total,
    required this.showing,
    required this.loading,
    required this.seeding,
    required this.seedProgress,
    required this.onSeed,
    required this.onRefresh,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 18),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: TT.line)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'TRAILS · CURATED CATALOGUE',
            style: TT.label(size: 11, color: TT.ember, letterSpacing: 1.6),
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                'Hilltrek catalogue',
                style: TT.title(22),
              ),
              const SizedBox(width: 14),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: TT.surf,
                  border: Border.all(color: TT.line2),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  loading
                      ? 'loading…'
                      : (showing == total
                          ? '$total trails'
                          : '$showing of $total trails'),
                  style: TT.mono(size: 11, color: TT.text2),
                ),
              ),
              const Spacer(),
              if (seeding) ...[
                SizedBox(
                  width: 140,
                  child: LinearProgressIndicator(
                    value: seedProgress,
                    backgroundColor: TT.surf,
                    color: TT.ember,
                    minHeight: 6,
                  ),
                ),
                const SizedBox(width: 12),
              ],
              _PcButton(
                icon: Icons.refresh,
                label: 'Refresh',
                onTap: seeding ? null : onRefresh,
              ),
              const SizedBox(width: 8),
              _PcButton(
                icon: Icons.cloud_upload_outlined,
                label: 'Seed from bundle',
                onTap: seeding ? null : onSeed,
              ),
              const SizedBox(width: 8),
              _PcButton(
                icon: Icons.add,
                label: 'Add trail',
                ember: true,
                onTap: seeding ? null : onAdd,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Filters extends StatelessWidget {
  final TextEditingController searchCtrl;
  final String difficulty;
  final String category;
  final void Function(String difficulty, String category) onChanged;
  final VoidCallback onSearchChanged;
  const _Filters({
    required this.searchCtrl,
    required this.difficulty,
    required this.category,
    required this.onChanged,
    required this.onSearchChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 14, 24, 14),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: TT.surf,
                border: Border.all(color: TT.line2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.search, size: 16, color: TT.text3),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: searchCtrl,
                      onChanged: (_) => onSearchChanged(),
                      style: TT.body(size: 13, color: TT.text),
                      decoration: InputDecoration(
                        isDense: true,
                        border: InputBorder.none,
                        hintText: 'Search by name…',
                        hintStyle: TT.body(size: 13, color: TT.text3),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _PcDropdown(
              value: difficulty,
              items: const [
                'All',
                'Easy',
                'Moderate',
                'Challenging',
                'Hard',
                'Extreme'
              ],
              onChanged: (v) => onChanged(v, category),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _PcDropdown(
              value: category,
              items: const ['All', 'hike', 'cave'],
              onChanged: (v) => onChanged(difficulty, v),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final int total;
  const _EmptyState({required this.total});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.alt_route_outlined, size: 48, color: TT.text3),
            const SizedBox(height: 16),
            Text(
              total == 0
                  ? 'Catalogue is empty'
                  : 'No trails match the current filter',
              style: TT.body(size: 14, w: FontWeight.w700, color: TT.text2),
            ),
            const SizedBox(height: 6),
            Text(
              total == 0
                  ? 'Run "Seed from bundle" to import the 239 trails that ship with the app.'
                  : 'Try clearing the search or switching filters.',
              textAlign: TextAlign.center,
              style: TT.body(size: 12, color: TT.text3),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrailRow extends StatelessWidget {
  final Trail trail;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const _TrailRow({
    required this.trail,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isCave = trail.isCave;
    return MouseRegion(
      cursor: SystemMouseCursors.basic,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: TT.surf,
          border: Border.all(color: TT.line),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isCave
                    ? const Color(0xFF8D6E63).withOpacity(0.18)
                    : TT.emberDim,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                isCave ? Icons.terrain : Icons.directions_walk,
                size: 18,
                color: isCave ? const Color(0xFFC2A695) : TT.ember,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              flex: 4,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    trail.name,
                    style: TT.body(size: 13.5, w: FontWeight.w700),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (trail.description.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      trail.description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TT.body(size: 11, color: TT.text3),
                    ),
                  ],
                ],
              ),
            ),
            Expanded(
              child: _MetaCell(
                label: 'Difficulty',
                value: trail.difficulty,
              ),
            ),
            Expanded(
              child: _MetaCell(
                label: 'Distance',
                value: '${trail.distanceKm.toStringAsFixed(1)} km',
              ),
            ),
            Expanded(
              child: _MetaCell(
                label: 'Gain',
                value: '${trail.elevationGainM} m',
              ),
            ),
            Expanded(
              child: _MetaCell(
                label: 'Category',
                value: isCave ? 'cave' : 'hike',
              ),
            ),
            const SizedBox(width: 8),
            _IconBtn(icon: Icons.edit_outlined, onTap: onEdit, tooltip: 'Edit'),
            const SizedBox(width: 4),
            _IconBtn(
              icon: Icons.delete_outline,
              danger: true,
              onTap: onDelete,
              tooltip: 'Delete',
            ),
          ],
        ),
      ),
    );
  }
}

class _MetaCell extends StatelessWidget {
  final String label;
  final String value;
  const _MetaCell({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: TT.label(size: 9.5, color: TT.text3, letterSpacing: 1.2),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: TT.mono(size: 12, color: TT.text),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;
  final bool danger;
  const _IconBtn({
    required this.icon,
    required this.onTap,
    required this.tooltip,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: TT.bg2,
              border: Border.all(color: TT.line2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: danger ? TT.red : TT.text2),
          ),
        ),
      ),
    );
  }
}

class _PcButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool ember;
  const _PcButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.ember = false,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.forbidden,
      child: GestureDetector(
        onTap: onTap,
        child: Opacity(
          opacity: enabled ? 1.0 : 0.45,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: ember ? TT.ember : TT.surf,
              border: Border.all(color: ember ? TT.ember : TT.line2),
              borderRadius: BorderRadius.circular(10),
              boxShadow: ember ? TT.shadowEmber : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 14, color: ember ? TT.emberInk : TT.text2),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TT
                      .body(
                        size: 12,
                        w: FontWeight.w800,
                        color: ember ? TT.emberInk : TT.text,
                      )
                      .copyWith(letterSpacing: 0.06 * 12),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PcDropdown extends StatelessWidget {
  final String value;
  final List<String> items;
  final ValueChanged<String> onChanged;
  const _PcDropdown({
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: TT.surf,
        border: Border.all(color: TT.line2),
        borderRadius: BorderRadius.circular(10),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: items.contains(value) ? value : items.first,
          isExpanded: true,
          dropdownColor: TT.bg2,
          icon: const Icon(Icons.expand_more, color: TT.text2, size: 16),
          style: TT.body(size: 13, color: TT.text),
          items: items
              .map((s) => DropdownMenuItem(value: s, child: Text(s)))
              .toList(),
          onChanged: (v) => v == null ? null : onChanged(v),
        ),
      ),
    );
  }
}

// ── Edit / Add dialog ─────────────────────────────────────────────────────

class _TrailEditResult {
  final String name;
  final String difficulty;
  final String category;
  final String description;
  final int elevationGainM;
  final bool published;
  _TrailEditResult({
    required this.name,
    required this.difficulty,
    required this.category,
    required this.description,
    required this.elevationGainM,
    required this.published,
  });
}

class _TrailEditDialog extends StatefulWidget {
  final String title;
  final String initialName;
  final String initialDifficulty;
  final String initialCategory;
  final String initialDescription;
  final int initialElevationGainM;
  final bool initialPublished;
  const _TrailEditDialog({
    required this.title,
    required this.initialName,
    required this.initialDifficulty,
    required this.initialCategory,
    required this.initialDescription,
    required this.initialElevationGainM,
    required this.initialPublished,
  });

  @override
  State<_TrailEditDialog> createState() => _TrailEditDialogState();
}

class _TrailEditDialogState extends State<_TrailEditDialog> {
  late final _nameCtrl = TextEditingController(text: widget.initialName);
  late final _descCtrl = TextEditingController(text: widget.initialDescription);
  late final _gainCtrl =
      TextEditingController(text: widget.initialElevationGainM.toString());
  late String _difficulty = widget.initialDifficulty;
  late String _category = widget.initialCategory;
  late bool _published = widget.initialPublished;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _gainCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: TT.bg2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(widget.title.toUpperCase(),
                  style:
                      TT.label(size: 11, color: TT.ember, letterSpacing: 1.6)),
              const SizedBox(height: 14),
              _Field(
                label: 'Name',
                child: TextField(
                  controller: _nameCtrl,
                  style: TT.body(size: 13.5, color: TT.text),
                  decoration: _inputDeco('Aasvoelkrans Cave via Highmoor'),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _Field(
                      label: 'Difficulty',
                      child: _PcDropdown(
                        value: _difficulty,
                        items: const [
                          'Easy',
                          'Moderate',
                          'Challenging',
                          'Hard',
                          'Extreme'
                        ],
                        onChanged: (v) => setState(() => _difficulty = v),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _Field(
                      label: 'Category',
                      child: _PcDropdown(
                        value: _category,
                        items: const [
                          'hike',
                          'cave',
                          'peak',
                          'circular',
                          'scramble'
                        ],
                        onChanged: (v) => setState(() => _category = v),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _Field(
                label: 'Elevation gain (m)',
                child: TextField(
                  controller: _gainCtrl,
                  keyboardType: TextInputType.number,
                  style: TT.mono(size: 13, color: TT.text),
                  decoration: _inputDeco('0'),
                ),
              ),
              const SizedBox(height: 12),
              _Field(
                label: 'Description',
                child: TextField(
                  controller: _descCtrl,
                  maxLines: 3,
                  style: TT.body(size: 13, color: TT.text),
                  decoration: _inputDeco('Short blurb shown in the app'),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Switch(
                    value: _published,
                    onChanged: (v) => setState(() => _published = v),
                    activeColor: TT.ember,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Published',
                    style: TT.body(size: 12, color: TT.text2),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('Cancel',
                        style: TT.body(size: 13, color: TT.text2)),
                  ),
                  const SizedBox(width: 4),
                  TextButton(
                    onPressed: () {
                      final name = _nameCtrl.text.trim();
                      if (name.isEmpty) return;
                      Navigator.pop(
                        context,
                        _TrailEditResult(
                          name: name,
                          difficulty: _difficulty,
                          category: _category,
                          description: _descCtrl.text.trim(),
                          elevationGainM:
                              int.tryParse(_gainCtrl.text.trim()) ?? 0,
                          published: _published,
                        ),
                      );
                    },
                    child: Text('Save',
                        style: TT.body(
                            size: 13, w: FontWeight.w800, color: TT.ember)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDeco(String hint) => InputDecoration(
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        filled: true,
        fillColor: TT.surf,
        hintText: hint,
        hintStyle: TT.body(size: 13, color: TT.text3),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: TT.line2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: TT.line2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: TT.ember, width: 1.2),
        ),
      );
}

class _Field extends StatelessWidget {
  final String label;
  final Widget child;
  const _Field({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: TT.label(size: 9.5, color: TT.text3, letterSpacing: 1.4),
        ),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}

// Keep latlong2 import alive — used implicitly when GpxService returns
// LatLng points consumed in _addViaGpx. Avoids an unused-import lint.
// ignore: unused_element
typedef _KeepLatLngImport = LatLng;
