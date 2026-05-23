// Trailtether — Drakensberg shelters (caves) catalog.
//
// Generated from `assets/data/caves.gpx` (the bundled Flutter app's
// surveyed waypoint set). 125 caves and shelters; static, ships in the
// bundle so reverse geocoding works offline.
//
// To regenerate after editing the GPX:
//   awk 'BEGIN{RS="</wpt>"} /<wpt/{ ... }' assets/data/caves.gpx
// (see scripts/ — or just re-run the inline pipeline used to author this).

export interface Shelter {
  name: string;
  lat: number;
  lon: number;
}

export const SHELTERS: Shelter[] = [
  { name: "5 Star Cave", lat: -28.86073100, lon: 28.99407900 },
  { name: "Aasvoelkrans Cave", lat: -29.29675000, lon: 29.62920000 },
  { name: "Ash Cave", lat: -29.39492673, lon: 29.47717700 },
  { name: "Bannerman Cave", lat: -29.26648336, lon: 29.42848334 },
  { name: "Barker's Chalet", lat: -28.93538300, lon: 29.18561700 },
  { name: "Bell Cave", lat: -28.92834968, lon: 29.13141696 },
  { name: "Bellevue Annexe Cave", lat: -28.95288334, lon: 29.11186667 },
  { name: "Bellevue Cave", lat: -28.95294998, lon: 29.11173332 },
  { name: "Birds Nest Cave", lat: -29.51342773, lon: 29.36943878 },
  { name: "Bushmans Cave", lat: -29.80840014, lon: 29.13424401 },
  { name: "C53 Shelter", lat: -29.66879500, lon: 29.35931900 },
  { name: "CannibalCave", lat: -28.64791333, lon: 28.94397003 },
  { name: "Caracal Cave", lat: -29.28895300, lon: 29.59978900 },
  { name: "Cave", lat: -28.72376243, lon: 28.94403465 },
  { name: "Chameleon Cave", lat: -29.66363300, lon: 29.27695000 },
  { name: "Cowl Cave", lat: -29.08254812, lon: 29.34474193 },
  { name: "Crows Nest Cave", lat: -28.75980360, lon: 28.88449531 },
  { name: "Curtain Cave", lat: -29.77912000, lon: 29.16186300 },
  { name: "Cycad Cave", lat: -28.80039800, lon: 28.97698752 },
  { name: "Dagga Planters Cave", lat: -28.86087527, lon: 28.99423982 },
  { name: "Didima Cave", lat: -29.07363287, lon: 29.25345428 },
  { name: "Eagle Cave", lat: -29.01528600, lon: 29.35403500 },
  { name: "Easter Cave", lat: -28.94654998, lon: 29.10061665 },
  { name: "Engagement Cave", lat: -29.74705777, lon: 29.17589100 },
  { name: "EntranceCave", lat: -28.72375103, lon: 28.94377163 },
  { name: "False Ifidi Cave", lat: -28.79083299, lon: 28.94041702 },
  { name: "Fangs Cave", lat: -28.86276741, lon: 28.94349360 },
  { name: "Fern Forrest Grotto", lat: -29.00213800, lon: 29.40120100 },
  { name: "Five Star Cave", lat: -28.86128146, lon: 28.99408434 },
  { name: "Five Star Cave 1", lat: -28.86087527, lon: 28.99423982 },
  { name: "Fun Cave", lat: -29.69201000, lon: 29.19434100 },
  { name: "Giants Castle Cave", lat: -29.34389837, lon: 29.46495904 },
  { name: "Giants Cave 1", lat: -29.34435493, lon: 29.46671521 },
  { name: "Giants Cave 2", lat: -29.34389800, lon: 29.46495900 },
  { name: "Grasscutters Cave", lat: -28.82638274, lon: 28.97568949 },
  { name: "Gravel Shelter", lat: -28.99999919, lon: 29.28221553 },
  { name: "Grindstone Cave 1", lat: -29.13116300, lon: 29.41899900 },
  { name: "Grindstone Cave 2", lat: -29.13106600, lon: 29.42104900 },
  { name: "Gxalingenwa Cave", lat: -29.63594031, lon: 29.36228265 },
  { name: "Hlatimba Cave North", lat: -29.43372513, lon: 29.40617583 },
  { name: "Hlatimba Cave South", lat: -29.43670222, lon: 29.40146218 },
  { name: "Icidi Cave", lat: -28.80518331, lon: 28.93410000 },
  { name: "Ifidi Annexe Cave", lat: -28.79408701, lon: 28.94378697 },
  { name: "Ifidi Cave", lat: -28.79592391, lon: 28.94562269 },
  { name: "Injasuthi Summit Cave", lat: -29.19721850, lon: 29.37142127 },
  { name: "Injisuthi Summit Cave", lat: -29.19721900, lon: 29.37142100 },
  { name: "Inkosasana Cave", lat: -29.07541671, lon: 29.31985002 },
  { name: "Jarateng Cave", lat: -29.31024101, lon: 29.44422422 },
  { name: "Jubilee Cave", lat: -28.82617700, lon: 28.97162800 },
  { name: "Junction Cave", lat: -29.14755300, lon: 29.39975000 },
  { name: "Khaula Cave", lat: -29.54697700, lon: 29.34385900 },
  { name: "Kwakwatsi Shelter", lat: -28.94720000, lon: 29.09825000 },
  { name: "Kwelidumayo Cave", lat: -28.78323600, lon: 29.06783600 },
  { name: "Ledgers Cave", lat: -28.88323333, lon: 29.01395003 },
  { name: "Lotheni Cave", lat: -29.36374714, lon: 29.44578661 },
  { name: "Lower Injisuthi Cave", lat: -29.17044030, lon: 29.40525990 },
  { name: "Lower Ndumeni Cave 1", lat: -29.01389999, lon: 29.18800000 },
  { name: "Lower Ndumeni Cave 2", lat: -29.01390670, lon: 29.18843167 },
  { name: "Lynx Cave", lat: -29.44742183, lon: 29.39805611 },
  { name: "Mahai Cave", lat: -28.69330234, lon: 28.91051282 },
  { name: "Manxome Cave", lat: -28.89134039, lon: 28.98224976 },
  { name: "Marble Baths Cave 1", lat: -29.15100597, lon: 29.39771371 },
  { name: "Marble Baths Cave 2", lat: -29.15068109, lon: 29.39831411 },
  { name: "Mashai Shelter", lat: -29.70789073, lon: 29.15221590 },
  { name: "Mbundini 1", lat: -28.86128100, lon: 28.99408400 },
  { name: "Mbundini Cave", lat: -28.84627718, lon: 28.94913303 },
  { name: "Mponjwane Cave", lat: -28.89107544, lon: 29.03013524 },
  { name: "Mzimkhulu Cave", lat: -29.69367800, lon: 29.20788100 },
  { name: "Mzimude Cave 1", lat: -29.76509300, lon: 29.13036300 },
  { name: "Mzimude Cave 2", lat: -29.76497200, lon: 29.13018000 },
  { name: "Mzimude Cave 3", lat: -29.76518400, lon: 29.13033100 },
  { name: "Nameless near Scaly", lat: -28.89261900, lon: 29.06774100 },
  { name: "Ndumeni Dome Cave 1", lat: -29.01601668, lon: 29.18700004 },
  { name: "Ndumeni Dome Cave 2", lat: -29.01530002, lon: 29.18868329 },
  { name: "Nguza Cave 1", lat: -28.91811663, lon: 29.05881668 },
  { name: "Nguza Cave 2", lat: -28.91680000, lon: 29.05864997 },
  { name: "Nhlangeni Cave", lat: -29.49265687, lon: 29.29641422 },
  { name: "Pholela Cave", lat: -29.64340917, lon: 29.32214348 },
  { name: "Pigeonhole Cave", lat: -29.70366692, lon: 29.15898940 },
  { name: "Pillar Cave Annexe", lat: -29.72729115, lon: 29.17431680 },
  { name: "Pins Cave", lat: -28.89029701, lon: 28.97783300 },
  { name: "Rat Hole Cave", lat: -28.85668332, lon: 28.94390004 },
  { name: "Red Shelter", lat: -29.74796300, lon: 29.17429900 },
  { name: "Reido Cave", lat: -29.07356439, lon: 29.27884634 },
  { name: "Ribbon Falls Cave", lat: -28.97006415, lon: 29.20029684 },
  { name: "Rolands Cave", lat: -29.01408331, lon: 29.18846671 },
  { name: "Rwanqa Cave 1", lat: -28.87607510, lon: 28.95942156 },
  { name: "Rwanqa Cave 2", lat: -28.87555853, lon: 28.96187930 },
  { name: "Sandleni Cave", lat: -29.65401663, lon: 29.21648330 },
  { name: "Scaly Cave", lat: -28.89418300, lon: 29.06161800 },
  { name: "Schoongezicht Cave", lat: -29.02246705, lon: 29.25530224 },
  { name: "Sentinel Caves", lat: -28.74509211, lon: 28.88522152 },
  { name: "Shepherds Cave", lat: -28.86439207, lon: 28.99530164 },
  { name: "Shepherds Cave 2", lat: -28.86858906, lon: 28.99227468 },
  { name: "Shermans Cave", lat: -28.93474943, lon: 29.18087966 },
  { name: "Sherry Cave (Old)", lat: -29.77539500, lon: 29.18137500 },
  { name: "Siphongweni Cave", lat: -29.68735100, lon: 29.36380500 },
  { name: "Sky Light Cave", lat: -28.85463344, lon: 28.94521667 },
  { name: "Sleeping Beauty Cave", lat: -29.74916171, lon: 29.17639534 },
  { name: "Spare Rib Cave", lat: -29.25520727, lon: 29.42716286 },
  { name: "Spectacle Cave", lat: -29.64515269, lon: 29.32551744 },
  { name: "Stable Cave", lat: -28.99718790, lon: 29.36320885 },
  { name: "Stealth Cave", lat: -29.73919110, lon: 29.14873380 },
  { name: "Suai Cave", lat: -28.71903285, lon: 28.85613933 },
  { name: "Tarn Cave", lat: -29.85832100, lon: 29.13783842 },
  { name: "Terateng Cave", lat: -29.40923790, lon: 29.42004754 },
  { name: "Thamathu Cave", lat: -29.83186008, lon: 29.15040398 },
  { name: "Tooth Cave", lat: -28.75864400, lon: 28.92951900 },
  { name: "Twins Annexe Cave", lat: -28.94981666, lon: 29.11146669 },
  { name: "Twins Cave", lat: -28.95011664, lon: 29.11328330 },
  { name: "Upper Ndumeni Cave 1", lat: -29.01601668, lon: 29.18700004 },
  { name: "Upper Ndumeni Cave 2", lat: -29.01530002, lon: 29.18868329 },
  { name: "Utshani Cave", lat: -28.94795001, lon: 29.10249998 },
  { name: "Venice Cave", lat: -29.66536700, lon: 29.27951700 },
  { name: "Veranda Cave", lat: -28.79071699, lon: 28.93736701 },
  { name: "Verkyker Cave", lat: -29.69206800, lon: 29.19451900 },
  { name: "Waterfall Cave", lat: -28.91355411, lon: 29.10297222 },
  { name: "Waterfall Cave (GCastle)", lat: -29.74917500, lon: 29.17505200 },
  { name: "Wave Cave", lat: -29.77897800, lon: 29.16143800 },
  { name: "Wilsons Cave", lat: -29.66171800, lon: 29.25509500 },
  { name: "Xeni Cave", lat: -28.96736300, lon: 29.16485400 },
  { name: "Yellowwood Cave", lat: -29.41515033, lon: 29.47640377 },
  { name: "Zulu Cave", lat: -29.02576910, lon: 29.34999813 },
  { name: "caveshelter", lat: -28.68367832, lon: 28.91715012 },
  { name: "kaNtuba Cave", lat: -29.52501200, lon: 29.30556700 },
];

