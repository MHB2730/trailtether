---
tags: [type/model, layer/db, status/stable, domain/pairing]
aliases: [public.tether_pairings]
source_paths: []
---

# tether_pairings

Short-lived pairing tokens for the PC-to-mobile "Pair Device" flow.

## Schema (key columns)

| Column | Type |
|---|---|
| id | uuid PK |
| watcher_uid | uuid → profiles.id |
| token | text (8-char A-Z2-9 minus I/O/0/1) |
| expires_at | timestamptz |
| claimed_by_uid | uuid (nullable) |
| claimed_at | timestamptz |
| created_at | timestamptz |

## Flow

1. PC user clicks "Pair Device" → `PcPairDeviceScreen` mints a row + shows QR
2. Mobile user scans QR → calls [[claim_tether_token]] RPC
3. Server marks row claimed; PC subscribes to row via realtime, sees the link
4. Mobile + PC now share an audit link for tracking

## CRUD locations

- **Created** by `PcPairDeviceScreen._mintToken()` in [[MainPcShell]]
- **Claimed** via [[claim_tether_token]] RPC from mobile scanner
- **Read realtime** by `PcPairDeviceScreen` waiting for claim

## RPC

[[claim_tether_token]] — validates token + not-expired + not-claimed → marks claimed, returns watcher info.
