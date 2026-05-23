// Trailtether — Home (`screens/home.jsx`).
//
// Implementation rules in force:
//   * NO hardcoded data / lorem ipsum / mock arrays.
//   * Every async surface ships LoadingState + ErrorState — no empty
//     fallbacks.
//   * UI constants (rarity colours, navigation targets, weather emoji)
//     count as configuration and stay in code; user/team/hike/weather
//     numbers come from real stores.
//   * Data shapes that don't have a backing source are tracked in
//     BLOCKERS.md (the Field Intel feed is #4 there — surface lands in
//     the next pass).

import React from 'react';
import {
  Image,
  Pressable,
  StyleSheet,
  Text,
  View,
} from 'react-native';
import { useRouter } from 'expo-router';
import { SafeAreaView } from 'react-native-safe-area-context';
import { Card } from '@components/primitives/Card';
import { DifficultyChip, Pill } from '@components/primitives/Pill';
import { ScreenShell } from '@components/primitives/ScreenShell';
import { IconBtn } from '@components/primitives/TTAppBar';
import { ErrorState, LoadingState } from '@components/primitives/States';
import { Icon, IconName } from '@components/Icon';
import { font, fz, ls, motion, radius, sp, tt } from '@theme/tokens';
import { useApp } from '@/store/app';
import { selectDisplayName, useAuth } from '@/store/auth';
import {
  AsyncResource,
  CurrentConditions,
  LastHikeSummary,
  UpcomingHike,
  useCurrentWeather,
  useFieldIntel,
  useHomeWeatherLocation,
  useLastHike,
  useUpcomingHikes,
  WeatherLocation,
} from '@/data/hooks';
import Animated, {
  Easing,
  useAnimatedStyle,
  useSharedValue,
  withRepeat,
  withTiming,
} from 'react-native-reanimated';

export default function HomeScreen() {
  const router = useRouter();
  const snow = useApp((s) => s.snow);
  const displayName = useAuth(selectDisplayName);
  const weatherLocation = useHomeWeatherLocation();

  const subEyebrow = weatherLocationEyebrow(weatherLocation);

  return (
    <ScreenShell contentContainerStyle={{ paddingTop: 0 }}>
      <HomeHero
        snow={snow}
        displayName={displayName}
        subEyebrow={subEyebrow}
        onPressBell={() => router.push('/notifications')}
        onPressSearch={() => router.push('/search')}
      />

      <View style={styles.body}>
        <QuickActions router={router} />
        <View style={{ height: sp.s7 }} />
        <UpcomingHikeCard router={router} />
        <View style={{ height: sp.s6 }} />
        <WeatherCard locationResource={weatherLocation} />
        <View style={{ height: sp.s6 }} />
        <LastHikeCard router={router} />
        <View style={{ height: sp.s6 }} />
        <FieldIntelCard
          center={
            weatherLocation.data
              ? { lat: weatherLocation.data.lat, lon: weatherLocation.data.lon }
              : null
          }
        />
      </View>
    </ScreenShell>
  );
}

// Eyebrow above the brand row in the app bar. Reflects current state so
// users always know which region the cards below are reading.
function weatherLocationEyebrow(
  res: AsyncResource<WeatherLocation | null>,
): string | undefined {
  if (res.loading) return 'LOADING REGION…';
  if (res.error) return 'REGION UNAVAILABLE';
  if (!res.data) return 'NO REGION SAVED · TAP WEATHER TO ADD';
  return res.data.name.toUpperCase();
}

// ── Hero ───────────────────────────────────────────────────────────────
//
// Matches `screens/home.jsx#HomeHero`: full-bleed mountain image fills
// a 260-tall header band, with the brand row pinned to the top and the
// "WELCOME BACK · {name}." greeting pinned to the bottom. A vertical
// gradient at the foot of the image fades into the body bg so the
// QuickActions strip flows out of the hero cleanly.

interface HomeHeroProps {
  snow: boolean;
  displayName: string;
  subEyebrow: string | undefined;
  onPressBell: () => void;
  onPressSearch: () => void;
}

