import './style.css';
import 'maplibre-gl/dist/maplibre-gl.css';
import maplibregl from 'maplibre-gl';

// --- CONFIG ---
const MAPTILER_KEY = 'Q0CAyoVboiRtEPd1QzcG';
const START_VIEW = {
  center: [29.12, -29.4],
  zoom: 10,
  pitch: 65,
  bearing: -20
};

// --- STATE ---
let map;
let profileChart;
let chartCtorPromise;
let activeTrackId = null;
let mapLoaded = false;
let weatherEnabled = false;
let routes = [];

// --- INITIALIZATION ---
async function init() {
  try {
    routes = await loadRoutes();
    initMap();
    setupUI();
    renderTrackList(routes);
    updateTelemetry();
    fetchWeather();
  } catch (error) {
    console.error('Trailtether startup failed', error);
    showStartupError(error);
  } finally {
    hideLoading();
  }
}

async function loadRoutes() {
  const response = await fetch('/data/routes.json');
  if (!response.ok) {
    throw new Error(`Route data failed to load (${response.status})`);
  }

  const data = await response.json();
  if (!Array.isArray(data)) {
    throw new Error('Route data is not a list');
  }

  return data.filter(route => Array.isArray(route.coords) && route.coords.length > 1);
}

function initMap() {
  map = new maplibregl.Map({
    container: 'map',
    style: `https://api.maptiler.com/maps/hybrid/style.json?key=${MAPTILER_KEY}`,
    center: START_VIEW.center,
    zoom: START_VIEW.zoom,
    pitch: START_VIEW.pitch,
    bearing: START_VIEW.bearing,
    antialias: true
  });

  map.on('load', () => {
    mapLoaded = true;
    setupMapLayers();
  });

  map.on('style.load', () => {
    setupMapLayers();
  });

  map.on('mousemove', (e) => {
    const { lng, lat } = e.lngLat;
    const el = document.getElementById('coords-display');
    if (el) el.innerText = `${formatCoordinate(lat, 'NS')}  ${formatCoordinate(lng, 'EW')}`;
  });
}

function setupMapLayers() {
    // Add 3D Terrain
    if (!map.getSource('terrain')) {
        map.addSource('terrain', {
            type: 'raster-dem',
            url: `https://api.maptiler.com/tiles/terrain-rgb-v2/tiles.json?key=${MAPTILER_KEY}`,
            tileSize: 256
        });
    }
    map.setTerrain({ source: 'terrain', exaggeration: 1.5 });

    // Atmosphere Handling (MapLibre 4.x check)
    if (typeof map.setFog === 'function') {
        map.setFog({
            'range': [0.5, 10],
            'color': '#050505',
            'horizon-blend': 0.05
        });
    }

    addTracksSourceAndLayers();
    if (weatherEnabled) toggle3DWeather(true);
}

function addTracksSourceAndLayers() {
  if (!routes.length) return;

  // Cache GeoJSON to avoid re-mapping on every update if possible
  const geojson = {
    type: 'FeatureCollection',
    features: routes.map(r => ({
      type: 'Feature',
      properties: { ...r },
      geometry: { type: 'LineString', coordinates: r.coords }
    }))
  };

  if (!map.getSource('tracks')) {
      map.addSource('tracks', { type: 'geojson', data: geojson });
  } else {
      map.getSource('tracks').setData(geojson);
  }

  if (!map.getLayer('tracks-line')) {
      map.addLayer({
          id: 'tracks-line',
          type: 'line',
          source: 'tracks',
          layout: { 'line-join': 'round', 'line-cap': 'round' },
          paint: { 'line-color': '#f27d26', 'line-width': 3, 'line-opacity': 0.8 }
      });
  }

  if (!map.getLayer('tracks-highlight')) {
      map.addLayer({
          id: 'tracks-highlight',
          type: 'line',
          source: 'tracks',
          layout: { 'line-join': 'round', 'line-cap': 'round' },
          paint: { 'line-color': '#fff', 'line-width': 5, 'line-opacity': 0, 'line-blur': 2 }
      });
  }

  map.off('click', 'tracks-line');
  map.on('click', 'tracks-line', (e) => selectTrack(e.features[0].properties.id));
  map.on('mouseenter', 'tracks-line', () => map.getCanvas().style.cursor = 'pointer');
  map.on('mouseleave', 'tracks-line', () => map.getCanvas().style.cursor = '');
  
  updateTelemetry();
}

