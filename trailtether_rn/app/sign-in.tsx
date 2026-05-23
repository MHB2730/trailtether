// Trailtether — Sign In.
//
// Email + password sign-in backed by `supabase.auth.signInWithPassword`.
// First-time visitors tap "Create account" to flip to sign-up which uses
// `supabase.auth.signUp`. On success the AuthGate at the (tabs) layout
// notices the new session and lets the user through to /(tabs).
//
// Errors come back from Supabase verbatim — surface them via the
// shared ErrorState component (read by the user, not silently swallowed).

import React, { useState } from 'react';
import {
  KeyboardAvoidingView,
  Platform,
  Pressable,
  ScrollView,
  StyleSheet,
  Text,
  View,
} from 'react-native';
import { useRouter } from 'expo-router';
import { SafeAreaView } from 'react-native-safe-area-context';
import { Icon } from '@components/Icon';
import { AmbientBg } from '@components/primitives/AmbientBg';
import { FormField } from '@components/design/FormField';
import { ErrorState } from '@components/primitives/States';
import { supabase } from '@/data/supabase';
import { font, fz, ls, radius, shadow, sp, tt } from '@theme/tokens';

type Mode = 'sign-in' | 'sign-up';

export default function SignInScreen() {
  const router = useRouter();
  const [mode, setMode] = useState<Mode>('sign-in');
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [info, setInfo] = useState<string | null>(null);

  const submit = async () => {
    setError(null);
    setInfo(null);
    setSubmitting(true);
    try {
      if (mode === 'sign-in') {
        const { error: err } = await supabase.auth.signInWithPassword({
          email: email.trim(),
          password,
        });
        if (err) throw err;
        router.replace('/(tabs)');
      } else {
        const { data, error: err } = await supabase.auth.signUp({
          email: email.trim(),
          password,
        });
        if (err) throw err;
        if (data.session) {
          router.replace('/(tabs)');
        } else {
          setInfo('Check your inbox to confirm your address before signing in.');
        }
      }
    } catch (err) {
      setError(err instanceof Error ? err.message : String(err));
    } finally {
      setSubmitting(false);
    }
  };

  const isSignIn = mode === 'sign-in';
  return (
    <SafeAreaView style={styles.safe} edges={['top', 'bottom']}>
      <AmbientBg />
      <KeyboardAvoidingView
        behavior={Platform.OS === 'ios' ? 'padding' : undefined}
        style={{ flex: 1 }}
      >
        <ScrollView
          contentContainerStyle={styles.scroll}
          keyboardShouldPersistTaps="handled"
          showsVerticalScrollIndicator={false}
        >
          <Pressable onPress={() => router.back()} hitSlop={10} style={styles.back}>
            <Icon name="chevron-up" size={18} color={tt.text2} />
          </Pressable>

          <View style={styles.heroRow}>
            <Text style={styles.title}>{isSignIn ? 'Welcome back.' : 'Create your tether.'}</Text>
            <Text style={styles.sub}>
              {isSignIn
                ? 'Sign in to sync your hikes, teams and live tether.'
                : 'Free, no ads. Built in South Africa, for South Africans.'}
            </Text>
          </View>

          <FormField
            label="Email"
            icon="user"
            value={email}
            onChangeText={setEmail}
            placeholder="you@example.com"
            keyboardType="email-address"
            autoCapitalize="none"
          />
          <FormField
            label="Password"
            icon="shield"
            value={password}
            onChangeText={setPassword}
            placeholder="At least 8 characters"
            secureTextEntry
            autoCapitalize="none"
          />

          {info && (
            <View style={styles.info}>
              <Icon name="check" size={14} color={tt.green} strokeWidth={2.4} />
              <Text style={styles.infoText}>{info}</Text>
            </View>
          )}

          {error && <ErrorState error={error} />}

          <Pressable
            onPress={submit}
            disabled={submitting || !email || !password}
            style={({ pressed }) => [
              styles.cta,
              (submitting || !email || !password) && { opacity: 0.5 },
              pressed && { opacity: 0.9 },
            ]}
          >
            <Text style={styles.ctaText}>
              {submitting ? '…' : isSignIn ? 'SIGN IN' : 'CREATE ACCOUNT'}
            </Text>
            <Icon name="chevron-right" size={16} color="#1a0d04" strokeWidth={2.6} />
          </Pressable>

          <Pressable onPress={() => setMode(isSignIn ? 'sign-up' : 'sign-in')} hitSlop={6}>
            <Text style={styles.switch}>
              {isSignIn ? 'No account yet?' : 'Already have one?'}{' '}
              <Text style={{ color: tt.ember, fontFamily: font.uiBold }}>
                {isSignIn ? 'Create one' : 'Sign in'}
              </Text>
            </Text>
          </Pressable>
        </ScrollView>
      </KeyboardAvoidingView>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  safe: { flex: 1, backgroundColor: tt.bg },
  scroll: { padding: sp.screen, paddingTop: 0 },
  back: { width: 38, height: 38, alignItems: 'center', justifyContent: 'center' },
  heroRow: { marginTop: sp.s4, marginBottom: sp.s10 },
  title: {
    fontFamily: font.uiHeavy,
    fontSize: fz.hero,
    lineHeight: fz.hero + 4,
    letterSpacing: ls.tight * fz.hero,
    color: tt.text,
  },
  sub: {
    marginTop: sp.s4,
    fontFamily: font.uiMed,
    fontSize: fz.body2,
    color: tt.text2,
    lineHeight: 20,
  },
  info: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: sp.s3,
    padding: sp.s5,
    marginBottom: sp.s4,
    borderRadius: radius.md,
    backgroundColor: 'rgba(76,195,138,0.12)',
    borderWidth: 1,
    borderColor: 'rgba(76,195,138,0.32)',
  },
  infoText: {
    flex: 1,
    fontFamily: font.uiSemi,
    fontSize: fz.body,
    color: tt.green,
  },
  cta: {
    marginTop: sp.s7,
    height: 54,
    borderRadius: 14,
    backgroundColor: tt.ember,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    gap: 10,
    ...shadow.ember,
  },
  ctaText: {
    fontFamily: font.uiHeavy,
    fontSize: fz.body2,
    letterSpacing: ls.monoWide * fz.body2,
    color: '#1a0d04',
  },
  switch: {
    marginTop: sp.s8,
    textAlign: 'center',
    fontFamily: font.uiSemi,
    fontSize: 12,
    color: tt.text3,
  },
});
