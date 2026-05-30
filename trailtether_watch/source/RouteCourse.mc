import Toybox.Lang;
import Toybox.Math;

// A loaded/planned route's elevation profile + look-ahead math.
//
// v1 is seeded with a bundled sample (loadSample). The real source is the
// Trailtether phone app pushing a planned hike (route_plans / hike_plans / GPX)
// to the watch over the Garmin Connect bridge — call loadCourse() with the same
// shape. Progress along the profile is driven by recorded distance for now;
// swap _indexForDist() for true GPS nearest-point projection when real
// (lat,lon) routes are loaded.
class RouteCourse {
    public var name as String;
    public var dist as Array<Float>; // cumulative metres, ascending
    public var elev as Array<Float>; // metres
    public var lat as Array<Float>;  // optional — populated when the route source has GPS
    public var lon as Array<Float>;
    public var totalDist as Float = 0.0;
    public var minE as Float = 0.0;
    public var maxE as Float = 0.0;

    function initialize() {
        name = "";
        dist = [] as Array<Float>;
        elev = [] as Array<Float>;
        lat = [] as Array<Float>;
        lon = [] as Array<Float>;
    }

    function loaded() as Boolean {
        return dist.size() >= 2;
    }

    function hasGeo() as Boolean {
        // Reject all-zero ((0,0) Null Island) or degenerate lat/lon arrays —
        // without this guard, off-route detection would project nonsense and
        // light up an "OFF ROUTE" pill on the Map page for any real position.
        if (lat.size() < 2 || lat.size() != lon.size()) { return false; }
        if (lat[0] == 0.0 && lon[0] == 0.0) { return false; }
        return true;
    }

    function clear() as Void {
        name = "";
        dist = [] as Array<Float>;
        elev = [] as Array<Float>;
        lat = [] as Array<Float>;
        lon = [] as Array<Float>;
        totalDist = 0.0;
        minE = 0.0;
        maxE = 0.0;
    }

    // Fed later by the phone channel: parallel cumulative-distance + elevation arrays.
    function loadCourse(courseName as String, distM as Array<Float>, elevM as Array<Float>) as Void {
        name = courseName;
        dist = distM;
        elev = elevM;
        lat = [] as Array<Float>;
        lon = [] as Array<Float>;
        _recompute();
    }

    // Full geo course: dist/elev + lat/lon. Used by the Map page to draw the
    // planned route polyline and by off-route detection.
    function loadCourseGeo(courseName as String, distM as Array<Float>, elevM as Array<Float>,
                           latArr as Array<Float>, lonArr as Array<Float>) as Void {
        name = courseName;
        dist = distM;
        elev = elevM;
        lat = latArr;
        lon = lonArr;
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

    // Minimum perpendicular distance (metres) from a query point to any segment
    // of the route polyline. Returns -1 if the route has no geo. Used by the
    // Map page's OFF ROUTE detection. Uses equirectangular projection anchored
    // on the route's first point — accurate well past any single-day hike span.
    function nearestRouteDistM(curLat as Float, curLon as Float) as Float {
        var n = lat.size();
        if (n < 2 || lon.size() != n) { return -1.0; }
        var refLat = lat[0];
        var refLon = lon[0];
        var cosRef = Math.cos(refLat * Math.PI / 180.0);
        var mPerDegLat = 111320.0;
        var mPerDegLon = mPerDegLat * cosRef;
        var qx = (curLon - refLon) * mPerDegLon;
        var qy = (curLat - refLat) * mPerDegLat;
        var minD = -1.0;
        for (var i = 1; i < n; i += 1) {
            var ax = (lon[i - 1] - refLon) * mPerDegLon;
            var ay = (lat[i - 1] - refLat) * mPerDegLat;
            var bx = (lon[i] - refLon) * mPerDegLon;
            var by = (lat[i] - refLat) * mPerDegLat;
            var d = pointToSegDist(qx, qy, ax, ay, bx, by);
            if (minD < 0.0 || d < minD) { minD = d; }
        }
        return minD;
    }

    private function pointToSegDist(px as Float, py as Float, ax as Float, ay as Float, bx as Float, by as Float) as Float {
        var dx = bx - ax;
        var dy = by - ay;
        var seg2 = dx * dx + dy * dy;
        if (seg2 < 0.000001) {
            var dpx = px - ax;
            var dpy = py - ay;
            return Math.sqrt(dpx * dpx + dpy * dpy).toFloat();
        }
        var t = ((px - ax) * dx + (py - ay) * dy) / seg2;
        if (t < 0.0) { t = 0.0; }
        if (t > 1.0) { t = 1.0; }
        var nx = ax + t * dx;
        var ny = ay + t * dy;
        var rx = px - nx;
        var ry = py - ny;
        return Math.sqrt(rx * rx + ry * ry).toFloat();
    }

    // Look-ahead from current recorded distance (m):
    //   rem      — distance remaining to finish (m)
    //   asc      — total climbing still ahead (m)
    //   gain     — height gain to the next high point ahead (m, 0 if only descent left)
    //   gainDist — distance to that next high point (m)
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
