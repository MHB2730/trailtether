# 🚨 Incident Reporting & Safety

Safety is crowd-sourced in Trailtether through a multi-stage verification pipeline.

## 📝 Reporting Incidents
Users can report hazards (fire, trail damage, medical emergencies) with:
- **Type & Severity**: Categorized for quick filtering.
- **Location**: Precise GPS coordinates.
- **Status**: Defaults to `active`.

## ✅ Verification Logic
To prevent false reports, the system uses a **Verification RPC**:
- **Verified Status**: An incident is marked `is_verified = true` once **3 unique users** have verified it.
- **Restrictions**: A user cannot verify their own report.

## 🚩 Moderation & Flagging
- **Crowd Moderation**: Users can flag suspicious or incorrect reports.
- **Auto-Hide**: At **5 flags**, the system automatically changes the status to `flagged`, and database RLS policies hide it from all map views.

## 🆘 Emergency Integration
- **SOS Flag**: Reports marked `is_emergency = true` are prioritized in the UI and can trigger background notifications to emergency contacts (stored in `profiles`).
