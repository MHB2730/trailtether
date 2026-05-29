#!/usr/bin/env python3
"""Remove duplicate routes from the bundled trail catalogue.

The bundle (`trailtether_app/assets/data/routes_cleaned.json`) historically
shipped many routes twice: a clean underscore-id entry
(``hc_to_caracal_cave`` -> "Caracal Cave via Highmoor") and a raw hyphen-id
twin (``hc-to-caracal-cave`` -> "Caracal Cave via Hc"). They have distinct
ids, so the idempotent "Seed from bundle" inserts both and the live
``public.trails`` catalogue ends up with duplicate routes.

This script collapses each group of ids that are identical after stripping
``-``/``_`` down to a single entry, keeping the cleanest one. The keep-rule
matches the one used to dedupe the live DB on 2026-05-29:

  1. prefer the id with NO hyphen (the clean underscore-slug),
  2. then the longest name (more descriptive),
  3. then the lexicographically smallest id (stable tiebreak).

Run from the repo root:  python scripts/dedupe_routes.py
Use --check to report duplicates without writing.
"""
import json
import re
import sys
import collections
from pathlib import Path

BUNDLE = Path(__file__).resolve().parent.parent / "trailtether_app" / "assets" / "data" / "routes_cleaned.json"


def norm(trail_id: str) -> str:
    return re.sub(r"[-_]", "", (trail_id or "").lower())


def keep_rank(entry: dict):
    tid = entry.get("id", "")
    return ("-" in tid, -len(entry.get("name", "")), tid)


def main() -> int:
    check_only = "--check" in sys.argv
    data = json.loads(BUNDLE.read_text(encoding="utf-8"))

    groups = collections.OrderedDict()
    for entry in data:
        groups.setdefault(norm(entry.get("id", "")), []).append(entry)

    kept, removed = [], []
    for variants in groups.values():
        winner = min(variants, key=keep_rank)
        kept.append(winner)
        removed.extend(v for v in variants if v is not winner)

    print(f"entries:  {len(data)}")
    print(f"unique:   {len(kept)}")
    print(f"removed:  {len(removed)}")
    if removed:
        print("removed ids:")
        for e in sorted(removed, key=lambda e: e.get("id", "")):
            print(f"  - {e.get('id')}  ({e.get('name')})")

    if check_only:
        return 0

    # Preserve original ordering of the kept entries.
    kept_ids = {id(e) for e in kept}
    deduped = [e for e in data if id(e) in kept_ids]
    BUNDLE.write_text(
        json.dumps(deduped, ensure_ascii=False, separators=(",", ":")),
        encoding="utf-8",
    )
    print(f"wrote {len(deduped)} entries to {BUNDLE.name}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
