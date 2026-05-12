/// Process-wide runtime flags set during startup.
///
/// Keeping these out of main.dart avoids circular imports from providers and
/// services back into the application entrypoint.
bool kSupabaseAvailable = false;

/// Local demo builds can opt into bypassing Supabase with:
/// --dart-define=TRAILTETHER_DEMO=true
const bool kAllowDemoMode =
    bool.fromEnvironment('TRAILTETHER_DEMO', defaultValue: false);
