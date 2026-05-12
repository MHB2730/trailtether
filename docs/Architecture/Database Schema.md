# 🗄️ Supabase Database Schema

Trailtether's backend is powered by **Supabase (PostgreSQL)** with strict **Row Level Security (RLS)** and real-time synchronization.

## 👥 User Data
- **`profiles`**: Extended user data (username, bio, emergency contact info).
- **`teams`**: User groups for shared missions. Tracks team-wide stats like `total_distance_km` and `peaks_climbed`.

## 🛰️ Telemetry & Tracking
- **`team_member_locations`**: High-frequency real-time updates for latitude, longitude, heading, speed, and altitude.
- **`hike_history`**: Finalized recordings of completed activities, including the full GPS point set (JSONB).
- **`user_gpx_tracks`**: User-uploaded tracks that can be shared with specific teams.

## 🚨 Safety & Incidents
- **`incidents`**: Community-sourced hazard reports.
  - **Verification**: Logic requires **3 separate verifications** from other users to mark an incident as `is_verified`.
  - **Moderation**: If an incident receives **5 flags**, its status is set to `flagged` and it is hidden from the map via RLS.
- **`app_logs`**: System diagnostics for debugging field failures.

## 💬 Social & Community
- **`chat_messages`**: Team-based and general chat rooms with real-time delivery.
- **`community_activities`**: A global event feed (e.g., "User X completed a 12km hike!").
- **`reviews`**: Trail ratings and condition reports.

## ⚙️ Core Logic (SQL Functions)
- **`handle_new_user()`**: Auto-creates a profile when a user signs up.
- **`on_hike_saved()`**: Trigger that updates team stats and posts to the community feed upon hike completion.
- **`join_team_by_invite_code()`**: Secure RPC for adding members to teams via unique codes.
