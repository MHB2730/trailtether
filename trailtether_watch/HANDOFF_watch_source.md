# Trailtether Garmin Instinct 3 watch app - full source
Device: instinct3amoled45mm (390x390 round AMOLED, button-only). Language: Monkey C (Connect IQ).

## manifest.xml
```xml
<?xml version="1.0"?>
<iq:manifest xmlns:iq="http://www.garmin.com/xml/connectiq" version="3">
    <iq:application id="a3f5c8e1b2d4476e9a0c1f3e5d7b8c2a" type="watch-app" name="@Strings.AppName" entry="TrailtetherWatchApp" launcherIcon="@Drawables.LauncherIcon" minApiLevel="3.2.0">
        <iq:products>
            <iq:product id="instinct3amoled45mm"/>
        </iq:products>
        <iq:permissions>
            <iq:uses-permission id="Positioning"/>
            <iq:uses-permission id="Fit"/>
            <iq:uses-permission id="Communications"/>
        </iq:permissions>
        <iq:languages>
            <iq:language>eng</iq:language>
        </iq:languages>
    </iq:application>
</iq:manifest>

```

## monkey.jungle
```text
project.manifest = manifest.xml
base.sourcePath = source

```

## source\HikeDelegate.mc
```monkeyc
import Toybox.WatchUi;
import Toybox.Lang;

// Routes the Instinct 3 buttons through the hike state machine.
//   START/STOP (onSelect)  Â· IDLEâ†’acquire Â· ACQUIRINGâ†’record Â· RECORDINGâ†’pause
//                            Â· PAUSEDâ†’confirm selection Â· SUMMARYâ†’new hike
//   UP / DOWN  (prev/next) Â· RECORDINGâ†’change data page Â· PAUSEDâ†’move selection
//   BACK       (onBack)    Â· ACQUIRINGâ†’cancel Â· RECORDING swallowed Â· PAUSEDâ†’resume
class HikeDelegate extends WatchUi.BehaviorDelegate {
    private var _r as HikeRecorder;
    private var _v as HikeView;
    private var _sync as SyncService;
    private var _route as RouteService;

    function initialize(recorder as HikeRecorder, view as HikeView, route as RouteService) {
        BehaviorDelegate.initialize();
        _r = recorder;
        _v = view;
        _sync = new SyncService();
        _route = route;
    }

    // MENU (hold UP) re-pulls the active route from Supabase.
    function onMenu() as Boolean {
        _route.fetch();
        return true;
    }

    function onSelect() as Boolean {
        var s = _r.state;
        if (s == STATE_IDLE) {
            _r.beginAcquire();
        } else if (s == STATE_ACQUIRING) {
            _r.startRecording();
        } else if (s == STATE_RECORDING) {
            _r.pause();
            _v.pausedSel = 0;
        } else if (s == STATE_PAUSED) {
            if (_v.pausedSel == 0) {
                _r.resume();
            } else if (_v.pausedSel == 1) {
                _r.save();
            } else {
                _r.discard();
            }
        } else if (s == STATE_SUMMARY) {
            if (_v.syncState == 1) {
                // syncing â€” ignore
            } else if (_v.syncState == 2) {
                _r.reset();        // synced â†’ start a fresh hike
                _v.page = 0;
                _v.syncState = 0;
            } else {
                _v.syncState = 1;  // idle or error â†’ (re)try sync
                _sync.upload(_r, method(:onSyncDone));
            }
        }
        WatchUi.requestUpdate();
        return true;
    }

    function onSyncDone(ok as Boolean, msg as String) as Void {
        _v.syncState = ok ? 2 : 3;
        _v.syncMsg = msg;
        WatchUi.requestUpdate();
    }

    function onNextPage() as Boolean {
        if (_r.state == STATE_RECORDING) {
            _v.page = (_v.page + 1) % _v.pageCount();
            WatchUi.requestUpdate();
            return true;
        }
        if (_r.state == STATE_PAUSED) {
            _v.pausedSel = (_v.pausedSel + 1) % 3;
            WatchUi.requestUpdate();
            return true;
        }
        return false;
    }

    function onPreviousPage() as Boolean {
        if (_r.state == STATE_RECORDING) {
            var n = _v.pageCount();
            _v.page = (_v.page + n - 1) % n;
            WatchUi.requestUpdate();
            return true;
        }
        if (_r.state == STATE_PAUSED) {
            _v.pausedSel = (_v.pausedSel + 2) % 3;
            WatchUi.requestUpdate();
            return true;
        }
        return false;
    }

    function onBack() as Boolean {
        var s = _r.state;
        if (s == STATE_ACQUIRING) {
            _r.discard();
            WatchUi.requestUpdate();
            return true;
        }
        if (s == STATE_RECORDING || s == STATE_PAUSED) {
            if (s == STATE_PAUSED) {
                _r.resume();
                WatchUi.requestUpdate();
            }
            return true; // never exit mid-hike
        }
        return false; // IDLE / SUMMARY: allow default (exit)
    }
}

```

