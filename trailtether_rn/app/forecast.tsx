// Trailtether — Forecast.
//
// Open-Meteo backed forecast for whichever weather_location the user
// has saved. Switch between locations with the ChipRow at the top.
// Today's big block: BigWxIcon + temperature + ScoreOrb + a short
// "DRY · 14% RAIN" strip. Below: 7-day strip from useForecast().
//
// Hourly graph + alert tiles use the same `notifications` table
// referenced by BLOCKERS.md #12 — until that lands they show a
// blocker stub.

import React, { useState } from 'react';
import {
  ScrollView,
  StyleSheet,
  Text,
  View,
} from 'react-native';
import { useRouter } from 'expo-router';
import { ScreenShell } from '@components/primitives/ScreenShell';
import { TTAppBar, IconBtn } from '@components/primitives/TTAppBar';
import { Card } from '@components/primitives/Card';
import { ChipRow } from '@components/design/ChipRow';
import { ScoreOrb } from '@components/design/ScoreOrb';
import { WeatherIcon } from '@components/design/WeatherIcon';
import { ErrorState, LoadingState } from '@components/primitives/States';
import { useCurrentWeather, useForecast, useWeatherLocations } from '@/data/hooks';
import { describeWeatherCode } from '@/data/adapters';
import { weatherIconKind } from '@/data/enums';
import { font, fz, ls, sp, tt } from '@theme/tokens';

export default function ForecastScreen() {
  const router = useRouter();
  const locations = useWeatherLocations();
  const [selectedId, setSelectedId] = useState<string | null>(null);
  const active =
    locations.data?.find((l) => l.id === selectedId) ?? locations.data?.[0] ?? null;
  const current = useCurrentWeather(active);
  const forecast = useForecast(active);

  return (
    <ScreenShell>
      <TTAppBar
        big
        title="Forecast"
        sub={active ? active.name.toUpperCase() : 'NO LOCATION'}
        leftIcon="chevron-up"
        onPressLeft={() => router.back()}
        right={<IconBtn name="plus" />}
      />
      <ScrollView
        contentContainerStyle={styles.body}
        showsVerticalScrollIndicator={false}
      >
        {locations.loading && <LoadingState />}
        {locations.error && !locations.loading && (
          <ErrorState error={locations.error} onRetry={locations.refetch} />
        )}
        {!locations.loading && locations.data && locations.data.length === 0 && (
          <Text style={styles.emptyHint}>
            No saved weather locations. Add one from Home → Weather card → "Add location".
          </Text>
        )}

        {locations.data && locations.data.length > 0 && (
          <ChipRow
            value={(active?.id ?? '')}
            onChange={(id) => setSelectedId(id)}
            items={locations.data.map((l) => ({ id: l.id, label: l.name }))}
            style={{ marginBottom: sp.s5 }}
          />
        )}

        {active && current.loading && <LoadingState style={{ marginTop: sp.s4 }} />}
        {active && current.error && !current.loading && (
          <ErrorState error={current.error} onRetry={current.refetch} />
        )}
        {active && current.data && (
          <Card style={{ marginTop: sp.s3 }}>
            <View style={styles.headerRow}>
              <View>
                <Text style={styles.eyebrow}>TODAY</Text>
                <View style={styles.tempRow}>
                  <WeatherIcon
                    kind={weatherIconKind(current.data.weatherCode)}
                    size="lg"
                  />
                  <Text style={styles.temp}>
                    {Math.round(current.data.temperatureC)}°
                  </Text>
                </View>
                <Text style={styles.desc}>
                  {describeWeatherCode(current.data.weatherCode)} ·{' '}
                  {Math.round(current.data.precipitation)}% RAIN
                </Text>
              </View>
              <ScoreOrb score={current.data.hikeScore} />
            </View>
            <View style={styles.tileGrid}>
              <Tile label="WIND" value={`${Math.round(current.data.windKmh)}`} unit="km/h" />
              <Tile label="HUMIDITY" value={`${Math.round(current.data.humidity)}`} unit="%" />
              <Tile label="FEELS" value={`${Math.round(current.data.feelsLikeC)}`} unit="°" />
              <Tile label="UV" value={`${Math.round(current.data.uvIndex)}`} unit="" />
            </View>
          </Card>
        )}

        {active && forecast.loading && <LoadingState style={{ marginTop: sp.s4 }} />}
        {active && forecast.error && !forecast.loading && (
          <ErrorState error={forecast.error} onRetry={forecast.refetch} />
        )}
        {active && forecast.data && forecast.data.length > 0 && (
          <Card style={{ marginTop: sp.s5 }}>
            <Text style={styles.sectionTitle}>7-DAY OUTLOOK</Text>
            <View style={styles.weekStrip}>
              {forecast.data.map((d) => (
                <View key={d.dayLabel} style={styles.weekCell}>
                  <Text style={styles.weekDay}>{d.dayLabel}</Text>
                  <WeatherIcon kind={d.icon} size="sm" />
                  <Text style={styles.weekHi}>{Math.round(d.hiC)}°</Text>
                  <Text style={styles.weekLo}>{Math.round(d.loC)}°</Text>
                  <View
                    style={[
                      styles.weekScore,
                      {
                        backgroundColor:
                          d.hikeScore >= 7
                            ? 'rgba(76,195,138,0.18)'
                            : d.hikeScore >= 5
                              ? 'rgba(242,169,59,0.18)'
                              : 'rgba(230,61,46,0.18)',
                      },
                    ]}
                  >
                    <Text
                      style={[
                        styles.weekScoreText,
                        {
                          color:
                            d.hikeScore >= 7
                              ? tt.green
                              : d.hikeScore >= 5
                                ? tt.amber
                                : tt.red,
                        },
                      ]}
                    >
                      {d.hikeScore}
                    </Text>
                  </View>
                </View>
              ))}
            </View>
          </Card>
        )}

        {/* Hourly graph + warning tiles are a follow-up UI pass — the
            data path exists (Open-Meteo hourly + notifications table)
            but the dedicated tiles aren't wired here yet. */}
      </ScrollView>
    </ScreenShell>
  );
}