function updateTelemetry() {
    const el = document.getElementById('tel-tracks');
    if (el) el.innerText = routes.length;
}

function setupUI() {
  document.querySelectorAll('.mode-btn').forEach(btn => {
    btn.onclick = () => {
      document.querySelectorAll('.mode-btn').forEach(b => b.classList.remove('active'));
      btn.classList.add('active');
      map.setStyle(`https://api.maptiler.com/maps/${btn.dataset.style}/style.json?key=${MAPTILER_KEY}`);
      if (document.getElementById('tel-style')) document.getElementById('tel-style').innerText = btn.innerText;
    };
  });

  document.getElementById('track-search').oninput = (e) => {
    const term = e.target.value.toLowerCase();
    const filtered = routes.filter(r => r.name.toLowerCase().includes(term));
    renderTrackList(filtered);
    if (mapLoaded && map.getLayer('tracks-line')) {
        const names = filtered.map(f => f.name);
        if (term && names.length > 0) {
            map.setFilter('tracks-line', ['match', ['get', 'name'], names, true, false]);
        } else if (term) {
            map.setFilter('tracks-line', ['==', ['get', 'name'], '__NON_EXISTENT__']);
        } else {
            map.setFilter('tracks-line', null);
        }
    }
  };

  document.getElementById('reset-view').onclick = () => {
    map.flyTo({ center: START_VIEW.center, zoom: START_VIEW.zoom, pitch: START_VIEW.pitch, bearing: START_VIEW.bearing, duration: 2000 });
  };

  document.getElementById('fit-all').onclick = () => {
      const lons = routes.flatMap(r => r.coords.map(c => c[0]));
      const lats = routes.flatMap(r => r.coords.map(c => c[1]));
      if (lons.length > 0) {
          map.fitBounds([[Math.min(...lons), Math.min(...lats)], [Math.max(...lons), Math.max(...lats)]], { padding: 100, duration: 2000 });
      }
  };

  const toggleWeather = () => {
      weatherEnabled = !weatherEnabled;
      toggle3DWeather(weatherEnabled);
      const label = weatherEnabled ? 'Disable 3D Weather' : 'Enable 3D Weather';
      const stormToggle = document.getElementById('toggle-storm');
      const sidebarToggle = document.getElementById('toggle-weather-layer');
      if (stormToggle) stormToggle.innerText = label;
      if (sidebarToggle) sidebarToggle.innerText = weatherEnabled ? 'Hide Precipitation Radar' : 'Show Precipitation Radar';
  };
  document.getElementById('toggle-storm').onclick = toggleWeather;
  document.getElementById('toggle-weather-layer').onclick = toggleWeather;

  document.getElementById('hide-detail').onclick = () => {
    document.getElementById('detail-panel').classList.remove('open');
    if (mapLoaded && map.getLayer('tracks-highlight')) map.setPaintProperty('tracks-highlight', 'line-opacity', 0);
    activeTrackId = null;
  };

  const uploadTrigger = document.getElementById('upload-trigger');
  const gpxInput = document.getElementById('gpx-input');
  if (uploadTrigger && gpxInput) {
    uploadTrigger.addEventListener('click', () => gpxInput.click());
    gpxInput.addEventListener('change', async (event) => {
      const [file] = event.target.files ?? [];
      if (!file) return;

      try {
        processGPX(await file.text(), file.name);
      } catch (error) {
        console.error('GPX import failed', error);
      } finally {
        gpxInput.value = '';
      }
    });
  }

  let weatherTimeout;
  let lastWeatherCoords = null;

  map.on('moveend', () => {
      const center = map.getCenter();
      
      // Only fetch if we've moved more than ~5km from last fetch or first time
      if (lastWeatherCoords) {
          const dist = haversineKm([lastWeatherCoords.lng, lastWeatherCoords.lat], [center.lng, center.lat]);
          if (dist < 5) return;
      }
      
      clearTimeout(weatherTimeout);
      weatherTimeout = setTimeout(() => {
          lastWeatherCoords = center;
          fetchWeather();
      }, 1000);
  });
}

