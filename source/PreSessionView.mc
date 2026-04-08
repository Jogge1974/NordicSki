import Toybox.Graphics;
import Toybox.Activity;
import Toybox.Position;
import Toybox.System;
import Toybox.Timer;
import Toybox.WatchUi;

class PreSessionView extends WatchUi.View {

    var _accuracy = 0;
    var _lastAccuracy = null;
    var _timer = null;
    var _selectedMode = 0; // 0=Classic, 1=Skate

    function initialize() {
        View.initialize();
    }

    function onUpdate(dc as Dc) as Void {
        updateGpsStatus();

        var width = dc.getWidth();
        var height = dc.getHeight();
        var pageBgColor = Graphics.COLOR_RED;

        var line1Y = (height / 6) * 1;
        var line2Y = (height / 6) * 2;
        var line3Y = (height / 6) * 4;
        var line4Y = (height / 6) * 5;
        var rowheight = height / 6;

        if (_accuracy == 4) {
            dc.setColor(Graphics.COLOR_GREEN, Graphics.COLOR_GREEN);
            dc.clear();
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_GREEN);
            pageBgColor = Graphics.COLOR_GREEN;

            dc.drawText(width / 2, line1Y, Graphics.FONT_SMALL, s(Rez.Strings.pre_gps_ready), Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            dc.drawText(width / 2, line2Y, Graphics.FONT_SMALL, s(Rez.Strings.pre_ready_start_line1), Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        } else if (_accuracy == 2 || _accuracy == 3) {
            dc.setColor(Graphics.COLOR_YELLOW, Graphics.COLOR_YELLOW);
            dc.clear();
            dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_YELLOW);
            pageBgColor = Graphics.COLOR_YELLOW;

            dc.drawText(width / 2, line1Y, Graphics.FONT_SMALL, s(Rez.Strings.pre_gps_ready), Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            dc.drawText(width / 2, line2Y, Graphics.FONT_SMALL, s(Rez.Strings.pre_ready_start_line1), Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        } else {
            dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_RED);
            dc.clear();
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_RED);
            pageBgColor = Graphics.COLOR_RED;

            dc.drawText(width / 2, line2Y, Graphics.FONT_SMALL, s(Rez.Strings.pre_waiting_gps), Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        }

        drawModeSelector(dc, width, rowheight, line3Y, line4Y, pageBgColor);
    }

    function drawModeSelector(dc as Dc, rowWidth, rowHeight, classicY, skateY, pageBgColor) as Void {
        drawModeRow(dc, classicY, rowWidth, rowHeight, s(Rez.Strings.pre_skimode_classic), _selectedMode == 0, pageBgColor);
        drawModeRow(dc, skateY, rowWidth, rowHeight, s(Rez.Strings.pre_skimode_skate), _selectedMode == 1, pageBgColor);
    }

    function drawModeRow(dc as Dc, centerY, rowWidth, rowHeight, text, selected, pageBgColor) as Void {
        var top = centerY - (rowHeight / 2);

        if (selected) {
            dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
            dc.fillRectangle(0, top, rowWidth, rowHeight);
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        } else {
            dc.setColor(0x555555, pageBgColor);
        }

        dc.drawText(rowWidth / 2, centerY, Graphics.FONT_SMALL, text, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }


    function onShow() as Void {
        updateGpsStatus();
        Position.enableLocationEvents(Position.LOCATION_CONTINUOUS, method(:onPosition));
        _timer = new Timer.Timer();
        _timer.start(method(:onTick), 1000, true);
    }

    function onHide() as Void {
        if (_timer != null) {
            _timer.stop();
            _timer = null;
        }
    }

    function onKey(keyEvent) {
        var key = keyEvent.getKey();
        var isStart = (key == WatchUi.KEY_START);
        if (!isStart && (WatchUi has :KEY_ENTER) && key == WatchUi.KEY_ENTER) {
            isStart = true;
        }
        if (!isStart && key == 4) {
            isStart = true;
        }

        if (key == WatchUi.KEY_UP || key == WatchUi.KEY_DOWN) {
            if (key == WatchUi.KEY_UP) {
                _selectedMode = (_selectedMode + 1) % 2;
                System.println("PreSessionView: UP pressed -> mode=" + modeToString(_selectedMode));
            } else {
                _selectedMode = (_selectedMode + 1) % 2;
                System.println("PreSessionView: DOWN pressed -> mode=" + modeToString(_selectedMode));
            }
            WatchUi.requestUpdate();
            return true;
        }

        if (isStart) {
            System.println("PreSessionView: START pressed");
            if (_timer != null) {
                _timer.stop();
                _timer = null;
            }
            var subSport = selectedSubSport();
            System.println("PreSessionView: navigating to SessionView subSport=" + subSport);
            var view = new SessionView(subSport);
            WatchUi.pushView(view, new SessionDelegate(view), WatchUi.SLIDE_IMMEDIATE);
            return true;
        }

        if (key == WatchUi.KEY_ESC) {
            System.println("PreSessionView: BACK pressed, exiting");
            WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
            return true;
        }

        System.println("PreSessionView: key pressed (ignored) key=" + key);
        return false;
    }

    function updateGpsStatus() as Void {
        var info = Position.getInfo();
        var accuracy = null;

        if (info != null) {
            accuracy = info.accuracy;
        }

        // var current = (accuracy != null) && (accuracy != Position.QUALITY_NOT_AVAILABLE);

        if (accuracy != _lastAccuracy) {
            System.println("PreSessionView: GPS accuracy changed -> " + accuracyToString(accuracy));
            _lastAccuracy = accuracy;
        }

        // if (current != _gpsReady) {
        //     _gpsReady = current;
        //     System.println("PreSessionView: GPS status changed -> " + (_gpsReady ? "ready" : "not ready"));
        // }
    }

    function onTick() as Void {
        updateGpsStatus();
        WatchUi.requestUpdate();
    }

    function s(id) {
        return WatchUi.loadResource(id);
    }

    function accuracyToString(accuracy) {
        if (accuracy == null) {
            _accuracy = 0;
            return "NULL";
        }

        if (accuracy == Position.QUALITY_NOT_AVAILABLE) {
            _accuracy = 1;
            return "NOT AVAILABLE";
        }

        if (accuracy == Position.QUALITY_POOR) {
            _accuracy = 2;
            return "POOR";
        }

        if (accuracy == Position.QUALITY_USABLE) {
            _accuracy = 3;
            return "USABLE";
        }

        if (accuracy == Position.QUALITY_GOOD) {
            _accuracy = 4;
            return "GOOD";
        }

        return "" + accuracy;
    }


    function onPosition(info as Position.Info) as Void {
        var accuracy = info.accuracy;
        if (accuracy != _lastAccuracy) {
            System.println("PreSessionView: GPS quality -> " + accuracyToString(accuracy));
            _lastAccuracy = accuracy;
        }

        // var ready = (accuracy != null) && (accuracy != Position.QUALITY_NOT_AVAILABLE);
        // if (ready != _gpsReady) {
        //     _gpsReady = ready;
        //     System.println("PreSessionView: GPS status changed -> " + (_gpsReady ? "ready" : "not ready"));
        // }
    }

    function selectedSubSport() {
        if (_selectedMode == 1) {
            return Activity.SUB_SPORT_SKATE_SKIING;
        }
        return Activity.SUB_SPORT_GENERIC;
    }

    function modeToString(mode) {
        return (mode == 1) ? "Skate" : "Classic";
    }
}
