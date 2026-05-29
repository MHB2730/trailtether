---
tags: [type/architecture, layer/infra, status/stable]
aliases: [Feature Map, Feature Tree, App Map]
source_paths: [trailtether_app/lib, supabase]
---

# Feature Map

A **structured, top-down** view of Trailtether — the clean-hierarchy alternative to the force-directed graph (which can only ever be a "nest"). Renders natively in Obsidian. Change `flowchart TD` → `LR` for a left-to-right (horizontal) version.

```mermaid
flowchart TD
  TT(["Trailtether 2.0"]):::root

  TT --> MOB["Mobile app<br/>Flutter · Android"]:::surface
  TT --> PC["PC command centre<br/>Flutter · Windows"]:::surface
  TT --> SITE["Hilltrek website<br/>+ admin SPA"]:::surface

  subgraph COREF["Core mobile features"]
    direction TB
    REC["Hike Recording"]:::core
    TRK["Live Tracking"]:::core
    TEAM["Teams + Chat"]:::core
    SAFE["Safety · Incidents · SOS"]:::core
    WX["Weather Alerts"]:::core
    MAP["Maps · Trails · Caves · 3D"]:::core
    COMM["Community · Berg Live"]:::core
  end
  MOB --> COREF

  subgraph BACK["Supabase backend"]
    direction TB
    PG[("Postgres<br/>44 tables · RLS")]:::back
    RT{{"Realtime"}}:::back
    AUTH["Auth<br/>Google + email"]:::back
    STOR[("Storage")]:::back
    EF["Edge Functions ×15"]:::back
    OTA["app_releases<br/>Android OTA"]:::back
  end

  REC --> PG
  TEAM --> PG
  SAFE --> PG
  COMM --> PG
  WX --> WAPI["weather APIs"]:::ext
  MAP --> TILES["offline tiles"]:::ext
  TRK --> RT
  RT --> PG
  PC --> RT
  PC --> PG
  MOB --> AUTH
  MOB --> OTA

  SITE --> EF
  EF --> PG
  EF --> PAY["PayFast · Yoco · Zapper"]:::ext
  PC --> GH["GitHub Releases<br/>Windows OTA"]:::ext

  classDef root fill:#1a0d04,stroke:#FF6A2C,color:#ffffff,stroke-width:2px
  classDef surface fill:#241a12,stroke:#FF6A2C,color:#ffd9c2
  classDef core fill:#FF6A2C,stroke:#1a0d04,color:#1a0d04
  classDef back fill:#5A8CC8,stroke:#0a0c0f,color:#06121f
  classDef ext fill:#333a44,stroke:#8a93a3,color:#dde3ec
```

Reading it: three **surfaces** branch from the product; the mobile app owns the **core features** (ember); they persist to the **Supabase backend** (blue); the website drives **edge functions + payments**; the two **OTA channels** are explicit — Android via `app_releases`, Windows via GitHub Releases. Colours match the graph colour groups.

## Split by surface (three apps, connections kept)

The three surfaces as **distinct groups**, with every shared connection drawn — note that **Android + Windows are the same Flutter codebase** (different shells), so they meet at a *shared core*; the **website** is separate code; all three converge on **Supabase**, and live tracking links mobile → Realtime → the PC watcher.

```mermaid
flowchart TD
  TT(["Trailtether 2.0"]):::root

  TT --> AND
  TT --> WIN
  TT --> WEB

  subgraph AND["Android app (mobile)"]
    direction TB
    AMOB["Mobile shell — tt_* screens"]:::core
    AFEAT["Recording · Teams · Safety · Weather · Community"]:::core
  end

  subgraph WIN["Windows app (command centre)"]
    direction TB
    WPC["PC shell — MainPcShell"]:::core
    WMC["Mission Control — watch live team"]:::core
  end

  subgraph WEB["Website + admin"]
    direction TB
    WSITE["hilltrek.co.za"]:::biz
    WADMIN["admin SPA"]:::biz
    WEF["Edge Functions ×15"]:::biz
  end

  CORE["Shared Flutter core — services · providers · models · maps"]:::back
  AND --> CORE
  WIN --> CORE

  SB[("Supabase — Postgres · RLS · Auth · Storage")]:::back
  RT{{"Realtime"}}:::back

  CORE --> SB
  WEB --> SB
  WEF --> SB
  AMOB -. "publishes GPS" .-> RT
  WMC -. "watches team" .-> RT
  RT --> SB

  classDef root fill:#1a0d04,stroke:#FF6A2C,color:#ffffff,stroke-width:2px
  classDef core fill:#FF6A2C,stroke:#1a0d04,color:#1a0d04
  classDef biz fill:#4CC38A,stroke:#0a0c0f,color:#06210f
  classDef back fill:#5A8CC8,stroke:#0a0c0f,color:#06121f
```

The dashed lines are the **cross-surface link** you care about — the mobile app publishes GPS into Realtime and the Windows command centre watches it. Splitting the boxes doesn't break that; it makes it visible.

## Getting a hierarchy view (not a nest) in Obsidian

| Want | Use | Status |
|---|---|---|
| **A controlled diagram** | The **Mermaid** map above — edit it to add/move nodes; exact, no nest | ✅ here |
| **An interactive tree of your real notes** | **ExcaliBrain** — palette → *ExcaliBrain: Open* | ✅ dialled in (below) |
| Interactive force-free graph | **Juggl** plugin (`dagre` hierarchical layout) | needs install |
| Overview-only | Core **Graph View** with colour groups | force-directed; will stay a "nest" |

### ExcaliBrain — now tuned for hierarchy
Config changed in `.obsidian/plugins/excalibrain/data.json` (reload Obsidian to apply):
- `inferAllLinksAsFriends: false` — links now read as **parent/child** (a tree), not sideways "friends" (a mesh). This was the cause of the web.
- `showAttachments: false`, `showVirtualNodes: false` — drop image + unresolved-link clutter.

The tree is built from the existing **[[Home]] → section Index → doc** link backbone, so opening Home (or any index) in ExcaliBrain shows a clean top-down hierarchy. To force a specific parent on any note, add `up: "[[Parent Note]]"` to its frontmatter (ExcaliBrain reads `up`/`parent`/`source` as parent fields).