function toggle3DWeather(enable) {
    if (!mapLoaded) return;
    
    if (enable) {
        // Add Clouds Layer
        if (!map.getSource('clouds')) {
            map.addSource('clouds', {
                type: 'raster',
                tiles: [`https://api.maptiler.com/tiles/weather-clouds/{z}/{x}/{y}.png?key=${MAPTILER_KEY}`],
                tileSize: 256
            });
        }
        if (!map.getLayer('weather-clouds')) {
            map.addLayer({
                id: 'weather-clouds',
                type: 'raster',
                source: 'clouds',
                paint: { 'raster-opacity': 0, 'raster-brightness-max': 0.8, 'raster-hue-rotate': 180 }
            });
            // "Rolling in" effect: Fade in over 5 seconds
            map.setPaintProperty('weather-clouds', 'raster-opacity', 0.8, { duration: 5000 });
        }
        
        // Add Rain Layer
        if (!map.getSource('rain')) {
            map.addSource('rain', {
                type: 'raster',
                tiles: [`https://api.maptiler.com/tiles/weather-precipitation/{z}/{x}/{y}.png?key=${MAPTILER_KEY}`],
                tileSize: 256
            });
        }
        if (!map.getLayer('weather-rain')) {
            map.addLayer({
                id: 'weather-rain',
                type: 'raster',
                source: 'rain',
                paint: { 'raster-opacity': 0, 'raster-hue-rotate': 120 }
            });
            map.setPaintProperty('weather-rain', 'raster-opacity', 0.5, { duration: 3000 });
        }

        // Atmosphere Change
        if (typeof map.setFog === 'function') {
            map.setFog({ 'range': [0.1, 5], 'color': '#1a222c', 'horizon-blend': 0.2 }, { duration: 4000 });
        }
        
        startWeatherAnimation();
    } else {
        if (map.getLayer('weather-clouds')) map.setPaintProperty('weather-clouds', 'raster-opacity', 0, { duration: 2000 });
        if (map.getLayer('weather-rain')) map.setPaintProperty('weather-rain', 'raster-opacity', 0, { duration: 1000 });
        setTimeout(() => {
            if (!weatherEnabled) {
                if (map.getLayer('weather-clouds')) map.removeLayer('weather-clouds');
                if (map.getLayer('weather-rain')) map.removeLayer('weather-rain');
            }
        }, 2000);
        
        if (typeof map.setFog === 'function') {
            map.setFog({ 'range': [0.5, 10], 'color': '#050505', 'horizon-blend': 0.05 }, { duration: 2000 });
        }
    }
}

function startWeatherAnimation() {
    if (!weatherEnabled) return;
    const animate = () => {
        if (!weatherEnabled) return;
        if (map.getLayer('weather-clouds')) {
            // Subtle "rolling" effect using hue and opacity pulse
            const hue = 180 + Math.sin(Date.now() / 5000) * 20;
            map.setPaintProperty('weather-clouds', 'raster-hue-rotate', hue);
        }
        requestAnimationFrame(animate);
    };
    animate();
}

