import Toybox.Lang;
import Toybox.WatchUi;

class PreSessionDelegate extends WatchUi.BehaviorDelegate {

    var _view;

    function initialize(view as PreSessionView) {
        BehaviorDelegate.initialize();
        _view = view;
    }

    function onKey(keyEvent) as Boolean {
        return _view.onKey(keyEvent);
    }

}
