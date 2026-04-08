import Toybox.Graphics;
import Toybox.System;
import Toybox.WatchUi;

class ConfirmDeleteView extends WatchUi.View {

    const OPTION_YES = 0;
    const OPTION_NO = 1;

    var _selected = OPTION_NO;
    var _sessionView;

    function initialize(sessionView as SessionView) {
        View.initialize();
        _sessionView = sessionView;
        System.println("ConfirmDeleteView: initialize");
    }

    function onShow() as Void {
        System.println("ConfirmDeleteView: onShow");
    }

    function onUpdate(dc as Dc) as Void {
        var width = dc.getWidth();
        var height = dc.getHeight();
        var rowHeight = height / 3;

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_WHITE);
        dc.clear();
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_WHITE);

        dc.drawText(
            width / 2,
            rowHeight / 2,
            Graphics.FONT_SMALL,
            s(Rez.Strings.confirm_title),
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
        );

        drawOption(dc, 1, rowHeight, s(Rez.Strings.confirm_yes), OPTION_YES);
        drawOption(dc, 2, rowHeight, s(Rez.Strings.confirm_no), OPTION_NO);
    }

    function onKey(keyEvent) {
        var key = keyEvent.getKey();
        System.println("ConfirmDeleteView: key pressed key=" + key);

        if (key == WatchUi.KEY_UP || key == WatchUi.KEY_DOWN) {
            var previous = _selected;
            _selected = (_selected == OPTION_YES) ? OPTION_NO : OPTION_YES;
            if (previous != _selected) {
                System.println("ConfirmDeleteView: selection -> " + getSelectedLabel());
                WatchUi.requestUpdate();
            }
            return true;
        }

        var isStart = (key == WatchUi.KEY_START || key == 4 || key == 5);
        if (!isStart && (WatchUi has :KEY_ENTER) && key == WatchUi.KEY_ENTER) {
            isStart = true;
        }

        if (isStart) {
            if (_selected == OPTION_YES) {
                System.println("ConfirmDeleteView: Yes selected -> delete");
                _sessionView.discardSessionAndExit();
            } else {
                System.println("ConfirmDeleteView: No selected -> back to EndSessionView");
                WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
            }
            return true;
        }

        if (key == WatchUi.KEY_ESC) {
            System.println("ConfirmDeleteView: BACK pressed -> No");
            WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
            return true;
        }

        return false;
    }

    function drawOption(dc as Dc, rowIndex, rowHeight, label, optionIndex) as Void {
        var width = dc.getWidth();
        var y = rowIndex * rowHeight;
        var isSelected = _selected == optionIndex;

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
        if (_selected == OPTION_YES) {
            return s(Rez.Strings.confirm_yes);
        }

        return s(Rez.Strings.confirm_no);
    }

    function s(id) {
        return WatchUi.loadResource(id);
    }

}
