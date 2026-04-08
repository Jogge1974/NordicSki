import Toybox.Lang;
import Toybox.WatchUi;

class SessionDelegate extends WatchUi.BehaviorDelegate {

    var _view;

    function initialize(view as SessionView) {
        BehaviorDelegate.initialize();
        _view = view;
    }

    function onKey(keyEvent) as Boolean {
        return _view.onKey(keyEvent);
    }

}
