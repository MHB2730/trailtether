// Trailtether — shared placeholder for screens not yet ported.
//
// Every screen route needs a Component or expo-router crashes — so the
// unbuilt screens render this until their real implementations land. It
// keeps the visual treatment on-brand (tokens, eyebrow, topo backdrop)
// rather than a stark "not implemented yet" page so when a tester or
// reviewer wanders into one they still see the design system.

import React from 'react';
import { StyleSheet, Text, View } from 'react-native';
import { Card } from './Card';
import { ScreenShell } from './ScreenShell';
import { TTAppBar } from './TTAppBar';
import { font, fz, ls, sp, tt } from '@theme/tokens';

export interface PlaceholderScreenProps {
  /** Human-readable screen name shown in the title. */
  title: string;
  /** Which file in design_source/screens/ this maps to, for traceability. */
  designSource?: string;
  /** Short note about what will eventually render here. */
  next?: string;
}

export function PlaceholderScreen({
  title,
  designSource,
  next,
}: PlaceholderScreenProps) {
  return (
    <ScreenShell>
      <TTAppBar big title={title} sub="UNDER CONSTRUCTION" />
      <View style={styles.body}>
        <Card>
          <Text style={styles.eyebrow}>NEXT</Text>
          <Text style={styles.line}>
            {next ?? `Porting ${designSource ?? `screens/${title.toLowerCase()}.jsx`} next.`}
          </Text>
        </Card>
      </View>
    </ScreenShell>
  );
}

const styles = StyleSheet.create({
  body: { paddingHorizontal: sp.screen, paddingTop: sp.s7 },
  eyebrow: {
    fontFamily: font.monoSemi,
    fontSize: 10.5,
    color: tt.text3,
    letterSpacing: ls.monoMed * 10.5,
    marginBottom: 6,
  },
  line: {
    fontFamily: font.uiSemi,
    fontSize: fz.body2,
    color: tt.text,
  },
});
