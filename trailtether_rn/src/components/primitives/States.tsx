// Trailtether — async UI state primitives.
//
// Per the implementation rules: every async surface must render proper
// loading + error states. These two components are the canonical way to
// do that — embed them at the top of any Card whose body depends on
// network/storage data.
//
// `LoadingState` shows a small spinner + an optional label. `ErrorState`
// renders the error message with an ember "retry" affordance. Neither
// renders an "empty" fallback — by design — because the rules forbid
// silent empty states.

import React from 'react';
import {
  ActivityIndicator,
  Pressable,
  StyleSheet,
  Text,
  View,
  ViewStyle,
} from 'react-native';
import { Icon } from '@components/Icon';
import { font, fz, ls, sp, tt } from '@theme/tokens';

export interface LoadingStateProps {
  label?: string;
  /** Use the row variant when the parent is a list row (no padding, left aligned). */
  inline?: boolean;
  style?: ViewStyle;
}

export function LoadingState({
  label = 'Loading…',
  inline = false,
  style,
}: LoadingStateProps) {
  return (
    <View style={[inline ? styles.inline : styles.block, style]}>
      <ActivityIndicator color={tt.ember} size="small" />
      <Text style={styles.loadingLabel}>{label}</Text>
    </View>
  );
}

export interface ErrorStateProps {
  /** Error object, message string, or null. */
  error: unknown;
  /** Optional retry handler — when present, renders a "RETRY →" button. */
  onRetry?: () => void;
  /** Render in a compact row form for nested cards. */
  inline?: boolean;
  style?: ViewStyle;
}

export function ErrorState({
  error,
  onRetry,
  inline = false,
  style,
}: ErrorStateProps) {
  const message = errorMessage(error);
  return (
    <View style={[inline ? styles.inline : styles.errorBlock, style]}>
      <Icon name="alert" size={16} color={tt.red} />
      <View style={{ flex: 1, minWidth: 0 }}>
        <Text style={styles.errorTitle}>Something broke loading this.</Text>
        <Text style={styles.errorBody}>{message}</Text>
      </View>
      {onRetry && (
        <Pressable
          onPress={onRetry}
          hitSlop={6}
          style={({ pressed }) => [styles.retry, pressed && { opacity: 0.6 }]}
        >
          <Text style={styles.retryText}>RETRY →</Text>
        </Pressable>
      )}
    </View>
  );
}

export function errorMessage(err: unknown): string {
  if (!err) return 'Unknown error';
  if (err instanceof Error) return err.message;
  if (typeof err === 'string') return err;
  if (typeof err === 'object' && err !== null && 'message' in err) {
    const m = (err as { message?: unknown }).message;
    if (typeof m === 'string') return m;
  }
  return 'Unknown error';
}

const styles = StyleSheet.create({
  block: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: sp.s4,
    paddingVertical: sp.s7,
    justifyContent: 'center',
  },
  errorBlock: {
    flexDirection: 'row',
    alignItems: 'flex-start',
    gap: sp.s4,
    paddingVertical: sp.s5,
  },
  inline: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: sp.s4,
  },
  loadingLabel: {
    fontFamily: font.monoSemi,
    fontSize: 11,
    color: tt.text3,
    letterSpacing: ls.monoMed * 11,
  },
  errorTitle: {
    fontFamily: font.uiBold,
    fontSize: fz.body2,
    color: tt.text,
  },
  errorBody: {
    marginTop: 2,
    fontFamily: font.uiMed,
    fontSize: fz.body,
    color: tt.text3,
  },
  retry: {
    paddingHorizontal: sp.s4,
    paddingVertical: sp.s2,
  },
  retryText: {
    fontFamily: font.monoBold,
    fontSize: 10.5,
    color: tt.ember,
    letterSpacing: ls.monoMed * 10.5,
  },
});