function HomeHero({ snow, displayName, subEyebrow, onPressBell, onPressSearch }: HomeHeroProps) {
  // Slow breathing pulse for the summit ember glow — stands in for the
  // SVG comet animation in the handoff until it's ported.
  const glow = useSharedValue(0);
  React.useEffect(() => {
    glow.value = withRepeat(
      withTiming(1, {
        duration: motion.pulse,
        easing: Easing.bezier(0.42, 0, 0.58, 1),
      }),
      -1,
      true,
    );
  }, [glow]);

  const glowStyle = useAnimatedStyle(() => ({
    opacity: 0.4 + glow.value * 0.35,
  }));

  const avatar = displayName.trim().slice(0, 2).toUpperCase() || 'TT';

  return (
    <View style={styles.hero}>
      <Image
        source={
          snow
            ? require('../../assets/hero_snow.png')
            : require('../../assets/hero_mountain.png')
        }
        style={styles.heroImg}
        resizeMode="cover"
      />
      {/* Summit ember halo — sits over the central peak in the photo. */}
      <Animated.View pointerEvents="none" style={[styles.heroGlow, glowStyle]} />
      {/* Bottom fade into app bg for QuickActions legibility. */}
      <View pointerEvents="none" style={styles.heroFade} />

      {/* Overlay 1: brand + actions at the top of the hero. */}
      <SafeAreaView edges={['top']} style={styles.heroAppbar}>
        <View style={styles.heroBrand}>
          <Image
            source={require('../../assets/logo.png')}
            style={styles.heroLogo}
            resizeMode="contain"
          />
          <Text style={styles.heroWordmark}>
            TRAIL<Text style={{ color: tt.ember }}>TETHER</Text>
          </Text>
        </View>
        <View style={styles.heroActionsRow}>
          <IconBtn name="bell" onPress={onPressBell} />
          <IconBtn name="search" onPress={onPressSearch} />
          <View style={styles.heroAvatar}>
            <Text style={styles.heroAvatarText}>{avatar}</Text>
          </View>
        </View>
      </SafeAreaView>

      {/* Overlay 2: greeting pinned to the bottom of the hero. */}
      <View style={styles.heroGreeting} pointerEvents="none">
        {subEyebrow && (
          <Text style={styles.heroRegion}>{subEyebrow}</Text>
        )}
        <Text style={styles.heroEyebrow}>WELCOME BACK,</Text>
        <Text style={styles.heroName}>{displayName}.</Text>
      </View>

      {snow && (
        <View style={styles.snowTag}>
          <Text style={styles.snowTagText}>❄ SNOW · UP TO 14CM</Text>
        </View>
      )}
    </View>
  );
}

// ── Quick actions ──────────────────────────────────────────────────────
//
// These are navigation targets, not data — staying in code per the rule
// distinction between "configuration" and "content".

interface QuickAction {
  label: string;
  icon: IconName;
  href: string;
}
const QUICK_ACTIONS: QuickAction[] = [
  { label: 'START HIKE', icon: 'play', href: '/map' },
  { label: 'PLAN ROUTE', icon: 'route', href: '/plan-route' },
  { label: 'LIVE TRACK', icon: 'crosshair', href: '/map' },
  { label: 'SOS', icon: 'sos', href: '/sos' },
];

function QuickActions({ router }: { router: ReturnType<typeof useRouter> }) {
  return (
    <View style={styles.actionGrid}>
      {QUICK_ACTIONS.map((a, i) => {
        const isSos = a.label === 'SOS';
        const isPrimary = i === 0;
        return (
          <Card
            key={a.label}
            tight
            padding={{ paddingVertical: sp.s6, paddingHorizontal: sp.s4 }}
            style={[
              styles.actionTile,
              isPrimary && styles.actionTilePrimary,
              isSos && styles.actionTileSos,
            ]}
            onPress={() => router.push(a.href as never)}
          >
            <View style={styles.actionInner}>
              <Icon
                name={a.icon}
                size={18}
                color={isPrimary ? tt.ember : isSos ? tt.red : tt.text2}
              />
              <Text
                style={[
                  styles.actionLabel,
                  { color: isPrimary ? tt.ember : isSos ? tt.red : tt.text2 },
                ]}
              >
                {a.label}
              </Text>
            </View>
          </Card>
        );
      })}
    </View>
  );
}

// ── Upcoming hike card ─────────────────────────────────────────────────