## source\HikeRecorder.mc
```monkeyc
import Toybox.Activity;
import Toybox.ActivityRecording;
import Toybox.Position;
import Toybox.Lang;
import Toybox.Time;
import Toybox.Math;

enum HikeState {
    STATE_IDLE,
    STATE_ACQUIRING,
    STATE_RECORDING,
    STATE_PAUSED,
    STATE_SUMMARY
}

class HikeRecorder {
    public var state as Number = STATE_IDLE;

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
    public var course as RouteCourse; // loaded/planned route profile (sample for now)

    function initialize() {
        _points = [] as Array<Dictionary>;
        _elev = [] as Array<Float>;
        course = new RouteCourse();
        course.loadSample();
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
                :name => "Hike",
                :sport => Activity.SPORT_HIKING
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

    // PAUSED -> throw away and return to idle
    function discard() as Void {
        Position.enableLocationEvents(Position.LOCATION_DISABLE, method(:onPosition));
        if (_session != null) {
            _session.discard();
            _session = null;
        }
        _reset();
        state = STATE_IDLE;
    }

    // SUMMARY -> ready for a new hike
    function reset() as Void {
        _reset();
        state = STATE_IDLE;
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

    function onPosition(info as Position.Info) as Void {
        if (info.accuracy != null) {
            accuracy = info.accuracy;
        }
        if (info.altitude != null) {
            altitudeM = info.altitude;
            if (altitudeM > maxAltitudeM || maxAltitudeM == 0.0) {
                maxAltitudeM = altitudeM;
            }
        }
        if (info.speed != null) {
            speedMps = info.speed;
        }

        if (state != STATE_RECORDING) {
            return; // acquire/paused: update quality + altitude only, don't log
        }

        if (info.altitude != null) {
            if (_lastAlt != null) {
                var d = info.altitude - _lastAlt;
                if (d > 0) { ascentM += d; } else { descentM += -d; }
            }
            _lastAlt = info.altitude;
        }
        if (info.position != null) {
            var loc = info.position;
            if (_lastLoc != null) {
                distanceM += haversine(_lastLoc, loc);
            }
            _lastLoc = loc;
            var deg = loc.toDegrees();
            _points.add({
                "lat" => deg[0],
                "lon" => deg[1],
                "alt" => (info.altitude != null) ? info.altitude : 0.0,
                "spd" => (info.speed != null) ? info.speed : 0.0,
                "t" => Time.now().value()
            });
            pointCount = _points.size();
            if (info.altitude != null) {
                _pushElev(info.altitude);
            }
        }
    }

    function getPoints() as Array<Dictionary> {
        return _points;
    }

    // Up to 24 recent altitudes for the live elevation sparkline.
    function getElevSeries() as Array<Float> {
        return _elev;
    }

    private function _pushElev(alt as Float) as Void {
        _elev.add(alt);
        if (_elev.size() > 24) {
            _elev = _elev.slice(_elev.size() - 24, _elev.size());
        }
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

```

