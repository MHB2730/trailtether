import Toybox.Activity;
import Toybox.ActivityRecording;
import Toybox.Position;
import Toybox.Lang;
import Toybox.Time;
import Toybox.Math;

enum HikeState {
    STATE_PICKING,
    STATE_ROUTE_PICKING,
    STATE_IDLE,
    STATE_ACQUIRING,
    STATE_RECORDING,
    STATE_PAUSED,
    STATE_SUMMARY,
    STATE_SYNCING
}

// Activity picker rows (Hike / Trail Run / Walk / Climb). Index also feeds the
// Garmin sport mapping and the activity_type string we send to Supabase.
const ACTIVITY_COUNT = 4;

class HikeRecorder {
    public var state as Number = STATE_PICKING;
    // 0 Hike, 1 Trail Run, 2 Walk, 3 Climb
    public var activity as Number = 0;

    // live metrics
    public var elapsedSec as Number = 0;
    public var distanceM as Float = 0.0;
    public var speedMps as Float = 0.0;
    public var altitudeM as Float = 0.0;
    public var ascentM as Float = 0.0;
    public var descentM as Float = 0.0;
    public var maxAltitudeM as Float = 0.0;
    public var heartRate as Number = 0;
    public var avgHeartRate as Number = 0;
    public var calories as Number = 0;
    public var pointCount as Number = 0;
    public var accuracy as Number = 0; // Position.Quality enum

    private var _session as ActivityRecording.Session?;
    private var _accumSec as Number = 0;
    private var _segStart as Number = 0;
    private var _lastLoc as Position.Location?;
    private var _lastAlt as Float?;
    private var _hrSum as Number = 0;
    private var _hrCount as Number = 0;
    private var _points as Array<Dictionary>;
    private var _elev as Array<Float>; // downsampled altitude series for sparkline
    // Memoized stride-sample of _points for the Map page; recomputed only when
    // _points grows or halves. Keeps drawMap allocation cost flat per frame.
    private var _mapPointsCache as Array<Array<Float>>?;
    private var _mapPointsCacheSize as Number = -1;
    public var course as RouteCourse; // loaded/planned route profile (sample for now)

    function initialize() {
        _points = [] as Array<Dictionary>;
        _elev = [] as Array<Float>;
        course = new RouteCourse();
        course.loadSample();
    }

    // Activity-picker plumbing ---------------------------------------------------
    // Display name used on the picker and the session label
    function activityName() as String {
        if (activity == 1) { return "Trail Run"; }
        if (activity == 2) { return "Walk"; }
        if (activity == 3) { return "Climb"; }
        return "Hike";
    }
    // Lowercase string sent to Supabase (`activity_type`)
    function activityType() as String {
        if (activity == 1) { return "trail_run"; }
        if (activity == 2) { return "walk"; }
        if (activity == 3) { return "climb"; }
        return "hike";
    }
    // Garmin sport for ActivityRecording.createSession
    function activitySport() as Activity.Sport {
        if (activity == 1) { return Activity.SPORT_RUNNING; }
        if (activity == 2) { return Activity.SPORT_WALKING; }
        // Climb and Hike both record as SPORT_HIKING (closest match on Garmin)
        return Activity.SPORT_HIKING;
    }

    // PICKING -> ROUTE_PICKING: lock in the chosen activity and move to the
    // route selection step. Caller (HikeDelegate) kicks off the route list fetch.
    function commitActivity() as Void {
        if (state == STATE_PICKING) {
            state = STATE_ROUTE_PICKING;
        }
    }

    // ROUTE_PICKING -> IDLE: route choice locked (None or a loaded course).
    // Caller may have populated `course` via RouteService.fetchById; for None
    // the caller should course.clear() first so the Map/Route pages reset.
    function commitRoute() as Void {
        if (state == STATE_ROUTE_PICKING) {
            state = STATE_IDLE;
        }
    }

    // IDLE -> turn GPS on and wait for a fix
    function beginAcquire() as Void {
        if (state != STATE_IDLE) {
            return;
        }
        _reset();
        Position.enableLocationEvents(Position.LOCATION_CONTINUOUS, method(:onPosition));
        state = STATE_ACQUIRING;
    }

    // ACQUIRING -> RECORDING (auto on good fix, or forced by button)
    function startRecording() as Void {
        if (state != STATE_ACQUIRING) {
            return;
        }
        if (Toybox has :ActivityRecording) {
            _session = ActivityRecording.createSession({
                :name => activityName(),
                :sport => activitySport()
            });
            _session.start();
        }
        _accumSec = 0;
        _segStart = Time.now().value();
        state = STATE_RECORDING;
    }

