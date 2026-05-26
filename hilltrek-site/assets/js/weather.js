// ============================================================================
// Hilltrek — Weather portal
//
// Renders the "This week in the Berg" section on the home page. Uses
// Open-Meteo (free, no API key) for the 7-day forecast and BigDataCloud's
// free reverse geocoder to label the location.
//
// The hike-score formula is a verbatim port of the Trailtether app's
// _hikeScore() in lib/screens/tt_home_screen.dart (lines 1963-1972). Keep
// them in lockstep — if the app changes its scoring, change this too, and
// vice versa, otherwise the site and the app will disagree about whether
// tomorrow is a good day to walk.
// ============================================================================
(function () {
  'use strict';

  // ----- Default location: Cathedral Peak, Drakensberg. -----------------
  // Used until the visitor opts into geolocation. Picked deliberately —
  // central enough that the "Berg" forecast applies to most of our
  // audience even if they don't share their location.
  var DEFAULT_LOC = {
    lat: -28.9504, lon: 29.2114,
    label: 'Cathedral Peak · Drakensberg'
  };

  var mount = document.querySelector('[data-weather-body]');
  var locLabel = document.querySelector('[data-weather-loc]');
  var useMineBtn = document.querySelector('[data-weather-use-mine]');
  if (!mount) return;

  if (useMineBtn) {
    useMineBtn.addEventListener('click', requestGeolocation);
  }

  // Kick off with the default location so the section paints before the
  // user has to do anything.
  loadForecast(DEFAULT_LOC).catch(showError);

  // -------------------------------------------------------------------
  // Geolocation
  // -------------------------------------------------------------------
  function requestGeolocation() {
    if (!('geolocation' in navigator)) {
      showError('Your browser does not support geolocation. Showing the Drakensberg forecast.');
      return;
    }
    useMineBtn.disabled = true;
    useMineBtn.innerHTML = '<span class="spinner" style="display:inline-block;width:12px;height:12px;border:2px solid rgba(255,255,255,0.2);border-top-color:var(--ember);border-radius:50%;animation:weather-spin 0.7s linear infinite;"></span> Finding you…';
    navigator.geolocation.getCurrentPosition(
      function (pos) {
        var loc = { lat: pos.coords.latitude, lon: pos.coords.longitude, label: 'Locating…' };
        reverseGeocode(loc.lat, loc.lon)
          .then(function (name) { loc.label = name || ('Lat ' + loc.lat.toFixed(2) + ', Lng ' + loc.lon.toFixed(2)); })
          .catch(function () { loc.label = 'Your location'; })
          .then(function () {
            resetUseMineBtn();
            useMineBtn.style.display = 'none';
            return loadForecast(loc);
          })
          .catch(showError);
      },
      function (err) {
        resetUseMineBtn();
        if (err.code === 1) {
          showError('Location request denied. Showing the Drakensberg forecast instead.');
        } else if (err.code === 3) {
          showError('Locating timed out. Showing the Drakensberg forecast instead.');
        } else {
          showError('Could not get your location. Showing the Drakensberg forecast instead.');
        }
      },
      { enableHighAccuracy: false, timeout: 8000, maximumAge: 5 * 60 * 1000 }
    );
  }
  function resetUseMineBtn() {
    if (!useMineBtn) return;
    useMineBtn.disabled = false;
    useMineBtn.innerHTML =
      '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><circle cx="12" cy="12" r="9"/><circle cx="12" cy="12" r="3"/><path d="M12 1v3M12 20v3M1 12h3M20 12h3"/></svg>Use my location';
  }

  // -------------------------------------------------------------------
  // Open-Meteo + reverse geocoding
  // -------------------------------------------------------------------
  function loadForecast(loc) {
    if (locLabel) locLabel.textContent = loc.label;
    paintLoading();

    var url = 'https://api.open-meteo.com/v1/forecast'
      + '?latitude='  + encodeURIComponent(loc.lat.toFixed(4))
      + '&longitude=' + encodeURIComponent(loc.lon.toFixed(4))
      + '&current=temperature_2m,apparent_temperature,relative_humidity_2m,'
      + 'is_day,precipitation,weather_code,cloud_cover,wind_speed_10m,wind_gusts_10m'
      + '&daily=weather_code,temperature_2m_max,temperature_2m_min,'
      + 'precipitation_sum,precipitation_probability_max,'
      + 'wind_speed_10m_max,wind_gusts_10m_max,sunrise,sunset,uv_index_max'
      + '&timezone=auto&wind_speed_unit=kmh&forecast_days=7';

    return fetch(url)
      .then(function (res) {
        if (!res.ok) throw new Error('Open-Meteo returned HTTP ' + res.status);
        return res.json();
      })
      .then(function (data) { paintForecast(loc, data); });
  }

  function reverseGeocode(lat, lon) {
    var url = 'https://api.bigdatacloud.net/data/reverse-geocode-client'
      + '?latitude='  + encodeURIComponent(lat.toFixed(4))
      + '&longitude=' + encodeURIComponent(lon.toFixed(4))
      + '&localityLanguage=en';
    return fetch(url)
      .then(function (res) { return res.ok ? res.json() : null; })
      .then(function (j) {
        if (!j) return null;
        var locality = j.locality || j.city || j.localityInfo?.administrative?.[3]?.name;
        var region = j.principalSubdivision || j.countryName;
        if (locality && region) return locality + ' · ' + region;
        return locality || region || null;
      });
  }

  // -------------------------------------------------------------------
  // Hike score — verbatim port of the Trailtether app's _hikeScore()
  // -------------------------------------------------------------------
  //
  //   final precipProb = today.precipProbability ?? 0;
  //   final windKmh    = current.windSpeed; // already km/h
  //   final windPenalty = ((windKmh - 10).clamp(0, 50)) / 50 * 4;
  //   final raw = (1 - precipProb / 100) * 10 - windPenalty;
  //   return raw.clamp(1, 10).round();
  //
  function hikeScore(windKmh, precipProb) {
    var w = Math.max(0, Math.min(50, (windKmh || 0) - 10));
    var windPenalty = w / 50 * 4;
    var raw = (1 - (precipProb || 0) / 100) * 10 - windPenalty;
    return Math.round(Math.max(1, Math.min(10, raw)));
  }
  function scoreBucket(s) {
    if (s >= 7) return { cls: 'score-good', label: 'Great', blurb: 'Perfect window. Go.' };
    if (s >= 4) return { cls: 'score-mid',  label: 'Marginal', blurb: 'Conditions are mixed. Pack layers and check the trail twice.' };
    return { cls: 'score-bad', label: 'Avoid', blurb: 'The sky is not on your side. Stay low or stay home.' };
  }

  // -------------------------------------------------------------------
  // Rendering
  // -------------------------------------------------------------------
  function paintLoading() {
    mount.innerHTML = '<div class="weather-loading"><span class="spinner"></span> Reading the sky…</div>';
  }
  function showError(msg) {
    var m = (typeof msg === 'string') ? msg : (msg && msg.message) || 'Could not load the forecast.';
    mount.innerHTML = '<div class="weather-error">' + escapeHtml(m) + '</div>';
  }

  function paintForecast(loc, data) {
    if (!data || !data.current || !data.daily) {
      showError('The forecast service returned an unexpected response.');
      return;
    }

    var cur = data.current;
    var daily = data.daily;
    var todayPrecipProb = (daily.precipitation_probability_max || [])[0] || 0;
    var score = hikeScore(cur.wind_speed_10m, todayPrecipProb);
    var bucket = scoreBucket(score);

    var summary = wmoSummary(cur.weather_code, cur.is_day !== 0);
    var icon = wmoIcon(cur.weather_code, cur.is_day !== 0);

    var todayHi = (daily.temperature_2m_max || [])[0];
    var todayLo = (daily.temperature_2m_min || [])[0];

    mount.innerHTML = ''
      + '<div class="weather-today">'
      +   '<div class="weather-card weather-today-main">'
      +     '<div>'
      +       '<div class="weather-today-head">'
      +         '<div>'
      +           '<div class="label">Right now &middot; ' + escapeHtml(loc.label) + '</div>'
      +           '<div class="summary">' + escapeHtml(summary) + '</div>'
      +         '</div>'
      +         '<div style="width:56px;height:56px;color:var(--ember);">' + icon + '</div>'
      +       '</div>'
      +       '<div class="weather-today-temp">'
      +         '<span class="now">' + formatNum(cur.temperature_2m) + '<span class="unit">°C</span></span>'
      +         '<span class="range">High <strong>' + formatNum(todayHi) + '°</strong> &middot; Low <strong>' + formatNum(todayLo) + '°</strong></span>'
      +       '</div>'
      +       '<div class="weather-today-feels">Feels like ' + formatNum(cur.apparent_temperature) + '°C</div>'
      +     '</div>'
      +     '<div class="weather-metrics">'
      +       metricCell('Wind',      formatNum(cur.wind_speed_10m, 0),  'km/h', iconWind())
      +       metricCell('Gusts',     formatNum(cur.wind_gusts_10m, 0),  'km/h', iconGust())
      +       metricCell('Rain prob', String(Math.round(todayPrecipProb)), '%',  iconRain())
      +       metricCell('Humidity',  String(Math.round(cur.relative_humidity_2m || 0)), '%', iconHumidity())
      +     '</div>'
      +   '</div>'
      +   '<div class="weather-card weather-score-card ' + bucket.cls + '">'
      +     '<div class="weather-score-eyebrow">Hike score</div>'
      +     '<div class="weather-score-num">' + score + '<span class="denom">/10</span></div>'
      +     '<div class="weather-score-label">' + bucket.label + '</div>'
      +     '<div class="weather-score-blurb">' + bucket.blurb + '</div>'
      +   '</div>'
      + '</div>'
      + '<div class="weather-week-title">// Next 7 days</div>'
      + '<div class="weather-week">'
      +   buildWeekStrip(daily)
      + '</div>';
  }

  function buildWeekStrip(daily) {
    var out = '';
    var n = Math.min(7, (daily.time || []).length);
    for (var i = 0; i < n; i++) {
      var ts = daily.time[i];
      var dow = dayLabel(ts, i === 0);
      var code = (daily.weather_code || [])[i] || 0;
      var hi = (daily.temperature_2m_max || [])[i];
      var lo = (daily.temperature_2m_min || [])[i];
      var precipProb = (daily.precipitation_probability_max || [])[i] || 0;
      var wind = (daily.wind_speed_10m_max || [])[i] || 0;
      var s = hikeScore(wind, precipProb);
      var b = scoreBucket(s);

      out += ''
        + '<div class="weather-day ' + b.cls + '" title="' + escapeHtml(wmoSummary(code, true)) + '">'
        +   '<div class="dow">' + escapeHtml(dow) + '</div>'
        +   '<div class="icon">' + wmoIcon(code, true) + '</div>'
        +   '<div class="temps"><span>' + formatNum(hi, 0) + '°</span><span class="lo">' + formatNum(lo, 0) + '°</span></div>'
        +   '<div class="precip">' + iconDrop() + Math.round(precipProb) + '% &middot; ' + Math.round(wind) + ' km/h</div>'
        +   '<div class="score-pill">' + s + '/10 &middot; ' + b.label + '</div>'
        + '</div>';
    }
    return out;
  }

  function metricCell(label, val, unit, icon) {
    return ''
      + '<div class="weather-metric">'
      +   '<div class="lbl">' + icon + escapeHtml(label) + '</div>'
      +   '<div class="val">' + val + '<span class="unit">' + unit + '</span></div>'
      + '</div>';
  }

  // -------------------------------------------------------------------
  // WMO weather code → label + SVG icon
  // -------------------------------------------------------------------
  // Codes per Open-Meteo docs (https://open-meteo.com/en/docs).
  // Icons are line-art SVGs matching the rest of the site's stroke style.
  function wmoSummary(code, isDay) {
    if (code === 0) return isDay ? 'Clear and bright' : 'Clear night sky';
    if (code === 1) return 'Mostly clear';
    if (code === 2) return 'Partly cloudy';
    if (code === 3) return 'Overcast';
    if (code === 45 || code === 48) return 'Foggy';
    if (code >= 51 && code <= 57) return 'Drizzle';
    if (code >= 61 && code <= 65) return 'Rain';
    if (code === 66 || code === 67) return 'Freezing rain';
    if (code >= 71 && code <= 77) return 'Snow';
    if (code >= 80 && code <= 82) return 'Rain showers';
    if (code === 85 || code === 86) return 'Snow showers';
    if (code === 95) return 'Thunderstorm';
    if (code === 96 || code === 99) return 'Thunderstorm with hail';
    return 'Unsettled';
  }
  function wmoIcon(code, isDay) {
    if (code === 0) return isDay ? iconSun() : iconMoon();
    if (code === 1 || code === 2) return iconCloudSun();
    if (code === 3) return iconCloud();
    if (code === 45 || code === 48) return iconFog();
    if (code >= 51 && code <= 67) return iconDrizzle();
    if (code >= 61 && code <= 65) return iconRain();
    if (code >= 71 && code <= 77) return iconSnow();
    if (code >= 80 && code <= 82) return iconRain();
    if (code === 85 || code === 86) return iconSnow();
    if (code === 95 || code === 96 || code === 99) return iconStorm();
    return iconCloud();
  }

  // SVG icons (stroke-based, currentColor)
  function svg(inner) {
    return '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">' + inner + '</svg>';
  }
  function iconSun()      { return svg('<circle cx="12" cy="12" r="4"/><path d="M12 2v2M12 20v2M4.93 4.93l1.41 1.41M17.66 17.66l1.41 1.41M2 12h2M20 12h2M4.93 19.07l1.41-1.41M17.66 6.34l1.41-1.41"/>'); }
  function iconMoon()     { return svg('<path d="M21 12.8A9 9 0 1 1 11.2 3a7 7 0 0 0 9.8 9.8z"/>'); }
  function iconCloud()    { return svg('<path d="M18 18a4 4 0 0 0-.5-7.97A6 6 0 0 0 6.1 11.5 4 4 0 0 0 7 19h11z"/>'); }
  function iconCloudSun() { return svg('<circle cx="7" cy="7" r="2.5"/><path d="M7 1.5v1.6M2.5 7H1M11.5 5.5 10.4 6.6M18 18a4 4 0 0 0-.5-7.97A6 6 0 0 0 6.1 11.5 4 4 0 0 0 7 19h11z"/>'); }
  function iconFog()      { return svg('<path d="M3 8h18M3 12h12M5 16h14M7 20h10"/>'); }
  function iconRain()     { return svg('<path d="M18 14a4 4 0 0 0-.5-7.97A6 6 0 0 0 6.1 7.5 4 4 0 0 0 7 15h11z"/><path d="M8 18l-1.5 3M12 18l-1.5 3M16 18l-1.5 3"/>'); }
  function iconDrizzle()  { return svg('<path d="M18 14a4 4 0 0 0-.5-7.97A6 6 0 0 0 6.1 7.5 4 4 0 0 0 7 15h11z"/><path d="M8 19v1M12 19v1M16 19v1"/>'); }
  function iconSnow()     { return svg('<path d="M18 14a4 4 0 0 0-.5-7.97A6 6 0 0 0 6.1 7.5 4 4 0 0 0 7 15h11z"/><path d="M8 18v3M12 18v3M16 18v3M6.5 19.5h3M10.5 19.5h3M14.5 19.5h3"/>'); }
  function iconStorm()    { return svg('<path d="M18 12a4 4 0 0 0-.5-7.97A6 6 0 0 0 6.1 5.5 4 4 0 0 0 7 13h2"/><path d="m13 11-3 5h3l-2 5"/>'); }

  function iconWind()     { return svg('<path d="M4 11h11a3 3 0 1 0-3-3M4 16h17a3 3 0 1 1-3 3"/>'); }
  function iconGust()     { return svg('<path d="M3 8h7a2.5 2.5 0 1 0-2.5-2.5M3 14h12a3 3 0 1 1-3 3M3 11h17"/>'); }
  function iconRainSmall() { return svg('<path d="M5 9a4 4 0 0 1 8-1 3 3 0 0 1 5 2.5 3 3 0 0 1-3 3.5H7a3 3 0 0 1 0-5z"/><path d="M9 18l-1 2M13 18l-1 2M17 18l-1 2"/>'); }
  function iconHumidity() { return svg('<path d="M12 3s-6 7-6 11a6 6 0 0 0 12 0c0-4-6-11-6-11z"/>'); }
  function iconDrop()     { return svg('<path d="M12 3s-6 7-6 11a6 6 0 0 0 12 0c0-4-6-11-6-11z"/>'); }

  // -------------------------------------------------------------------
  // Utils
  // -------------------------------------------------------------------
  function formatNum(n, digits) {
    if (n === undefined || n === null || isNaN(n)) return '—';
    var d = (digits === undefined) ? 1 : digits;
    return Number(n).toFixed(d).replace(/\.0+$/, '');
  }
  function dayLabel(iso, isToday) {
    if (isToday) return 'Today';
    try {
      var d = new Date(iso + 'T12:00:00');
      return d.toLocaleDateString('en-ZA', { weekday: 'short' }).toUpperCase();
    } catch (_) { return iso; }
  }
  function escapeHtml(s) {
    return String(s == null ? '' : s).replace(/[&<>"']/g, function (c) {
      return { '&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;' }[c];
    });
  }
})();
