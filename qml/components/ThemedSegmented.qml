// Copyright (C) 2026 Renzard Politakis.
// This program is licensed under the GNU Affero General Public License v3
// or any later version. See the LICENSE file for details.

import QtQuick 2.7
import Lomiri.Components 1.3
import "../themes"

// Segmented selector (e.g. 1 / 5 / 15 min). `skin` is "onyx", "emerald",
// "aegis" or "bitwarden" for the custom themes, or "" for the plain Lomiri look.
Item {
    id: seg
    property string skin: "onyx"
    // [ { label: "1 min", value: 1 }, ... ]
    property var options: []
    property var currentValue
    signal picked(var value)

    readonly property bool plain: skin === ""
    readonly property int currentIndex: indexOfValue(currentValue)

    height: units.gu(4.6)

    function indexOfValue(v) {
        for (var i = 0; i < options.length; i++) {
            if (options[i].value === v) return i;
        }
        return -1;
    }

    SkinColors { id: c; skin: seg.plain ? "onyx" : seg.skin }

    readonly property color trackColor:  plain ? theme.palette.normal.base : c.track
    readonly property color accentColor: plain ? theme.palette.normal.focus : c.accent
    readonly property color onAccent:    plain ? "#ffffff" : c.accentText
    readonly property color idleText:    plain ? theme.palette.normal.baseText : c.secondaryText

    Rectangle {
        id: track
        anchors.fill: parent
        radius: seg.plain ? units.gu(1) : height / 2
        color: seg.trackColor

        readonly property real pad: units.gu(0.4)
        readonly property real segWidth: (width - 2 * pad) / Math.max(1, seg.options.length)

        // Sliding highlight behind the selected option
        Rectangle {
            visible: seg.currentIndex >= 0
            y: track.pad
            height: parent.height - 2 * track.pad
            width: track.segWidth
            x: track.pad + Math.max(0, seg.currentIndex) * track.segWidth
            radius: seg.plain ? units.gu(0.7) : height / 2
            color: seg.accentColor
            Behavior on x { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
        }

        Row {
            x: track.pad
            y: track.pad
            height: parent.height - 2 * track.pad
            Repeater {
                model: seg.options
                delegate: Item {
                    width: track.segWidth
                    height: parent.height
                    Label {
                        anchors.centerIn: parent
                        text: modelData.label
                        fontSize: "small"
                        font.bold: index === seg.currentIndex
                        color: index === seg.currentIndex ? seg.onAccent : seg.idleText
                        Behavior on color { ColorAnimation { duration: 180 } }
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: seg.picked(modelData.value)
                    }
                }
            }
        }
    }
}