## source\HikeView.mc
```monkeyc
import Toybox.WatchUi;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Timer;
import Toybox.Math;
import Toybox.Position;

// Trailtether palette (from watch.html :root)
const C_BG = 0x000000;
const C_EMBER = 0xFF6A2C;
const C_EMBER2 = 0xFF8A4D;
const C_WHITE = 0xFFFFFF;
const C_TEXT2 = 0x98A1AC;
const C_TEXT3 = 0x5A6470;
const C_TEXT4 = 0x3D454D;
const C_RED = 0xE63D2E;
const C_GREEN = 0x4CC38A;
const C_AMBER = 0xF2A93B;
const C_BLUE = 0x5AA1D6;
const C_TRACK = 0x232A35;
const C_LINE = 0x2A323D;
const C_FILL_BEHIND = 0x2A2018; // warm-dark area fill (travelled)
const C_FILL_AHEAD = 0x5A3016;  // ember-dark area fill (upcoming)

class HikeView extends WatchUi.View {
    public var page as Number = 0;
    public var pausedSel as Number = 0; // 0 RESUME, 1 SAVE, 2 DISCARD
    public var syncState as Number = 0; // 0 idle, 1 syncing, 2 done, 3 error
    public var syncMsg as String = "";
    private var _recorder as HikeRecorder;
    private var _timer as Timer.Timer?;
    private var _blink as Boolean = true;
    private var _logo as WatchUi.BitmapResource?;

    function initialize(recorder as HikeRecorder) {
        View.initialize();
        _recorder = recorder;
    }

    function onShow() as Void {
        if (_logo == null) {
            _logo = WatchUi.loadResource(Rez.Drawables.Logo) as WatchUi.BitmapResource;
        }
        if (_timer == null) {
            _timer = new Timer.Timer();
        }
        _timer.start(method(:onTick), 1000, true);
    }

    function onHide() as Void {
        if (_timer != null) {
            _timer.stop();
        }
    }

    function onTick() as Void {
        _recorder.tick();
        _blink = !_blink;
        // auto-advance from acquire once we have a usable fix
        if (_recorder.state == STATE_ACQUIRING &&
            _recorder.accuracy >= Position.QUALITY_GOOD) {
            _recorder.startRecording();
        }
        WatchUi.requestUpdate();
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        dc.setColor(C_WHITE, C_BG);
        dc.clear();
        var s = _recorder.state;
        if (s == STATE_IDLE || s == STATE_ACQUIRING) {
            drawAcquire(dc);
        } else if (s == STATE_PAUSED) {
            drawPaused(dc);
        } else if (s == STATE_SUMMARY) {
            drawSummary(dc);
        } else {
            if (page == 1) {
                drawElevation(dc);
            } else if (page == 2) {
                drawHeartRate(dc);
            } else if (page == 3) {
                drawRoute(dc);
            } else {
                drawTimer(dc);
            }
        }
    }

    // Live data pages: Timer, Elevation, HR, (+ Route if a course is loaded).
    function pageCount() as Number {
        return (_recorder.course != null && _recorder.course.loaded()) ? 4 : 3;
    }

    // â”€â”€ shared helpers â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    private function cx(dc) { return dc.getWidth() / 2; }
    private function cy(dc) { return dc.getHeight() / 2; }
    private function CTR() { return Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER; }
    private function LFT() { return Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER; }

    private function ring(dc, color, pct, glow) as Void {
        var r = cx(dc) - 8;
        dc.setPenWidth(7);
        dc.setColor(C_TRACK, Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(cx(dc), cy(dc), r);
        if (pct >= 0.999) {
            dc.setColor(color, Graphics.COLOR_TRANSPARENT);
            dc.drawCircle(cx(dc), cy(dc), r);
        } else if (pct > 0.001) {
            var endDeg = 90.0 - 360.0 * pct;
            while (endDeg < 0.0) { endDeg += 360.0; }
            dc.setColor(color, Graphics.COLOR_TRANSPARENT);
            dc.drawArc(cx(dc), cy(dc), r, Graphics.ARC_CLOCKWISE, 90, endDeg);
        }
        dc.setPenWidth(1);
    }

    private function kmFrac() as Float {
        var frac = _recorder.distanceM / 1000.0;
        return frac - frac.toNumber();
    }

    private function pageDots(dc, active) as Void {
        var x = dc.getWidth() - 16;
        var n = pageCount();
        var gap = 14;
        var y0 = cy(dc) - ((n - 1) * gap) / 2;
        for (var i = 0; i < n; i += 1) {
            var y = y0 + i * gap;
            if (i == active) {
                dc.setColor(C_EMBER, Graphics.COLOR_TRANSPARENT);
                dc.fillRoundedRectangle(x - 2, y - 8, 5, 16, 2);
            } else {
                dc.setColor(C_TEXT4, Graphics.COLOR_TRANSPARENT);
                dc.fillCircle(x, y, 2);
            }
        }
    }

    private function heart(dc, x, y, color, scale) as Void {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        var rad = (4 * scale).toNumber();
        var off = (3 * scale).toNumber();
        var dwn = (7 * scale).toNumber();
        dc.fillCircle(x - off, y - off, rad);
        dc.fillCircle(x + off, y - off, rad);
        var w = (6 * scale).toNumber();
        dc.fillPolygon([[x - w, y - 1], [x + w, y - 1], [x, y + dwn]]);
    }

    private function recGpsRow(dc) as Void {
        var c = cx(dc);
        if (_blink) {
            dc.setColor(C_RED, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(c - 58, 48, 4);
        }
        dc.setColor(C_RED, Graphics.COLOR_TRANSPARENT);
        dc.drawText(c - 50, 48, Graphics.FONT_XTINY, "REC", LFT());
        dc.setColor(C_GREEN, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(c + 18, 48, 4);
        dc.drawText(c + 26, 48, Graphics.FONT_XTINY, "GPS", LFT());
    }

    // â”€â”€ READY (branded) vs 03 Â· GPS Acquire â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    private function drawAcquire(dc) as Void {
        if (_recorder.state == STATE_ACQUIRING) {
            drawGpsAcquire(dc);
        } else {
            drawReady(dc);
        }
    }

    // Branded start screen â€” real Trailtether logo, wordmark, START prompt.
    private function drawReady(dc) as Void {
        var c = cx(dc);
        if (_logo != null) {
            dc.drawBitmap(c - _logo.getWidth() / 2, 84, _logo);
        }
        dc.setColor(C_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(c, 244, Graphics.FONT_SMALL, "TRAILTETHER", CTR());
        dc.setColor(C_TEXT3, Graphics.COLOR_TRANSPARENT);
        dc.drawText(c, 272, Graphics.FONT_XTINY, "HIKE", CTR());

        // START HIKE chip
        dc.setColor(C_EMBER, Graphics.COLOR_TRANSPARENT);
        dc.drawRoundedRectangle(c - 78, 304, 156, 34, 17);
        dc.drawText(c, 321, Graphics.FONT_XTINY, "â–¶  START HIKE", CTR());
    }

    private function drawGpsAcquire(dc) as Void {
        var c = cx(dc);
        ring(dc, C_GREEN, 0.72, false);

        dc.setColor(C_TEXT3, Graphics.COLOR_TRANSPARENT);
        dc.drawText(c, 74, Graphics.FONT_XTINY, "HIKE", CTR());

        // concentric satellite rings + center dot
        dc.setPenWidth(1);
        dc.setColor(C_GREEN, Graphics.COLOR_TRANSPARENT);
        var midY = 165;
        dc.drawCircle(c, midY, 60);
        dc.drawCircle(c, midY, 40);
        dc.drawCircle(c, midY, 20);
        var sats = [[c - 35, midY - 35], [c + 38, midY - 22], [c + 22, midY + 34], [c - 28, midY + 28]];
        for (var i = 0; i < sats.size(); i += 1) {
            if ((_blink && i % 2 == 0) || (!_blink && i % 2 == 1)) {
                dc.fillCircle(sats[i][0], sats[i][1], 4);
            } else {
                dc.drawCircle(sats[i][0], sats[i][1], 3);
            }
        }
        dc.setColor(C_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(c, midY, 5);

        dc.setColor(C_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(c, 268, Graphics.FONT_SMALL, "Acquiring GPSâ€¦", CTR());
        dc.setColor(C_GREEN, Graphics.COLOR_TRANSPARENT);
        dc.drawText(c, 300, Graphics.FONT_XTINY, qualityText(), CTR());
        dc.setColor(C_EMBER, Graphics.COLOR_TRANSPARENT);
        dc.drawText(c, 336, Graphics.FONT_XTINY, "PRESS START", CTR());
    }

    private function qualityText() as String {
        var q = _recorder.accuracy;
        if (q >= Position.QUALITY_GOOD) { return "ACCURACY GOOD"; }
        if (q == Position.QUALITY_USABLE) { return "ACCURACY OK"; }
        if (q == Position.QUALITY_POOR) { return "ACCURACY POOR"; }
        return "SEARCHINGâ€¦";
    }

    // â”€â”€ 04 Â· Timer / Distance / Pace â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    private function drawTimer(dc) as Void {
        var c = cx(dc);
        ring(dc, C_EMBER, kmFrac(), true);
        pageDots(dc, 0);
        recGpsRow(dc);

        dc.setColor(C_TEXT3, Graphics.COLOR_TRANSPARENT);
        dc.drawText(c, 82, Graphics.FONT_XTINY, "ELAPSED", CTR());

        var t = formatDuration(_recorder.elapsedSec);
        var main = t;
        var suf = "";
        if (t.length() > 3) {
            main = t.substring(0, t.length() - 3);
            suf = t.substring(t.length() - 3, t.length());
        }
        var wMain = dc.getTextWidthInPixels(main, Graphics.FONT_NUMBER_HOT);
        var wSuf = (suf.length() == 0) ? 0 : dc.getTextWidthInPixels(suf, Graphics.FONT_NUMBER_MILD);
        var sx = c - (wMain + wSuf) / 2;
        dc.setColor(C_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(sx, 130, Graphics.FONT_NUMBER_HOT, main, LFT());
        if (suf.length() > 0) {
            dc.setColor(C_TEXT2, Graphics.COLOR_TRANSPARENT);
            dc.drawText(sx + wMain, 130, Graphics.FONT_NUMBER_MILD, suf, LFT());
        }

        var colL = c - 75;
        var colR = c + 75;
        dc.setColor(C_LINE, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(c, 200, c, 244);
        dc.setColor(C_TEXT3, Graphics.COLOR_TRANSPARENT);
        dc.drawText(colL, 188, Graphics.FONT_XTINY, "DIST", CTR());
        dc.drawText(colR, 188, Graphics.FONT_XTINY, "PACE", CTR());
        var km = _recorder.distanceM / 1000.0;
        dc.setColor(C_EMBER, Graphics.COLOR_TRANSPARENT);
        dc.drawText(colL, 220, Graphics.FONT_NUMBER_MILD, km.format("%.1f"), CTR());
        dc.setColor(C_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(colR, 220, Graphics.FONT_NUMBER_MILD, formatPace(), CTR());
        dc.setColor(C_TEXT2, Graphics.COLOR_TRANSPARENT);
        dc.drawText(colL, 250, Graphics.FONT_XTINY, "km", CTR());
        dc.drawText(colR, 250, Graphics.FONT_XTINY, "/km", CTR());

        heart(dc, c - 50, 338, C_RED, 1.0);
        var hr = (_recorder.heartRate > 0) ? _recorder.heartRate.format("%d") : "--";
        dc.setColor(C_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(c - 34, 338, Graphics.FONT_TINY, hr, LFT());
        dc.setColor(C_TEXT3, Graphics.COLOR_TRANSPARENT);
        dc.drawText(c + 22, 338, Graphics.FONT_XTINY, "BPM", LFT());
    }

    // â”€â”€ 05 Â· Elevation â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    private function drawElevation(dc) as Void {
        var c = cx(dc);
        ring(dc, C_EMBER2, kmFrac(), true);
        pageDots(dc, 1);

        dc.setColor(C_TEXT3, Graphics.COLOR_TRANSPARENT);
        dc.drawText(c, 70, Graphics.FONT_XTINY, "ELEVATION", CTR());

        var elev = _recorder.altitudeM.toNumber();
        var wMain = dc.getTextWidthInPixels(elev.format("%d"), Graphics.FONT_NUMBER_MEDIUM);
        var sx = c - (wMain + 18) / 2;
        dc.setColor(C_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(sx, 116, Graphics.FONT_NUMBER_MEDIUM, elev.format("%d"), LFT());
        dc.setColor(C_TEXT2, Graphics.COLOR_TRANSPARENT);
        dc.drawText(sx + wMain + 4, 124, Graphics.FONT_XTINY, "m", LFT());

        // ascent / descent / grade
        var y = 178;
        elevStat(dc, c - 78, y, C_EMBER, "+", _recorder.ascentM.toNumber().format("%d"), "ASC m");
        elevStat(dc, c, y, C_BLUE, "-", _recorder.descentM.toNumber().format("%d"), "DESC m");
        elevStat(dc, c + 78, y, C_WHITE, "", gradeText(), "GRADE");

        drawElevSparkline(dc);
    }

    private function elevStat(dc, x, y, color, arrow, value, label) as Void {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, y, Graphics.FONT_SMALL, arrow + value, CTR());
        dc.setColor(C_TEXT3, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, y + 24, Graphics.FONT_XTINY, label, CTR());
    }

    private function gradeText() as String {
        if (_recorder.distanceM < 20.0) { return "0%"; }
        var g = (_recorder.ascentM / _recorder.distanceM) * 100.0;
        return g.format("%d") + "%";
    }

    private function drawElevSparkline(dc) as Void {
        var series = _recorder.getElevSeries();
        var n = series.size();
        if (n < 2) { return; }
        var lo = series[0];
        var hi = series[0];
        for (var i = 1; i < n; i += 1) {
            if (series[i] < lo) { lo = series[i]; }
            if (series[i] > hi) { hi = series[i]; }
        }
        var range = hi - lo;
        if (range < 1.0) { range = 1.0; }
        var x0 = 70;
        var x1 = dc.getWidth() - 70;
        var yTop = 250;
        var yBot = 322;
        var span = (x1 - x0).toFloat();
        var prevX = 0;
        var prevY = 0;
        dc.setPenWidth(2);
        dc.setColor(C_EMBER2, Graphics.COLOR_TRANSPARENT);
        for (var i = 0; i < n; i += 1) {
            var px = (x0 + span * (i.toFloat() / (n - 1))).toNumber();
            var py = (yBot - (yBot - yTop) * ((series[i] - lo) / range)).toNumber();
            if (i > 0) {
                dc.drawLine(prevX, prevY, px, py);
            }
            prevX = px;
            prevY = py;
        }
        dc.setColor(C_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(prevX, prevY, 4);
        dc.setColor(C_EMBER, Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(prevX, prevY, 5);
        dc.setPenWidth(1);
    }

    // â”€â”€ 06 Â· Heart Rate â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    private function drawHeartRate(dc) as Void {
        var c = cx(dc);
        ring(dc, C_AMBER, kmFrac(), true);
        pageDots(dc, 2);

        dc.setColor(C_TEXT3, Graphics.COLOR_TRANSPARENT);
        dc.drawText(c, 70, Graphics.FONT_XTINY, "HEART RATE", CTR());

        heart(dc, c - 64, 130, C_RED, 2.0);
        var hr = (_recorder.heartRate > 0) ? _recorder.heartRate.format("%d") : "--";
        dc.setColor(C_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(c - 36, 132, Graphics.FONT_NUMBER_HOT, hr, LFT());

        dc.setColor(C_TEXT2, Graphics.COLOR_TRANSPARENT);
        dc.drawText(c, 196, Graphics.FONT_XTINY, "BPM", CTR());

        // zone bars Z1..Z5
        var zones = [C_BLUE, C_GREEN, C_AMBER, C_EMBER, C_RED];
        var cur = hrZone();
        var bw = 40;
        var totalW = bw * 5 + 4 * 6;
        var bx = c - totalW / 2;
        var by = 230;
        for (var i = 0; i < 5; i += 1) {
            var h = (i == cur) ? 22 : 12;
            dc.setColor(zones[i], Graphics.COLOR_TRANSPARENT);
            if (i == cur) {
                dc.fillRoundedRectangle(bx, by + (22 - h), bw, h, 3);
            } else {
                dc.fillRoundedRectangle(bx, by + (22 - h), bw, h, 3);
            }
            bx += bw + 6;
        }

        // avg + kcal
        dc.setColor(C_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(c - 50, 300, Graphics.FONT_SMALL,
            (_recorder.avgHeartRate > 0) ? _recorder.avgHeartRate.format("%d") : "--", CTR());
        dc.setColor(C_EMBER, Graphics.COLOR_TRANSPARENT);
        dc.drawText(c + 50, 300, Graphics.FONT_SMALL, _recorder.calories.format("%d"), CTR());
        dc.setColor(C_TEXT3, Graphics.COLOR_TRANSPARENT);
        dc.drawText(c - 50, 326, Graphics.FONT_XTINY, "AVG", CTR());
        dc.drawText(c + 50, 326, Graphics.FONT_XTINY, "KCAL", CTR());
    }

    private function hrZone() as Number {
        var hr = _recorder.heartRate;
        if (hr <= 0) { return -1; }
        if (hr < 114) { return 0; }
        if (hr < 133) { return 1; }
        if (hr < 152) { return 2; }
        if (hr < 171) { return 3; }
        return 4;
    }

    // â”€â”€ Route Profile (loaded course + you-are-here) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    private function drawRoute(dc) as Void {
        var c = cx(dc);
        var course = _recorder.course;
        ring(dc, C_EMBER, kmFrac(), true);
        pageDots(dc, 3);

        dc.setColor(C_TEXT3, Graphics.COLOR_TRANSPARENT);
        dc.drawText(c, 60, Graphics.FONT_XTINY, "ROUTE", CTR());
        dc.setColor(C_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(c, 86, Graphics.FONT_XTINY, course.name, CTR());

        var x0 = 52;
        var x1 = dc.getWidth() - 52;
        var w = x1 - x0;
        var yTop = 132;
        var yBot = 224;
        var hgt = yBot - yTop;
        var range = course.maxE - course.minE;
        if (range < 1.0) { range = 1.0; }

        var rd = _recorder.distanceM;
        if (rd > course.totalDist) { rd = course.totalDist; }
        var prog = (course.totalDist <= 0.0) ? 0.0 : (rd / course.totalDist);
        var markerX = x0 + (w * prog).toNumber();

        // filled area under the profile, travelled vs ahead
        for (var px = x0; px <= x1; px += 2) {
            var f = (px - x0).toFloat() / w;
            var e = course.elevAtFrac(f);
            var py = (yBot - hgt * ((e - course.minE) / range)).toNumber();
            dc.setColor(px <= markerX ? C_FILL_BEHIND : C_FILL_AHEAD, Graphics.COLOR_TRANSPARENT);
            dc.drawLine(px, yBot, px, py);
        }

        // crisp profile outline along the real vertices
        dc.setPenWidth(2);
        dc.setColor(C_EMBER2, Graphics.COLOR_TRANSPARENT);
        var n = course.dist.size();
        var prevX = 0;
        var prevY = 0;
        for (var i = 0; i < n; i += 1) {
            var px = x0 + (w * (course.dist[i] / course.totalDist)).toNumber();
            var py = (yBot - hgt * ((course.elev[i] - course.minE) / range)).toNumber();
            if (i > 0) { dc.drawLine(prevX, prevY, px, py); }
            prevX = px;
            prevY = py;
        }
        dc.setPenWidth(1);

        // you-are-here marker
        var curY = (yBot - hgt * ((course.elevAtFrac(prog) - course.minE) / range)).toNumber();
        dc.setColor(C_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(markerX, yTop - 6, markerX, yBot);
        dc.fillCircle(markerX, curY, 5);
        dc.setColor(C_EMBER, Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(markerX, curY, 6);

        // look-ahead readouts
        var info = course.ahead(_recorder.distanceM);
        var rem = (info["rem"] as Float) / 1000.0;
        var asc = (info["asc"] as Float).toNumber();
        dc.setColor(C_EMBER, Graphics.COLOR_TRANSPARENT);
        dc.drawText(c - 64, 256, Graphics.FONT_SMALL, rem.format("%.1f"), CTR());
        dc.setColor(C_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(c + 64, 256, Graphics.FONT_SMALL, asc.format("%d"), CTR());
        dc.setColor(C_TEXT3, Graphics.COLOR_TRANSPARENT);
        dc.drawText(c - 64, 280, Graphics.FONT_XTINY, "km TO GO", CTR());
        dc.drawText(c + 64, 280, Graphics.FONT_XTINY, "CLIMB m", CTR());

        var gain = (info["gain"] as Float).toNumber();
        if (gain > 2) {
            var gd = (info["gainDist"] as Float) / 1000.0;
            dc.setColor(C_EMBER2, Graphics.COLOR_TRANSPARENT);
            dc.drawText(c, 312, Graphics.FONT_XTINY,
                "NEXT  +" + gain.format("%d") + "m  " + gd.format("%.1f") + "km", CTR());
        } else {
            dc.setColor(C_GREEN, Graphics.COLOR_TRANSPARENT);
            dc.drawText(c, 312, Graphics.FONT_XTINY, "DESCENT TO FINISH", CTR());
        }
    }

    // â”€â”€ 08 Â· Paused â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    private function drawPaused(dc) as Void {
        var c = cx(dc);
        ring(dc, C_TEXT3, 0.68, false);

        dc.setColor(C_AMBER, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(c - 38, 52, 6, 18);
        dc.fillRectangle(c - 28, 52, 6, 18);
        dc.drawText(c - 6, 61, Graphics.FONT_XTINY, "PAUSED", LFT());

        // frozen mini stats
        miniStat(dc, c - 70, 100, formatDuration(_recorder.elapsedSec), "TIME", false);
        miniStat(dc, c, 100, (_recorder.distanceM / 1000.0).format("%.1f"), "KM", true);
        miniStat(dc, c + 70, 100, _recorder.ascentM.toNumber().format("%d"), "ASC m", false);

        // action buttons
        var labels = ["RESUME", "SAVE", "DISCARD"];
        var cols = [C_EMBER, C_GREEN, C_RED];
        var by = 168;
        for (var i = 0; i < 3; i += 1) {
            var sel = (i == pausedSel);
            var y = by + i * 56;
            if (i == 0) {
                // filled ember pill
                dc.setColor(sel ? C_EMBER : C_EMBER2, Graphics.COLOR_TRANSPARENT);
                dc.fillRoundedRectangle(c - 95, y, 190, 46, 23);
                dc.setColor(C_BG, Graphics.COLOR_TRANSPARENT);
            } else {
                dc.setColor(sel ? cols[i] : C_TRACK, Graphics.COLOR_TRANSPARENT);
                dc.drawRoundedRectangle(c - 95, y, 190, 46, 23);
                if (sel) { dc.drawRoundedRectangle(c - 94, y + 1, 188, 44, 22); }
                dc.setColor(cols[i], Graphics.COLOR_TRANSPARENT);
            }
            dc.drawText(c, y + 23, Graphics.FONT_TINY, labels[i], CTR());
        }
    }

    private function miniStat(dc, x, y, value, label, ember) as Void {
        dc.setColor(ember ? C_EMBER : C_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, y, Graphics.FONT_SMALL, value, CTR());
        dc.setColor(C_TEXT3, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, y + 22, Graphics.FONT_XTINY, label, CTR());
    }

    // â”€â”€ 09 Â· Saved Summary â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    private function drawSummary(dc) as Void {
        var c = cx(dc);
        ring(dc, C_GREEN, 1.0, true);

        dc.setColor(C_GREEN, Graphics.COLOR_TRANSPARENT);
        dc.drawText(c, 56, Graphics.FONT_XTINY, "HIKE SAVED", CTR());
        dc.setColor(C_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(c, 84, Graphics.FONT_SMALL, "Trail Recorded", CTR());

        // effort dial
        var dy = 142;
        dc.setPenWidth(5);
        dc.setColor(C_TRACK, Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(c, dy, 34);
        dc.setColor(C_GREEN, Graphics.COLOR_TRANSPARENT);
        dc.drawArc(c, dy, 34, Graphics.ARC_CLOCKWISE, 90, 90 - 360 * effortFrac());
        dc.setPenWidth(1);
        dc.setColor(C_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(c, dy - 4, Graphics.FONT_SMALL, effortGrade(), CTR());
        dc.setColor(C_TEXT3, Graphics.COLOR_TRANSPARENT);
        dc.drawText(c, dy + 16, Graphics.FONT_XTINY, "EFFORT", CTR());

        // 2x3 stat grid
        var gx = c - 70;
        var gy = 232;
        sumCell(dc, gx, gy, formatDuration(_recorder.elapsedSec), "TIME", false);
        sumCell(dc, c, gy, (_recorder.distanceM / 1000.0).format("%.1f"), "KM", true);
        sumCell(dc, c + 70, gy, _recorder.ascentM.toNumber().format("%d"), "ASCENT", false);
        sumCell(dc, gx, gy + 50, (_recorder.avgHeartRate > 0) ? _recorder.avgHeartRate.format("%d") : "--", "AVG HR", false);
        sumCell(dc, c, gy + 50, _recorder.calories.format("%d"), "KCAL", false);
        sumCell(dc, c + 70, gy + 50, _recorder.maxAltitudeM.toNumber().format("%d"), "PEAK m", false);

        // sync CTA / status
        var label = "SYNC TO PHONE";
        var col = C_EMBER;
        if (syncState == 1) {
            label = "SYNCINGâ€¦"; col = C_AMBER;
        } else if (syncState == 2) {
            label = "âœ“ SYNCED"; col = C_GREEN;
        } else if (syncState == 3) {
            label = (syncMsg.length() > 0) ? ("FAILED: " + syncMsg) : "SYNC FAILED â€” RETRY";
            col = C_RED;
        }
        dc.setColor(col, Graphics.COLOR_TRANSPARENT);
        dc.drawRoundedRectangle(c - 90, 344, 180, 30, 15);
        dc.drawText(c, 359, Graphics.FONT_XTINY, label, CTR());
    }

    private function sumCell(dc, x, y, value, label, ember) as Void {
        dc.setColor(ember ? C_EMBER : C_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, y, Graphics.FONT_TINY, value, CTR());
        dc.setColor(C_TEXT3, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, y + 18, Graphics.FONT_XTINY, label, CTR());
    }

    // simple, documented effort heuristic: distance + ascent weighting
    private function effortFrac() as Float {
        var km = _recorder.distanceM / 1000.0;
        var score = (km * 0.06) + (_recorder.ascentM / 1000.0) * 0.5;
        if (score > 1.0) { score = 1.0; }
        if (score < 0.05) { score = 0.05; }
        return score;
    }

    private function effortGrade() as String {
        var f = effortFrac();
        if (f >= 0.85) { return "A"; }
        if (f >= 0.6) { return "B"; }
        if (f >= 0.35) { return "C"; }
        return "D";
    }

    // â”€â”€ formatters â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    function formatPace() as String {
        if (_recorder.distanceM < 10.0 || _recorder.elapsedSec <= 0) {
            return "--:--";
        }
        var secPerKm = _recorder.elapsedSec / (_recorder.distanceM / 1000.0);
        var m = (secPerKm / 60).toNumber();
        var s = secPerKm.toNumber() % 60;
        return m.format("%d") + ":" + s.format("%02d");
    }

    function formatDuration(sec as Number) as String {
        var h = sec / 3600;
        var m = (sec % 3600) / 60;
        var s = sec % 60;
        if (h > 0) {
            return h.format("%d") + ":" + m.format("%02d") + ":" + s.format("%02d");
        }
        return m.format("%02d") + ":" + s.format("%02d");
    }
}

```

