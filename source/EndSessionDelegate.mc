import Toybox.Lang;
import Toybox.WatchUi;

class EndSessionDelegate extends WatchUi.BehaviorDelegate {

    var _view;

    function initialize(view as EndSessionView) {
        BehaviorDelegate.initialize();
        _view = view;
    }

    function onKey(keyEvent) as Boolean {
        return _view.onKey(keyEvent);
    }

}