/**
 * Earth-radius haversine distance between two lat/lon points, in metres.
 * Static utility — used by `nearestShelter` and team-row geocoding.
 */
export function haversineMetres(
  lat1: number,
  lon1: number,
  lat2: number,
  lon2: number,
): number {
  const R = 6_371_000;
  const toRad = (d: number) => (d * Math.PI) / 180;
  const dLat = toRad(lat2 - lat1);
  const dLon = toRad(lon2 - lon1);
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) * Math.sin(dLon / 2) ** 2;
  return 2 * R * Math.asin(Math.sqrt(a));
}

export interface NearestShelter extends Shelter {
  distanceM: number;
}

/**
 * Linear scan over SHELTERS (~125 rows). At Drakensberg density that's
 * fine for the team-row use case — we're calling it a handful of times
 * per render, not in a tight loop.
 *
 * Returns the closest shelter within `maxMetres` of (lat, lon), or null.
 * Default cutoff: 3 km — anything further is "not near a shelter".
 */
export function nearestShelter(
  lat: number,
  lon: number,
  maxMetres = 3000,
): NearestShelter | null {
  let best: NearestShelter | null = null;
  for (const s of SHELTERS) {
    const d = haversineMetres(lat, lon, s.lat, s.lon);
    if (d <= maxMetres && (best == null || d < best.distanceM)) {
      best = { ...s, distanceM: d };
    }
  }
  return best;
}
