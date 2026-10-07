// Copyright (C) 2026 Renzard Politakis.
// This program is licensed under the GNU Affero General Public License v3
// or any later version. See the LICENSE file for details.

import QtQuick 2.7
import "../themes"

// Toggle for the "Onyx" / "Emerald" themes (accent track + dark knob when on).
Item {
    id: sw
    property string skin: "onyx"
    property bool checked: false
    signal clicked()

    width: units.gu(6); height: units.gu(3.4)

    SkinColors { id: c; skin: sw.skin }

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: sw.checked ? c.accent : c.track
        Behavior on color { ColorAnimation { duration: 180 } }
        Rectangle {
            width: parent.height - units.gu(0.8); height: width; radius: width / 2
            anchors.verticalCenter: parent.verticalCenter
            x: sw.checked ? parent.width - width - units.gu(0.4) : units.gu(0.4)
            color: sw.checked ? c.accentText : c.secondaryText
            Behavior on x { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
            Behavior on color { ColorAnimation { duration: 180 } }
        }
    }
    MouseArea { anchors.fill: parent; anchors.margins: -units.gu(1); onClicked: sw.clicked() }
}
