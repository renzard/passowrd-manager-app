// Copyright (C) 2026 Renzard Politakis.
// This program is licensed under the GNU Affero General Public License v3
// or any later version. See the LICENSE file for details.

import QtQuick 2.7
import Lomiri.Components 1.3
import "../themes"

// Button shared by the "Onyx" (pill) and "Emerald" (rounded) themes.
// primary = solid accent colour, otherwise card-coloured.
Item {
    id: btn
    property string skin: "onyx"
    property string text: ""
    property string iconName: ""
    property bool primary: false
    signal clicked()

    implicitHeight: units.gu(5.6)
    implicitWidth: units.gu(14)
    height: implicitHeight

    SkinColors { id: c; skin: btn.skin }

    Rectangle {
        anchors.fill: parent
        radius: c.pillRadius(height)
        border.width: btn.primary ? 0 : units.dp(1)
        border.color: c.border
        color: btn.primary ? (area.pressed ? c.accentPressed : c.accent) : "transparent"
        gradient: btn.primary ? (area.pressed ? null : primaryGrad) : plain
        scale: area.pressed ? 0.96 : 1
        Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
        Behavior on color { ColorAnimation { duration: 120 } }

        Gradient {
            id: primaryGrad
            GradientStop { position: 0; color: c.accentTop }
            GradientStop { position: 1; color: c.accent }
        }
        Gradient {
            id: plain
            GradientStop { position: 0; color: area.pressed ? c.cardPressed : c.cardTop }
            GradientStop { position: 1; color: area.pressed ? c.cardPressed : c.cardBottom }
        }

        Row {
            anchors.centerIn: parent
            spacing: units.gu(1)
            Icon {
                visible: btn.iconName !== ""
                anchors.verticalCenter: parent.verticalCenter
                width: units.gu(2.2); height: width
                name: btn.iconName
                color: btn.primary ? c.accentText : c.text
            }
            Label {
                visible: btn.text !== ""
                anchors.verticalCenter: parent.verticalCenter
                text: btn.text
                font.bold: true
                fontSize: "small"
                color: btn.primary ? c.accentText : c.text
            }
        }
    }
    MouseArea { id: area; anchors.fill: parent; onClicked: btn.clicked() }
}
