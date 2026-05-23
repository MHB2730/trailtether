// Trailtether — TrailMap.
//
// Real MapView wrapper built on react-native-maps. Renders an
// arbitrary set of trail polylines, hazard pins, shelter pins, and
// team-member avatars over the platform map (Google Maps on Android,
// Apple Maps on iOS by default — both fine for the topographic-ish
// region we care about).
//
// Use it three ways:
//   * `<TrailMap trails={…} />` — overview of multiple trails (Map tab)
//   * `<TrailMap trails={[trail]} fitToTrail />` — single trail detail
//   * `<TrailMap teamMembers={…} hazards={…} />` — team-tracking view
//
// Picks an initial region by fitting around whatever data was passed.
// Falls back to a Drakensberg-wide region if everything is empty —
// never an arbitrary 0,0.

import React, { useMemo, useRef } from 'react';
import { StyleSheet, View } from 'react-native';
import MapView, {
  Marker,
  Polyline,
  PROVIDER_DEFAULT,
  type Region,
} from 'react-native-maps';
import type { TeamMemberLive, Trail } from '@/data/types';
import type { NearbyHazard } from '@/data/types';
import { difficultyColor, tt } from '@theme/tokens';
import { SHELTERS } from '@/data/shelters';

// Drakensberg bbox — used when callers pass no data.
const DEFAULT_REGION: Region = {
  latitude: -29.3,
  longitude: 29.4,
  latitudeDelta: 1.2,
  longitudeDelta: 1.2,
};

export interface TrailMapProps {
  trails?: Trail[];
  teamMembers?: TeamMemberLive[];
  hazards?: (NearbyHazard & { lat: number; lon: number })[];
  /** Show every bundled shelter as a small pin. Default false. */
  showShelters?: boolean;
  /** Fit map to the first trail's bbox on mount. */
  fitToTrail?: boolean;
  /** Map tile flavour. Defaults to the platform default. */
  mapType?: 'standard' | 'satellite' | 'hybrid' | 'terrain';
  /** Tap callback when a trail polyline is pressed. */
  onTrailPress?: (trailId: string) => void;
  style?: object;
}

export function TrailMap({
  trails = [],
  teamMembers = [],
  hazards = [],
  showShelters = false,
  fitToTrail = false,
  mapType = 'standard',
  onTrailPress,
  style,
}: TrailMapProps) {
  const mapRef = useRef<MapView>(null);

  const initialRegion = useMemo<Region>(() => {
    if (fitToTrail && trails.length > 0) {
      const t = trails[0]!;
      return {
        latitude: (t.bbox.minLat + t.bbox.maxLat) / 2,
        longitude: (t.bbox.minLon + t.bbox.maxLon) / 2,
        latitudeDelta: Math.max(0.02, (t.bbox.maxLat - t.bbox.minLat) * 1.4),
        longitudeDelta: Math.max(0.02, (t.bbox.maxLon - t.bbox.minLon) * 1.4),
      };
    }
    if (trails.length > 0) {
      const lats: number[] = [];
      const lons: number[] = [];
      for (const t of trails) {
        lats.push(t.bbox.minLat, t.bbox.maxLat);
        lons.push(t.bbox.minLon, t.bbox.maxLon);
      }
      const minLat = Math.min(...lats);
      const maxLat = Math.max(...lats);
      const minLon = Math.min(...lons);
      const maxLon = Math.max(...lons);
      return {
        latitude: (minLat + maxLat) / 2,
        longitude: (minLon + maxLon) / 2,
        latitudeDelta: Math.max(0.05, (maxLat - minLat) * 1.2),
        longitudeDelta: Math.max(0.05, (maxLon - minLon) * 1.2),
      };
    }
    if (teamMembers.length > 0) {
      const lats = teamMembers.map((m) => m.lat).filter((n) => n !== 0);
      const lons = teamMembers.map((m) => m.lon).filter((n) => n !== 0);
      if (lats.length > 0) {
        const minLat = Math.min(...lats);
        const maxLat = Math.max(...lats);
        const minLon = Math.min(...lons);
        const maxLon = Math.max(...lons);
        return {
          latitude: (minLat + maxLat) / 2,
          longitude: (minLon + maxLon) / 2,
          latitudeDelta: Math.max(0.05, (maxLat - minLat) * 1.6),
          longitudeDelta: Math.max(0.05, (maxLon - minLon) * 1.6),
        };
      }
    }
    return DEFAULT_REGION;
  }, [trails, teamMembers, fitToTrail]);

  return (
    <View style={[styles.fill, style]}>
      <MapView
        ref={mapRef}
        style={styles.fill}
        provider={PROVIDER_DEFAULT}
        mapType={mapType}
        initialRegion={initialRegion}
        showsUserLocation
        showsMyLocationButton={false}
        showsCompass
        loadingEnabled
        loadingBackgroundColor={tt.bg2}
        loadingIndicatorColor={tt.ember}
      >
        {trails.map((t) => (
          <Polyline
            key={t.id}
            coordinates={t.coords.map((c) => ({ latitude: c.lat, longitude: c.lon }))}
            strokeColor={difficultyColor(t.difficulty)}
            strokeWidth={3}
            tappable={!!onTrailPress}
            onPress={() => onTrailPress?.(t.id)}
          />
        ))}

        {showShelters &&
          SHELTERS.map((s) => (
            <Marker
              key={`shelter-${s.name}`}
              coordinate={{ latitude: s.lat, longitude: s.lon }}
              title={s.name}
              description="Shelter / cave"
              pinColor={tt.green}
            />
          ))}

        {hazards.map((h) => (
          <Marker
            key={h.id}
            coordinate={{ latitude: h.lat, longitude: h.lon }}
            title={h.title}
            description={h.sub}
            pinColor={hazardPinColor(h.risk)}
          />
        ))}

        {teamMembers.map((m) => (
          <Marker
            key={m.uid}
            coordinate={{ latitude: m.lat, longitude: m.lon }}
            title={m.name}
            description={`${Math.round(m.altitudeM)} m · ${m.locationLabel}`}
            pinColor={m.alert ? tt.red : m.lead ? tt.ember : tt.blue}
          />
        ))}
      </MapView>
    </View>
  );
}

function hazardPinColor(risk: NearbyHazard['risk']): string {
  switch (risk) {
    case 'high':     return tt.red;
    case 'moderate': return tt.amber;
    case 'low':      return tt.green;
    default:         return tt.blue;
  }
}

const styles = StyleSheet.create({
  fill: { flex: 1 },
});
