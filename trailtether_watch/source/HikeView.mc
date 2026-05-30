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
// "Green" status indicator was the brand green #4cc38a — user preferred amber,
// so the alias now resolves to the same hex as C_AMBER. HR zone bar uses C_TEAL
// (below) to keep its cold→warm gradient legible without green.
const C_GREEN = 0xF2A93B;
const C_AMBER = 0xF2A93B;
const C_BLUE = 0x5AA1D6;
const C_TEAL = 0x5BD4C8;
const C_TRACK = 0x232A35;
const C_LINE = 0x2A323D;
const C_FILL_BEHIND = 0x2A2018; // warm-dark area fill (travelled)
const C_FILL_AHEAD = 0x5A3016;  // ember-dark area fill (upcoming)
// Pre-composited tt-ember-dim (rgba(255,106,44,0.14) over true black) — used
// as the highlighted-row background on the activity picker.
const C_EMBER_DIM = 0x331812;
const C_PHONE_GREEN = 0x4CC38A; // alias for the phone glyph stroke on Sync

class HikeView extends WatchUi.View {
    public var page as Number = 0;
    public var pausedSel as Number = 0; // 0 RESUME, 1 SAVE, 2 DISCARD
    public var syncState as Number = 0; // 0 idle, 1 syncing, 2 done, 3 error
    public var syncMsg as String = "";
    public var syncProgress as Float = 0.0; // 0..1 — animated during STATE_SYNCING
    // Route picker state — owned by the view, populated by the delegate via the
    // RouteService callbacks. routeList includes a synthetic "None" entry at idx 0.
    public var routeList as Array<Dictionary> = [{ "id" => "", "name" => "None" }] as Array<Dictionary>;
    public var routePickerIdx as Number = 0;
    public var routeListLoading as Boolean = false;
    public var routeListError as String = "";
    public var routeLoadingId as String = ""; // id currently being fetched (for spinner)
    private var _recorder as HikeRecorder;
    private var _timer as Timer.Timer?;
    private var _blink as Boolean = true;
    private var _sweep as Number = 0; // 0..11 — GPS Acquire / Sync animation tick
    private var _logo as WatchUi.BitmapResource?;     // 128px hero logo
    private var _logoSm as WatchUi.BitmapResource?;   // 28px brand mark
    private var _logoMd as WatchUi.BitmapResource?;   // 56px mid (Summary)

    function initialize(recorder as HikeRecorder) {
        View.initialize();
        _recorder = recorder;
    }

    function onShow() as Void {
        if (_logo == null) {
            _logo = WatchUi.loadResource(Rez.Drawables.Logo) as WatchUi.BitmapResource;
            _logoSm = WatchUi.loadResource(Rez.Drawables.LogoSmall) as WatchUi.BitmapResource;
            _logoMd = WatchUi.loadResource(Rez.Drawables.LogoMid) as WatchUi.BitmapResource;
        }
        if (_timer == null) {
            _timer = new Timer.Timer();
        }
        // 250 ms tick so the GPS sweep + sync packet animation read as motion;
        // the recorder + REC-dot blink only advance every 4 ticks (1 Hz).
        _timer.start(method(:onTick), 250, true);
    }

    function onHide() as Void {
        if (_timer != null) {
            _timer.stop();
        }
    }

    function onTick() as Void {
        _sweep = (_sweep + 1) % 12;
        if (_sweep % 4 == 0) {
            _recorder.tick();
            _blink = !_blink;
        }
        // While the upload is in-flight, ease the bar toward 95% — the callback
        // will snap it to 100% on success.
        if (_recorder.state == STATE_SYNCING && syncProgress < 0.95) {
            syncProgress += 0.05;
        }
        // auto-advance from acquire once we have a usable fix
        if (_recorder.state == STATE_ACQUIRING &&
            _recorder.accuracy >= Position.QUALITY_GOOD &&
            _sweep % 4 == 0) {
            _recorder.startRecording();
        }
        WatchUi.requestUpdate();
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        dc.setColor(C_WHITE, C_BG);
        dc.clear();
        drawStage(dc);
        var s = _recorder.state;
        if (s == STATE_PICKING) {
            drawPicker(dc);
        } else if (s == STATE_ROUTE_PICKING) {
            drawRoutePicker(dc);
        } else if (s == STATE_IDLE || s == STATE_ACQUIRING) {
            drawAcquire(dc);
        } else if (s == STATE_PAUSED) {
            drawPaused(dc);
        } else if (s == STATE_SUMMARY) {
            drawSummary(dc);
        } else if (s == STATE_SYNCING) {
            drawSyncing(dc);
        } else {
            if (page == 1) {
                drawElevation(dc);
            } else if (page == 2) {
                drawHeartRate(dc);
            } else if (page == 3) {
                drawMap(dc);
            } else if (page == 4) {
                drawRoute(dc);
            } else {
                drawTimer(dc);
            }
        }
    }

    // Live data pages: Timer, Elevation, HR, Map (always) + Route Profile (only
    // when a planned course is loaded).
    function pageCount() as Number {
        return (_recorder.course != null && _recorder.course.loaded()) ? 5 : 4;
    }

    // ── shared helpers ─────────────────────────────────────────────
    private function cx(dc) { return dc.getWidth() / 2; }
    private function cy(dc) { return dc.getHeight() / 2; }
    private function CTR() { return Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER; }
    private function LFT() { return Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER; }

    // Scale a 24-bit color's R/G/B independently by factor (0..1). Used to fake
    // alpha on Garmin AMOLED where the Graphics API has no real transparency.
    private function dimColor(color as Number, factor as Float) as Number {
        if (factor <= 0.0) { return 0; }
        if (factor >= 1.0) { return color; }
        var r = ((color >> 16) & 0xFF);
        var g = ((color >> 8) & 0xFF);
        var b = (color & 0xFF);
        var nr = (r * factor).toNumber();
        var ng = (g * factor).toNumber();
        var nb = (b * factor).toNumber();
        return (nr << 16) | (ng << 8) | nb;
    }

    // Smooth 0..1 sine where phaseFrac is 0..1 over the cycle. Useful for
    // pulse animations driven by _sweep (12-frame cycle at 4 Hz = 3 s period).
    private function pulse(phaseFrac as Float) as Float {
        var s = Math.sin(phaseFrac * 2.0 * Math.PI);
        return 0.5 + 0.5 * s;
    }

    private function tickPhase() as Float {
        return _sweep.toFloat() / 12.0;
    }