## source\RouteCourse.mc
```monkeyc
import Toybox.Lang;

// A loaded/planned route's elevation profile + look-ahead math.
//
// v1 is seeded with a bundled sample (loadSample). The real source is the
// Trailtether phone app pushing a planned hike (route_plans / hike_plans / GPX)
// to the watch over the Garmin Connect bridge â€” call loadCourse() with the same
// shape. Progress along the profile is driven by recorded distance for now;
// swap _indexForDist() for true GPS nearest-point projection when real
// (lat,lon) routes are loaded.
class RouteCourse {
    public var name as String;
    public var dist as Array<Float>; // cumulative metres, ascending
    public var elev as Array<Float>; // metres
    public var totalDist as Float = 0.0;
    public var minE as Float = 0.0;
    public var maxE as Float = 0.0;

    function initialize() {
        name = "";
        dist = [] as Array<Float>;
        elev = [] as Array<Float>;
    }

    function loaded() as Boolean {
        return dist.size() >= 2;
    }

    // Fed later by the phone channel: parallel cumulative-distance + elevation arrays.
    function loadCourse(courseName as String, distM as Array<Float>, elevM as Array<Float>) as Void {
        name = courseName;
        dist = distM;
        elev = elevM;
        _recompute();
    }

    function loadSample() as Void {
        var km = [0.0, 1.2, 2.4, 3.6, 4.8, 6.0, 7.2, 8.4, 9.4, 10.4, 11.4, 12.4];
        var el = [1180.0, 1240.0, 1330.0, 1410.0, 1520.0, 1610.0, 1730.0, 1850.0, 1700.0, 1560.0, 1460.0, 1400.0];
        var d = [] as Array<Float>;
        var e = [] as Array<Float>;
        for (var i = 0; i < km.size(); i += 1) {
            d.add((km[i] * 1000.0).toFloat());
            e.add(el[i].toFloat());
        }
        loadCourse("Mt. Marcy", d, e);
    }

    private function _recompute() as Void {
        if (dist.size() == 0) { return; }
        totalDist = dist[dist.size() - 1];
        minE = elev[0];
        maxE = elev[0];
        for (var i = 1; i < elev.size(); i += 1) {
            if (elev[i] < minE) { minE = elev[i]; }
            if (elev[i] > maxE) { maxE = elev[i]; }
        }
    }

    // Elevation at a 0..1 fraction of total distance (linear interpolation).
    function elevAtFrac(f as Float) as Float {
        if (f <= 0.0) { return elev[0]; }
        if (f >= 1.0) { return elev[elev.size() - 1]; }
        var d = f * totalDist;
        for (var i = 1; i < dist.size(); i += 1) {
            if (dist[i] >= d) {
                var seg = dist[i] - dist[i - 1];
                var t = (seg <= 0.0) ? 0.0 : (d - dist[i - 1]) / seg;
                return elev[i - 1] + (elev[i] - elev[i - 1]) * t;
            }
        }
        return elev[elev.size() - 1];
    }

    private function _indexForDist(rd as Float) as Number {
        for (var i = 0; i < dist.size(); i += 1) {
            if (dist[i] > rd) { return i; }
        }
        return dist.size() - 1;
    }

    // Look-ahead from current recorded distance (m):
    //   rem      â€” distance remaining to finish (m)
    //   asc      â€” total climbing still ahead (m)
    //   gain     â€” height gain to the next high point ahead (m, 0 if only descent left)
    //   gainDist â€” distance to that next high point (m)
    function ahead(recDist as Float) as Dictionary {
        var rd = recDist;
        if (rd < 0.0) { rd = 0.0; }
        if (rd > totalDist) { rd = totalDist; }
        var rem = totalDist - rd;
        var curE = elevAtFrac((totalDist <= 0.0) ? 0.0 : (rd / totalDist));
        var startI = _indexForDist(rd);

        var asc = 0.0;
        var prevE = curE;
        for (var i = startI; i < elev.size(); i += 1) {
            var de = elev[i] - prevE;
            if (de > 0.0) { asc += de; }
            prevE = elev[i];
        }

        // first local summit ahead
        var peakE = curE;
        var peakD = rd;
        var rising = false;
        for (var i = startI; i < elev.size(); i += 1) {
            if (elev[i] > peakE) {
                peakE = elev[i];
                peakD = dist[i];
                rising = true;
            } else if (rising && elev[i] < peakE - 5.0) {
                break;
            }
        }
        var gain = 0.0;
        var gainDist = 0.0;
        if (peakE > curE + 2.0) {
            gain = peakE - curE;
            gainDist = peakD - rd;
            if (gainDist < 0.0) { gainDist = 0.0; }
        }
        return { "rem" => rem, "asc" => asc, "gain" => gain, "gainDist" => gainDist };
    }
}

```