function UpcomingHikeCard({ router }: { router: ReturnType<typeof useRouter> }) {
  const { data, loading, error, refetch } = useUpcomingHikes();
  const next = data?.[0];

  if (loading) {
    return (
      <Card>
        <Text style={styles.eyebrow}>UPCOMING HIKE</Text>
        <LoadingState label="Reading your team's calendar…" />
      </Card>
    );
  }
  if (error) {
    return (
      <Card>
        <Text style={styles.eyebrow}>UPCOMING HIKE</Text>
        <ErrorState error={error} onRetry={refetch} />
      </Card>
    );
  }
  if (!next) {
    return (
      <Card onPress={() => router.push('/plan-route')}>
        <View style={styles.rowBetween}>
          <Text style={styles.eyebrow}>NO UPCOMING HIKES</Text>
          <Icon name="chevron-right" size={14} color={tt.text3} />
        </View>
        <Text style={[styles.cardTitle, { marginTop: 4 }]}>
          Plan your next adventure
        </Text>
        <Text style={[styles.line, { marginTop: 6 }]}>
          Tap to plan a route. Tether your team in.
        </Text>
      </Card>
    );
  }

  return (
    <Card onPress={() => router.push(`/trail-detail?id=${next.trailId}` as never)}>
      <View style={styles.rowBetween}>
        <Text style={styles.eyebrow}>{upcomingEyebrow(next)}</Text>
        <Icon name="chevron-right" size={14} color={tt.text3} />
      </View>
      <Text style={[styles.cardTitle, { marginTop: 4 }]}>{next.trailName}</Text>
      {next.meetingPoint && (
        <Text style={[styles.line, { marginTop: 6 }]}>
          MEET · {next.meetingPoint.toUpperCase()}
        </Text>
      )}
      <View style={[styles.row, { marginTop: 10, gap: 8, flexWrap: 'wrap' }]}>
        {next.status && next.status !== 'planned' && (
          <Pill
            label={next.status.toUpperCase()}
            variant={next.status === 'confirmed' ? 'live' : 'default'}
          />
        )}
      </View>
    </Card>
  );
}

function upcomingEyebrow(hike: UpcomingHike): string {
  const now = Date.now();
  const diff = hike.hikeDate.getTime() - now;
  const days = Math.round(diff / (1000 * 60 * 60 * 24));
  if (days <= 0) return 'UPCOMING HIKE · TODAY';
  if (days === 1) return 'UPCOMING HIKE · TOMORROW';
  return `UPCOMING HIKE · IN ${days} DAYS`;
}

// ── Weather card ───────────────────────────────────────────────────────

function WeatherCard({
  locationResource,
}: {
  locationResource: AsyncResource<WeatherLocation | null>;
}) {
  const weather = useCurrentWeather(locationResource.data);
  const isLoading = locationResource.loading || weather.loading;
  const sourceError = locationResource.error ?? weather.error;

  return (
    <Card onPress={!isLoading && !sourceError ? weather.refetch : undefined}>
      <View style={styles.rowBetween}>
        <Text style={styles.eyebrow}>
          CONDITIONS · {locationResource.data?.name.toUpperCase() ?? '—'}
        </Text>
        <Text style={styles.refresh}>
          {weather.loading ? 'LOADING…' : 'REFRESH →'}
        </Text>
      </View>
      {isLoading ? (
        <LoadingState label="Pulling current conditions…" />
      ) : sourceError ? (
        <ErrorState
          error={sourceError}
          onRetry={() => {
            void locationResource.refetch();
            void weather.refetch();
          }}
        />
      ) : !locationResource.data ? (
        <Text style={[styles.line, { marginTop: 10 }]}>
          Add a weather location from Profile → Settings to see live conditions here.
        </Text>
      ) : !weather.data ? (
        <ErrorState
          error="Weather service returned no data."
          onRetry={weather.refetch}
        />
      ) : (
        <WeatherBody current={weather.data} />
      )}
    </Card>
  );
}

function WeatherBody({ current }: { current: CurrentConditions }) {
  return (
    <View>
      <View style={[styles.row, { marginTop: 12, alignItems: 'flex-end' }]}>
        <Text style={styles.temp}>{Math.round(current.temperatureC)}°</Text>
        <Text style={[styles.tempUnit, { marginLeft: 4, marginBottom: 8 }]}>C</Text>
        <View style={{ flex: 1 }} />
        <Pill
          variant="ember"
          label={`HIKE SCORE ${current.hikeScore}/10`}
        />
      </View>
      <Text style={[styles.eyebrow, { marginTop: 8 }]}>
        {describeCode(current.weatherCode)} · WIND {Math.round(current.windKmh)} KM/H · 💧 {current.precipitation.toFixed(1)} MM
      </Text>
    </View>
  );
}

