# 🤝 Team Tracking & Collaboration

Trailtether is designed for group safety and coordinated field operations.

## 👥 Team Management
- **Invite System**: Teams are joined via a unique `invite_code`.
- **Statistics**: The app aggregates data from all members into team-wide milestones (e.g., total ascent, total distance).

## 📍 Real-Time Tracking
The `team_member_locations` system provides:
- **Live Positioning**: Updates of all teammates on the map.
- **Heading & Speed**: Visualization of which way a teammate is moving and how fast.
- **Privacy**: RLS policies ensure you can **only** see the location of users who are in your active team.

## 💬 Secure Communication
- **Team Chat**: Each team has a private room (`room_id = team_id`).
- **General Chat**: A global room for all authenticated users.
- **Real-Time**: Powered by Supabase Realtime (WebSockets) for instant message delivery.

## 📤 Shared Assets
- **GPX Sharing**: A user can upload a track and "link" it to a team, making it instantly visible to all members for navigation.
