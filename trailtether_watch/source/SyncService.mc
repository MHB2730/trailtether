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

    private var _cb as Method?;

    function initialize() {}

    // Pairing token from Garmin Connect app settings (mint_watch_token in the
    // Trailtether phone app). Empty string means unpaired — caller MUST treat
    // that as a hard error and prompt the user to pair, rather than fall back
    // to any hardcoded test token (production safety: no cross-account leak).
    // For the sim, set the property via Connect IQ Settings Editor.
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
        return "";
    }

    // cb is invoked as cb(ok as Boolean, msg as String)
    function upload(recorder as HikeRecorder, cb as Method) as Void {
        _cb = cb;
        // Fail-closed if unpaired so we don't silently write to the wrong account.
        var token = deviceToken();
        if (token.length() == 0) {
            cb.invoke(false, "Pair watch");
            return;
        }
        // No phone/Bluetooth bridge -> the request would queue forever. Fail fast
        // so the UI can show a clear state (and a real watch can retry later).
        if (!System.getDeviceSettings().connectionAvailable) {
            cb.invoke(false, "No phone");
            return;
        }
        var body = {
            "name" => recorder.activityName() + " (Watch)",
            "distance_km" => recorder.distanceM / 1000.0,
            "ascent_m" => recorder.ascentM.toNumber(),
            "descent_m" => recorder.descentM.toNumber(),
            "duration_seconds" => recorder.elapsedSec,
            "activity_type" => recorder.activityType(),
            "points" => buildPoints(recorder.getPoints(), 250)
        };
        var options = {
            :method => Communications.HTTP_REQUEST_METHOD_POST,
            :headers => {
                "Content-Type" => Communications.REQUEST_CONTENT_TYPE_JSON,
                "apikey" => ANON,
                "Authorization" => "Bearer " + ANON,
                "x-device-token" => token
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
