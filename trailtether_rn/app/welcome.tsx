// Trailtether — Welcome / Onboarding.
//
// Five-pillar rotator that auto-advances every 5.2s (matching the
// design source). Tap a dot to jump. The hero illustration zone uses
// the radial ember glow from the design but replaces the per-pillar
// `Scene` SVG with the `TopoBackdrop` we already ship — the pillar
// copy carries the meaning.

import React, { useEffect, useState } from 'react';
import { Image, Pressable, StyleSheet, Text, View } from 'react-native';
import { useRouter } from 'expo-router';
import { SafeAreaView } from 'react-native-safe-area-context';
import { Icon } from '@components/Icon';
import { AmbientBg } from '@components/primitives/AmbientBg';
import { TopoBackdrop } from '@components/primitives/TopoBackdrop';
import { WELCOME_FEATURES } from '@/data/welcome_features';
import { font, fz, ls, motion, radius, shadow, sp, tt } from '@theme/tokens';

const ROTATE_MS = 5200;

export default function WelcomeScreen() {
  const router = useRouter();
  const [idx, setIdx] = useState(0);
  const feat = WELCOME_FEATURES[idx];

  useEffect(() => {
    const t = setTimeout(() => setIdx((idx + 1) % WELCOME_FEATURES.length), ROTATE_MS);
    return () => clearTimeout(t);
  }, [idx]);

  if (!feat) return null;

  return (
    <SafeAreaView style={styles.safe} edges={['top', 'bottom']}>
      <AmbientBg />
      <View style={styles.appbar}>
        <View style={styles.brand}>
          <Image
            source={require('../assets/logo.png')}
            style={styles.logo}
            resizeMode="contain"
          />
          <Text style={styles.wordmark}>
            TRAIL<Text style={styles.wordmarkAccent}>TETHER</Text>
          </Text>
        </View>
        <Pressable onPress={() => router.replace('/sign-in')} hitSlop={10}>
          <Text style={styles.skip}>SKIP</Text>
        </Pressable>
      </View>

      <View style={[styles.hero, { backgroundColor: `${feat.color}10` }]}>
        <TopoBackdrop opacity={0.35} />
        <View
          pointerEvents="none"
          style={[
            StyleSheet.absoluteFillObject,
            { backgroundColor: `${feat.color}14` },
          ]}
        />
        <View style={styles.heroCenter}>
          <View
            style={[
              styles.heroDot,
              { backgroundColor: `${feat.color}33`, borderColor: feat.color },
            ]}
          >
            <Icon name={iconFor(feat.id)} size={36} color={feat.color} />
          </View>
        </View>
      </View>

      <View style={styles.body}>
        <Text style={styles.tagline}>
          Plan smarter.{'\n'}Hike safer.{'\n'}
          <Text style={{ color: tt.ember }}>Stay connected on the trail.</Text>
        </Text>

        <View style={styles.pillar}>
          <View
            style={[
              styles.eyebrow,
              { backgroundColor: `${feat.color}1f`, borderColor: `${feat.color}55` },
            ]}
          >
            <View
              style={[styles.eyebrowDot, { backgroundColor: feat.color }]}
            />
            <Text style={[styles.eyebrowText, { color: feat.color }]}>{feat.eyebrow}</Text>
          </View>
          <Text style={styles.title}>{feat.title}</Text>
          <Text style={styles.bodyText}>{feat.body}</Text>
        </View>

        <View style={styles.dots}>
          {WELCOME_FEATURES.map((f, i) => (
            <Pressable
              key={f.id}
              onPress={() => setIdx(i)}
              hitSlop={6}
              style={[
                styles.dot,
                i === idx && styles.dotActive,
              ]}
            />
          ))}
        </View>

        <View style={styles.ctaWrap}>
          <Pressable
            onPress={() => router.replace('/sign-in')}
            style={({ pressed }) => [styles.cta, pressed && { opacity: 0.9 }]}
          >
            <Text style={styles.ctaText}>GET STARTED</Text>
            <Icon name="chevron-right" size={16} color="#1a0d04" strokeWidth={2.6} />
          </Pressable>
          <Pressable onPress={() => router.replace('/sign-in')} hitSlop={6}>
            <Text style={styles.signin}>
              Already have an account?{' '}
              <Text style={{ color: tt.ember, fontFamily: font.uiBold }}>Sign in</Text>
            </Text>
          </Pressable>
          <Text style={styles.footnote}>
            FREE · NO ADS · BUILT IN SOUTH AFRICA, FOR SOUTH AFRICANS
          </Text>
        </View>
      </View>
    </SafeAreaView>
  );
}