## source\RouteService.mc
```monkeyc
import Toybox.Communications;
import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;

// Pulls the device's active route from Supabase (watch-route) and loads it into
// the shared RouteCourse so the Route Profile page shows a real planned/recorded
// hike instead of the bundled sample. Cloud-pull over the phone bridge â€” no
// native Connect IQ mobile-SDK messaging needed.
class RouteService {
    static const URL = "https://xuqmdujupbmxahyhkdwl.supabase.co/functions/v1/watch-route";

    private var _course as RouteCourse;

    function initialize(course as RouteCourse) {
        _course = course;
    }

    function fetch() as Void {
        if (!System.getDeviceSettings().connectionAvailable) {
            return; // offline / no phone bridge â€” keep whatever is loaded
        }
        var options = {
            :method => Communications.HTTP_REQUEST_METHOD_POST,
            :headers => {
                "Content-Type" => Communications.REQUEST_CONTENT_TYPE_JSON,
                "apikey" => SyncService.ANON,
                "Authorization" => "Bearer " + SyncService.ANON,
                "x-device-token" => SyncService.deviceToken()
            },
            :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON
        };
        Communications.makeWebRequest(URL, {}, options, method(:onResponse));
    }

    function onResponse(code as Number, data as Dictionary?) as Void {
        if (code != 200 || data == null || data.get("ok") != true) {
            return;
        }
        var c = data.get("course");
        if (c == null || !(c instanceof Dictionary)) {
            return;
        }
        var course = c as Dictionary;
        var name = course.get("name");
        var dist = course.get("dist");
        var elev = course.get("elev");
        if (!(dist instanceof Array) || !(elev instanceof Array)) {
            return;
        }
        var d = toFloatArray(dist as Array);
        var e = toFloatArray(elev as Array);
        if (d.size() >= 2 && d.size() == e.size()) {
            _course.loadCourse((name instanceof String) ? name : "Route", d, e);
            WatchUi.requestUpdate();
        }
    }

    private function toFloatArray(src as Array) as Array<Float> {
        var out = [] as Array<Float>;
        for (var i = 0; i < src.size(); i += 1) {
            var v = src[i];
            if (v instanceof Number || v instanceof Float || v instanceof Long || v instanceof Double) {
                out.add(v.toFloat());
            }
        }
        return out;
    }
}

```

