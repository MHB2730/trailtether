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
        // CIQ persists property values across upgrades and ignores the new
        // properties.xml default once any value is stored. A previous version
        // shipped with an empty default — that empty string sticks even after
        // we ship a real token as the new default. Seed it once if missing.
        try {
            var v = Application.Properties.getValue("pairingToken");
            var cur = (v instanceof String) ? (v as String) : "";
            if (cur.length() == 0) {
                Application.Properties.setValue(
                    "pairingToken",
                    "ttw_df78433dbc56421f9aba494773c22543"
                );
            }
        } catch (e) {
            // Storage failure here is non-fatal — SyncService/RouteService will
            // surface "Pair watch" and the user can paste via Connect IQ Mobile.
        }
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
