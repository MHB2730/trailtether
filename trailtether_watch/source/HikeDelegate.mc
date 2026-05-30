import Toybox.WatchUi;
import Toybox.Lang;

// Routes the Instinct 3 buttons through the hike state machine.
//   START/STOP (onSelect)  · IDLE→acquire · ACQUIRING→record · RECORDING→pause
//                            · PAUSED→confirm selection · SUMMARY→new hike
//   UP / DOWN  (prev/next) · RECORDING→change data page · PAUSED→move selection
//   BACK       (onBack)    · ACQUIRING→cancel · RECORDING swallowed · PAUSED→resume
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

    // MENU (hold UP) re-pulls the active route from Supabase. Skipped during
    // upload so the Communications stack doesn't have two in-flight requests
    // competing on the phone bridge.
    function onMenu() as Boolean {
        if (_r.state == STATE_SYNCING) { return true; }
        _route.fetch();
        return true;
    }

    function onSelect() as Boolean {
        var s = _r.state;
        if (s == STATE_PICKING) {
            _r.commitActivity(); // → STATE_ROUTE_PICKING
            beginRoutePicker();
        } else if (s == STATE_ROUTE_PICKING) {
            commitSelectedRoute();
        } else if (s == STATE_IDLE) {
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
            if (_v.syncState == 2) {
                _r.reset();        // synced → start a fresh hike (back to picker)
                _v.page = 0;
                _v.syncState = 0;
                _v.syncProgress = 0.0;
            } else {
                // idle or error → enter the dedicated Sync screen + kick off upload.
                // Reset to 0 before the seed so a retry after failure never
                // animates from the previous run's 95%.
                _v.syncState = 1;
                _v.syncProgress = 0.0;
                _v.syncMsg = "";
                _v.syncProgress = 0.05;
                _r.state = STATE_SYNCING;
                _sync.upload(_r, method(:onSyncDone));
            }
        } else if (s == STATE_SYNCING) {
            // pressing START during upload is a no-op — wait for the callback
        }
        WatchUi.requestUpdate();
        return true;
    }

    function onSyncDone(ok as Boolean, msg as String) as Void {
        _v.syncState = ok ? 2 : 3;
        _v.syncMsg = msg;
        _v.syncProgress = 1.0;
        // Only flip back to SUMMARY if we're still on the SYNCING screen — a
        // user who already exited the summary via reset() shouldn't get pulled
        // back here by a late-arriving callback.
        if (_r.state == STATE_SYNCING) {
            _r.state = STATE_SUMMARY;
        }
        WatchUi.requestUpdate();
    }

    function onNextPage() as Boolean {
        if (_r.state == STATE_PICKING) {
            _r.activity = (_r.activity + 1) % ACTIVITY_COUNT;
            WatchUi.requestUpdate();
            return true;
        }
        if (_r.state == STATE_ROUTE_PICKING && !_v.routeListLoading) {
            var n = _v.routeList.size();
            if (n > 0) {
                _v.routePickerIdx = (_v.routePickerIdx + 1) % n;
                WatchUi.requestUpdate();
            }
            return true;
        }
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
        if (_r.state == STATE_PICKING) {
            _r.activity = (_r.activity + ACTIVITY_COUNT - 1) % ACTIVITY_COUNT;
            WatchUi.requestUpdate();
            return true;
        }
        if (_r.state == STATE_ROUTE_PICKING && !_v.routeListLoading) {
            var n = _v.routeList.size();
            if (n > 0) {
                _v.routePickerIdx = (_v.routePickerIdx + n - 1) % n;
                WatchUi.requestUpdate();
            }
            return true;
        }
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
        if (s == STATE_ROUTE_PICKING) {
            // Back out to the activity picker; cancel any in-flight selection.
            _v.routeLoadingId = "";
            _r.state = STATE_PICKING;
            WatchUi.requestUpdate();
            return true;
        }
        if (s == STATE_ACQUIRING) {
            _r.discard();          // also routes back to STATE_PICKING
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
        if (s == STATE_SYNCING) {
            return true; // don't exit mid-upload
        }
        return false; // PICKING / IDLE / SUMMARY: allow default (exit)
    }

    // ── Route picker plumbing ──────────────────────────────────────
    private function beginRoutePicker() as Void {
        _v.routeList = [{ "id" => "", "name" => "None" }] as Array<Dictionary>;
        _v.routePickerIdx = 0;
        _v.routeListLoading = true;
        _v.routeListError = "";
        _v.routeLoadingId = "";
        _route.fetchList(method(:onRouteList));
    }

    function onRouteList(routes as Array<Dictionary>?, err as String?) as Void {
        // Drop late callbacks if the user already left the picker.
        if (_r.state != STATE_ROUTE_PICKING) { return; }
        _v.routeListLoading = false;
        if (err != null) {
            _v.routeListError = err;
            _v.routeList = [{ "id" => "", "name" => "None" }] as Array<Dictionary>;
            _v.routePickerIdx = 0;
            WatchUi.requestUpdate();
            return;
        }
        var list = [{ "id" => "", "name" => "None" }] as Array<Dictionary>;
        if (routes != null) {
            for (var i = 0; i < routes.size(); i += 1) {
                list.add(routes[i]);
            }
        }
        _v.routeList = list;
        _v.routePickerIdx = 0;
        WatchUi.requestUpdate();
    }

    private function commitSelectedRoute() as Void {
        if (_v.routeListLoading) { return; }
        // Already loading a previous selection — ignore double-press so the
        // first response can't end up associated with the second selection.
        if (_v.routeLoadingId.length() > 0) { return; }
        var idx = _v.routePickerIdx;
        if (idx < 0 || idx >= _v.routeList.size()) { idx = 0; }
        var route = _v.routeList[idx] as Dictionary;
        var id = (route.get("id") instanceof String) ? route["id"] as String : "";
        if (id.length() == 0) {
            // None — clear any pre-loaded course and proceed straight to Acquire.
            _r.course.clear();
            _r.commitRoute();
            _r.beginAcquire();
            WatchUi.requestUpdate();
            return;
        }
        // Real route — fetch its lat/lon/dist/elev, then advance on the callback.
        _v.routeLoadingId = id;
        _route.fetchById(id, method(:onRouteLoaded));
        WatchUi.requestUpdate();
    }

    function onRouteLoaded(ok as Boolean, msg as String) as Void {
        _v.routeLoadingId = "";
        // Drop late callbacks if the user backed out before the fetch returned.
        // The course was already overwritten by RouteService — that's fine,
        // the next pick will overwrite it again.
        if (_r.state != STATE_ROUTE_PICKING) {
            WatchUi.requestUpdate();
            return;
        }
        if (!ok) {
            _v.routeListError = msg;
            WatchUi.requestUpdate();
            return;
        }
        _r.commitRoute();
        _r.beginAcquire();
        WatchUi.requestUpdate();
    }
}