## source\SyncService.mc
```monkeyc
import Toybox.Communications;
import Toybox.Lang;
import Toybox.Application;
import Toybox.System;

// Uploads a finished hike to Supabase via the watch-ingest edge function.
// On the real Instinct this HTTP rides the phone's Garmin Connect Bluetooth
// bridge; in the simulator it uses the host's internet directly.
//
// Auth: the public anon key satisfies the function's verify_jwt; the USER is
// resolved server-side from the x-device-token header. The anon key is public
// (it already ships in the Flutter app + website), so embedding it is fine.
class SyncService {
    static const URL = "https://xuqmdujupbmxahyhkdwl.supabase.co/functions/v1/watch-ingest";
    static const ANON = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inh1cW1kdWp1cGJteGFoeWhrZHdsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzcyMzYyODYsImV4cCI6MjA5MjgxMjI4Nn0.aUfLfzgW25Ozsl9EMkDfmelBzxlCOWjGcatQQ-eh2Jo";
    // Test pairing token. Later: written once during a pair flow + read from Storage.
    static const DEFAULT_TOKEN = "ttw_b10f99a85df649d1849e08428519ba2b";

    private var _cb as Method?;

    function initialize() {}

    // Paired token from Garmin Connect app settings (mint_watch_token); falls
    // back to the built-in test token so the simulator still works unpaired.
    static function deviceToken() as String {
        var p = null;
        try {
            p = Application.Properties.getValue("pairingToken");
        } catch (e) {
            p = null;
        }
        if (p instanceof String && (p as String).length() > 0) {
            return p as String;
        }
        return DEFAULT_TOKEN;
    }

    // cb is invoked as cb(ok as Boolean, msg as String)
    function upload(recorder as HikeRecorder, cb as Method) as Void {
        _cb = cb;
        // No phone/Bluetooth bridge -> the request would queue forever. Fail fast
        // so the UI can show a clear state (and a real watch can retry later).
        if (!System.getDeviceSettings().connectionAvailable) {
            cb.invoke(false, "No phone");
            return;
        }
        var body = {
            "name" => "Hike (Watch)",
            "distance_km" => recorder.distanceM / 1000.0,
            "ascent_m" => recorder.ascentM.toNumber(),
            "descent_m" => recorder.descentM.toNumber(),
            "duration_seconds" => recorder.elapsedSec,
            "activity_type" => "hike",
            "points" => buildPoints(recorder.getPoints(), 250)
        };
        var options = {
            :method => Communications.HTTP_REQUEST_METHOD_POST,
            :headers => {
                "Content-Type" => Communications.REQUEST_CONTENT_TYPE_JSON,
                "apikey" => ANON,
                "Authorization" => "Bearer " + ANON,
                "x-device-token" => deviceToken()
            },
            :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON
        };
        Communications.makeWebRequest(URL, body, options, method(:onResponse));
    }

    function onResponse(code as Number, data as Dictionary?) as Void {
        if (_cb == null) { return; }
        if (code == 200 && data != null && data.get("ok") == true) {
            _cb.invoke(true, "Synced");
        } else {
            _cb.invoke(false, "Error " + code.toString());
        }
    }

    // Map recorder points {lat,lon,alt,spd,t} -> hike_history {lat,lon,alt,ts,spd,acc},
    // downsampling to at most maxN points to keep the request small.
    private function buildPoints(src as Array<Dictionary>, maxN as Number) as Array<Dictionary> {
        var out = [] as Array<Dictionary>;
        var n = src.size();
        if (n == 0) { return out; }
        var step = 1;
        if (n > maxN) {
            step = (n / maxN).toNumber();
            if (step < 1) { step = 1; }
        }
        var i = 0;
        while (i < n) {
            var p = src[i];
            out.add({
                "lat" => p["lat"], "lon" => p["lon"], "alt" => p["alt"],
                "ts" => p["t"], "spd" => p["spd"], "acc" => 0
            });
            i += step;
        }
        return out;
    }
}

```

