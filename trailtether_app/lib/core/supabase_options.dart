/// Supabase project credentials.
/// ────────────────────────────────────────────────────────────────────────────
/// STEP: Replace the two placeholder strings below with the real values from
///       your Supabase project:
///
///   1. Go to https://supabase.com/dashboard/project/_/settings/api
///   2. Copy "Project URL"  → paste as kSupabaseUrl
///   3. Copy "anon / public" key → paste as kSupabaseAnonKey
/// ────────────────────────────────────────────────────────────────────────────
const kSupabaseUrl = 'https://xuqmdujupbmxahyhkdwl.supabase.co';
const kSupabaseAnonKey = 'sb_publishable_1EoOSHJLk5Wlh8ZSDR3Vjw_9WtQgv30';

/// Web OAuth Client ID from Google Cloud Console.
/// Used as serverClientId by the native google_sign_in flow on Android/iOS so
/// Google returns an ID token Supabase can validate. The Android OAuth client
/// (same Google Cloud project, package com.trailtether.app + the upload
/// keystore's SHA-1) authorizes the calling app at consent time but is not
/// referenced in code.
const kGoogleWebClientId =
    '269171860007-38o8kk1tm1p59el7e5ghscmu812rpn6g.apps.googleusercontent.com';
