// Trailtether — auth gate.
//
// Wraps the (tabs) group. While the auth store is still hydrating
// (first call to getSession() hasn't resolved), shows the same splash-
// style fallback the root layout shows; once we know the session state,
// either renders the children OR redirects to /sign-in.
//
// This keeps individual screens free of "if (!user)" boilerplate — they
// can assume a signed-in user is present in the auth store.

import React, { useEffect } from 'react';
import { Redirect } from 'expo-router';
import { ActivityIndicator, StyleSheet, View } from 'react-native';
import { useAuth } from '@/store/auth';
import { tt } from '@theme/tokens';

export interface AuthGateProps {
  children: React.ReactNode;
}

export function AuthGate({ children }: AuthGateProps) {
  const loading = useAuth((s) => s.loading);
  const session = useAuth((s) => s.session);
  const init = useAuth((s) => s.init);
  // First-mount hydrate.
  useEffect(() => {
    void init();
  }, [init]);

  if (loading) {
    return (
      <View style={styles.center}>
        <ActivityIndicator color={tt.ember} />
      </View>
    );
  }
  if (!session) {
    // Returning a <Redirect> from inside a layout's render is how
    // expo-router wants "session-less → /sign-in" to be expressed.
    return <Redirect href="/sign-in" />;
  }
  return <>{children}</>;
}

const styles = StyleSheet.create({
  center: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: tt.bg,
  },
});
