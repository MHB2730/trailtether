// Trailtether — base screen shell.
//
// Every screen wraps its content in this. Provides:
//   * AmbientBg + TopoBackdrop layered behind the content
//   * SafeAreaView with the dark body bg
//   * Optional `scroll` mode that wraps the content in a ScrollView
//
// This keeps the per-screen file focused on actual UI rather than
// re-declaring backgrounds. Match the handoff's `.phone .screen` setup.

import React from 'react';
import {
  ScrollView,
  ScrollViewProps,
  StyleSheet,
  View,
  ViewProps,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { AmbientBg } from './AmbientBg';
import { TopoBackdrop } from './TopoBackdrop';
import { tt } from '@theme/tokens';

export interface ScreenShellProps {
  /** Wrap the children in a ScrollView. Defaults to true. */
  scroll?: boolean;
  /** Hide the ambient ember + topo overlay (useful for full-bleed map). */
  bare?: boolean;
  /** Standard footer padding to clear the 84-tall bottom nav. */
  insetBottom?: number;
  contentContainerStyle?: ScrollViewProps['contentContainerStyle'];
  style?: ViewProps['style'];
  children?: React.ReactNode;
}

export function ScreenShell({
  scroll = true,
  bare = false,
  insetBottom = 96,
  contentContainerStyle,
  style,
  children,
}: ScreenShellProps) {
  const body = scroll ? (
    <ScrollView
      style={styles.flex}
      contentContainerStyle={[
        { paddingBottom: insetBottom },
        contentContainerStyle,
      ]}
      showsVerticalScrollIndicator={false}
    >
      {children}
    </ScrollView>
  ) : (
    <View style={[styles.flex, { paddingBottom: insetBottom }, style]}>
      {children}
    </View>
  );

  return (
    <SafeAreaView style={styles.safe} edges={['top']}>
      {!bare && <AmbientBg />}
      {!bare && <TopoBackdrop opacity={0.5} />}
      {body}
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  safe: { flex: 1, backgroundColor: tt.bg },
  flex: { flex: 1 },
});
