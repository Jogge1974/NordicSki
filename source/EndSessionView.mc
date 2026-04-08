import Toybox.Graphics;
import Toybox.System;
import Toybox.WatchUi;

class EndSessionView extends WatchUi.View {

    const OPTION_RESUME = 0;
    const OPTION_SAVE = 1;
    const OPTION_DELETE = 2;

    var _selected = OPTION_RESUME;
    var _sessionView;

    function initialize(sessionView as SessionView) {
        View.initialize();
        _sessionView = sessionView;
        System.println("EndSessionView: initialize");
    }

    function onShow() as Void {
        System.println("EndSessionView: onShow");
    }

    function onUpdate(dc as Dc) as Void {
        var height = dc.getHeight();
        var headerHeight = 50;
        var listHeight = height - headerHeight;
        var rowHeight = listHeight / 3;

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_WHITE);
        dc.clear();

        drawHeader(dc, headerHeight);
        drawRow(dc, headerHeight, 0, rowHeight, s(Rez.Strings.end_option_resume));
        drawRow(dc, headerHeight, 1, rowHeight, s(Rez.Strings.end_option_save));
        drawRow(dc, headerHeight, 2, rowHeight, s(Rez.Strings.end_option_delete));
    }

    function onKey(keyEvent) {
        var key = keyEvent.getKey();
        System.println("EndSessionView: key pressed key=" + key);

        if (key == WatchUi.KEY_UP || key == WatchUi.KEY_DOWN) {
            var previous = _selected;
            if (key == WatchUi.KEY_UP) {
                _selected = (_selected + 2) % 3;
            } else {
                _selected = (_selected + 1) % 3;
            }

            if (previous != _selected) {
                System.println("EndSessionView: selection -> " + getSelectedLabel());
                WatchUi.requestUpdate();
            }
            return true;
        }

        var isStart = (key == WatchUi.KEY_START || key == 4);
        if (!isStart && (WatchUi has :KEY_ENTER) && key == WatchUi.KEY_ENTER) {
            isStart = true;
        }

        if (isStart) {
            if (_selected == OPTION_RESUME) {
                System.println("EndSessionView: Resume activated");
                _sessionView.resumeSession();
                WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
            } else if (_selected == OPTION_SAVE) {
                System.println("EndSessionView: Save activated");
                _sessionView.saveSessionAndExit();
            } else {
                System.println("EndSessionView: Delete selected");
                var view = new ConfirmDeleteView(_sessionView);
                WatchUi.pushView(view, new ConfirmDeleteDelegate(view), WatchUi.SLIDE_IMMEDIATE);
            }
            return true;
        }

        if (key == WatchUi.KEY_ESC || key == 5) {
            System.println("EndSessionView: BACK pressed -> Resume");
            _sessionView.resumeSession();
            WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
            return true;
        }

        return false;
    }

    function drawHeader(dc as Dc, headerHeight) as Void {
        var width = dc.getWidth();
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.fillRectangle(0, 0, width, headerHeight);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.drawText(
            width / 2,
            (headerHeight / 2) + 6,
            Graphics.FONT_TINY,
            s(Rez.Strings.end_header_paused),
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
        );
        dc.setColor(Graphics.COLOR_GREEN, Graphics.COLOR_GREEN);
        dc.fillRectangle(0, headerHeight - 2, width, 2);
    }

    function drawRow(dc as Dc, yOffset, index, rowHeight, label) as Void {
        var width = dc.getWidth();
        var y = yOffset + (index * rowHeight);
        var isSelected = _selected == index;

        if (isSelected) {
            dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        } else {
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_WHITE);
        }
        dc.fillRectangle(0, y, width, rowHeight);

        if (isSelected) {
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        } else {
            dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_WHITE);
        }

        dc.drawText(
            width / 2,
            y + (rowHeight / 2),
            Graphics.FONT_MEDIUM,
            label,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
        );
    }

    function getSelectedLabel() {
        if (_selected == OPTION_RESUME) {
            return s(Rez.Strings.end_option_resume);
        } else if (_selected == OPTION_SAVE) {
            return s(Rez.Strings.end_option_save);
        }

        return s(Rez.Strings.end_option_delete);
    }

    function s(id) {
        return WatchUi.loadResource(id);
    }

}