function Tile({ label, value, unit }: { label: string; value: string; unit: string }) {
  return (
    <View style={styles.tile}>
      <Text style={styles.tileLabel}>{label}</Text>
      <View style={styles.tileRow}>
        <Text style={styles.tileValue}>{value}</Text>
        {unit && <Text style={styles.tileUnit}>{unit}</Text>}
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  body: { paddingHorizontal: sp.screen, paddingBottom: sp.s11 },
  emptyHint: {
    marginTop: sp.s5,
    paddingVertical: sp.s5,
    fontFamily: font.uiMed,
    fontSize: fz.body,
    color: tt.text3,
    textAlign: 'center',
  },
  headerRow: {
    flexDirection: 'row',
    alignItems: 'flex-start',
    justifyContent: 'space-between',
  },
  eyebrow: {
    fontFamily: font.uiBold,
    fontSize: 10.5,
    color: tt.text3,
    letterSpacing: ls.monoWide * 10.5,
    textTransform: 'uppercase',
  },
  tempRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: sp.s4,
    marginTop: sp.s3,
  },
  temp: {
    fontFamily: font.uiHeavy,
    fontSize: 56,
    color: tt.text,
    letterSpacing: ls.tight * 56,
  },
  desc: {
    marginTop: 4,
    fontFamily: font.monoSemi,
    fontSize: fz.body,
    color: tt.text2,
    letterSpacing: ls.monoTight * fz.body,
  },
  tileGrid: {
    marginTop: sp.s6,
    flexDirection: 'row',
    gap: sp.s3,
  },
  tile: {
    flex: 1,
    padding: sp.s4,
    backgroundColor: tt.surf2,
    borderRadius: 8,
    borderWidth: 1,
    borderColor: tt.line,
  },
  tileLabel: {
    fontFamily: font.uiBold,
    fontSize: 9,
    color: tt.text3,
    letterSpacing: ls.monoWide * 9,
    textTransform: 'uppercase',
  },
  tileRow: { flexDirection: 'row', alignItems: 'baseline', gap: 3, marginTop: 5 },
  tileValue: {
    fontFamily: font.monoBold,
    fontSize: 18,
    color: tt.text,
    letterSpacing: ls.tight * 18,
  },
  tileUnit: { fontFamily: font.monoSemi, fontSize: 10, color: tt.text2 },
  sectionTitle: {
    fontFamily: font.uiBold,
    fontSize: 11,
    color: tt.text2,
    letterSpacing: ls.monoWide * 11,
    textTransform: 'uppercase',
    marginBottom: sp.s4,
  },
  weekStrip: {
    flexDirection: 'row',
    gap: sp.s2,
  },
  weekCell: {
    flex: 1,
    alignItems: 'center',
    paddingVertical: sp.s3,
    gap: 4,
  },
  weekDay: {
    fontFamily: font.uiBold,
    fontSize: 9.5,
    color: tt.text3,
    letterSpacing: ls.monoMed * 9.5,
  },
  weekHi: {
    fontFamily: font.monoBold,
    fontSize: 13,
    color: tt.text,
    letterSpacing: ls.tight * 13,
    marginTop: 2,
  },
  weekLo: {
    fontFamily: font.monoSemi,
    fontSize: 10,
    color: tt.text3,
    letterSpacing: ls.monoTight * 10,
  },
  weekScore: {
    marginTop: 2,
    width: 22,
    height: 22,
    borderRadius: 6,
    alignItems: 'center',
    justifyContent: 'center',
  },
  weekScoreText: {
    fontFamily: font.monoBold,
    fontSize: 11,
    letterSpacing: ls.tight * 11,
  },
});