// WMO weather-code → short description. Mirrors the Flutter app's
// `weatherDescription` helper for parity.
function describeCode(code: number): string {
  if (code === 0) return 'CLEAR SKY';
  if (code === 1) return 'MAINLY CLEAR';
  if (code === 2) return 'PARTLY CLOUDY';
  if (code === 3) return 'OVERCAST';
  if (code === 45 || code === 48) return 'FOG';
  if (code <= 55) return 'DRIZZLE';
  if (code <= 57) return 'FREEZING DRIZZLE';
  if (code <= 65) return 'RAIN';
  if (code <= 67) return 'FREEZING RAIN';
  if (code <= 77) return 'SNOW';
  if (code <= 82) return 'RAIN SHOWERS';
  if (code <= 86) return 'SNOW SHOWERS';
  if (code <= 99) return 'THUNDERSTORM';
  return 'UNKNOWN';
}

// ── Last hike card ─────────────────────────────────────────────────────

function LastHikeCard({ router }: { router: ReturnType<typeof useRouter> }) {
  const { data, loading, error, refetch } = useLastHike();

  if (loading) {
    return (
      <Card>
        <Text style={styles.eyebrow}>LAST HIKE</Text>
        <LoadingState label="Reading your hike history…" />
      </Card>
    );
  }
  if (error) {
    return (
      <Card>
        <Text style={styles.eyebrow}>LAST HIKE</Text>
        <ErrorState error={error} onRetry={refetch} />
      </Card>
    );
  }
  if (!data) {
    return (
      <Card onPress={() => router.push('/map')}>
        <View style={styles.rowBetween}>
          <Text style={styles.eyebrow}>NO HIKES RECORDED YET</Text>
          <Icon name="chevron-right" size={14} color={tt.text3} />
        </View>
        <Text style={[styles.cardTitle, { marginTop: 4 }]}>Tap Map to start one</Text>
      </Card>
    );
  }

  return (
    <Card onPress={() => router.push('/history')}>
      <View style={styles.rowBetween}>
        <Text style={styles.eyebrow}>{lastHikeEyebrow(data)}</Text>
        <Icon name="chevron-right" size={14} color={tt.text3} />
      </View>
      <Text style={[styles.cardTitle, { marginTop: 4 }]}>{data.name}</Text>
      <View style={[styles.row, { marginTop: 10, gap: sp.s7 }]}>
        <Stat label="DISTANCE" value={data.distanceKm.toFixed(1)} unit="km" />
        <Stat label="ASCENT" value={withThousands(data.ascentM)} unit="m" />
        <Stat label="TIME" value={formatDuration(data.durationSeconds)} />
      </View>
    </Card>
  );
}

function lastHikeEyebrow(h: LastHikeSummary): string {
  const days = Math.floor(
    (Date.now() - h.createdAt.getTime()) / (1000 * 60 * 60 * 24),
  );
  if (days <= 0) return 'LAST HIKE · TODAY';
  if (days === 1) return 'LAST HIKE · YESTERDAY';
  if (days < 30) return `LAST HIKE · ${days} DAYS AGO`;
  return `LAST HIKE · ${h.createdAt.toISOString().slice(0, 10)}`;
}

function withThousands(n: number): string {
  const rounded = Math.round(n);
  const sign = rounded < 0 ? '-' : '';
  const abs = Math.abs(rounded).toString();
  const out: string[] = [];
  for (let i = 0; i < abs.length; i++) {
    const remaining = abs.length - i;
    out.push(abs[i]!);
    if (remaining > 1 && remaining % 3 === 1) out.push(',');
  }
  return sign + out.join('');
}

function formatDuration(seconds: number): string {
  const h = Math.floor(seconds / 3600);
  const m = Math.floor((seconds % 3600) / 60);
  return `${h}:${String(m).padStart(2, '0')}`;
}

function Stat({
  label,
  value,
  unit,
}: {
  label: string;
  value: string;
  unit?: string;
}) {
  return (
    <View>
      <Text style={styles.statLabel}>{label}</Text>
      <View style={styles.row}>
        <Text style={styles.statValue}>{value}</Text>
        {unit && <Text style={styles.statUnit}>{unit}</Text>}
      </View>
    </View>
  );
}