    // 3-pass faux drop-shadow halo around a center point. Outer rings are
    // dimmer so the eye reads them as glow rather than a hard ring.
    private function drawGlow(dc, x, y, color, baseR) as Void {
        var passes = [[baseR + 8, 0.18], [baseR + 5, 0.32], [baseR + 2, 0.55]];
        for (var i = 0; i < passes.size(); i += 1) {
            dc.setColor(dimColor(color, passes[i][1]), Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(x, y, passes[i][0]);
        }
    }

    // Glowing accent dot — solid center + halo for pulsing indicators.
    private function drawHaloDot(dc, x, y, color, r) as Void {
        drawGlow(dc, x, y, color, r);
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x, y, r);
    }

    // Rounded-pill status chip: optional left dot + caps mono text + thin outline.
    private function drawStatusPill(dc, cxp, y, text as String, dotColor as Number, textColor as Number, borderColor as Number) as Void {
        var pad = 10;
        var dotW = (dotColor != 0) ? 9 : 0;
        var tw = dc.getTextWidthInPixels(text, Graphics.FONT_XTINY);
        var w = tw + dotW + pad * 2;
        var h = 22;
        var rx = cxp - w / 2;
        var ry = y - h / 2;
        // Outline (no fill — AMOLED reads the black inside as part of the bezel)
        dc.setColor(borderColor, Graphics.COLOR_TRANSPARENT);
        dc.drawRoundedRectangle(rx, ry, w, h, h / 2);
        if (dotColor != 0) {
            drawHaloDot(dc, rx + pad + 3, y, dotColor, 3);
        }
        dc.setColor(textColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(rx + pad + dotW, y, Graphics.FONT_XTINY, text, LFT());
    }

    // TT branded backdrop — faint topo arcs + ember corner pool + a few stars.
    // Called at the top of every screen so the round AMOLED has the same dark
    // "world" the design renders against. All draws use very dim colors so they
    // sit BEHIND content visually without competing for attention.
    private function drawStage(dc as Graphics.Dc) as Void {
        var w = dc.getWidth();

        // Ember corner pool in the top-right — 3 concentric circles from
        // dim-to-brightest to fake a radial glow. The center sits outside the
        // visible disk, so only a crescent shows on the round face.
        var ex = w + 30;
        var ey = -30;
        var pool = [[150, 0x0C0602], [110, 0x1A0C04], [70, 0x2E1408]];
        for (var i = 0; i < pool.size(); i += 1) {
            dc.setColor(pool[i][1], Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(ex, ey, pool[i][0]);
        }
        // Second, smaller pool bottom-left to balance.
        var px = -20;
        var py = w + 20;
        var pool2 = [[120, 0x080402], [80, 0x12080A]];
        for (var i = 0; i < pool2.size(); i += 1) {
            dc.setColor(pool2[i][1], Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(px, py, pool2[i][0]);
        }

        // Faint topographic contour lines crossing the screen — drawn as
        // multi-segment sin waves so they read as gentle curves on the round.
        var arcs = [
            [310, 16, 240, 0x16202B],
            [275, 22, 280, 0x101820],
            [340, 14, 220, 0x101820],
            [240, 18, 260, 0x0E141B]
        ];
        for (var i = 0; i < arcs.size(); i += 1) {
            drawTopoArc(dc, arcs[i][0], arcs[i][1], arcs[i][2], arcs[i][3]);
        }

        // Stars (sparse, upper third)
        var stars = [[64, 50], [124, 32], [196, 64], [248, 26], [322, 58], [82, 96], [276, 110]];
        dc.setColor(0x2A3038, Graphics.COLOR_TRANSPARENT);
        for (var i = 0; i < stars.size(); i += 1) {
            dc.fillCircle(stars[i][0], stars[i][1], 1);
        }
    }

    // One topographic arc: sin wave of given amplitude / wavelength.
    private function drawTopoArc(dc, y0, amp, period, color) as Void {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        var w = dc.getWidth();
        var step = 10;
        var prevX = 0;
        var prevY = y0;
        for (var x = step; x <= w; x += step) {
            var py = (y0 + amp * Math.sin((x.toFloat() / period) * 2.0 * Math.PI)).toNumber();
            dc.drawLine(prevX, prevY, x, py);
            prevX = x;
            prevY = py;
        }
    }

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
        // REC dot pulses smoothly via sine, brightest at center of cycle.
        var recBrightness = 0.4 + 0.6 * pulse(tickPhase());
        var recColor = dimColor(C_RED, recBrightness);
        drawHaloDot(dc, c - 58, 48, recColor, 3);
        dc.setColor(C_RED, Graphics.COLOR_TRANSPARENT);
        dc.drawText(c - 50, 48, Graphics.FONT_XTINY, "REC", LFT());
        drawHaloDot(dc, c + 18, 48, C_GREEN, 3);
        dc.setColor(C_GREEN, Graphics.COLOR_TRANSPARENT);
        dc.drawText(c + 26, 48, Graphics.FONT_XTINY, "GPS", LFT());
    }

    // ── READY (branded) vs 03 · GPS Acquire ───────────────────────
    private function drawAcquire(dc) as Void {
        if (_recorder.state == STATE_ACQUIRING) {
            drawGpsAcquire(dc);
        } else {
            drawReady(dc);
        }
    }

    // Branded start screen — real Trailtether logo, wordmark, START prompt.
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
        dc.drawText(c, 321, Graphics.FONT_XTINY, "▶  START HIKE", CTR());
    }

    private function drawGpsAcquire(dc) as Void {
        var c = cx(dc);
        ring(dc, C_GREEN, 0.72, false);

        dc.setColor(C_TEXT3, Graphics.COLOR_TRANSPARENT);
        dc.drawText(c, 74, Graphics.FONT_XTINY, _recorder.activityName().toUpper(), CTR());

        var midY = 165;

        // Rotating sweep wedge — 60° pie-slice that rotates clockwise around the
        // satellite cluster. _sweep is 0..11 (4 Hz), so it advances 30° per tick.
        drawSweepWedge(dc, c, midY, 60, _sweep * 30);

        // concentric satellite rings + center dot (dimmed for a faint orbit look)
        dc.setColor(dimColor(C_GREEN, 0.55), Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(c, midY, 60);
        dc.setColor(dimColor(C_GREEN, 0.4), Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(c, midY, 40);
        dc.drawCircle(c, midY, 20);

        // Satellites pulse smoothly on staggered phases so the eye reads the
        // group as "listening" rather than blinking on/off.
        var sats = [[c - 35, midY - 35], [c + 38, midY - 22], [c + 22, midY + 34], [c - 28, midY + 28]];
        for (var i = 0; i < sats.size(); i += 1) {
            var phase = (_sweep + i * 3) % 12;
            var b = 0.35 + 0.65 * pulse(phase.toFloat() / 12.0);
            drawHaloDot(dc, sats[i][0], sats[i][1], dimColor(C_GREEN, b), 3);
        }
        // Center fix
        drawHaloDot(dc, c, midY, C_WHITE, 4);

        dc.setColor(C_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(c, 268, Graphics.FONT_SMALL, "Acquiring GPS…", CTR());
        // Accuracy as a status pill (matches the brand chrome on the other screens)
        drawStatusPill(dc, c, 300, qualityText(), C_GREEN, C_GREEN, dimColor(C_GREEN, 0.5));
        dc.setColor(C_EMBER, Graphics.COLOR_TRANSPARENT);
        dc.drawText(c, 326, Graphics.FONT_XTINY, "PRESS START", CTR());
    }

    private function qualityText() as String {
        var q = _recorder.accuracy;
        if (q >= Position.QUALITY_GOOD) { return "ACCURACY GOOD"; }
        if (q == Position.QUALITY_USABLE) { return "ACCURACY OK"; }
        if (q == Position.QUALITY_POOR) { return "ACCURACY POOR"; }
        return "SEARCHING…";
    }

    // ── 04 · Timer / Distance / Pace ──────────────────────────────
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
        var z = hrZone();
        var bpmFoot = (z >= 0) ? "BPM · Z" + (z + 1).format("%d") : "BPM";
        dc.drawText(c + 22, 338, Graphics.FONT_XTINY, bpmFoot, LFT());
    }

    // ── 05 · Elevation ────────────────────────────────────────────
    private function drawElevation(dc) as Void {
        var c = cx(dc);
        ring(dc, C_EMBER2, kmFrac(), true);
        pageDots(dc, 1);

        dc.setColor(C_TEXT3, Graphics.COLOR_TRANSPARENT);
        dc.drawText(c, 70, Graphics.FONT_XTINY, "ELEVATION", CTR());

        var elev = _recorder.altitudeM.toNumber();
        var wMain = dc.getTextWidthInPixels(elev.format("%d"), Graphics.FONT_NUMBER_HOT);
        var sx = c - (wMain + 18) / 2;
        dc.setColor(C_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(sx, 116, Graphics.FONT_NUMBER_HOT, elev.format("%d"), LFT());
        dc.setColor(C_TEXT2, Graphics.COLOR_TRANSPARENT);
        dc.drawText(sx + wMain + 4, 134, Graphics.FONT_XTINY, "m", LFT());

        // ascent / descent / grade with thin dividers between columns
        var y = 178;
        elevStat(dc, c - 78, y, C_EMBER, "+", _recorder.ascentM.toNumber().format("%d"), "ASC m");
        elevStat(dc, c, y, C_BLUE, "-", _recorder.descentM.toNumber().format("%d"), "DESC m");
        elevStat(dc, c + 78, y, C_WHITE, "", gradeText(), "GRADE");
        dc.setColor(C_LINE, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(c - 39, y - 8, c - 39, y + 20);
        dc.drawLine(c + 39, y - 8, c + 39, y + 20);

        drawElevSparkline(dc);

        // Next-summit hint (matches design "NEXT: SUMMIT +Δm · Xkm") when a
        // course is loaded; otherwise omit.
        var crs = _recorder.course;
        if (crs != null && crs.loaded()) {
            var info = crs.ahead(_recorder.distanceM);
            var gain = (info["gain"] as Float).toNumber();
            if (gain > 2) {
                var km = (info["gainDist"] as Float) / 1000.0;
                dc.setColor(C_EMBER2, Graphics.COLOR_TRANSPARENT);
                dc.drawText(c, 340, Graphics.FONT_XTINY,
                    "NEXT  +" + gain.format("%d") + "m  " + km.format("%.1f") + "km", CTR());
            }
        }
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
        drawGlow(dc, prevX, prevY, C_EMBER, 5);
        dc.setColor(C_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(prevX, prevY, 4);
        dc.setColor(C_EMBER, Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(prevX, prevY, 5);
        dc.setPenWidth(1);
    }

    // ── 06 · Heart Rate ───────────────────────────────────────────
    private function drawHeartRate(dc) as Void {
        var c = cx(dc);
        ring(dc, C_AMBER, kmFrac(), true);
        pageDots(dc, 2);

        dc.setColor(C_TEXT3, Graphics.COLOR_TRANSPARENT);
        dc.drawText(c, 70, Graphics.FONT_XTINY, "HEART RATE", CTR());

        // Heart pulses smoothly — brighter at peak, dim at trough
        var hrPulse = 0.5 + 0.5 * pulse(tickPhase());
        // Faint halo behind the heart
        drawGlow(dc, c - 64, 130, C_RED, 10);
        heart(dc, c - 64, 130, dimColor(C_RED, 0.6 + 0.4 * hrPulse), 2.0);
        var hr = (_recorder.heartRate > 0) ? _recorder.heartRate.format("%d") : "--";
        dc.setColor(C_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(c - 36, 132, Graphics.FONT_NUMBER_HOT, hr, LFT());

        // Cold→warm gradient stays legible by stepping blue → teal → amber → ember → red.
        var zones = [C_BLUE, C_TEAL, C_AMBER, C_EMBER, C_RED];
        var zoneNames = ["RECOVERY", "ENDURANCE", "AEROBIC", "THRESHOLD", "MAX"];
        var zoneLabels = ["Z1", "Z2", "Z3", "Z4", "Z5"];
        var cur = hrZone();

        // BPM + ZONE N · NAME descriptor
        dc.setColor(C_TEXT2, Graphics.COLOR_TRANSPARENT);
        var bpmCaption = "BPM";
        if (cur >= 0) {
            bpmCaption = "BPM · ZONE " + (cur + 1).format("%d") + " · " + zoneNames[cur];
        }
        dc.drawText(c, 196, Graphics.FONT_XTINY, bpmCaption, CTR());

        // zone bars Z1..Z5 with letter labels underneath
        var bw = 40;
        var totalW = bw * 5 + 4 * 6;
        var bx = c - totalW / 2;
        var by = 230;
        for (var i = 0; i < 5; i += 1) {
            var h = (i == cur) ? 22 : 12;
            var top = by + (22 - h);
            if (i == cur) {
                // Soft halo around the active bar — two outer fills at decreasing brightness
                dc.setColor(dimColor(zones[i], 0.2), Graphics.COLOR_TRANSPARENT);
                dc.fillRoundedRectangle(bx - 3, top - 3, bw + 6, h + 6, 5);
                dc.setColor(dimColor(zones[i], 0.45), Graphics.COLOR_TRANSPARENT);
                dc.fillRoundedRectangle(bx - 1, top - 1, bw + 2, h + 2, 4);
            } else {
                dc.setColor(dimColor(zones[i], 0.55), Graphics.COLOR_TRANSPARENT);
            }
            dc.setColor(zones[i], Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(bx, top, bw, h, 3);
            // letter label
            dc.setColor(i == cur ? zones[i] : C_TEXT3, Graphics.COLOR_TRANSPARENT);
            dc.drawText(bx + bw / 2, by + 32, Graphics.FONT_XTINY, zoneLabels[i], CTR());
            bx += bw + 6;
        }

        // avg + kcal with divider — tighter font keeps the value+label pair
        // inside one safe band above the bottom curve, no overlap.
        dc.setColor(C_LINE, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(c, 290, c, 322);
        dc.setColor(C_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(c - 50, 298, Graphics.FONT_TINY,
            (_recorder.avgHeartRate > 0) ? _recorder.avgHeartRate.format("%d") : "--", CTR());
        dc.setColor(C_EMBER, Graphics.COLOR_TRANSPARENT);
        dc.drawText(c + 50, 298, Graphics.FONT_TINY, _recorder.calories.format("%d"), CTR());
        dc.setColor(C_TEXT3, Graphics.COLOR_TRANSPARENT);
        dc.drawText(c - 50, 318, Graphics.FONT_XTINY, "AVG BPM", CTR());
        dc.drawText(c + 50, 318, Graphics.FONT_XTINY, "KCAL", CTR());
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

    // ── 07 · Live Track Map ───────────────────────────────────────
    // Equirectangular-projects the recorder's downsampled points (and the
    // planned route, if loaded) into a centred viewport. Auto-fits the shared
    // bounding box so both overlay at the same scale. When the live position
    // drifts >50m from the planned route, an amber OFF ROUTE pill appears.
    private function drawMap(dc as Graphics.Dc) as Void {
        var c = cx(dc);
        pageDots(dc, 3);

        var course = _recorder.course;
        var hasRoute = (course != null) && course.hasGeo();
        var pillLabel = hasRoute ? ("ROUTE · " + course.name.toUpper()) : "TOPO · LIVE TRACK";
        drawStatusPill(dc, c, 50, pillLabel, C_EMBER, C_EMBER, dimColor(C_EMBER, 0.45));

        // Map viewport bounds
        var mapTop = 78;
        var mapBot = 308;
        var mapH = mapBot - mapTop;
        var mapW = 260;
        var mapL = c - mapW / 2;
        var mapR = c + mapW / 2;
        var mapCy = (mapTop + mapBot) / 2;

        drawMapBackground(dc, mapL, mapTop, mapR, mapBot);

        // ▲ N compass indicator
        dc.setColor(C_EMBER, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon([[c - 5, mapTop + 18], [c + 5, mapTop + 18], [c, mapTop + 8]]);
        dc.setColor(C_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(c, mapTop + 26, Graphics.FONT_XTINY, "N", CTR());

        var pts = _recorder.getMapPoints();
        var nLive = pts.size();

        // Bounding box across live track + route (if loaded)
        var hasAnyPoint = false;
        var minLat = 0.0;
        var maxLat = 0.0;
        var minLon = 0.0;
        var maxLon = 0.0;
        if (nLive > 0) {
            minLat = pts[0][0]; maxLat = pts[0][0];
            minLon = pts[0][1]; maxLon = pts[0][1];
            hasAnyPoint = true;
            for (var i = 1; i < nLive; i += 1) {
                var la = pts[i][0]; var lo = pts[i][1];
                if (la < minLat) { minLat = la; } if (la > maxLat) { maxLat = la; }
                if (lo < minLon) { minLon = lo; } if (lo > maxLon) { maxLon = lo; }
            }
        }
        if (hasRoute) {
            var rN = course.lat.size();
            if (!hasAnyPoint && rN > 0) {
                minLat = course.lat[0]; maxLat = course.lat[0];
                minLon = course.lon[0]; maxLon = course.lon[0];
                hasAnyPoint = true;
            }
            for (var i = 0; i < rN; i += 1) {
                var la = course.lat[i]; var lo = course.lon[i];
                if (la < minLat) { minLat = la; } if (la > maxLat) { maxLat = la; }
                if (lo < minLon) { minLon = lo; } if (lo > maxLon) { maxLon = lo; }
            }
        }

        if (!hasAnyPoint || (nLive < 2 && !hasRoute)) {
            // Nothing meaningful to project — show the pulsing centred chevron
            var emptyPulse = 0.5 + 0.5 * pulse(tickPhase());
            drawGlow(dc, c, mapCy, dimColor(C_EMBER, 0.5 + 0.5 * emptyPulse), 12);
            dc.setColor(C_EMBER, Graphics.COLOR_TRANSPARENT);
            dc.fillPolygon([[c, mapCy - 10], [c + 8, mapCy + 8], [c, mapCy + 4], [c - 8, mapCy + 8]]);
            dc.setColor(C_TEXT3, Graphics.COLOR_TRANSPARENT);
            dc.drawText(c, mapBot + 12, Graphics.FONT_XTINY,
                hasRoute ? "ROUTE READY — START MOVING" : "ACQUIRING TRACK…", CTR());
            return;
        }

        var midLat = (minLat + maxLat) / 2.0;
        var lonFactor = Math.cos(midLat * Math.PI / 180.0);
        var spanLat = maxLat - minLat;
        var spanLon = (maxLon - minLon) * lonFactor;
        if (spanLat < 0.000001) { spanLat = 0.000001; }
        if (spanLon < 0.000001) { spanLon = 0.000001; }

        var pad = 18;
        var availW = mapW - 2 * pad;
        var availH = mapH - 2 * pad;
        var sxF = availW.toFloat() / spanLon;
        var syF = availH.toFloat() / spanLat;
        var s = (sxF < syF) ? sxF : syF;
        var trackW = spanLon * s;
        var trackH = spanLat * s;
        var ox = mapL + (mapW - trackW) / 2;
        var oy = mapTop + (mapH - trackH) / 2;

        // Project planned route first (drawn underneath the live track)
        if (hasRoute) {
            var rN = course.lat.size();
            var rxs = [] as Array<Number>;
            var rys = [] as Array<Number>;
            for (var i = 0; i < rN; i += 1) {
                var pxF = ox + ((course.lon[i] - minLon) * lonFactor) * s;
                var pyF = oy + (maxLat - course.lat[i]) * s;
                rxs.add(pxF.toNumber());
                rys.add(pyF.toNumber());
            }
            // Dim amber outline so it reads as "the plan" not "where I am"
            dc.setPenWidth(3);
            dc.setColor(dimColor(C_AMBER, 0.35), Graphics.COLOR_TRANSPARENT);
            for (var i = 1; i < rN; i += 1) {
                dc.drawLine(rxs[i - 1], rys[i - 1], rxs[i], rys[i]);
            }
            dc.setPenWidth(1);
            dc.setColor(dimColor(C_AMBER, 0.85), Graphics.COLOR_TRANSPARENT);
            for (var i = 1; i < rN; i += 1) {
                dc.drawLine(rxs[i - 1], rys[i - 1], rxs[i], rys[i]);
            }
            // Start + finish flags
            dc.setColor(C_AMBER, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(rxs[0], rys[0], 3);
            dc.fillCircle(rxs[rN - 1], rys[rN - 1], 3);
        }

        // Project live track + draw glow + chevron (skip if just 1 point)
        if (nLive >= 1) {
            var xs = [] as Array<Number>;
            var ys = [] as Array<Number>;
            for (var i = 0; i < nLive; i += 1) {
                var pxF = ox + ((pts[i][1] - minLon) * lonFactor) * s;
                var pyF = oy + (maxLat - pts[i][0]) * s;
                xs.add(pxF.toNumber());
                ys.add(pyF.toNumber());
            }
            if (nLive >= 2) {
                dc.setPenWidth(5);
                dc.setColor(dimColor(C_EMBER, 0.3), Graphics.COLOR_TRANSPARENT);
                for (var i = 1; i < nLive; i += 1) {
                    dc.drawLine(xs[i - 1], ys[i - 1], xs[i], ys[i]);
                }
                dc.setPenWidth(2);
                dc.setColor(C_EMBER2, Graphics.COLOR_TRANSPARENT);
                for (var i = 1; i < nLive; i += 1) {
                    dc.drawLine(xs[i - 1], ys[i - 1], xs[i], ys[i]);
                }
                dc.setPenWidth(1);
            }
            // You-are-here chevron at the latest point
            var lastX = xs[nLive - 1];
            var lastY = ys[nLive - 1];
            var chevronPulse = 0.5 + 0.5 * pulse(tickPhase());
            drawGlow(dc, lastX, lastY, dimColor(C_EMBER, 0.4 + 0.5 * chevronPulse), 8);
            dc.setColor(C_EMBER, Graphics.COLOR_TRANSPARENT);
            dc.fillPolygon([[lastX, lastY - 9], [lastX + 7, lastY + 6], [lastX, lastY + 3], [lastX - 7, lastY + 6]]);

            // Off-route check — only meaningful when a planned route is loaded
            if (hasRoute && nLive >= 1) {
                var curLat = pts[nLive - 1][0];
                var curLon = pts[nLive - 1][1];
                var offM = course.nearestRouteDistM(curLat, curLon);
                if (offM > 50.0) {
                    drawStatusPill(dc, c, mapTop + 50, "OFF ROUTE · " + offM.toNumber().format("%d") + "m",
                        C_AMBER, C_AMBER, dimColor(C_AMBER, 0.5));
                }
            }
        }

        // Bottom readout
        var km = _recorder.distanceM / 1000.0;
        dc.setColor(C_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(c, mapBot + 16, Graphics.FONT_TINY, km.format("%.2f") + " km", CTR());
    }

    // Faint ember contour arcs inside the map viewport — concentrated topo
    // wallpaper. Cheap to redraw per frame; static lines, no animation.
    private function drawMapBackground(dc, l, t, r, b) as Void {
        var w = (r - l).toFloat();
        var h = (b - t).toFloat();
        dc.setColor(0x331812, Graphics.COLOR_TRANSPARENT);
        var prevX = l;
        var prevY = (t + h * 0.32).toNumber();
        for (var x = l + 12; x <= r; x += 12) {
            var f = (x - l).toFloat() / w;
            var py = (t + h * (0.32 + 0.08 * Math.sin(f * 4.0))).toNumber();
            dc.drawLine(prevX, prevY, x, py);
            prevX = x;
            prevY = py;
        }
        dc.setColor(0x2A1408, Graphics.COLOR_TRANSPARENT);
        prevX = l;
        prevY = (t + h * 0.68).toNumber();
        for (var x = l + 12; x <= r; x += 12) {
            var f = (x - l).toFloat() / w;
            var py = (t + h * (0.68 + 0.07 * Math.sin(f * 5.0 + 1.0))).toNumber();
            dc.drawLine(prevX, prevY, x, py);
            prevX = x;
            prevY = py;
        }
    }

    // ── Route Profile (loaded course + you-are-here) ──────────────
    private function drawRoute(dc) as Void {
        var c = cx(dc);
        var course = _recorder.course;
        ring(dc, C_EMBER, kmFrac(), true);
        pageDots(dc, 4);

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

        // you-are-here marker — pulsing ember halo around a white center dot
        var curY = (yBot - hgt * ((course.elevAtFrac(prog) - course.minE) / range)).toNumber();
        dc.setColor(C_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(markerX, yTop - 6, markerX, yBot);
        var markerPulse = 0.5 + 0.5 * pulse(tickPhase());
        drawGlow(dc, markerX, curY, dimColor(C_EMBER, 0.6 + 0.4 * markerPulse), 6);
        dc.setColor(C_WHITE, Graphics.COLOR_TRANSPARENT);
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

    // ── 08 · Paused ───────────────────────────────────────────────
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
            var iconColor;
            var labelColor;
            if (i == 0) {
                // RESUME is always a filled ember pill; selected gets a brighter
                // ring + glow halo to match the design's RESUME shadow.
                dc.setColor(C_EMBER, Graphics.COLOR_TRANSPARENT);
                dc.fillRoundedRectangle(c - 95, y, 190, 46, 23);
                if (sel) {
                    dc.setColor(C_EMBER2, Graphics.COLOR_TRANSPARENT);
                    dc.drawRoundedRectangle(c - 96, y - 1, 192, 48, 24);
                    dc.drawRoundedRectangle(c - 97, y - 2, 194, 50, 25);
                }
                iconColor = C_BG;
                labelColor = C_BG;
            } else {
                dc.setColor(sel ? cols[i] : C_TRACK, Graphics.COLOR_TRANSPARENT);
                dc.drawRoundedRectangle(c - 95, y, 190, 46, 23);
                if (sel) { dc.drawRoundedRectangle(c - 94, y + 1, 188, 44, 22); }
                iconColor = cols[i];
                labelColor = cols[i];
            }
            // Icon at the left, label centred — small offset so the pair reads
            // as a unit rather than centred independently.
            var iconX = c - 56;
            drawPausedIcon(dc, i, iconX, y + 23, iconColor);
            dc.setColor(labelColor, Graphics.COLOR_TRANSPARENT);
            dc.drawText(c + 14, y + 23, Graphics.FONT_TINY, labels[i], CTR());
        }
    }

    // Pill-internal icons: play triangle (RESUME), check (SAVE), x (DISCARD).
    private function drawPausedIcon(dc, idx, x, y, color) as Void {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        if (idx == 0) {
            // play triangle
            dc.fillPolygon([[x - 6, y - 8], [x + 8, y], [x - 6, y + 8]]);
        } else if (idx == 1) {
            // check mark
            dc.setPenWidth(3);
            dc.drawLine(x - 7, y + 1, x - 2, y + 6);
            dc.drawLine(x - 2, y + 6, x + 8, y - 5);
            dc.setPenWidth(1);
        } else {
            // x / cross
            dc.setPenWidth(3);
            dc.drawLine(x - 7, y - 7, x + 7, y + 7);
            dc.drawLine(x - 7, y + 7, x + 7, y - 7);
            dc.setPenWidth(1);
        }
    }

    private function miniStat(dc, x, y, value, label, ember) as Void {
        dc.setColor(ember ? C_EMBER : C_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, y, Graphics.FONT_SMALL, value, CTR());
        dc.setColor(C_TEXT3, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, y + 22, Graphics.FONT_XTINY, label, CTR());
    }

    // ── 09 · Saved Summary ────────────────────────────────────────
    private function drawSummary(dc) as Void {
        var c = cx(dc);
        ring(dc, C_GREEN, 1.0, true);

        // Small brand mark crowning the screen
        if (_logoSm != null) {
            dc.drawBitmap(c - _logoSm.getWidth() / 2, 22, _logoSm);
        }
        dc.setColor(C_AMBER, Graphics.COLOR_TRANSPARENT);
        dc.drawText(c, 64, Graphics.FONT_XTINY, "HIKE SAVED", CTR());
        dc.setColor(C_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(c, 88, Graphics.FONT_XTINY, _recorder.activityName() + " Recorded", CTR());

        // effort dial — outer halo behind the green ring
        var dy = 142;
        // Soft halo: a slightly larger dim-green ring outside the main arc
        dc.setPenWidth(8);
        dc.setColor(dimColor(C_GREEN, 0.18), Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(c, dy, 36);
        dc.setPenWidth(5);
        dc.setColor(C_TRACK, Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(c, dy, 34);
        dc.setColor(C_GREEN, Graphics.COLOR_TRANSPARENT);
        dc.drawArc(c, dy, 34, Graphics.ARC_CLOCKWISE, 90, 90 - 360 * effortFrac());
        dc.setPenWidth(1);
        // Letter grade in big mono — looks like a watch dial readout
        dc.setColor(C_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(c, dy - 6, Graphics.FONT_NUMBER_MEDIUM, effortGrade(), CTR());
        dc.setColor(C_TEXT3, Graphics.COLOR_TRANSPARENT);
        dc.drawText(c, dy + 22, Graphics.FONT_XTINY, "EFFORT", CTR());

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
            label = "SYNCING…"; col = C_AMBER;
        } else if (syncState == 2) {
            label = "✓ SYNCED"; col = C_GREEN;
        } else if (syncState == 3) {
            label = (syncMsg.length() > 0) ? ("FAILED: " + syncMsg) : "SYNC FAILED — RETRY";
            col = C_RED;
        }
        dc.setColor(col, Graphics.COLOR_TRANSPARENT);
        // Pulled up from 344 — the original placement clipped past the bottom
        // curve of the round display on the Instinct 3.
        dc.drawRoundedRectangle(c - 78, 322, 156, 28, 14);
        dc.drawText(c, 336, Graphics.FONT_XTINY, label, CTR());
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

    // ── 02 · Activity picker ──────────────────────────────────────
    private function drawPicker(dc) as Void {
        var c = cx(dc);

        // Brand mark above the header — small ember pin/mountain.
        if (_logoSm != null) {
            dc.drawBitmap(c - _logoSm.getWidth() / 2, 32, _logoSm);
        }
        dc.setColor(C_TEXT3, Graphics.COLOR_TRANSPARENT);
        dc.drawText(c, 78, Graphics.FONT_XTINY, "ACTIVITY", CTR());

        var labels = ["Hike", "Trail Run", "Walk", "Climb"];
        // Four 44px slots centred slightly above the geometric middle so the
        // "UP / DOWN  SELECT" hint reads cleanly along the bottom curve.
        var ys = [129, 173, 217, 261];
        for (var i = 0; i < ACTIVITY_COUNT; i += 1) {
            var sel = (i == _recorder.activity);
            var yc = ys[i];
            var w = sel ? 250 : 210;
            var h = sel ? 42 : 30;
            var rx = c - w / 2;
            var ry = yc - h / 2;
            var rr = h / 2;

            if (sel) {
                // Outer halo: two dimming ember outlines outside the border line.
                dc.setColor(dimColor(C_EMBER, 0.32), Graphics.COLOR_TRANSPARENT);
                dc.drawRoundedRectangle(rx - 2, ry - 2, w + 4, h + 4, rr + 2);
                dc.setColor(dimColor(C_EMBER, 0.55), Graphics.COLOR_TRANSPARENT);
                dc.drawRoundedRectangle(rx - 1, ry - 1, w + 2, h + 2, rr + 1);
                dc.setColor(C_EMBER_DIM, Graphics.COLOR_TRANSPARENT);
                dc.fillRoundedRectangle(rx, ry, w, h, rr);
                dc.setColor(C_EMBER, Graphics.COLOR_TRANSPARENT);
                dc.drawRoundedRectangle(rx, ry, w, h, rr);
                dc.drawRoundedRectangle(rx + 1, ry + 1, w - 2, h - 2, rr - 1);
            } else {
                dc.setColor(C_TRACK, Graphics.COLOR_TRANSPARENT);
                dc.drawRoundedRectangle(rx, ry, w, h, rr);
            }

            var iconColor = sel ? C_EMBER : C_TEXT2;
            var iconX = rx + (sel ? 24 : 20);
            var iconR = sel ? 10 : 7;
            drawActivityIcon(dc, i, iconX, yc, iconR, iconColor);

            var lblColor = sel ? C_WHITE : C_TEXT2;
            dc.setColor(lblColor, Graphics.COLOR_TRANSPARENT);
            var lblX = rx + (sel ? 52 : 40);
            var lblFont = sel ? Graphics.FONT_SMALL : Graphics.FONT_XTINY;
            dc.drawText(lblX, yc, lblFont, labels[i], LFT());

            if (sel) {
                dc.setColor(C_EMBER, Graphics.COLOR_TRANSPARENT);
                var tx = rx + w - 22;
                dc.fillPolygon([[tx, yc - 7], [tx + 9, yc], [tx, yc + 7]]);
            }
        }

        dc.setColor(C_TEXT3, Graphics.COLOR_TRANSPARENT);
        // Pinned above the bottom curve — getHeight() - 40 was clipping on round.
        dc.drawText(c, dc.getHeight() - 54, Graphics.FONT_XTINY, "UP / DOWN  SELECT", CTR());
    }

    // ── 02b · Route picker (after activity pick, before GPS acquire) ───
    private function drawRoutePicker(dc) as Void {
        var c = cx(dc);

        if (_logoSm != null) {
            dc.drawBitmap(c - _logoSm.getWidth() / 2, 32, _logoSm);
        }
        dc.setColor(C_TEXT3, Graphics.COLOR_TRANSPARENT);
        dc.drawText(c, 78, Graphics.FONT_XTINY, "ROUTE", CTR());

        // States: loading spinner / error / list
        if (routeListLoading) {
            // Spinner: 3 dots phase-shifted (reusing sat-style pulses)
            for (var i = 0; i < 3; i += 1) {
                var phase = (_sweep + i * 4) % 12;
                var b = 0.3 + 0.7 * pulse(phase.toFloat() / 12.0);
                drawHaloDot(dc, c - 24 + i * 24, cy(dc), dimColor(C_EMBER, b), 4);
            }
            dc.setColor(C_TEXT2, Graphics.COLOR_TRANSPARENT);
            dc.drawText(c, cy(dc) + 30, Graphics.FONT_XTINY, "FETCHING ROUTES…", CTR());
            return;
        }
        if (routeListError.length() > 0) {
            dc.setColor(C_AMBER, Graphics.COLOR_TRANSPARENT);
            dc.drawText(c, cy(dc) - 6, Graphics.FONT_TINY, routeListError, CTR());
            dc.setColor(C_TEXT3, Graphics.COLOR_TRANSPARENT);
            dc.drawText(c, cy(dc) + 24, Graphics.FONT_XTINY, "START TO SKIP", CTR());
            return;
        }

        // Scrolling list — render the selected row centred and one above / one
        // below for context. Round display constrains us to ~3 rows.
        var n = routeList.size();
        if (n == 0) {
            dc.setColor(C_TEXT2, Graphics.COLOR_TRANSPARENT);
            dc.drawText(c, cy(dc) - 6, Graphics.FONT_TINY, "No routes", CTR());
            dc.setColor(C_TEXT3, Graphics.COLOR_TRANSPARENT);
            dc.drawText(c, cy(dc) + 24, Graphics.FONT_XTINY, "START TO SKIP", CTR());
            return;
        }
        var rowH = 50;
        var idx = routePickerIdx;
        // Slots: [above, selected, below] vertically; selected centered around y=200
        var slots = [
            { "i" => idx - 1, "y" => 140 },
            { "i" => idx,     "y" => 200 },
            { "i" => idx + 1, "y" => 260 }
        ];
        for (var k = 0; k < slots.size(); k += 1) {
            var slot = slots[k];
            var ri = slot["i"] as Number;
            if (ri < 0 || ri >= n) { continue; }
            var sel = (ri == idx);
            var route = routeList[ri] as Dictionary;
            drawRouteRow(dc, c, slot["y"] as Number, route, sel);
        }

        // Up/down chevrons indicating scroll affordance
        if (idx > 0) {
            dc.setColor(C_TEXT3, Graphics.COLOR_TRANSPARENT);
            dc.fillPolygon([[c - 6, 110], [c + 6, 110], [c, 102]]);
        }
        if (idx < n - 1) {
            dc.setColor(C_TEXT3, Graphics.COLOR_TRANSPARENT);
            dc.fillPolygon([[c - 6, 296], [c + 6, 296], [c, 304]]);
        }

        dc.setColor(C_TEXT3, Graphics.COLOR_TRANSPARENT);
        dc.drawText(c, dc.getHeight() - 54, Graphics.FONT_XTINY, "UP / DOWN  START", CTR());
    }

    private function drawRouteRow(dc as Graphics.Dc, c as Number, yc as Number, route as Dictionary, sel as Boolean) as Void {
        var name = (route.get("name") instanceof String) ? route["name"] as String : "Route";
        var id = (route.get("id") instanceof String) ? route["id"] as String : "";
        var w = sel ? 260 : 220;
        var h = sel ? 50 : 36;
        var rx = c - w / 2;
        var ry = yc - h / 2;
        var rr = h / 2;
        var loading = (routeLoadingId.length() > 0 && id.equals(routeLoadingId));

        if (sel) {
            // Two outer halo outlines + dim-ember fill + ember border
            dc.setColor(dimColor(C_EMBER, 0.32), Graphics.COLOR_TRANSPARENT);
            dc.drawRoundedRectangle(rx - 2, ry - 2, w + 4, h + 4, rr + 2);
            dc.setColor(dimColor(C_EMBER, 0.55), Graphics.COLOR_TRANSPARENT);
            dc.drawRoundedRectangle(rx - 1, ry - 1, w + 2, h + 2, rr + 1);
            dc.setColor(C_EMBER_DIM, Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(rx, ry, w, h, rr);
            dc.setColor(C_EMBER, Graphics.COLOR_TRANSPARENT);
            dc.drawRoundedRectangle(rx, ry, w, h, rr);
            dc.drawRoundedRectangle(rx + 1, ry + 1, w - 2, h - 2, rr - 1);
        } else {
            dc.setColor(C_TRACK, Graphics.COLOR_TRANSPARENT);
            dc.drawRoundedRectangle(rx, ry, w, h, rr);
        }

        // Name (truncated by Garmin's text renderer if too long)
        var lblColor = sel ? C_WHITE : C_TEXT2;
        dc.setColor(lblColor, Graphics.COLOR_TRANSPARENT);
        var lblFont = sel ? Graphics.FONT_TINY : Graphics.FONT_XTINY;
        dc.drawText(c, yc - (sel ? 6 : 0), lblFont, name, CTR());

        // Sub-line under the selected row
        if (sel) {
            dc.setColor(dimColor(C_TEXT2, 0.85), Graphics.COLOR_TRANSPARENT);
            var sub = "Skip · record freely";
            if (id.length() > 0) {
                // The list response trims distance/ascent to fit the CIQ HTTP
                // buffer; show them if a previous fetchById populated them.
                var km = toFloat(route.get("distance_km"));
                var asc = toFloat(route.get("ascent_m"));
                if (km > 0.0 || asc > 0.0) {
                    sub = km.format("%.1f") + " km · ↑" + asc.toNumber().format("%d") + "m";
                } else {
                    sub = "Press START to load";
                }
            }
            dc.drawText(c, yc + 12, Graphics.FONT_XTINY, sub, CTR());
        }

        // Loading spinner on the right of the selected row
        if (sel && loading) {
            var sx = rx + w - 22;
            var b = 0.4 + 0.6 * pulse(tickPhase());
            drawHaloDot(dc, sx, yc, dimColor(C_EMBER, b), 4);
        }
    }

    private function toFloat(v) as Float {
        if (v instanceof Number || v instanceof Float || v instanceof Long || v instanceof Double) {
            return v.toFloat();
        }
        return 0.0;
    }

    private function drawActivityIcon(dc, idx, x, y, r, color) as Void {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        if (idx == 0) {
            // Hike → solid mountain triangle
            dc.fillPolygon([[x - r, y + r / 2], [x, y - r], [x + r, y + r / 2]]);
        } else if (idx == 1) {
            // Trail Run → zigzag stride
            dc.setPenWidth(2);
            dc.drawLine(x - r, y + r / 2, x - r / 3, y - r / 2);
            dc.drawLine(x - r / 3, y - r / 2, x + r / 3, y + r / 2);
            dc.drawLine(x + r / 3, y + r / 2, x + r, y - r / 2);
            dc.setPenWidth(1);
        } else if (idx == 2) {
            // Walk → footprint dots (two small ovals approximated with circles)
            dc.fillCircle(x - r / 2, y + r / 3, r / 2);
            dc.fillCircle(x + r / 2, y - r / 3, r / 2);
        } else {
            // Climb → twin peaks
            dc.fillPolygon([[x - r, y + r / 2], [x - r / 3, y - r / 2 + 1], [x + r / 3, y + r / 2]]);
            dc.fillPolygon([[x - r / 3, y + r / 2], [x + r / 3, y - r], [x + r, y + r / 2]]);
        }
    }

    // ── GPS sweep wedge (Acquire animation) ───────────────────────
    // _sweep advances 30° clockwise per tick; this paints a 60° pie-slice
    // approximated by 7 vertices for a smoother edge than a 3-point triangle.
    private function drawSweepWedge(dc, ctrX, ctrY, radius, leadingDegCw) as Void {
        var pts = [[ctrX, ctrY]];
        for (var k = 0; k <= 6; k += 1) {
            var a = (leadingDegCw - k * 10) * Math.PI / 180.0;
            var px = ctrX + (Math.sin(a) * radius).toNumber();
            var py = ctrY - (Math.cos(a) * radius).toNumber();
            pts.add([px, py]);
        }
        dc.setColor(0x144D32, Graphics.COLOR_TRANSPARENT); // deep forest green
        dc.fillPolygon(pts);
    }

    // ── 10 · Dedicated Sync screen ────────────────────────────────
    private function drawSyncing(dc) as Void {
        var c = cx(dc);

        dc.setColor(C_TEXT3, Graphics.COLOR_TRANSPARENT);
        dc.drawText(c, 62, Graphics.FONT_XTINY, "SYNCING", CTR());

        // Watch end — actual Trailtether logo (the pin = "the field end of the
        // tether") with a subtle ember halo behind it. Pulses with the upload.
        var wcx = c - 78;
        var wcy = 165;
        var halo = 0.5 + 0.5 * pulse(tickPhase());
        drawGlow(dc, wcx, wcy, dimColor(C_EMBER, 0.5 + 0.5 * halo), 26);
        if (_logoMd != null) {
            dc.drawBitmap(wcx - _logoMd.getWidth() / 2, wcy - _logoMd.getHeight() / 2, _logoMd);
        }
        dc.setColor(C_EMBER2, Graphics.COLOR_TRANSPARENT);
        dc.drawText(wcx, wcy + 38, Graphics.FONT_XTINY, "WATCH", CTR());

        // Phone glyph (right) — green-bordered rounded rectangle (portrait)
        var pcx = c + 78;
        var pcy = 165;
        dc.setColor(C_PHONE_GREEN, Graphics.COLOR_TRANSPARENT);
        dc.drawRoundedRectangle(pcx - 18, pcy - 30, 36, 60, 8);
        dc.drawRoundedRectangle(pcx - 17, pcy - 29, 34, 58, 7);
        dc.setColor(C_BG, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(pcx - 15, pcy - 27, 30, 54, 6);
        dc.setColor(C_PHONE_GREEN, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(2);
        dc.drawLine(pcx - 9, pcy, pcx - 3, pcy - 6);
        dc.drawLine(pcx - 3, pcy - 6, pcx + 3, pcy + 2);
        dc.drawLine(pcx + 3, pcy + 2, pcx + 9, pcy - 8);
        dc.setPenWidth(1);
        dc.fillCircle(pcx, pcy + 20, 2);
        dc.drawText(pcx, pcy + 34, Graphics.FONT_XTINY, "PHONE", CTR());

        // Link line + animated packets with glow halos
        dc.setColor(dimColor(C_EMBER, 0.4), Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(1);
        dc.drawLine(wcx + 25, wcy, pcx - 18, pcy);
        var linkLen = (pcx - 18) - (wcx + 25);
        var linkX0 = wcx + 25;
        for (var p = 0; p < 3; p += 1) {
            var phase = (_sweep + p * 4) % 12;
            var px = linkX0 + (linkLen * phase / 12);
            drawHaloDot(dc, px, wcy, C_EMBER2, 3);
        }

        // Status text
        dc.setColor(C_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(c, 240, Graphics.FONT_SMALL, "Uploading hike…", CTR());

        // Progress bar with subtle halo above/below the fill
        var barX = 92;
        var barW = dc.getWidth() - 2 * barX;
        var barY = 274;
        dc.setColor(C_TRACK, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(barX, barY, barW, 7, 3);
        var fillW = (barW * syncProgress).toNumber();
        if (fillW > 0) {
            // Faint glow above and below the fill
            dc.setColor(dimColor(C_EMBER, 0.25), Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(barX - 1, barY - 2, fillW + 2, 11, 4);
            dc.setColor(C_EMBER, Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(barX, barY, fillW, 7, 3);
            // Leading-edge highlight
            dc.setColor(C_EMBER2, Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(barX + fillW - 4, barY, 4, 7, 2);
        }
        // Percent label
        dc.setColor(C_EMBER, Graphics.COLOR_TRANSPARENT);
        var pct = (syncProgress * 100).toNumber();
        dc.drawText(c, 296, Graphics.FONT_XTINY, pct.format("%d") + "%", CTR());

        // Bottom status pill — TRAILTETHER · GARMIN BRIDGE
        drawStatusPill(dc, c, 330, "TRAILTETHER · GARMIN BRIDGE", C_GREEN, C_GREEN, dimColor(C_GREEN, 0.4));
    }

    // ── formatters ────────────────────────────────────────────────
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
