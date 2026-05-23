// Trailtether — Supabase client.
//
// Points at the same backend the production Flutter app uses
// (xuqmdujupbmxahyhkdwl). The same anon key is shipped in the Flutter
// build (`lib/core/supabase_options.dart`), so this is not a new secret
// — it's the public publishable key that RLS enforces on the server.
//
// Notes for RN:
//   - `react-native-url-polyfill/auto` MUST be imported before the client
//     is constructed, because @supabase/supabase-js relies on the
//     standard URL global which RN doesn't ship with full WHATWG support.
//   - AsyncStorage backs the session so the user stays signed-in across
//     cold starts.
//   - `detectSessionInUrl: false` because we don't run in a browser.

import 'react-native-url-polyfill/auto';
import AsyncStorage from '@react-native-async-storage/async-storage';
import { createClient } from '@supabase/supabase-js';

const SUPABASE_URL = 'https://xuqmdujupbmxahyhkdwl.supabase.co';
const SUPABASE_ANON_KEY =
  'sb_publishable_1EoOSHJLk5Wlh8ZSDR3Vjw_9WtQgv30';

export const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
  auth: {
    storage: AsyncStorage,
    autoRefreshToken: true,
    persistSession: true,
    detectSessionInUrl: false,
  },
});