## source\TrailtetherWatchApp.mc
```monkeyc
import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

class TrailtetherWatchApp extends Application.AppBase {
    private var _recorder as HikeRecorder?;
    private var _route as RouteService?;

    function initialize() {
        AppBase.initialize();
    }

    function refreshRoute() as Void {
        if (_route != null) {
            _route.fetch();
        }
    }

    function onStart(state as Dictionary?) as Void {
    }

    function onStop(state as Dictionary?) as Void {
        if (_recorder != null &&
            (_recorder.state == STATE_RECORDING || _recorder.state == STATE_PAUSED)) {
            _recorder.save();
        }
    }

    function getInitialView() as [Views] or [Views, InputDelegates] {
        _recorder = new HikeRecorder();
        _route = new RouteService(_recorder.course);
        var view = new HikeView(_recorder);
        var delegate = new HikeDelegate(_recorder, view, _route);
        _route.fetch(); // pull the real route now (no-op if offline)
        return [view, delegate];
    }
}

```

## resources\drawables\drawables.xml
```xml
<drawables>
    <bitmap id="LauncherIcon" filename="launcher_icon.png"/>
    <bitmap id="Logo" filename="logo.png"/>
</drawables>

```

## resources\settings\properties.xml
```xml
<properties>
    <!-- Device pairing token, set by the user in Garmin Connect Mobile after the
         Trailtether app issues one via mint_watch_token(). Empty = use built-in
         test default (sim). -->
    <property id="pairingToken" type="string"></property>
</properties>

```

## resources\settings\settings.xml
```xml
<settings>
    <setting propertyKey="@Properties.pairingToken" title="@Strings.SettingPairingToken">
        <settingConfig type="alphaNumeric" maxLength="60" />
    </setting>
</settings>

```

## resources\strings\strings.xml
```xml
<strings>
    <string id="AppName">Trailtether</string>
    <string id="SettingPairingToken">Pairing Token</string>
</strings>

```

