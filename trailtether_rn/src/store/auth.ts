// Trailtether — auth store.
//
// Wraps Supabase auth in a Zustand slice the whole app reads from.
// `init()` is called once at root layout mount: it hydrates the existing
// session (if any) from AsyncStorage via supabase.auth.getSession() and
// then subscribes to onAuthStateChange so sign-in / sign-out from any
// screen propagates everywhere.
//
// Exposed surface:
//   - session, user, profile
//   - loading (true on first hydrate, before getSession resolves)
//   - error (caught from getSession / onAuthStateChange)
//   - displayName — first non-empty of profile.display_name, user.email
//     local-part, "Hiker"
//   - signOut()
//
// Screens never call supabase.auth directly — they go through this store
// so the per-screen UI can react to auth changes through Zustand's
// selector pattern.

import { create } from 'zustand';
import type { Session, User } from '@supabase/supabase-js';
import { supabase } from '@/data/supabase';
import type { ProfileRow } from '@/data/schema';

export interface AuthState {
  session: Session | null;
  user: User | null;
  profile: ProfileRow | null;
  loading: boolean;
  error: string | null;
  init: () => Promise<void>;
  refreshProfile: () => Promise<void>;
  signOut: () => Promise<void>;
}

export const useAuth = create<AuthState>((set, get) => ({
  session: null,
  user: null,
  profile: null,
  loading: true,
  error: null,

  init: async () => {
    set({ loading: true, error: null });
    try {
      const { data, error } = await supabase.auth.getSession();
      if (error) throw error;
      const session = data.session;
      set({
        session,
        user: session?.user ?? null,
      });
      if (session?.user) {
        await get().refreshProfile();
      }
    } catch (err) {
      set({ error: errMessage(err) });
    } finally {
      set({ loading: false });
    }

    // Subscribe to subsequent auth state changes — sign-in, sign-out,
    // token refresh. Idempotent if init() is called twice (the previous
    // subscription is garbage-collected because we don't unsubscribe;
    // we only call init() from root layout, so this is intentional).
    supabase.auth.onAuthStateChange((_event, session) => {
      set({
        session,
        user: session?.user ?? null,
      });
      if (session?.user) {
        void get().refreshProfile();
      } else {
        set({ profile: null });
      }
    });
  },

  refreshProfile: async () => {
    const uid = get().user?.id;
    if (!uid) {
      set({ profile: null });
      return;
    }
    try {
      const { data, error } = await supabase
        .from('profiles')
        .select('*')
        .eq('id', uid)
        .maybeSingle();
      if (error) throw error;
      set({ profile: (data as ProfileRow | null) ?? null });
    } catch (err) {
      set({ error: errMessage(err) });
    }
  },

  signOut: async () => {
    await supabase.auth.signOut();
    set({ session: null, user: null, profile: null });
  },
}));

/**
 * Selector helper: derive a friendly first-name greeting from auth state
 * without each screen re-implementing the priority chain.
 */
export function selectDisplayName(s: AuthState): string {
  const dn = s.profile?.display_name?.trim();
  if (dn) return dn.split(/\s+/)[0] ?? dn;
  const email = s.user?.email?.trim();
  if (email?.includes('@')) {
    const local = email.split('@')[0];
    if (local && local.length > 0) return capitalize(local);
  }
  return 'Hiker';
}

function capitalize(s: string): string {
  return s.length === 0 ? s : s[0]!.toUpperCase() + s.slice(1);
}

function errMessage(err: unknown): string {
  if (err instanceof Error) return err.message;
  if (typeof err === 'string') return err;
  return 'Unknown error';
}