    function pause() as Void {
        if (state != STATE_RECORDING) {
            return;
        }
        _accumSec += (Time.now().value() - _segStart);
        if (_session != null) {
            _session.stop();
        }
        state = STATE_PAUSED;
    }

    function resume() as Void {
        if (state != STATE_PAUSED) {
            return;
        }
        _segStart = Time.now().value();
        if (_session != null) {
            _session.start();
        }
        state = STATE_RECORDING;
    }

    // PAUSED -> save FIT + go to summary
    function save() as Void {
        if (state != STATE_PAUSED && state != STATE_RECORDING) {
            return;
        }
        if (state == STATE_RECORDING) {
            _accumSec += (Time.now().value() - _segStart);
        }
        Position.enableLocationEvents(Position.LOCATION_DISABLE, method(:onPosition));
        if (_session != null) {
            _session.stop();
            _session.save();
            _session = null;
        }
        elapsedSec = _accumSec;
        state = STATE_SUMMARY;
    }

    // PAUSED -> throw away and return to the activity picker
    function discard() as Void {
        Position.enableLocationEvents(Position.LOCATION_DISABLE, method(:onPosition));
        if (_session != null) {
            _session.discard();
            _session = null;
        }
        _reset();
        state = STATE_PICKING;
    }

    // SUMMARY -> back to the activity picker for the next hike
    function reset() as Void {
        _reset();
        state = STATE_PICKING;
    }

    function tick() as Void {
        if (state == STATE_RECORDING) {
            elapsedSec = _accumSec + (Time.now().value() - _segStart);
        }
        if (state == STATE_RECORDING || state == STATE_ACQUIRING) {
            var info = Activity.getActivityInfo();
            if (info != null) {
                if (info.currentHeartRate != null) {
                    heartRate = info.currentHeartRate;
                    if (state == STATE_RECORDING) {
                        _hrSum += heartRate;
                        _hrCount += 1;
                        avgHeartRate = (_hrSum / _hrCount).toNumber();
                    }
                }
                if (info.calories != null) {
                    calories = info.calories;
                }
            }
        }
    }

    // GPS noise filtering — the Instinct's fix jitters a few metres even when
    // stationary; without these floors a still hiker accrues phantom distance,
    // speed and pace.
    private const DIST_FILTER_M = 5.0;  // ignore sub-5m steps (stationary jitter)
    private const MAX_STEP_M = 150.0;   // ignore teleport spikes; just resync
    private const MIN_SPEED_MPS = 0.7;  // below ~2.5 km/h is treated as stopped
    private const ALT_NOISE_M = 1.0;    // ignore <1m baro/GPS altitude wobble

    function onPosition(info as Position.Info) as Void {
        // Null accuracy (some sources don't populate it) is treated as usable so
        // we don't drop every fix; otherwise require USABLE or better.
        var goodAcc = (info.accuracy == null) || (info.accuracy >= Position.QUALITY_USABLE);
        if (info.accuracy != null) {
            accuracy = info.accuracy;
        }
        if (info.altitude != null) {
            altitudeM = info.altitude;
            if (maxAltitudeM == 0.0 || altitudeM > maxAltitudeM) {
                maxAltitudeM = altitudeM;
            }
        }
        // Floor speed to 0 when noisy/slow/poor so a still hiker reads 0, not jitter.
        if (info.speed != null && goodAcc && info.speed > MIN_SPEED_MPS) {
            speedMps = info.speed;
        } else {
            speedMps = 0.0;
        }

        if (state != STATE_RECORDING) {
            return; // acquire/paused: quality + altitude only, don't log
        }
        if (!goodAcc || info.position == null) {
            return; // drop poor fixes from the track entirely
        }

        var loc = info.position;
        if (_lastLoc == null) {
            _lastLoc = loc;
            _lastAlt = info.altitude;
            logPoint(loc, info); // anchor the track start
            return;
        }

        var step = haversine(_lastLoc, loc);
        if (step < DIST_FILTER_M) {
            return; // inside the jitter radius -> not actually moving
        }
        if (step > MAX_STEP_M) {
            _lastLoc = loc; // GPS spike -> resync without counting the jump
            return;
        }

        distanceM += step;
        if (info.altitude != null) {
            if (_lastAlt != null) {
                var d = info.altitude - _lastAlt;
                if (d >= ALT_NOISE_M) { ascentM += d; }
                else if (d <= -ALT_NOISE_M) { descentM += -d; }
            }
            _lastAlt = info.altitude;
        }
        _lastLoc = loc;
        logPoint(loc, info);
    }

