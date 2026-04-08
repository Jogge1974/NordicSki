import Toybox.Application;
import Toybox.Activity;
import Toybox.ActivityRecording;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.Position;
import Toybox.Sensor;
import Toybox.System;
import Toybox.Timer;
import Toybox.WatchUi;

class Coord {
    var lat;
    var lon;

    function initialize(latValue, lonValue) {
        lat = latValue;
        lon = lonValue;
    }
}

class SessionView extends WatchUi.View {

    const PAGE_COUNT = 4;

    var _session = null;
    var _session2 = null;
    var _timer = null;
    var _startTimeSeconds = null;
    var _elapsedOffsetSeconds = 0;
    var _isPaused = false;
    var _hasStarted = false;
    var _currentPage = 0;
    var _lastElapsedSeconds = -1;
    var _lastDistanceMeters = null;
    var _lastAltitudeMeters = null;
    var _lastAscentMeters = null;
    var _lastHeartRate = null;
    var _lastRawDistance = null;
    var _lastRawAltitude = null;
    var _lastAltAccuracy = null;
    var _lastAltHasPos = null;
    var _lastRawStatsDistance = null;
    var _lastRawStatsAscent = null;
    var _totalAscentMeters = 0;
    var _lastAltitudeSample = null;
    var _totalDistanceMeters = 0;
    var _lastCoords = null;
    var _lastPositionLog = null;
    var _lastAccuracyLog = null;
    var _coordsLogDone = false;
    var _lastDistanceUpdateSeconds = null;
    var _lastActivityLogSeconds = null;
    // var _locationEventsEnabled = false;
    var _lastPositionEventSeconds = null;
    var _lastPositionEventLogSeconds = null;
    var _currentAltitudeMeters = null;
    var _lastDeltaMeters = null;
    var _lastTickLogSeconds = null;
    var _exitTimer = null;
    var _maxHeartRate = 0;
    var _maxSpeedMps = 0.0;
    var _maxAltitudeMeters = null;
    var _trackPoints as Array<Coord> = [];
    var _trackStarted = false;
    var _trackOriginLat = null;
    var _trackOriginLon = null;
    var _trackCosOrigin = null;
    var _trackMinX = null;
    var _trackMaxX = null;
    var _trackMinY = null;
    var _trackMaxY = null;
    var _trackCache as BufferedBitmap? = null;
    var _trackCacheDirty = true;
    var _trackCacheWidth as Number? = null;
    var _trackCacheHeight as Number? = null;
    var _lastTrackPointForCache as Coord? = null;
    const TRACK_POINT_MIN_DISTANCE_M = 6.0;

    var _counter = 0;
    var _tickcounter = 0;
    var _subSport = Activity.SUB_SPORT_GENERIC;

    function initialize(subSport) {
        View.initialize();
        if (subSport != null) {
            _subSport = subSport;
        }
        // _locationEventsEnabled = false;
        _startTimeSeconds = getNowSeconds();
        System.println("SessionView: initialize startTimeSeconds=" + _startTimeSeconds + " subSport=" + _subSport);
    }

    function onShow() as Void {
        if (!_hasStarted) {
            startSession();
            _hasStarted = true;
        }
        if (_timer == null) {
            _timer = new Timer.Timer();
            _timer.start(method(:onTick), 1000, true);
        }
    }

    function onHide() as Void {
        if (_timer != null) {
            _timer.stop();
            _timer = null;
        }
        // disableLocationEvents();
    }

    function onUpdate(dc as Dc) as Void {
        if (_currentPage == 0) {
            drawPageOne(dc);
        } else if (_currentPage == 1) {
            drawPageTwo(dc, _currentAltitudeMeters);
        } else if (_currentPage == 2) {
            drawPageThree(dc);
        } else {
            drawPageFour(dc);
        }
    }