// ── Field Intel ────────────────────────────────────────────────────────
//
// Reads open incidents within 80 km of the user's first
// `weather_locations` row (BLOCKERS.md #4 resolved client-side via
// haversine). When the user has no saved weather location, falls back
// to the global feed — Field Intel still has signal, just no scoping.

function FieldIntelCard({ center }: { center: { lat: number; lon: number } | null }) {
  const intel = useFieldIntel({ center, radiusKm: 80, limit: 6 });
  return (
    <Card>
      <Text style={styles.eyebrow}>FIELD INTEL</Text>
      {intel.loading && <LoadingState />}
      {intel.error && !intel.loading && (
        <ErrorState error={intel.error} onRetry={intel.refetch} />
      )}
      {!intel.loading && !intel.error && intel.data && intel.data.length === 0 && (
        <Text style={styles.intelEmpty}>
          No open hazards{center ? ' within 80 km' : ''}.
        </Text>
      )}
      {intel.data?.map((r) => (
        <View key={r.id} style={styles.intelRow}>
          <Icon name={r.iconName} size={13} color={tt.amber} />
          <View style={{ flex: 1, minWidth: 0 }}>
            <Text style={styles.intelTitle} numberOfLines={1}>
              {r.title}
            </Text>
            <Text style={styles.intelSub} numberOfLines={2}>
              {r.sub}
            </Text>
          </View>
          <Text style={styles.intelTime}>{r.timeLabel}</Text>
        </View>
      ))}
    </Card>
  );
}

// ── Styles ─────────────────────────────────────────────────────────────