    // Cap the live track at a reasonable size — at the 5 m DIST_FILTER_M floor
    // a brisk hiker logs roughly one point every 3 s, so 4000 points covers a
    // ~3.3-hour active hike. Beyond that we keep the FIRST point (anchor) and
    // halve the rest in place; cumulative `distanceM` is unaffected because we
    // only ever add inter-fix steps, not recompute from the array.
    private const MAX_POINTS = 4000;

    private function logPoint(loc as Position.Location, info as Position.Info) as Void {
        var deg = loc.toDegrees();
        _points.add({
            "lat" => deg[0],
            "lon" => deg[1],
            "alt" => (info.altitude != null) ? info.altitude : 0.0,
            "spd" => (info.speed != null) ? info.speed : 0.0,
            "t" => Time.now().value()
        });
        if (_points.size() > MAX_POINTS) {
            _halvePointsInPlace();
        }
        pointCount = _points.size();
        if (info.altitude != null) {
            _pushElev(info.altitude);
        }
    }

    // Keep [0], then every other later point. After this the next add can grow
    // back up to MAX_POINTS again, halving as needed for the full hike length.
    private function _halvePointsInPlace() as Void {
        var n = _points.size();
        var kept = [] as Array<Dictionary>;
        kept.add(_points[0]);
        for (var i = 1; i < n; i += 2) {
            kept.add(_points[i]);
        }
        _points = kept;
        _mapPointsCache = null; // force recompute next getMapPoints()
        _mapPointsCacheSize = -1;
    }

    function getPoints() as Array<Dictionary> {
        return _points;
    }

    // Stride-sampled lat/lon pairs for the live Map page. Cap at ~150 points so
    // the polyline stays cheap to redraw on a slow Garmin CPU at 4 Hz.
    // Memoized — the Map page redraws at 4 Hz but _points only changes when a
    // new GPS fix passes the filter (~every few seconds). Returning the same
    // array avoids allocating ~150 dicts every frame.
    function getMapPoints() as Array<Array<Float>> {
        var n = _points.size();
        if (_mapPointsCache != null && _mapPointsCacheSize == n) {
            return _mapPointsCache;
        }
        var out = [] as Array<Array<Float>>;
        if (n == 0) {
            _mapPointsCache = out;
            _mapPointsCacheSize = 0;
            return out;
        }
        var maxN = 150;
        var step = 1;
        if (n > maxN) {
            step = (n / maxN).toNumber();
            if (step < 1) { step = 1; }
        }
        for (var i = 0; i < n; i += step) {
            var p = _points[i];
            out.add([p["lat"] as Float, p["lon"] as Float]);
        }
        var last = _points[n - 1];
        var lastPair = [last["lat"] as Float, last["lon"] as Float];
        if (out.size() == 0 || out[out.size() - 1][0] != lastPair[0] || out[out.size() - 1][1] != lastPair[1]) {
            out.add(lastPair);
        }
        _mapPointsCache = out;
        _mapPointsCacheSize = n;
        return out;
    }

    // Up to 24 recent altitudes for the live elevation sparkline.
    function getElevSeries() as Array<Float> {
        return _elev;
    }

    private function _pushElev(alt as Float) as Void {
        // Under cap: append. At cap: shift left in place and overwrite the
        // tail — no allocation per push, vs. the previous slice() pattern
        // that allocated a fresh array every fix past the 25th.
        if (_elev.size() < 24) {
            _elev.add(alt);
            return;
        }
        for (var i = 0; i < 23; i += 1) {
            _elev[i] = _elev[i + 1];
        }
        _elev[23] = alt;
    }

    private function _reset() as Void {
        elapsedSec = 0;
        distanceM = 0.0;
        speedMps = 0.0;
        ascentM = 0.0;
        descentM = 0.0;
        maxAltitudeM = 0.0;
        heartRate = 0;
        avgHeartRate = 0;
        calories = 0;
        pointCount = 0;
        _accumSec = 0;
        _hrSum = 0;
        _hrCount = 0;
        _lastLoc = null;
        _lastAlt = null;
        _points = [] as Array<Dictionary>;
        _elev = [] as Array<Float>;
        _mapPointsCache = null;
        _mapPointsCacheSize = -1;
    }

    private function haversine(a as Position.Location, b as Position.Location) as Float {
        var ra = a.toRadians();
        var rb = b.toRadians();
        var dLat = rb[0] - ra[0];
        var dLon = rb[1] - ra[1];
        var s1 = Math.sin(dLat / 2.0);
        var s2 = Math.sin(dLon / 2.0);
        var h = s1 * s1 + Math.cos(ra[0]) * Math.cos(rb[0]) * s2 * s2;
        var c = 2.0 * Math.asin(Math.sqrt(h));
        return (6371000.0 * c).toFloat();
    }
}