    function onKey(keyEvent) {
        var key = keyEvent.getKey();
        System.println("SessionView: key pressed key=" + key);

        if (key == WatchUi.KEY_UP || key == WatchUi.KEY_DOWN) {
            var previous = _currentPage;
            if (key == WatchUi.KEY_UP) {
                _currentPage = (_currentPage + (PAGE_COUNT - 1)) % PAGE_COUNT;
                System.println("SessionView: UP pressed -> page " + _currentPage);
            } else {
                _currentPage = (_currentPage + 1) % PAGE_COUNT;
                System.println("SessionView: DOWN pressed -> page " + _currentPage);
            }

            if (previous != _currentPage) {
                System.println("SessionView: page changed -> " + _currentPage);
                WatchUi.requestUpdate();
            }
            return true;
        }

        var isPause = (key == WatchUi.KEY_START || key == WatchUi.KEY_ESC || key == 4 || key == 5);
        if (!isPause && (WatchUi has :KEY_ENTER) && key == WatchUi.KEY_ENTER) {
            isPause = true;
        }

        if (isPause) {
            System.println("SessionView: PAUSE pressed");

            pauseSession();
            System.println("SessionView: navigating to EndSessionView");
            var view = new EndSessionView(self);
            WatchUi.pushView(view, new EndSessionDelegate(view), WatchUi.SLIDE_IMMEDIATE);
            return true;
        }

        return false;
    }

    function onTick() as Void {
        try{
            _tickcounter++;

            var info = Position.getInfo();
            if (info != null && info.position != null) {
                updateAltitude(info);
                updateDistance(info);
            }

            updateMaxHeartRate();
            updateMaxSpeed();

            WatchUi.requestUpdate();
        }
        catch(e)
        {
            System.println(e.getErrorMessage());
        }
    }

    function startSession() as Void {
        _elapsedOffsetSeconds = 0;
        _isPaused = false;
        _totalAscentMeters = 0;
        _lastAltitudeSample = null;
        _totalDistanceMeters = 0;
        _lastCoords = null;
        _lastPositionLog = null;
        _trackPoints = [];
        _trackStarted = false;
        _trackOriginLat = null;
        _trackOriginLon = null;
        _trackCosOrigin = null;
        _trackMinX = null;
        _trackMaxX = null;
        _trackMinY = null;
        _trackMaxY = null;
        _trackCache = null;
        _trackCacheDirty = true;
        _trackCacheWidth = null;
        _trackCacheHeight = null;
        _lastTrackPointForCache = null;
        _maxHeartRate = 0;
        _maxSpeedMps = 0.0;
        _maxAltitudeMeters = null;
        _lastDistanceUpdateSeconds = null;
        _lastPositionEventSeconds = null;
        _lastPositionEventLogSeconds = null;

        Position.enableLocationEvents(Position.LOCATION_CONTINUOUS, method(:onPosition));

        if (_session == null) {
            try {
                _session = ActivityRecording.createSession({
                    :name => s(Rez.Strings.session_name),
                    :sport => Activity.SPORT_CROSS_COUNTRY_SKIING,
                    :subSport => _subSport
                });

                _session.start();
            } catch (e) {
                System.println("SessionView: createSession error -> " + e.getErrorMessage());
                _session = null;
            }
        }

        if (_session != null) {
        }

        System.println("SessionView: enableLocationEvents in startSession");

        // enableLocationEvents();
        // System.println("SessionView: session started");
    }

    function pauseSession() as Void {
        if (!_isPaused) {
            Position.enableLocationEvents(Position.LOCATION_DISABLE, null);
            _elapsedOffsetSeconds = getElapsedSeconds();
            _startTimeSeconds = null;
            _isPaused = true;
        }

        if (_timer != null) {
            _timer.stop();
            _timer = null;
        }

        if (_session != null) {
            _session.stop();
        }

        // disableLocationEvents();
        // System.println("SessionView: session paused");
    }

    function resumeSession() as Void {
        if (_isPaused) {
            Position.enableLocationEvents(Position.LOCATION_CONTINUOUS, method(:onPosition));
            _startTimeSeconds = getNowSeconds();
            _isPaused = false;
            _lastDistanceUpdateSeconds = null;
        }

        if (_session != null) {
            _session.start();
        }

        if (_timer == null) {
            _timer = new Timer.Timer();
            _timer.start(method(:onTick), 1000, true);
        }

    }

