# 🧭 Tools & Sensors

Beyond mapping, Trailtether provides essential field survival tools.

## 🧭 Direction & Level
- **Compass**: Provides real-time magnetic and true north orientation.
- **Bubble Level**: Uses the device's accelerometer (`sensors_plus`) to assist in pitch/roll detection, useful for campsite leveling or steepness assessment.

## 🔦 Emergency Tools
- **Flashlight**: Native torch control via `torch_light`.
- **SOS Signal**: Background service capable of sending emergency coordinates via Supabase or local triggers.
- **QR Scanner**: `mobile_scanner` integration for quick syncing between devices or scanning checkpoint codes.

## 🏥 Health & Vitals
- **Metrics**: Integrates with system health services to track:
  - Steps and distance.
  - Heart rate (where available).
  - Battery status (`battery_plus`) to warn operators of impending power loss.