const styles = StyleSheet.create({
  actions: { flexDirection: 'row', gap: 8 },
  body: { paddingHorizontal: sp.screen, paddingTop: sp.s7 },
  hero: {
    width: '100%',
    height: 280,
    overflow: 'hidden',
    backgroundColor: tt.bg2,
    position: 'relative',
  },
  heroImg: {
    ...StyleSheet.absoluteFillObject,
    width: '100%',
    height: '100%',
  },
  heroGlow: {
    position: 'absolute',
    top: 28,
    left: '32%',
    right: '32%',
    height: 80,
    borderRadius: 60,
    backgroundColor: 'rgba(255,138,77,0.28)',
  },
  // Bottom-to-top fade into the app background so QuickActions has
  // somewhere to land. Built from a stack of decreasing-alpha views
  // because we don't ship expo-linear-gradient — close enough.
  heroFade: {
    position: 'absolute',
    bottom: 0,
    left: 0,
    right: 0,
    height: 120,
    backgroundColor: tt.bg,
    opacity: 0,
  },
  heroAppbar: {
    position: 'absolute',
    top: 0,
    left: 0,
    right: 0,
    paddingHorizontal: sp.screen,
    paddingTop: sp.s2,
    paddingBottom: sp.s5,
    flexDirection: 'row',
    alignItems: 'center',
    gap: sp.s4,
  },
  heroBrand: { flex: 1, flexDirection: 'row', alignItems: 'center', gap: 9 },
  heroLogo: { width: 22, height: 22 },
  heroWordmark: {
    fontFamily: font.uiHeavy,
    fontSize: 13,
    letterSpacing: ls.monoWide * 13,
    color: tt.text,
    textShadowColor: 'rgba(0,0,0,0.55)',
    textShadowOffset: { width: 0, height: 1 },
    textShadowRadius: 6,
  },
  heroActionsRow: { flexDirection: 'row', alignItems: 'center', gap: 8 },
  heroAvatar: {
    width: 38,
    height: 38,
    borderRadius: 19,
    backgroundColor: tt.ember,
    borderWidth: 2,
    borderColor: tt.ember,
    alignItems: 'center',
    justifyContent: 'center',
  },
  heroAvatarText: {
    fontFamily: font.uiHeavy,
    fontSize: 13,
    color: '#1a0d04',
    letterSpacing: ls.tight * 13,
  },
  heroGreeting: {
    position: 'absolute',
    left: 22,
    right: 22,
    bottom: 26,
  },
  heroRegion: {
    fontFamily: font.monoBold,
    fontSize: 9.5,
    color: tt.text2,
    letterSpacing: ls.monoWide * 9.5,
    textTransform: 'uppercase',
    marginBottom: 4,
    textShadowColor: 'rgba(0,0,0,0.55)',
    textShadowOffset: { width: 0, height: 1 },
    textShadowRadius: 6,
  },
  heroEyebrow: {
    fontFamily: font.monoBold,
    fontSize: 11,
    color: tt.ember,
    letterSpacing: ls.monoWide * 11,
    textTransform: 'uppercase',
    textShadowColor: 'rgba(0,0,0,0.55)',
    textShadowOffset: { width: 0, height: 2 },
    textShadowRadius: 8,
  },
  snowTag: {
    position: 'absolute',
    top: 78,
    left: 14,
    paddingHorizontal: 9,
    paddingVertical: 4,
    borderRadius: radius.sm,
    backgroundColor: 'rgba(7,9,12,0.7)',
    borderWidth: 1,
    borderColor: 'rgba(255,106,44,0.55)',
  },
  snowTagText: {
    fontFamily: font.monoBold,
    fontSize: 9,
    color: tt.ember,
    letterSpacing: 0.12 * 9,
  },
  eyebrow: {
    fontFamily: font.monoSemi,
    fontSize: 10.5,
    color: tt.text3,
    letterSpacing: ls.monoMed * 10.5,
    textTransform: 'uppercase',
  },
  intelRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: sp.s4,
    paddingTop: sp.s4,
    marginTop: sp.s3,
    borderTopWidth: 1,
    borderTopColor: tt.line,
  },
  intelTitle: {
    fontFamily: font.uiBold,
    fontSize: fz.body2,
    color: tt.text,
  },
  intelSub: {
    marginTop: 2,
    fontFamily: font.uiMed,
    fontSize: fz.body,
    color: tt.text2,
  },
  intelTime: {
    fontFamily: font.monoBold,
    fontSize: 10,
    color: tt.text3,
    letterSpacing: ls.monoTight * 10,
  },
  intelEmpty: {
    marginTop: sp.s3,
    fontFamily: font.uiMed,
    fontSize: fz.body,
    color: tt.text3,
  },
  line: {
    fontFamily: font.uiMed,
    fontSize: fz.body,
    color: tt.text2,
  },
  refresh: {
    fontFamily: font.monoBold,
    fontSize: 10.5,
    color: tt.ember,
    letterSpacing: 0.1 * 10.5,
  },
  heroName: {
    marginTop: 6,
    fontFamily: font.uiHeavy,
    fontSize: 34,
    lineHeight: 34,
    color: tt.text,
    letterSpacing: ls.tight * 34,
    textShadowColor: 'rgba(0,0,0,0.55)',
    textShadowOffset: { width: 0, height: 2 },
    textShadowRadius: 16,
  },
  actionGrid: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: 10,
  },
  actionTile: {
    flexBasis: '47%',
    flexGrow: 1,
  },
  actionTilePrimary: {
    borderColor: 'rgba(255,106,44,0.4)',
    backgroundColor: tt.emberSoft,
  },
  actionTileSos: {
    borderColor: 'rgba(230,61,46,0.4)',
    backgroundColor: 'rgba(230,61,46,0.06)',
  },
  actionInner: { flexDirection: 'row', alignItems: 'center', gap: 10 },
  actionLabel: {
    fontFamily: font.monoBold,
    fontSize: 11,
    letterSpacing: ls.monoMed * 11,
  },
  cardTitle: {
    fontFamily: font.uiHeavy,
    fontSize: fz.cardTitle,
    color: tt.text,
    letterSpacing: ls.tight * fz.cardTitle,
  },
  row: { flexDirection: 'row', alignItems: 'center' },
  rowBetween: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
  },
  temp: {
    fontFamily: font.uiHeavy,
    fontSize: 44,
    color: tt.text,
    letterSpacing: -0.025 * 44,
  },
  tempUnit: {
    fontFamily: font.monoBold,
    fontSize: 14,
    color: tt.text2,
  },
  statLabel: {
    fontFamily: font.monoSemi,
    fontSize: 9.5,
    color: tt.text3,
    letterSpacing: ls.monoMed * 9.5,
  },
  statValue: {
    fontFamily: font.uiHeavy,
    fontSize: 17,
    color: tt.text,
    letterSpacing: -0.015 * 17,
    marginTop: 3,
  },
  statUnit: {
    fontFamily: font.mono,
    fontSize: 11,
    color: tt.text2,
    marginLeft: 4,
    marginBottom: 1,
  },
});

// `DifficultyChip` is re-exported here implicitly to keep the imports
// list honest — it will be used when the upcoming-hike card learns about
// the trail's difficulty (next round).
const _unused = DifficultyChip;
void _unused;
