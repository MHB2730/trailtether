import Toybox.Communications;
import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;

// Pulls the device's routes from Supabase (watch-route v3) and loads them into
// the shared RouteCourse. Three operations: fetch() = active or most-recent
// auto-pull; fetchList(cb) = the user's saved trails for the picker; fetchById
// (id, cb) = explicit route selection. Cloud-mediated over the phone bridge.
class RouteService {
    static const URL = "https://xuqmdujupbmxahyhkdwl.supabase.co/functions/v1/watch-route";

    private var _course as RouteCourse;
    private var _listCb as Method?;
    private var _selectCb as Method?;

    function initialize(course as RouteCourse) {
        _course = course;
    }

    // Convenience accessor for screens that don't already hold the course.
    function course() as RouteCourse {
        return _course;
    }

    // Active-route auto-pull (existing behaviour) — fires on launch + MENU-hold.
    // No-op if unpaired or offline; the active route (if any) just doesn't load.
    function fetch() as Void {
        var opts = baseOptions();
        if (opts == null) { return; }
        Communications.makeWebRequest(URL, {}, opts, method(:onResponse));
    }

    // Fetch a specific route by id and load it as the active course.
    // cb is invoked as cb(ok as Boolean, msg as String).
    function fetchById(id as String, cb as Method) as Void {
        _selectCb = cb;
        if (SyncService.deviceToken().length() == 0) {
            cb.invoke(false, "Pair watch");
            return;
        }
        if (!System.getDeviceSettings().connectionAvailable) {
            cb.invoke(false, "No phone");
            return;
        }
        Communications.makeWebRequest(URL, { "id" => id }, baseOptions(), method(:onSelectResponse));
    }

    // Fetch the user's saved trails as a route list. cb(routes, errMsg) where
    // routes is Array<Dictionary{ id, name }> — distance/ascent come back on
    // the by-id fetch instead so the list fits the CIQ HTTP buffer.
    function fetchList(cb as Method) as Void {
        _listCb = cb;
        if (SyncService.deviceToken().length() == 0) {
            cb.invoke(null, "Pair watch");
            return;
        }
        if (!System.getDeviceSettings().connectionAvailable) {
            cb.invoke(null, "No phone");
            return;
        }
        Communications.makeWebRequest(URL, { "action" => "list" }, baseOptions(), method(:onListResponse));
    }

    // Returns null when the request shouldn't be sent (unpaired or offline);
    // the no-callback fetch() path silently drops in that case.
    private function baseOptions() as Dictionary? {
        var token = SyncService.deviceToken();
        if (token.length() == 0) { return null; }
        if (!System.getDeviceSettings().connectionAvailable) { return null; }
        return {
            :method => Communications.HTTP_REQUEST_METHOD_POST,
            :headers => {
                "Content-Type" => Communications.REQUEST_CONTENT_TYPE_JSON,
                "apikey" => SyncService.ANON,
                "Authorization" => "Bearer " + SyncService.ANON,
                "x-device-token" => token
            },
            :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON
        };
    }

    function onResponse(code as Number, data as Dictionary?) as Void {
        loadCourseFromResponse(code, data);
        WatchUi.requestUpdate();
    }

    function onSelectResponse(code as Number, data as Dictionary?) as Void {
        // Snapshot + clear the callback first so any later/duplicate response
        // (or a subsequent fetchById firing while this one was in flight) can't
        // re-invoke the wrong handler. If we have no callback we treat the
        // response as stale and DON'T mutate the course — that prevents a
        // late-arriving response from silently overwriting a fresh selection.
        var cb = _selectCb;
        _selectCb = null;
        if (cb == null) { return; }
        var ok = loadCourseFromResponse(code, data);
        cb.invoke(ok, ok ? "Loaded" : "Load failed");
        WatchUi.requestUpdate();
    }

    function onListResponse(code as Number, data as Dictionary?) as Void {
        var cb = _listCb;
        _listCb = null;
        if (cb == null) { return; }
        if (code != 200 || data == null || data.get("ok") != true) {
            cb.invoke(null, "HTTP " + code.toString());
            return;
        }
        var routes = data.get("routes");
        if (!(routes instanceof Array)) {
            cb.invoke([] as Array<Dictionary>, null);
            return;
        }
        var src = routes as Array;
        var out = [] as Array<Dictionary>;
        for (var i = 0; i < src.size(); i += 1) {
            var r = src[i];
            if (r instanceof Dictionary) {
                var dict = r as Dictionary;
                out.add({
                    "id" => (dict.get("id") instanceof String) ? dict.get("id") : "",
                    "name" => (dict.get("name") instanceof String) ? dict.get("name") : "Route",
                    "distance_km" => toFloat(dict.get("distance_km")),
                    "ascent_m" => toFloat(dict.get("ascent_m"))
                });
            }
        }
        cb.invoke(out, null);
    }

    // Parse a course payload and load it; returns true on success.
    private function loadCourseFromResponse(code as Number, data as Dictionary?) as Boolean {
        if (code != 200 || data == null || data.get("ok") != true) { return false; }
        var c = data.get("course");
        if (c == null || !(c instanceof Dictionary)) { return false; }
        var course = c as Dictionary;
        var name = course.get("name");
        var dist = course.get("dist");
        var elev = course.get("elev");
        if (!(dist instanceof Array) || !(elev instanceof Array)) { return false; }
        var d = toFloatArray(dist as Array);
        var e = toFloatArray(elev as Array);
        if (d.size() < 2 || d.size() != e.size()) { return false; }
        var label = (name instanceof String) ? name : "Route";

        var latRaw = course.get("lat");
        var lonRaw = course.get("lon");
        if (latRaw instanceof Array && lonRaw instanceof Array) {
            var la = toFloatArray(latRaw as Array);
            var lo = toFloatArray(lonRaw as Array);
            if (la.size() == lo.size() && la.size() == d.size()) {
                _course.loadCourseGeo(label, d, e, la, lo);
                return true;
            }
        }
        _course.loadCourse(label, d, e);
        return true;
    }

    private function toFloat(v) as Float {
        if (v instanceof Number || v instanceof Float || v instanceof Long || v instanceof Double) {
            return v.toFloat();
        }
        return 0.0;
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