async function fetchWeather() {
    const { lng, lat } = map.getCenter();
    try {
        const response = await fetch(`https://api.open-meteo.com/v1/forecast?latitude=${lat}&longitude=${lng}&current=temperature_2m,relative_humidity_2m,apparent_temperature,precipitation,weather_code,wind_speed_10m&wind_speed_unit=ms`);
        const data = await response.json();
        if (data.current) {
            const c = data.current;
            if (document.getElementById('w-temp')) document.getElementById('w-temp').innerText = `${Math.round(c.temperature_2m)}\u00b0C`;
            if (document.getElementById('w-wind')) document.getElementById('w-wind').innerText = `${Math.round(c.wind_speed_10m * 3.6)} km/h`;
            if (document.getElementById('w-prec')) document.getElementById('w-prec').innerText = `${Math.round(c.precipitation)}mm`;
            const codes = { 0: 'Clear', 1: 'Mostly Clear', 2: 'Partly Cloudy', 3: 'Overcast', 45: 'Fog', 51: 'Drizzle', 61: 'Rain', 71: 'Snow', 95: 'Storm' };
            if (document.getElementById('w-desc')) document.getElementById('w-desc').innerText = codes[c.weather_code] || 'Variable';
        }
    } catch (e) {
        console.error('Weather fetch failed', e);
    }
}

function renderTrackList(tracks) {
  const container = document.getElementById('route-list');
  if (!container) return;
  container.replaceChildren();
  tracks.forEach(track => {
    const el = document.createElement('div');
    el.className = `route-item ${activeTrackId === track.id ? 'active' : ''}`;

    const name = document.createElement('span');
    name.className = 'route-name';
    name.textContent = track.name;

    const meta = document.createElement('div');
    meta.className = 'route-meta';

    const distance = document.createElement('span');
    distance.textContent = `${Number(track.distanceKm || 0).toFixed(1)}km`;

    const elevation = document.createElement('span');
    elevation.textContent = `${Math.round(Number(track.maxEle || 0))}m`;

    meta.append(distance, elevation);
    el.append(name, meta);
    el.onclick = () => selectTrack(track.id);
    container.appendChild(el);
  });
}

function selectTrack(id) {
  const track = routes.find(r => r.id === id);
  if (!track) return;
  activeTrackId = id;
  document.querySelectorAll('.route-item').forEach(el => {
    const nameEl = el.querySelector('.route-name');
    if (nameEl) el.classList.toggle('active', nameEl.innerText === track.name);
  });
  if (document.getElementById('d-name')) document.getElementById('d-name').innerText = track.name;
  if (document.getElementById('d-gain')) document.getElementById('d-gain').innerText = track.elevationGainM;
  if (document.getElementById('d-elev')) document.getElementById('d-elev').innerText = `${track.minEle}\u2013${track.maxEle}m`;
  if (document.getElementById('d-id')) document.getElementById('d-id').innerText = track.id.toUpperCase();
  if (document.getElementById('d-badge')) document.getElementById('d-badge').innerText = track.difficulty;
  document.getElementById('detail-panel').classList.add('open');
  if (mapLoaded && map.getLayer('tracks-highlight')) {
      map.setFilter('tracks-highlight', ['==', ['get', 'id'], id]);
      map.setPaintProperty('tracks-highlight', 'line-opacity', 0.8);
  }
  updateChart(track);
  flyToTrack(track);
}

function flyToTrack(track) {
  const lons = track.coords.map(c => c[0]);
  const lats = track.coords.map(c => c[1]);
  map.fitBounds([[Math.min(...lons), Math.min(...lats)], [Math.max(...lons), Math.max(...lats)]], { padding: 100, pitch: 50, bearing: -10, duration: 2000 });
}

async function updateChart(track) {
  const ctx = document.getElementById('profile-chart')?.getContext('2d');
  if (!ctx) return;
  const Chart = await getChartCtor();
  if (profileChart) profileChart.destroy();
  profileChart = new Chart(ctx, {
    type: 'line',
    data: { labels: track.profile.map(p => p[0]), datasets: [{ data: track.profile.map(p => p[1]), borderColor: '#f27d26', backgroundColor: 'rgba(242, 125, 38, 0.1)', fill: true, pointRadius: 0, borderWidth: 2, tension: 0.4 }] },
    options: { responsive: true, maintainAspectRatio: false, plugins: { legend: { display: false } }, scales: { x: { display: false }, y: { grid: { color: 'rgba(255,255,255,0.05)' }, ticks: { color: '#666', font: { size: 9 } } } } }
  });
}

