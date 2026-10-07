// Copyright (C) 2026 Renzard Politakis.
// This program is licensed under the GNU Affero General Public License v3
// or any later version. See the LICENSE file for details.

import QtQuick 2.7
import "../themes"

// Integer slider for the "Onyx" / "Emerald" themes. Emits moved(newValue) while dragging.
Item {
    id: sl
    property string skin: "onyx"
    property real minimumValue: 0
    property real maximumValue: 100
    property real value: 0
    signal moved(int newValue)

    height: units.gu(4)

    SkinColors { id: c; skin: sl.skin }

    readonly property real knob: units.gu(2.8)
    readonly property real fraction: (value - minimumValue) / (maximumValue - minimumValue)

    Rectangle {
        id: track
        anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter }
        height: units.gu(0.7); radius: height / 2
        color: c.track
        Rectangle {
            width: sl.knob / 2 + sl.fraction * (parent.width - sl.knob)
            height: parent.height; radius: height / 2
            color: c.accent
        }
    }
    Rectangle {
        width: sl.knob; height: width; radius: width / 2
        anchors.verticalCenter: parent.verticalCenter
        x: sl.fraction * (sl.width - sl.knob)
        color: c.accent
        scale: area.pressed ? 1.15 : 1
        Behavior on scale { NumberAnimation { duration: 120 } }
    }

    function setFromX(mx) {
        var f = Math.max(0, Math.min(1, (mx - knob / 2) / (width - knob)));
        var v = Math.round(minimumValue + f * (maximumValue - minimumValue));
        if (v !== Math.round(value)) moved(v);
    }
    MouseArea {
        id: area
        anchors.fill: parent
        onPressed: sl.setFromX(mouse.x)
        onPositionChanged: if (pressed) sl.setFromX(mouse.x)
    }
}
