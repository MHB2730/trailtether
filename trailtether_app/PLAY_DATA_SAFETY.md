# Trailtether — Google Play "Data safety" form answers

Fill these into Play Console → **App content → Data safety**. Derived from the
app's actual permissions, dependencies (`supabase_flutter`, `geolocator`,
`image_picker`, `google_sign_in`, `sentry_flutter`, `health`) and the Supabase
tables it writes. Items marked **(confirm)** are judgement calls — verify before
submitting. Last updated 2026-05-30.

---

## Section 1 — Data collection & security (3 questions)

1. **Does your app collect or share any of the required user data types?** → **Yes**
2. **Is all of the user data collected by your app encrypted in transit?** → **Yes**
   (All traffic goes to Supabase over HTTPS/TLS; Sentry over HTTPS.)
3. **Do you provide a way for users to request that their data be deleted?** → **Yes**
   - In-app: **Profile → Delete account** (full server-side erasure via the `account-delete` function).
   - Web: **https://hilltrek.co.za/account** → Delete account.
   - Use **`https://hilltrek.co.za/account`** as the "deletion request URL" the form asks for.

Other top-level toggles:
- **Data used to track users / advertising ID:** No (no ad SDKs, no Firebase/analytics).
- **Designed for Families / targets children:** No (unless you opt in — then extra rules apply).

---

## Section 2 — Data types

For every row below: **Shared = No** (Supabase and Sentry act as your processors;
other Trailtether users seeing your shared location/posts is *app functionality*,
not third-party "sharing" under Play's definition). **Collection is required** only
for the core safety features; everything else is **Optional**. Nothing is
"processed ephemerally" — it's stored in your backend.

| Data type | Collected | Optional? | Purpose(s) | Why |
|---|---|---|---|---|
| **Precise location** | Yes | Required | App functionality | GPS hike recording + live location sharing with your team. **Uses background location** → also do the separate declaration (below). |
| **Approximate location** | Yes | Required | App functionality | Coarse location fallback / weather lookups. |
| **Name** | Yes | Optional | App functionality, Account management | Display name on profile / team. |
| **Email address** | Yes | Required | Account management, App functionality | Sign-in identity (email or Google). |
| **Photos** | Yes | Optional | App functionality | Profile photo + incident photos the user chooses to upload. |
| **Files & docs** | Yes | Optional | App functionality | GPX route import/upload. |
| **Fitness info** | Yes | Optional | App functionality | Recorded hikes — distance, duration, pace, elevation, route. |
| **Health info** | Yes *(confirm)* | Optional | App functionality | Only if heart-rate / calorie data is stored in the backend (the app writes exercise/distance/calories to Health Connect; confirm whether it also *stores* HR). If it only exports to Health Connect and never stores HR, answer **No**. |
| **In-app messages** | Yes *(confirm)* | Optional | App functionality | Team chat, if that feature is live for users. If chat is disabled/unused, answer **No**. |
| **Other user-generated content** | Yes | Optional | App functionality | Incident reports, reviews, community posts, check-ins. |
| **Contacts** | Yes | Optional | App functionality | Emergency contacts the user manually enters for SOS (names + numbers). |
| **Crash logs** | Yes | — | App functionality, Fraud prevention/security | Collected by **Sentry**. |
| **Diagnostics** | Yes | — | App functionality | Performance/error diagnostics via **Sentry**. |
| **Device or other IDs** | Yes *(confirm)* | Optional | App functionality | Sentry's install/device identifier; paired Garmin device id in `watch_devices`. If you'd rather not declare, confirm Sentry's "send default PII / device id" setting is off. |

### Data types you can answer **No** to
- **Financial info** — payments happen on the website, not in the app.
- **Approximate/precise location for ads, Web browsing history, Search history,
  Audio, Calendar, Phone number*, Installed apps, Ad/marketing IDs.**
  (*The app collects the user's *email*, not their phone number; emergency-contact
  numbers are covered under Contacts.)

---

## Section 3 — Background location declaration (separate, required)

Because you collect **background location**, Play requires an extra step in the
review:
1. In the **App content** area, complete the **"Location permissions" / sensitive
   permissions** declaration.
2. Justification: *"Trailtether records the user's hike and shares their live
   location with their chosen safety contacts/team while a recording is active,
   including when the screen is off, so they can be found if something goes wrong.
   A persistent foreground-service notification is shown the entire time."*
3. Record a **short screen capture (~20–40s)** showing: the in-app prominent
   disclosure → granting "Allow all the time" → the ongoing tracking notification.
   Upload it where the form requests the demo video/link.

---

## Things to confirm before you submit
- **Sentry**: confirm whether it's set to send default PII / device identifiers
  (affects the "Device or other IDs" and whether crash data carries any PII).
- **Health info**: only declare if heart-rate / health metrics are actually
  stored server-side (vs only written to Health Connect on-device).
- **In-app messages**: only declare if team chat is live for end users.
- Keep this in sync if you later add Firebase/analytics/an ad SDK — those would
  flip "tracking" and several "Shared" answers to Yes.