async function getChartCtor() {
  if (!chartCtorPromise) {
    chartCtorPromise = import('chart.js').then(({ Chart, registerables }) => {
      Chart.register(...registerables);
      return Chart;
    });
  }
  return chartCtorPromise;
}

function processGPX(xmlString, filename) {
    const parser = new DOMParser();
    const xml = parser.parseFromString(xmlString, 'text/xml');
    const parserError = xml.querySelector('parsererror');
    if (parserError) throw new Error('Invalid GPX XML');

    const points = Array.from(xml.querySelectorAll('trkpt, rtept'))
      .map(pt => [
        parseFloat(pt.getAttribute('lon')),
        parseFloat(pt.getAttribute('lat')),
        parseFloat(pt.querySelector('ele')?.textContent || 0)
      ])
      .filter(([lon, lat]) => Number.isFinite(lon) && Number.isFinite(lat));
    if (points.length === 0) return;

    const elevations = points.map(p => p[2]).filter(Number.isFinite);
    const newId = `user_${Date.now()}`;
    const newRoute = {
      id: newId,
      name: filename.replace(/\.gpx$/i, ''),
      distanceKm: calculateDistanceKm(points),
      difficulty: 'User Upload',
      minEle: elevations.length ? Math.round(Math.min(...elevations)) : 0,
      maxEle: elevations.length ? Math.round(Math.max(...elevations)) : 0,
      elevationGainM: calculateElevationGainM(elevations),
      coords: points,
      profile: points.map((p, i) => [i, Number.isFinite(p[2]) ? p[2] : 0])
    };
    routes.push(newRoute);
    addTracksSourceAndLayers();
    renderTrackList(routes);
    selectTrack(newId);
}

function calculateDistanceKm(points) {
  let distance = 0;
  for (let i = 1; i < points.length; i++) {
    distance += haversineKm(points[i - 1], points[i]);
  }
  return Number(distance.toFixed(1));
}

function calculateElevationGainM(elevations) {
  let gain = 0;
  for (let i = 1; i < elevations.length; i++) {
    const diff = elevations[i] - elevations[i - 1];
    if (diff > 0.5) gain += diff;
  }
  return Math.round(gain);
}

function haversineKm(a, b) {
  const toRad = deg => deg * Math.PI / 180;
  const radiusKm = 6371;
  const dLat = toRad(b[1] - a[1]);
  const dLon = toRad(b[0] - a[0]);
  const lat1 = toRad(a[1]);
  const lat2 = toRad(b[1]);
  const x = Math.sin(dLat / 2) ** 2 +
    Math.cos(lat1) * Math.cos(lat2) * Math.sin(dLon / 2) ** 2;
  return radiusKm * 2 * Math.atan2(Math.sqrt(x), Math.sqrt(1 - x));
}

function formatCoordinate(value, axis) {
  const positive = value >= 0;
  const suffix = axis === 'NS' ? (positive ? 'N' : 'S') : (positive ? 'E' : 'W');
  return `${Math.abs(value).toFixed(4)}\u00b0${suffix}`;
}

function showStartupError(error) {
  const container = document.getElementById('route-list');
  if (!container) return;
  container.textContent = `Unable to load route data: ${error.message}`;
}
function hideLoading() {
    const loadingScreen = document.getElementById('loading-screen');
    if (!loadingScreen) return;
    loadingScreen.style.transition = 'opacity 1.5s ease';
    loadingScreen.style.opacity = '0';
    setTimeout(() => {
      loadingScreen.style.display = 'none';
    }, 1500);
}

init();

