import Toybox.Lang;
import Toybox.WatchUi;

class NordicSkiDelegate extends WatchUi.BehaviorDelegate {

    function initialize() {
        BehaviorDelegate.initialize();
    }

    function onMenu() as Boolean {
        WatchUi.pushView(new Rez.Menus.MainMenu(), new NordicSkiMenuDelegate(), WatchUi.SLIDE_UP);
        return true;
    }

}