    function saveSessionAndExit() as Void {
        if (_timer != null) {
            _timer.stop();
            _timer = null;
        }

        if (_session != null) {
            Position.enableLocationEvents(Position.LOCATION_DISABLE, null);
            _session.stop();
                System.println("Start save: " + getTimeString());

            var success = _session.save();
                System.println("Finished save: " + getTimeString());

            if(success){
                System.println("SessionView: saving session, exiting in 2s");
                scheduleExit();
            }
        }

    }

    function discardSessionAndExit() as Void {
        if (_timer != null) {
            _timer.stop();
            _timer = null;
        }

        if (_session != null) {
            _session.stop();
            _session.discard();
        }

        System.println("SessionView: discarding session, exiting in 1s");
        scheduleExit();
    }

    function scheduleExit() as Void {
        if (_exitTimer != null) {
            _exitTimer.stop();
            _exitTimer = null;
        }

        _exitTimer = new Timer.Timer();
        _exitTimer.start(method(:exitAfterSave), 3000, false);
    }

    function exitAfterSave() as Void {
        if (_exitTimer != null) {
            _exitTimer.stop();
            _exitTimer = null;
        }
                System.println("Exit App: " + getTimeString());
        System.exit();
    }

    function drawPageOne(dc as Dc) as Void {
        var height = dc.getHeight();
        var rowHeight = height / 3;

        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);

        var elapsedSeconds = getElapsedSeconds();
        var distanceMeters = _totalDistanceMeters;
        if (elapsedSeconds != _lastElapsedSeconds) {
            _lastElapsedSeconds = elapsedSeconds;
        }

        if (distanceMeters != _lastDistanceMeters) {
            _lastDistanceMeters = distanceMeters;
        }

        var ascentMeters = getAscentMeters();
        if (ascentMeters != _lastAscentMeters) {
            _lastAscentMeters = ascentMeters;
        }

        // if (altitudeMeters != _lastAltitudeMeters) {
        //     _lastAltitudeMeters = altitudeMeters;
        // }

        var timeText = buildTimeString(elapsedSeconds);
        var distanceText = buildDistanceString(distanceMeters);
        // var altitudeText = buildAltitudeString(altitudeMeters);
        var ascentText = buildAscentString(ascentMeters);

