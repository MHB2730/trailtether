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
