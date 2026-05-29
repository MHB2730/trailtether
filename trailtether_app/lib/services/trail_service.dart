import 'package:flutter/foundation.dart';
import '../models/trail.dart';
import 'logger_service.dart';
import 'trail_repository.dart';

class TrailService {
  static List<Trail>? _cache;

  /// Resolve the curated trail catalogue.
  ///
  /// Layering (each falls through to the next on miss / failure):
  ///   1. In-memory cache (set after first successful load)
  ///   2. Supabase `public.trails` via TrailRepository.fetchAll
  ///   3. SharedPreferences cache from a previous fetch (offline)
  ///   4. Bundled assets/data/routes_cleaned.json (first launch / no signal)
  ///
  /// Admin edits land in Supabase, so step 2 always wins once we have a
  /// signal. The bundled JSON is the unchanging fallback — it shipped with
  /// the binary and is here purely so the app works on first launch
  /// without a network round-trip.
  static Future<List<Trail>> loadTrails({bool forceRefresh = false}) async {
    if (!forceRefresh && _cache != null) return _cache!;

    List<Map<String, dynamic>> rows = const [];
    var source = 'bundle';

    try {
      rows = await TrailRepository.fetchAll();
      source = 'supabase';
    } catch (e) {
      LoggerService.log(
          'TRAILS', 'Supabase fetch failed ($e); falling back to cache');
      rows = await TrailRepository.loadCache();
      if (rows.isNotEmpty) source = 'cache';
    }

    if (rows.isEmpty) {
      rows = await TrailRepository.loadBundleAsRows();
      source = 'bundle';
    }

    final loadedTrails = <Trail>[];
    for (final row in rows) {
      try {
        // Normalize the name at load time so search results, list rows,
        // detail headers and map labels all show the same uniform text. The
        // upstream JSON has mixed conventions (kebab-case, leading-zero
        // typos, "via via" duplication, inconsistent possessive casing —
        // see normalizeTrailName for the full ruleset).
        final original = row['name']?.toString() ?? '';
        row['name'] = normalizeTrailName(original);
        loadedTrails.add(Trail.fromJson(row));
      } catch (err) {
        debugPrint(
            'Error parsing trail: ${row['name'] ?? 'unknown'}. Error: $err');
        // Skip corrupt trails instead of failing entirely
      }
    }

    loadedTrails.sort((a, b) => a.name.compareTo(b.name));
    _cache = loadedTrails;
    LoggerService.log(
        'TRAILS', 'Loaded ${loadedTrails.length} trails from $source');
    return loadedTrails;
  }

  /// Invalidate the in-memory cache. The next `loadTrails()` call will
  /// hit Supabase again. Used after admin edits / seeds so changes
  /// surface without an app restart.
  static void invalidateCache() {
    _cache = null;
  }

  static List<Trail> filter(
    List<Trail> all, {
    String query = '',
    String? difficulty,
  }) {
    return all.where((t) {
      final matchesQuery =
          query.isEmpty || t.name.toLowerCase().contains(query.toLowerCase());
      final matchesDiff = difficulty == null ||
          difficulty == 'All' ||
          t.difficulty == difficulty;
      return matchesQuery && matchesDiff;
    }).toList();
  }

  /// Words that stay lowercase when they appear in the middle of a name
  /// (e.g. "Cathedral Peak to Doreen Falls", "Cave via Bushman's Nek").
  static const _kConnectors = {
    'via',
    'to',
    'and',
    'or',
    'of',
    'the',
    'from',
    'in',
    'on',
    'at',
    'a',
    'an',
    'for',
    'with',
  };

  /// Normalize a raw trail name from the upstream JSON to a uniform format.
  ///
  /// Rules (idempotent):
  /// - Trim, collapse runs of whitespace, replace kebab-case with spaces.
  /// - Strip a single leading "0" before a letter ("0mnweni" → "Mnweni" —
  ///   the underlying data has a known OCR-style typo on Mnweni routes).
  /// - Collapse repeated "via via" / "to to" segments to a single token.
  /// - Title-case each word; preserve internal apostrophes lowercase
  ///   ("Cleo'S" → "Cleo's", "Bushman'S" → "Bushman's").
  /// - Keep prepositions / conjunctions lowercase when they appear after the
  ///   first word so reads like "Cathedral Peak to Baboon Rock" instead of
  ///   "Cathedral Peak To Baboon Rock".
  static String normalizeTrailName(String raw) {
    var s = raw.trim();
    if (s.isEmpty) return s;

    // Strip leading "0" typo before a letter (e.g. "0mnweni" → "mnweni").
    s = s.replaceFirst(RegExp(r'^0(?=[a-zA-Z])'), '');

    // kebab-case → spaces
    s = s.replaceAll('-', ' ');

    // Collapse whitespace
    s = s.replaceAll(RegExp(r'\s+'), ' ').trim();

    // Collapse "via via", "to to" etc — run repeatedly so triple-stutters
    // also collapse ("via via via" → "via").
    for (final connector in ['via', 'to', 'and']) {
      final dupe =
          RegExp('\\b$connector\\s+$connector\\b', caseSensitive: false);
      while (dupe.hasMatch(s)) {
        s = s.replaceAll(dupe, connector);
      }
    }
    s = s.replaceAll(RegExp(r'\s+'), ' ').trim();

    // Title-case word by word.
    final words = s.split(' ');
    final out = <String>[];
    for (var i = 0; i < words.length; i++) {
      final w = words[i];
      if (w.isEmpty) continue;
      final lower = w.toLowerCase();
      final isFirst = out.isEmpty;
      if (!isFirst && _kConnectors.contains(lower)) {
        out.add(lower);
      } else {
        out.add(_capitalize(lower));
      }
    }
    return out.join(' ');
  }

  /// Capitalize first letter and leave the rest alone. Because the caller
  /// passes the already-lowercased word, this correctly produces "Cleo's"
  /// from "cleo's" (the s after the apostrophe stays lowercase naturally).
  /// Pure numeric / punctuation words (like "(2)") pass through unchanged.
  static String _capitalize(String word) {
    if (word.isEmpty) return word;
    // Find the first letter we can capitalize (skip leading non-letters
    // like "(" so "(2)" stays "(2)").
    for (var i = 0; i < word.length; i++) {
      final ch = word[i];
      if (RegExp(r'[a-z]').hasMatch(ch)) {
        return word.substring(0, i) + ch.toUpperCase() + word.substring(i + 1);
      }
    }
    return word;
  }
}
