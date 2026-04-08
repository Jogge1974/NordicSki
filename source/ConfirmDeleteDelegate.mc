import Toybox.Lang;
import Toybox.WatchUi;

class ConfirmDeleteDelegate extends WatchUi.BehaviorDelegate {

    var _view;

    function initialize(view as ConfirmDeleteView) {
        BehaviorDelegate.initialize();
        _view = view;
    }

    function onKey(keyEvent) as Boolean {
        return _view.onKey(keyEvent);
    }

}
