// Copyright (C) 2026 Renzard Politakis.
// This program is licensed under the GNU Affero General Public License v3
// or any later version. See the LICENSE file for details.

import QtQuick 2.7
import Lomiri.Components 1.3
import "../themes"

// Rounded settings row of the "Onyx" / "Emerald" themes: title + subtitle on the
// left, optional trailing item (switch, tick...) or chevron on the right.
Item {
    id: row
    property string skin: "onyx"
    property string title: ""
    property string subtitle: ""
    property bool chevron: false
    property bool pressable: true
    default property alias trailing: slot.data
    signal clicked()

    height: units.gu(9.2)

    SkinColors { id: c; skin: row.skin }

    Rectangle {
        anchors { fill: parent; topMargin: units.gu(0.6); bottomMargin: units.gu(0.6) }
        radius: c.cardRadius
        border.width: units.dp(1)
        border.color: (area.pressed && row.pressable) ? c.pressedBorder : c.border
        gradient: Gradient {
            GradientStop { position: 0; color: (area.pressed && row.pressable) ? c.cardPressed : c.cardTop }
            GradientStop { position: 1; color: (area.pressed && row.pressable) ? c.cardPressed : c.cardBottom }
        }
        scale: (area.pressed && row.pressable) ? 0.98 : 1
        Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

        Column {
            anchors { left: parent.left; leftMargin: units.gu(2.2); right: slot.left; rightMargin: row.chevron ? units.gu(5) : units.gu(1)
                      verticalCenter: parent.verticalCenter }
            spacing: units.gu(0.4)
            Label { width: parent.width; text: row.title; font.bold: true; fontSize: "medium"
                    color: c.text; elide: Text.ElideRight }
            Label { width: parent.width; text: row.subtitle; visible: text !== ""; fontSize: "x-small"
                    color: c.secondaryText; wrapMode: Text.WordWrap; maximumLineCount: 2; elide: Text.ElideRight }
        }
        Item {
            id: slot
            anchors { right: parent.right; rightMargin: units.gu(2); verticalCenter: parent.verticalCenter }
            width: childrenRect.width; height: childrenRect.height
        }
        Icon {
            visible: row.chevron
            anchors { right: parent.right; rightMargin: units.gu(2); verticalCenter: parent.verticalCenter }
            width: units.gu(2.2); height: width; name: "go-next"; color: c.secondaryText
        }
    }
    MouseArea { id: area; anchors.fill: parent; enabled: row.pressable; onClicked: row.clicked() }
}