function iconFor(id: string) {
  switch (id) {
    case 'tether': return 'tether' as const;
    case 'plan': return 'route' as const;
    case 'navigate': return 'compass' as const;
    case 'aware': return 'eye' as const;
    case 'sos': return 'shield' as const;
    default: return 'mountain' as const;
  }
}

// Pull motion timing so the dot indicator transitions feel consistent.
void motion;

const styles = StyleSheet.create({
  safe: { flex: 1, backgroundColor: tt.bg },
  appbar: {
    paddingHorizontal: sp.screen,
    paddingTop: sp.s5,
    paddingBottom: sp.s2,
    flexDirection: 'row',
    alignItems: 'center',
  },
  brand: { flex: 1, flexDirection: 'row', alignItems: 'center', gap: 10 },
  logo: { width: 26, height: 26 },
  wordmark: {
    fontFamily: font.uiHeavy,
    fontSize: 14,
    letterSpacing: ls.monoWide * 14,
    color: tt.text,
  },
  wordmarkAccent: { color: tt.ember },
  skip: {
    fontFamily: font.uiBold,
    fontSize: 11,
    color: tt.text2,
    letterSpacing: ls.monoMed * 11,
  },
  hero: {
    height: 320,
    overflow: 'hidden',
    position: 'relative',
  },
  heroCenter: {
    ...StyleSheet.absoluteFillObject,
    alignItems: 'center',
    justifyContent: 'center',
  },
  heroDot: {
    width: 130,
    height: 130,
    borderRadius: 65,
    borderWidth: 2,
    alignItems: 'center',
    justifyContent: 'center',
  },
  body: { flex: 1, paddingHorizontal: 22 },
  tagline: {
    marginTop: 6,
    fontFamily: font.uiHeavy,
    fontSize: 26,
    lineHeight: 30,
    color: tt.text,
    letterSpacing: ls.tight * 26,
    textAlign: 'center',
  },
  pillar: { marginTop: 20, alignItems: 'center', minHeight: 110 },
  eyebrow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 6,
    paddingVertical: 4,
    paddingHorizontal: 10,
    borderRadius: 999,
    borderWidth: 1,
  },
  eyebrowDot: { width: 5, height: 5, borderRadius: 2.5 },
  eyebrowText: {
    fontFamily: font.monoBold,
    fontSize: 9.5,
    letterSpacing: ls.monoWide * 9.5,
  },
  title: {
    marginTop: 10,
    fontFamily: font.uiBold,
    fontSize: 15,
    lineHeight: 20,
    color: tt.text,
    textAlign: 'center',
  },
  bodyText: {
    marginTop: 6,
    paddingHorizontal: 4,
    fontFamily: font.uiMed,
    fontSize: 12,
    lineHeight: 18,
    color: tt.text2,
    textAlign: 'center',
  },
  dots: {
    flexDirection: 'row',
    justifyContent: 'center',
    gap: 8,
    marginTop: 18,
  },
  dot: {
    width: 6,
    height: 6,
    borderRadius: 3,
    backgroundColor: tt.line3,
  },
  dotActive: {
    width: 22,
    backgroundColor: tt.ember,
  },
  ctaWrap: { marginTop: 'auto', paddingBottom: sp.s7 },
  cta: {
    marginTop: 22,
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
  signin: {
    marginTop: 14,
    textAlign: 'center',
    fontFamily: font.uiSemi,
    fontSize: 12,
    color: tt.text3,
  },
  footnote: {
    marginTop: 16,
    textAlign: 'center',
    fontFamily: font.monoBold,
    fontSize: 9.5,
    color: tt.text4,
    letterSpacing: ls.monoWide * 9.5,
  },
});

void radius; // tokens kept import-warm for future iterations
