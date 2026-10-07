// Copyright (C) 2026 Renzard Politakis.
// This program is licensed under the GNU Affero General Public License v3
// or any later version. See the LICENSE file for details.

import QtQuick 2.7
import Lomiri.Components 1.3
import "../themes"

// Rounded card row used by the "Emerald" theme: letter tile, title, subtitle.
Item {
    id: item
    property string uuid: ""
    property string title: ""
    property string subtitle: ""
    property int order: 0
    property int run: 1

    signal entryClicked(string uuid)
    signal entryLongPressed(string uuid)

    height: units.gu(9.5)

    EmeraldColors { id: c }

    opacity: ap.progress
    transform: Translate { x: ap.offset }
    Appear { id: ap; run: item.run; delay: 60 + Math.min(item.order, 8) * 60
             distance: units.gu(3); duration: 420 }

    Rectangle {
        anchors { fill: parent; topMargin: units.gu(0.6); bottomMargin: units.gu(0.6) }
        radius: units.gu(1.8)
        color: area.pressed ? c.cardPressed : c.card
        border.width: units.dp(1)
        border.color: area.pressed ? c.accent : c.border
        Behavior on color { ColorAnimation { duration: 140 } }
        Behavior on border.color { ColorAnimation { duration: 140 } }
        scale: area.pressed ? 0.98 : 1
        Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

        Rectangle {
            id: tile
            anchors { left: parent.left; leftMargin: units.gu(1.6); verticalCenter: parent.verticalCenter }
            width: units.gu(5.2); height: width; radius: units.gu(1.5)
            color: c.tile
            Label {
                anchors.centerIn: parent
                text: item.title.length ? item.title.charAt(0).toUpperCase() : "?"
                font.bold: true; fontSize: "large"
                color: c.accent
            }
        }
        Column {
            anchors { left: tile.right; leftMargin: units.gu(1.6); right: parent.right
                      rightMargin: units.gu(1.5); verticalCenter: parent.verticalCenter }
            spacing: units.gu(0.4)
            Label { width: parent.width; text: item.title; font.bold: true; fontSize: "medium"
                    color: c.text; elide: Text.ElideRight }
            Label { width: parent.width; text: item.subtitle; fontSize: "x-small"
                    color: c.secondaryText; elide: Text.ElideRight }
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        onClicked: item.entryClicked(item.uuid)
        onPressAndHold: item.entryLongPressed(item.uuid)
    }
}