        drawLabeledValue(dc, rowHeight / 2, s(Rez.Strings.session_label_time), timeText, Graphics.FONT_LARGE);
        drawLabeledValue(dc, rowHeight + (rowHeight / 2), s(Rez.Strings.session_label_distance), distanceText, Graphics.FONT_LARGE);
        // drawLabeledValue(dc, (rowHeight * 2) + (rowHeight / 2), s(Rez.Strings.session_label_altitude), altitudeText, Graphics.FONT_SMALL);
        drawLabeledValue(dc, (rowHeight * 2) + (rowHeight / 2), s(Rez.Strings.session_label_ascent), ascentText, Graphics.FONT_LARGE);
    }

    function drawPageTwo(dc as Dc, altitudeMeters) as Void {
        var height = dc.getHeight();
        var rowHeight = height / 3;

        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);

        var clockText = buildClockString();
        // var ascentMeters = getAscentMeters();
        var heartRate = getHeartRateBpm();

        // if (ascentMeters != _lastAscentMeters) {
        //     _lastAscentMeters = ascentMeters;
        // }

        if (altitudeMeters != _lastAltitudeMeters) {
            _lastAltitudeMeters = altitudeMeters;
        }

        System.println("SessionView: heart rate=" + heartRate);
        _lastHeartRate = heartRate;

        // var ascentText = buildAscentString(ascentMeters);
        var heartRateText = buildHeartRateString(heartRate);
        var altitudeText = buildAltitudeString(altitudeMeters);

        drawLabeledValue(dc, rowHeight / 2, s(Rez.Strings.session_label_clock), clockText, Graphics.FONT_LARGE);
        // drawLabeledValue(dc, rowHeight + (rowHeight / 2), s(Rez.Strings.session_label_ascent), ascentText, Graphics.FONT_LARGE);
        drawLabeledValue(dc, rowHeight + (rowHeight / 2), s(Rez.Strings.session_label_altitude), altitudeText, Graphics.FONT_SMALL);
        drawLabeledValue(dc, (rowHeight * 2) + (rowHeight / 2), s(Rez.Strings.session_label_pulse), heartRateText, Graphics.FONT_SMALL);
    }

    function drawPageThree(dc as Dc) as Void {
        var height = dc.getHeight();
        var rowHeight = height / 3;
        var width = dc.getWidth();
        // var topCenterY = height / 8;
        // var middleCenterY = height / 2;
        // var bottomCenterY = (height * 7) / 8;
        var leftCenterX = width / 4;
        var rightCenterX = (width * 3) / 4;

        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);

        drawLabeledValue(dc, rowHeight / 2, s(Rez.Strings.session_label_max_pulse), buildHeartRateString(_maxHeartRate), Graphics.FONT_LARGE);
        drawLabeledValueAtX(dc, leftCenterX, rowHeight + (rowHeight / 2), s(Rez.Strings.session_label_max_speed), buildSpeedString(_maxSpeedMps), Graphics.FONT_MEDIUM);
        drawLabeledValueAtX(dc, rightCenterX, rowHeight + (rowHeight / 2), s(Rez.Strings.session_label_avg_speed), buildSpeedString(getAverageSpeedMps()), Graphics.FONT_MEDIUM);
        drawLabeledValue(dc, (rowHeight * 2) + (rowHeight / 2), s(Rez.Strings.session_label_max_altitude), buildAltitudeString(_maxAltitudeMeters), Graphics.FONT_LARGE);
    }

    function drawPageFour(dc as Dc) as Void {
        var width = dc.getWidth();
        var height = dc.getHeight();

        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        if (_trackPoints.size() < 2 || _trackMinX == null || _trackMaxX == null || _trackMinY == null || _trackMaxY == null) {
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
            dc.drawText(width / 2, height / 2, Graphics.FONT_SMALL, "Track", Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            return;
        }

        ensureTrackCache(width, height);

        if (_trackCache != null) {
            dc.drawBitmap(0, 0, _trackCache);
        } else {
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
            dc.drawText(width / 2, height / 2, Graphics.FONT_SMALL, "Track", Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        }
    }

    function ensureTrackCache(width, height) as Void {
        if (!_trackCacheDirty
            && _trackCache != null
            && _trackCacheWidth == width
            && _trackCacheHeight == height
            && _trackCache.isCached()) {
            return;
        }

        _trackCacheWidth = width;
        _trackCacheHeight = height;

        var cacheOptions = {
            :width => width,
            :height => height
        };

        if (Graphics has :createBufferedBitmap) {
            _trackCache = Graphics.createBufferedBitmap(cacheOptions).get() as BufferedBitmap;
        } else if (Graphics has :BufferedBitmap) {
            _trackCache = new Graphics.BufferedBitmap(cacheOptions);
        } else {
            _trackCache = null;
        }

        if (_trackCache == null) {
            _trackCacheDirty = false;
            return;
        }

        var cacheDc = _trackCache.getDc();
        var margin = 10;

        cacheDc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        cacheDc.clear();

        var rangeX = _trackMaxX - _trackMinX;
        var rangeY = _trackMaxY - _trackMinY;
        if (rangeX < 1.0) { rangeX = 1.0; }
        if (rangeY < 1.0) { rangeY = 1.0; }

        var drawW = width - (margin * 2);
        var drawH = height - (margin * 2);
        var scaleX = drawW / rangeX;
        var scaleY = drawH / rangeY;
        var scale = (scaleX < scaleY) ? scaleX : scaleY;
        scale = scale * 0.85;

        var contentW = rangeX * scale;
        var contentH = rangeY * scale;
        var offsetX = (width - contentW) / 2;
        var offsetY = (height - contentH) / 2;

        cacheDc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        var i = 1;
        while (i < _trackPoints.size()) {
            var a = _trackPoints[i - 1];
            var b = _trackPoints[i];

            var ax = projectTrackX(a);
            var ay = projectTrackY(a);
            var bx = projectTrackX(b);
            var by = projectTrackY(b);

            var x1 = offsetX + ((ax - _trackMinX) * scale);
            var y1 = (height - offsetY) - ((ay - _trackMinY) * scale);
            var x2 = offsetX + ((bx - _trackMinX) * scale);
            var y2 = (height - offsetY) - ((by - _trackMinY) * scale);

            cacheDc.drawLine(x1, y1, x2, y2);
            i += 1;
        }

        var startPoint = _trackPoints[0];
        var sx = offsetX + ((projectTrackX(startPoint) - _trackMinX) * scale);
        var sy = (height - offsetY) - ((projectTrackY(startPoint) - _trackMinY) * scale);

        cacheDc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        cacheDc.drawLine(sx, sy - 14, sx, sy + 3);
        cacheDc.setColor(Graphics.COLOR_GREEN, Graphics.COLOR_GREEN);
        cacheDc.fillRectangle(sx + 1, sy - 14, 20, 12);

        _trackCacheDirty = false;
    }

    function drawLabeledValue(dc as Dc, centerY, label, value, valueFont) as Void {
        var width = dc.getWidth();
        var labelFont = Graphics.FONT_TINY;
        var gap = 4;

        var labelH = dc.getFontHeight(labelFont);
        var valueH = dc.getFontHeight(valueFont);

        var blockH = labelH + gap + valueH;
        var topY = centerY - (blockH / 2);

        var labelY = topY + (labelH / 2);
        var valueY = topY + labelH + gap + (valueH / 2);

        dc.drawText(width / 2, labelY, labelFont, label, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.drawText(width / 2, valueY, valueFont, value, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    function drawLabeledValueAtX(dc as Dc, centerX, centerY, label, value, valueFont) as Void {
        var labelFont = Graphics.FONT_TINY;
        var kmFont = Graphics.FONT_XTINY;
        var gap = 3;
        var labelH = dc.getFontHeight(labelFont);
        var valueH = dc.getFontHeight(valueFont);
        var kmH = dc.getFontHeight(kmFont);
        var blockH = labelH + gap + valueH + gap + kmH;
        var topY = centerY - (blockH / 3) - kmH;
        var labelY = topY + (labelH / 2);
        var valueY = topY + labelH + gap + (valueH / 2);
        var kmY = topY + labelH + gap + valueH + gap + (kmH / 2);

        dc.drawText(centerX, labelY, labelFont, label, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.drawText(centerX, valueY, valueFont, value, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.drawText(centerX, kmY, kmFont, "(km/h)", Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }



    function getNowSeconds() {
        var now = System.getClockTime();
        return (now.hour * 3600) + (now.min * 60) + now.sec;
    }

    function getTimeString() {
        var now = System.getClockTime();
        return now.hour.toString() + ":" + now.min.toString() + ":" + now.sec.toString();
    }

    function getElapsedSeconds() {
        if (_startTimeSeconds == null) {
            return _elapsedOffsetSeconds;
        }

        var nowSeconds = getNowSeconds();
        var elapsedSeconds = nowSeconds - _startTimeSeconds;
        if (elapsedSeconds < 0) {
            elapsedSeconds += 24 * 3600;
        }

        return _elapsedOffsetSeconds + elapsedSeconds;
    }

    function buildTimeString(elapsedSeconds) {
        var minutes = Math.floor(elapsedSeconds / 60);
        var seconds = Math.floor(elapsedSeconds % 60);
        var secondsText = (seconds < 10) ? ("0" + seconds) : ("" + seconds);
        return "" + minutes + ":" + secondsText;
    }

    function buildDistanceString(distanceMeters) {
        if (distanceMeters == null) {
            return "-- km";
        }

        var km = distanceMeters / 1000.0;
        if (km >= 10.0) {
            var kmTimes10 = (km * 10.0 + 0.5).toNumber();
            var kmInt = Math.floor(kmTimes10 / 10);
            var kmFrac = kmTimes10 % 10;
            return "" + kmInt + "." + kmFrac + " km";
        } else {
            var kmTimes100 = (km * 100.0 + 0.5).toNumber();
            var kmInt100 = Math.floor(kmTimes100 / 100);
            var kmFrac100 = kmTimes100 % 100;
            var fracText = (kmFrac100 < 10) ? ("0" + kmFrac100) : ("" + kmFrac100);
            return "" + kmInt100 + "." + fracText + " km";
        }
    }

    // function updateAltitude(info as Activity.Info) {
    function updateAltitude(info as Position.Info) {
        var rawAlt = info.altitude;
        var accuracy = info.accuracy; //.currentLocationAccuracy;

        if (rawAlt == null) {
            return null;
        }

        if (rawAlt != _lastRawAltitude || accuracy != _lastAltAccuracy) {
            _lastRawAltitude = rawAlt;
            _lastAltAccuracy = accuracy;
        }

        var altitudeMeters = (rawAlt + 0.5).toNumber();
        if (altitudeMeters > 10000 || altitudeMeters < -500) {
            return null;
        }

        if (_lastAltitudeSample != null && altitudeMeters > _lastAltitudeSample) {
            var ascentDelta = altitudeMeters - _lastAltitudeSample;
            if (ascentDelta < 8) {
                _totalAscentMeters += ascentDelta;
            }
        }

        _lastAltitudeSample = altitudeMeters;
        _currentAltitudeMeters = altitudeMeters;
        if (_maxAltitudeMeters == null || altitudeMeters > _maxAltitudeMeters) {
            _maxAltitudeMeters = altitudeMeters;
        }

        return altitudeMeters;
    }

    // function updateDistance(info as Activity.Info) as Void {
    //     if (_lastPositionLog != null && info.currentLocation != null) {
    //         var delta = distanceBetweenTwoPointsMeters(_lastPositionLog, info.currentLocation);
    //         _totalDistanceMeters += delta;
    //     }

    //     if(info.currentLocation != null){
    //         _lastPositionLog = copyLocation(info.currentLocation);
    //     }
    // }

    function updateDistance(info as Position.Info) as Void {
        if (info.position == null) {
            return;
        }

        var current = copyLocation(info.position);
        if (current == null) {
            return;
        }

        if (_lastPositionLog != null) {
            var delta = distanceBetweenCoordsMeters(_lastPositionLog, current);
            if (delta > TRACK_POINT_MIN_DISTANCE_M && delta < 30.0) {
                _totalDistanceMeters += delta;

                if (!_trackStarted && _totalDistanceMeters > 10.0) {
                    _trackStarted = true;
                    addTrackPoint(_lastPositionLog);
                    addTrackPoint(current);
                    initTrackBounds(_lastPositionLog);
                    updateTrackBounds(current);
                    System.println("SessionView: track started at distance=" + _totalDistanceMeters);
                } else if (_trackStarted) {
                    addTrackPoint(current);
                    updateTrackBounds(current);
                }
            }
        }

        _lastPositionLog = current;
    }

    function addTrackPoint(point as Coord?) as Void {
        if (point == null) {
            return;
        }

        if (_lastTrackPointForCache != null) {
            var separation = distanceBetweenCoordsMeters(_lastTrackPointForCache, point);
            if (separation < TRACK_POINT_MIN_DISTANCE_M) {
                return;
            }
        }

        _trackPoints.add(point);
        _lastTrackPointForCache = point;
        _trackCacheDirty = true;
    }

    function distanceBetweenTwoPointsMeters(a as Coord, b as Position.Location) {

        try {
            var R = 6371000.0; // meter

            // var aRad = a.toRadians();
            var bRad = b.toRadians();

            var lat1 = a.lat;
            var lon1 = a.lon;
            var lat2 = bRad[0];
            var lon2 = bRad[1];

            var dLat = lat2 - lat1;
            var dLon = lon2 - lon1;

            var sinLat = Math.sin(dLat / 2.0);
            var sinLon = Math.sin(dLon / 2.0);

            var h =
                sinLat * sinLat +
                Math.cos(lat1) * Math.cos(lat2) *
                sinLon * sinLon;

            var c = 2.0 * Math.atan2(Math.sqrt(h), Math.sqrt(1.0 - h));

            _lastDeltaMeters = (R * 10 * c).toString();
            return R * c; // ??? meter
        }
        catch (e) {
            return 0.0;
        }
    }

    function copyLocation(pos as Position.Location) {
        var rad = pos.toRadians();
        if (rad == null || rad.size() < 2) {
            return null;
        }

        return new Coord(rad[0], rad[1]);
    }

    function initTrackBounds(firstPoint as Coord?) as Void {
        if (firstPoint == null) {
            return;
        }

        _trackOriginLat = firstPoint.lat;
        _trackOriginLon = firstPoint.lon;
        _trackCosOrigin = Math.cos(_trackOriginLat);

        var x = projectTrackX(firstPoint);
        var y = projectTrackY(firstPoint);
        _trackMinX = x;
        _trackMaxX = x;
        _trackMinY = y;
        _trackMaxY = y;
    }

    function updateTrackBounds(point as Coord?) as Void {
        if (point == null) {
            return;
        }
        if (_trackOriginLat == null || _trackOriginLon == null) {
            initTrackBounds(point);
            return;
        }

        var x = projectTrackX(point);
        var y = projectTrackY(point);
        if (_trackMinX == null || x < _trackMinX) { _trackMinX = x; }
        if (_trackMaxX == null || x > _trackMaxX) { _trackMaxX = x; }
        if (_trackMinY == null || y < _trackMinY) { _trackMinY = y; }
        if (_trackMaxY == null || y > _trackMaxY) { _trackMaxY = y; }
    }

    function projectTrackX(point as Coord) {
        var earthR = 6371000.0;
        return (point.lon - _trackOriginLon) * _trackCosOrigin * earthR;
    }

    function projectTrackY(point as Coord) {
        var earthR = 6371000.0;
        return (point.lat - _trackOriginLat) * earthR;
    }

    function distanceBetweenCoordsMeters(a as Coord, b as Coord) {
        if (a == null || b == null) {
            return 0.0;
        }

        try {
            var R = 6371000.0;
            var dLat = b.lat - a.lat;
            var dLon = b.lon - a.lon;
            var sinLat = Math.sin(dLat / 2.0);
            var sinLon = Math.sin(dLon / 2.0);
            var h = (sinLat * sinLat) + Math.cos(a.lat) * Math.cos(b.lat) * (sinLon * sinLon);
            var c = 2.0 * Math.atan2(Math.sqrt(h), Math.sqrt(1.0 - h));
            return R * c;
        } catch (e) {
            return 0.0;
        }
    }

    function absVal(value) {
        return (value < 0) ? -value : value;
    }

    function normalizeCoord(value) {
        if (value == null) {
            return 0;
        }

        var v = value;
        if (absVal(v) > 180) {
            v = (v * 180.0) / 2147483648.0;
        }

        if (absVal(v) > 3.5) {
            v = Math.toRadians(v);
        }

        return v;
    }

    function getLatLonFromInfo(info) {
        if (info == null) {
            return null;
        }

        if (info has :position) {
            var coords = getLatLon(info.position);
            if (coords != null) {
                return coords;
            }
        }
        if (info has :location) {
            var coords2 = getLatLon(info.location);
            if (coords2 != null) {
                return coords2;
            }
        }
        if ((info has :latitude) && (info has :longitude)) {
            return new Coord(info.latitude, info.longitude);
        }
        if ((info has :lat) && (info has :lon)) {
            return new Coord(info.lat, info.lon);
        }

        return null;
    }

    function getLatLon(pos) {
        if (pos == null) {
            return null;
        }

        if ((pos has :latitude) && (pos has :longitude)) {
            return new Coord(pos.latitude, pos.longitude);
        }
        if ((pos has :lat) && (pos has :lon)) {
            return new Coord(pos.lat, pos.lon);
        }
        if (pos has :toDegrees) {
            var deg = pos.toDegrees();
            if (deg != null && (deg has :lat) && (deg has :lon)) {
                return new Coord(deg.lat, deg.lon);
            }
            if (deg != null && (deg has :latitude) && (deg has :longitude)) {
                return new Coord(deg.latitude, deg.longitude);
            }
        }

        return null;
    }

    function updateDistanceFromSpeed(info) {
        if (info == null || !(info has :speed) || info.speed == null) {
            return;
        }

        var nowSeconds = getNowSeconds();
        if (_lastDistanceUpdateSeconds == null) {
            _lastDistanceUpdateSeconds = nowSeconds;
            return;
        }

        var deltaSeconds = nowSeconds - _lastDistanceUpdateSeconds;
        if (deltaSeconds < 0) {
            deltaSeconds += 24 * 3600;
        }

        var deltaMeters = info.speed * deltaSeconds;
        if (deltaMeters > 0) {
            _totalDistanceMeters += deltaMeters;
            System.println("SessionView: distance speed mps=" + info.speed + " delta=" + deltaMeters + " total=" + _totalDistanceMeters);
        }

        _lastDistanceUpdateSeconds = nowSeconds;
    }

    function buildAltitudeString(altitudeMeters) {
        if (altitudeMeters == null) {
            return "-- m";
        }

        return "" + altitudeMeters + " m";
    }

    function getAscentMeters() {
        return _totalAscentMeters;
    }

    function buildAscentString(ascentMeters) {
        if (ascentMeters == null) {
            return "-- m";
        }

        return "" + ascentMeters + " m";
    }

    function getHeartRateBpm() {
        var info = Sensor.getInfo();
        if (info == null || info.heartRate == null) {
            return null;
        }

        return info.heartRate;
    }

    function buildHeartRateString(heartRate) {
        if (heartRate == null) {
            return "--";
        }

        return "" + heartRate;
    }

    function buildClockString() {
        var now = System.getClockTime();
        var hours = now.hour;
        var minutes = now.min;
        var minutesText = (minutes < 10) ? ("0" + minutes) : ("" + minutes);
        return "" + hours + ":" + minutesText;
    }

    function updateMaxHeartRate() as Void {
        var hr = getHeartRateBpm();
        if (hr != null && hr > _maxHeartRate) {
            _maxHeartRate = hr;
        }
    }

    function updateMaxSpeed() as Void {
        var activityInfo = Activity.getActivityInfo();
        if (activityInfo == null) {
            return;
        }

        var speed = null;
        if (activityInfo has :currentSpeed) {
            speed = activityInfo[:currentSpeed];
        } else if (activityInfo has :speed) {
            speed = activityInfo[:speed];
        }

        if (speed != null && speed > _maxSpeedMps) {
            _maxSpeedMps = speed;
        }
    }

    function getAverageSpeedMps() {
        var elapsed = getElapsedSeconds();
        if (elapsed <= 0) {
            return 0.0;
        }
        return _totalDistanceMeters / elapsed;
    }

    function buildSpeedString(speedMps) {
        if (speedMps == null) {
            return "--";
        }
        var kmh = speedMps * 3.6;
        var kmh10 = (kmh * 10.0 + 0.5).toNumber();
        var kmhInt = Math.floor(kmh10 / 10);
        var kmhFrac = kmh10 % 10;
        return "" + kmhInt + "." + kmhFrac;
    }

    function buildDeltaString(deltaMeters) {
        if (deltaMeters == null) {
            return "-- m";
        }
        else
        {
            return _lastDeltaMeters;
        }

    }

    function s(id) {
        return WatchUi.loadResource(id);
    }

    function onPosition(info as Position.Info) as Void {
        // System.println("SessionView: onPosition");
        _counter++;
        
        if (info.position == null) {
            return;
        }

        // Distance/altitude updates are handled in onTick to avoid double counting.

    }
}


